# Phase 3 -- Power Automate Build (Sandbox)

Action-by-action rebuild of the original Senversa flow in the `APdatademo.onmicrosoft.com` tenant. No import zip is required -- the flow is built from scratch in the Power Automate UI at https://make.powerautomate.com/. Sign in as an APdatademo admin (`gp@APdatademo.onmicrosoft.com`).

The reference JSON is the `Foreach` block in `claude.md` (section: "What I Built at Senversa"). This guide preserves every original action, remaps the sandbox-specific targets, adds the Graph API calls that were blocked in the original build, and documents every deviation from the planned build encountered during construction.

---

## Reference IDs

| Thing | Value |
| --- | --- |
| Tenant | `APdatademo.onmicrosoft.com` |
| Shared mailbox | `sharedinbox@APdatademo.onmicrosoft.com` |
| SharePoint site URL | `https://APdatademo.sharepoint.com/sites/aptrackerdem` |
| SharePoint site ID (Python) | see `.env` (SHAREPOINT_SITE_ID) |
| SharePoint site GUID (Graph HTTP) | see `.env` (SHAREPOINT_SITE_ID -- first GUID segment) |
| SharePoint list name | `Approval Tracker` |
| SharePoint list ID | see `.env` (SHAREPOINT_LIST_ID) |
| App Registration client ID | see `.env` (AZURE_CLIENT_ID) |
| App Registration client secret | see `credentials.txt` (expires 2026-07-14) |

---

## Original vs sandbox -- what changes and why

| Element | Original (Senversa) | Sandbox | Reason |
| --- | --- | --- | --- |
| Mailbox | `supplieraccounts@senversa.com.au` | `sharedinbox@APdatademo.onmicrosoft.com` | new tenant |
| SharePoint dataset | `senversa-my.sharepoint.com/personal/george_potter_...` (personal OneDrive) | `APdatademo.sharepoint.com/sites/aptrackerdem` (team site) | proper shared site vs. personal OneDrive kludge |
| SharePoint list ID | `01e16776-1b1c-4c78-a3ec-89797e8386b0` | see `.env` (SHAREPOINT_LIST_ID) | new list |
| Subject condition | `contains(toLower(...), 'invoice')` | same, plus excludes `RE:` and `FW:` replies | eliminates duplicate writes on reply chains |
| Cycle time | ticks expression, hours + days | unchanged | preserves original behaviour; Python mirror lives in `src/cycle_time.py` |
| Dedup | SharePoint connector `Get items` on EmailID | Graph API HTTP call on EmailID -- bypasses connector-level caching | SharePoint connector caches `Get items` responses at the platform level (`x-ms-apihub-cached-response: true`), causing false positive duplicate detections; direct HTTP is cache-free |
| `ThreadMessageCount` | schema column, unpopulated (IT blocked Graph access) | populated via Graph HTTP -- all-mailbox scope | **headline Phase 3 gap closure**; scope extended beyond inbox to include sent replies |
| `ApproverCategory` | connector field unavailable (IT blocked Graph access) | populated via dedicated Graph HTTP message detail call | **planned to use V3 connector field -- V3 and V2 connector responses do not return `categories`; Graph HTTP required** |
| `ApprovalStatus` | not in schema | dynamic on Create and Update -- `Unopened` / `flagged` / `complete` derived from `isRead` and Outlook flag state | **original expression mapped all `notFlagged` emails to `Unopened` regardless of read status -- corrected to use `isRead` for Unopened determination** |
| `ConversationID` | not captured | populated from V2 email body | new sandbox field |
| `ApproverName`, `ComplianceStatus`, `SupplierRisk`, `AnomalyFlag`, `AnomalyReason` | not in schema | left unset by this flow | populated by Make.com in Phase 4 |
| Graph token | none (IT blocked) | fetched once per flow run, reused inside the loop | avoids hammering `/token` per iteration |

---

## Note on email count -- 36 of 40 is correct

The sandbox inbox contains 40 emails. The flow will process 36 of them. This is by design, not a bug.

The 4 excluded emails are the reply chain types sent by `07_send_test_emails.ps1`:

- `RE: Invoice HEG-0571` (seq 6)
- `RE: Invoice BPC-1187` (seq 11)
- `RE: Invoice CES-3325` (seq 14)
- `FW: Invoice ASW-7741` (seq 38)

Condition 1 filters these out with the `not(startsWith(..., 're:'))` / `not(startsWith(..., 'fw:'))` clauses. They were sent specifically to prove the filter works -- they should not produce SharePoint rows and they will not.

---

## Flow structure

```
Recurrence (15 min)
  |
HTTP: Get Graph token                           <-- new, outside loop
  |
Parse JSON: token                               <-- new
  |
Get emails (V3)
  |
Apply to each  (body/value)
  |
  Condition 1 -- subject contains 'invoice' AND not a reply/forward
    |
    (True) Get email (V2)
      |
      HTTP: Get message details                 <-- new: Graph call for flag + categories
      |
      Parse JSON: message details               <-- new
      |
      Current time
      |
      Compose          (hours)
      |
      Compose 2        (days)
      |
      HTTP: Get thread count                    <-- new, all-mailbox scope
      |
      Parse JSON: thread count                  <-- new
      |
      HTTP: Check duplicate                     <-- replaces SharePoint Get items
      |
      Parse JSON: dedup result                  <-- new
      |
      Condition 2 -- length = 0
        |
        (True)  Create item                     (12 mapped fields)
        |
        (False) Update item                     (ThreadMessageCount, ApproverCategory, ApprovalStatus)
```

---

## Note on HTTP header values -- expression vs plain text

Every HTTP action in this flow has headers. The rule for how to enter them:

- `Authorization` -- **Expression tab**. Paste the expression without the `@{...}` wrapper; Power Automate adds it on save.
- `Accept`, `ConsistencyLevel`, `Prefer`, `Content-Type` -- **plain text**. Type the value directly into the value field.

Anything containing dynamic content references or function calls uses the Expression tab. Static strings do not.

---

## Step-by-step

Save after each step. Power Automate does not autosave.

### Step 1 -- Create the scheduled flow

1. https://make.powerautomate.com/ -- confirm tenant **APdatademo** (top-right avatar).
2. Left nav -- **+ Create** -- **Scheduled cloud flow**.
3. Flow name: `AP Invoice Tracker`. Starting: now. Repeat every **15 Minute**.
4. **Create**. You land in the designer with a **Recurrence** trigger in place.

### Step 2 -- Confirm Recurrence trigger

Click the trigger. Confirm: Interval `15`, Frequency `Minute`. No advanced parameters needed.

### Step 3 -- HTTP: Get Graph token (outside the loop)

Add **HTTP** action directly under Recurrence. Rename it to `HTTP - Get Graph token`.

| Field | Value |
| --- | --- |
| Method | `POST` |
| URI | `https://login.microsoftonline.com/APdatademo.onmicrosoft.com/oauth2/v2.0/token` |
| Headers | `Content-Type` = `application/x-www-form-urlencoded` (plain text) |
| Body | `grant_type=client_credentials&client_id={AZURE_CLIENT_ID from .env}&client_secret={PASTE_FROM_credentials.txt}&scope=https%3A%2F%2Fgraph.microsoft.com%2F.default` |

Do not URL-encode the GUID or secret yourself. Only the `scope` value is pre-encoded.

### Step 4 -- Parse JSON: token

Add **Parse JSON** action below the token HTTP action. Rename to `Parse_JSON_token`.

| Field | Value |
| --- | --- |
| Content | `Body` dynamic content from `HTTP - Get Graph token` |
| Schema | see below |

```json
{
  "type": "object",
  "properties": {
    "token_type": { "type": "string" },
    "expires_in": { "type": "integer" },
    "ext_expires_in": { "type": "integer" },
    "access_token": { "type": "string" }
  },
  "required": ["access_token"]
}
```

After this, `access_token` is available in the dynamic content picker for every downstream action.

### Step 5 -- Get emails (V3)

Add **Office 365 Outlook -- Get emails (V3)** action. Rename to `Get_emails_(V3)`.

| Field | Value |
| --- | --- |
| Folder | `Inbox` |
| Original Mailbox Address | `sharedinbox@APdatademo.onmicrosoft.com` |
| Include Attachments | `No` |
| Top | `50` |
| Fetch Only Unread Messages | `No` |
| From / To / Importance / Subject Filter | leave blank |

**Top must be set high enough to cover the full inbox.** The sandbox has 40 emails. At the default of 25, the connector returns the 25 most recent and silently skips the rest -- emails beyond position 25 in the sort order never enter the loop and never get a SharePoint row.

**Fetch Only Unread Messages must be `No`.** Any email that has been opened, flagged, ticked, or categorised in Outlook is marked as read. With this set to `Yes`, all such emails are silently dropped from the connector response -- they never reach Condition 1 and never get a SharePoint row. The Update item path (If no branch) also depends on re-processing already-read emails on every subsequent run; `Yes` breaks it entirely.

Subject filtering happens inside the loop -- the V3 `$filter` param is unreliable on shared mailboxes. This matches the original design.

The connection you sign in as must have delegated access to the shared inbox. If the default connection doesn't work, click the `...` menu on the action -- **My connections** -- add a new Office 365 Outlook connection signed in as `gp@APdatademo.onmicrosoft.com` (global admin has access to all mailboxes in the tenant).

### Step 6 -- Apply to each

Add **Control -- Apply to each**.

| Field | Value (paste via Expression tab) |
| --- | --- |
| Select an output from previous steps | `outputs('Get_emails_(V3)')?['body/value']` |

Everything from Step 7 onward lives inside this loop.

### Step 7 -- Condition 1: is this an invoice and not a reply/forward

Inside **Apply to each**, add **Control -- Condition**.

Click the left operand -- Expression tab -- paste:

```
and(
  contains(toLower(items('Apply_to_each')?['subject']), 'invoice'),
  not(startsWith(toLower(items('Apply_to_each')?['subject']), 're:')),
  not(startsWith(toLower(items('Apply_to_each')?['subject']), 'fw:'))
)
```

Operator: `is equal to`. Right operand: `true` (lowercase, via Expression tab).

The `RE:` / `FW:` exclusion is new in the sandbox build -- it prevents reply chains from generating duplicate SharePoint rows and mirrors the filter in `src/email_monitor.py`.

Leave **If no** empty. All remaining steps go in the **If yes** branch.

### Step 8 -- Get email (V2)

Add **Office 365 Outlook -- Get email (V2)**. Rename to `Get_email_(V2)`.

| Field | Value |
| --- | --- |
| Message Id | `items('Apply_to_each')?['id']` (Expression tab) |
| Original Mailbox Address | `sharedinbox@APdatademo.onmicrosoft.com` |
| Include Attachments | `No` |

V3 list returns `receivedDateTime` at lower granularity; V2 returns the full-precision timestamp that the ticks math depends on. V2 also returns `conversationId` which becomes the `ConversationID` column.

**Build note:** The original plan assumed both `flag` (for `ApprovalStatus`) and `categories` (for `ApproverCategory`) could be read from either the V3 list item or the V2 single-message response. During build, confirmed that neither the V3 connector endpoint nor the V2 single-message endpoint returns these fields -- both responses contain only `id`, `subject`, `from`, `receivedDateTime`, `conversationId`, `isRead`, `body`, and `attachments`. A dedicated Graph HTTP call for the individual message was required (Step 9).

### Step 9 -- HTTP: Get message details

Add **HTTP** action. Rename to `HTTP - Get message details`.

This call retrieves `flag` and `categories` for the current email -- two fields the Outlook connector does not expose in either V2 or V3 responses.

| Field | Value |
| --- | --- |
| Method | `GET` |
| URI | expression below |
| Headers (1) | `Authorization` = Expression: `concat('Bearer ', body('Parse_JSON_token')?['access_token'])` |
| Headers (2) | `Accept` = `application/json` (plain text) |

URI expression (Expression tab):

```
concat(
  'https://graph.microsoft.com/v1.0/users/sharedinbox@APdatademo.onmicrosoft.com/messages/',
  items('Apply_to_each')?['id'],
  '?$select=flag,categories'
)
```

Expected 200 response body:
```json
{
  "flag": { "flagStatus": "notFlagged" },
  "categories": []
}
```

For a flagged email: `"flagStatus": "flagged"`. For a ticked/completed email: `"flagStatus": "complete"`. For a categorised email: `"categories": ["Red Category"]`.

### Step 10 -- Parse JSON: message details

Add **Parse JSON** action. Rename to `Parse_JSON_message_details`.

| Field | Value |
| --- | --- |
| Content | `Body` dynamic content from `HTTP - Get message details` |
| Schema | see below |

```json
{
  "type": "object",
  "properties": {
    "flag": {
      "type": "object",
      "properties": {
        "flagStatus": { "type": "string" }
      }
    },
    "categories": {
      "type": "array",
      "items": { "type": "string" }
    }
  }
}
```

After this, `flagStatus` and `categories` are available as dynamic content for downstream field mappings.

### Step 11 -- Current time

Add **Date Time -- Current time**. No configuration.

### Step 12 -- Compose: hours

Add **Data Operation -- Compose**. Rename to `Compose`.

Inputs (Expression tab):

```
div(sub(ticks(outputs('Current_time')?['body']),ticks(body('Get_email_(V2)')?['receivedDateTime'])),36000000000)
```

Subtracts received-ticks from now-ticks, divides by `36,000,000,000` (ticks per hour) to produce hours elapsed.

### Step 13 -- Compose 2: days

Add another **Compose**. Rename to `Compose_2`.

Inputs (Expression tab):

```
div(outputs('Compose'),24)
```

### Step 14 -- HTTP: Get thread count

Add **HTTP** action. Rename to `HTTP - Get thread count`.

| Field | Value |
| --- | --- |
| Method | `GET` |
| URI | expression below |
| Headers (1) | `Authorization` = Expression: `concat('Bearer ', body('Parse_JSON_token')?['access_token'])` |
| Headers (2) | `ConsistencyLevel` = `eventual` (plain text) |
| Headers (3) | `Accept` = `application/json` (plain text) |

URI expression (Expression tab):

```
concat(
  'https://graph.microsoft.com/v1.0/users/sharedinbox@APdatademo.onmicrosoft.com/messages',
  '?$filter=conversationId eq ''', body('Get_email_(V2)')?['conversationId'], '''',
  '&$count=true&$top=1&$select=id'
)
```

**Build note -- scope change:** The original URI used `/mailFolders/inbox/messages`. This scopes the count to inbox messages only and excludes any replies sent from the shared mailbox (which land in Sent Items, not Inbox). The URI was updated to `/messages` (all folders) so that outbound replies from the AP team are included in the thread count. `$count=true` plus `ConsistencyLevel: eventual` are both required -- Graph returns a count-less body if either is absent.

The three consecutive apostrophes inside the filter string escape a literal single quote in Power Automate's expression language.

### Step 15 -- Parse JSON: thread count

Add **Parse JSON** action. Rename to `Parse_JSON_thread_count`.

| Field | Value |
| --- | --- |
| Content | `Body` dynamic content from `HTTP - Get thread count` |
| Schema | see below |

```json
{
  "type": "object",
  "properties": {
    "@odata.context": { "type": "string" },
    "@odata.count": { "type": "integer" },
    "value": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": { "id": { "type": "string" } }
      }
    }
  },
  "required": ["@odata.count"]
}
```

**Important:** When mapping `ThreadMessageCount` in Create item and Update item, use the **Expression tab** and paste `body('Parse_JSON_thread_count')?['@odata.count']` explicitly. The dynamic content picker labels this field as `odata count` and may insert an incorrect reference path due to the `@` prefix in the field name.

### Step 16 -- HTTP: Check duplicate

The SharePoint connector caches `Get items` responses at the platform level. The `x-ms-apihub-cached-response: true` response header confirms this and no connector-side workaround reliably overrides it. The dedup check is therefore performed via a direct Graph API HTTP call, which is not subject to connector caching.

**Before adding this action:** The `EmailID` column in the SharePoint list must be indexed, or Graph will return `400 invalidRequest: Field 'EmailID' cannot be referenced in filter or orderby as it is not indexed`.

To index the column -- go to **List Settings** (gear icon -- List settings, opens the classic settings page) -- scroll to **Columns** -- click **EmailID** -- set **Indexed** to **Yes** -- **OK**.

If the classic settings path is not accessible, add the `Prefer` header below as a workaround. This is safe for lists under approximately 5,000 items.

Add **HTTP** action. Rename to `HTTP - Check duplicate`.

| Field | Value |
| --- | --- |
| Method | `GET` |
| URI | expression below |
| Headers (1) | `Authorization` = Expression: `concat('Bearer ', body('Parse_JSON_token')?['access_token'])` |
| Headers (2) | `Accept` = `application/json` (plain text) |
| Headers (3) | `Prefer` = `HonorNonIndexedQueriesWarningMayFailRandomly` (plain text -- add if EmailID is not indexed) |

URI expression (Expression tab):

```
concat(
  'https://graph.microsoft.com/v1.0/sites/{SHAREPOINT_SITE_GUID from .env}',
  '/lists/{SHAREPOINT_LIST_ID from .env}/items',
  '?$filter=fields/EmailID eq ''', encodeUriComponent(items('Apply_to_each')?['id']), '''',
  '&$select=id&$top=1'
)
```

**Build note -- EmailID URL encoding required:** Exchange message IDs contain characters including `%3D` (a URL-encoded `=` sign from Base64 padding). When this is embedded raw in the OData filter URL, the HTTP layer decodes `%3D` back to `=` before the OData parser sees it -- so the filter looks for a value ending in `=` but the value stored in SharePoint ends in `%3D`. No match, dedup always returns empty, every email routes to Create_item on every run. Fix: wrap the email ID with `encodeUriComponent()` to double-encode the `%3D` to `%253D` in the URL. The HTTP layer decodes this to `%3D`, the OData parser sees `%3D`, which matches the stored value. Without this, the dedup will silently fail regardless of whether the EmailID column is indexed.

### Step 17 -- Parse JSON: dedup result

Add **Parse JSON** action. Rename to `Parse_JSON_dedup`.

| Field | Value |
| --- | --- |
| Content | `Body` dynamic content from `HTTP - Check duplicate` |
| Schema | see below |

```json
{
  "type": "object",
  "properties": {
    "value": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": { "id": { "type": "string" } }
      }
    }
  }
}
```

After this, `value` is available as dynamic content. The array will contain one item if a matching row exists, or be empty if it does not.

### Step 18 -- Condition 2: not a duplicate

Add **Control -- Condition**. Rename to `Condition_2`.

Left operand (Expression tab):

```
length(body('Parse_JSON_dedup')?['value'])
```

Operator: `is equal to`. Right operand: `0`.

Step 19 goes in **If yes**. Step 20 goes in **If no**.

### Step 19 -- Create item

Inside **If yes** of Condition 2, add **SharePoint -- Create item**. Rename to `Create_item`.

| Field | Value |
| --- | --- |
| Site Address | `https://APdatademo.sharepoint.com/sites/aptrackerdem` |
| List Name | `Approval Tracker` |

Populate these columns (all values via Expression tab):

| SharePoint column | Expression |
| --- | --- |
| Title | `items('Apply_to_each')?['subject']` |
| EmailSubject | `items('Apply_to_each')?['subject']` |
| SenderEmail | `items('Apply_to_each')?['from']` |
| ReceivedDate | `body('Get_email_(V2)')?['receivedDateTime']` |
| ApprovalDate | `body('Current_time')` |
| DaysToApprove | `outputs('Compose_2')` |
| HoursToApprove | `outputs('Compose')` |
| ApproverCategory | `string(body('Parse_JSON_message_details')?['categories'])` |
| EmailID | `items('Apply_to_each')?['id']` |
| ApprovalStatus | see expression below |
| ThreadMessageCount | `body('Parse_JSON_thread_count')?['@odata.count']` |
| ConversationID | `body('Get_email_(V2)')?['conversationId']` |

**ApprovalStatus expression:**

```
if(equals(body('Parse_JSON_message_details')?['flag']?['flagStatus'], 'flagged'), 'flagged',
  if(equals(body('Parse_JSON_message_details')?['flag']?['flagStatus'], 'complete'), 'complete',
    if(equals(items('Apply_to_each')?['isRead'], false), 'Unopened', null)))
```

**Build note -- ApprovalStatus logic revision:** The original expression was `if(equals(...flagStatus, 'notFlagged'), 'Unopened', flagStatus)`. This mapped every email that was not flagged or completed -- including emails that had been read and reviewed but not actioned -- to `Unopened`. Corrected logic: `flagged` → `flagged`, `complete` → `complete`, unread (`isRead` = false) → `Unopened`, read but not flagged → null (blank). The null case reflects an email that has been seen but not formally actioned.

**Build note -- ApproverCategory source:** Originally mapped as `string(items('Apply_to_each')?['categories'])` from the V3 item, then `string(body('Get_email_(V2)')?['categories'])` from V2. Both returned empty/null -- neither connector response includes the `categories` field. Source changed to `body('Parse_JSON_message_details')?['categories']` from the dedicated Graph HTTP call in Step 9.

Leave these columns blank -- Make.com (Phase 4) populates them: `ApproverName`, `ComplianceStatus`, `SupplierRisk`, `AnomalyFlag`, `AnomalyReason`.

Save the flow.

### Step 20 -- Update item (If no branch)

Inside **If no** of Condition 2, add **SharePoint -- Update item**. Rename to `Update_item`.

Before adding this step, update the `ApprovalStatus` column in the SharePoint list:
1. Open the Approval Tracker list -- click **ApprovalStatus** column -- **Column settings -- Edit**
2. Remove existing choices and replace with exactly: `Unopened`, `flagged`, `complete`
3. Save the column

Then configure the action:

| Field | Value |
| --- | --- |
| Site Address | `https://APdatademo.sharepoint.com/sites/aptrackerdem` |
| List Name | `Approval Tracker` |
| Id | Expression: `int(body('Parse_JSON_dedup')?['value']?[0]?['id'])` |

Graph returns the SharePoint item ID as a string in the `id` field of the dedup response. `int()` converts it to the integer the SharePoint connector expects.

Map these columns (Expression tab):

| SharePoint column | Expression |
| --- | --- |
| ThreadMessageCount | `body('Parse_JSON_thread_count')?['@odata.count']` |
| ApproverCategory | `string(body('Parse_JSON_message_details')?['categories'])` |
| ApprovalStatus | `if(equals(body('Parse_JSON_message_details')?['flag']?['flagStatus'], 'flagged'), 'flagged', if(equals(body('Parse_JSON_message_details')?['flag']?['flagStatus'], 'complete'), 'complete', if(equals(items('Apply_to_each')?['isRead'], false), 'Unopened', null)))` |

Every 15-minute run refreshes existing rows: thread count picks up new replies across all folders, ApproverCategory picks up colour categories applied in Outlook, and ApprovalStatus reflects the current flag state.

Save the flow.

---

## Step 21 -- First test run

**Turn the flow off before testing.** The 15-minute recurrence fires automatically in the background. If the flow is left on while you clear the SharePoint list and manually trigger a test run, the recurrence fires independently and writes additional rows -- resulting in multiples of 36 rows (e.g. 63 or 99) before the dedup can prevent them. Always click **Turn off** on the flow detail page before clearing the list. Re-enable after the manual test confirms the correct row count.

1. Click **Turn off** on the flow detail page.
2. Delete all rows from the Approval Tracker list.
3. In the designer -- **Test** -- **Manually** -- **Save & Test** -- **Run flow**.
4. Wait for the run to finish. Open the run history.
5. Every action should be green. Click into `HTTP - Get message details` and confirm the response includes `flag` and `categories`. Click into `HTTP - Check duplicate` and confirm the response body contains a `value` array. Click into `Create_item` and confirm all 12 field writes including `ApprovalStatus`, `ApproverCategory`, and `ThreadMessageCount`.
6. Open the Approval Tracker list in SharePoint. Confirm exactly 36 rows. Rows should carry `ThreadMessageCount >= 1`, a populated `ConversationID`, and `ApprovalStatus` set to `Unopened`, `flagged`, or `complete` as appropriate.
7. Click **Turn on** to re-enable the recurrence.

If anything goes red, copy the request/response panel from the failing action and paste it here for diagnosis.

---

## Step 22 -- Portfolio artefacts

Capture screenshots of:

- Flow designer showing all actions including `HTTP - Get message details` and `Parse_JSON_message_details`
- Run history with all actions green (both If yes and If no branches visible)
- The populated SharePoint row showing `ThreadMessageCount`, `ConversationID`, `ApproverCategory`, and `ApprovalStatus` all populated
- The Condition 1 expression showing `RE:` / `FW:` exclusion
- An existing row showing `ApprovalStatus` updated to `flagged` or `complete` after a re-run
- The `HTTP - Check duplicate` action showing a successful Graph response (proves the cache-free dedup path)
- The `HTTP - Get message details` action showing `flag` and `categories` in the response body

These artefacts are the visible evidence that this build closed the two "pending -- IT blocked" fields from the original Senversa flow, replaced the caching-prone SharePoint connector dedup with a reliable Graph HTTP call, extended it with duplicate-reply suppression, added a live update path, and resolved five field-sourcing gaps discovered during construction that were not anticipated in the original plan.

---

## Common errors

| Error | Likely cause | Fix |
| --- | --- | --- |
| `HTTP - Get Graph token` returns `400 AADSTS70011` | scope value malformed | ensure scope is exactly `https%3A%2F%2Fgraph.microsoft.com%2F.default` in the body |
| `HTTP - Get Graph token` returns `401 AADSTS7000215 invalid client secret` | client secret expired or mistyped | regenerate via `05_create_app_registration.ps1`, update the HTTP body |
| `Get emails (V3)` returns `The specified item was not found` | mailbox typo, or the Outlook connection doesn't have access to the shared mailbox | retype mailbox literal; reselect connection as an admin-level account |
| Emails that have been opened, flagged, ticked, or categorised are missing from SharePoint | `Fetch Only Unread Messages` is `Yes` in `Get emails (V3)` | set `Fetch Only Unread Messages` to `No` |
| Fewer rows than expected -- some emails not processed | `Top` in `Get emails (V3)` set lower than the inbox count | increase `Top` to 50 or higher |
| `ApproverCategory` and `ApprovalStatus` blank -- `HTTP - Get message details` not yet added | flow uses V3 or V2 connector response for these fields -- neither returns `flag` or `categories` | add `HTTP - Get message details` (Step 9) and `Parse_JSON_message_details` (Step 10); update all field mappings to reference `body('Parse_JSON_message_details')` |
| `ApprovalStatus` shows `Unopened` for emails that have been read | original expression mapped all `notFlagged` emails to `Unopened` regardless of read state | use the corrected nested-if expression from Step 19 which checks `isRead` for the `Unopened` branch |
| `ThreadMessageCount` not counting sent replies from the shared mailbox | `HTTP - Get thread count` URI scoped to `mailFolders/inbox/messages` -- sent replies live in Sent Items | change URI to `/messages` (all folders); see Step 14 |
| `HTTP - Get thread count` returns 200 but `@odata.count` is null | missing `$count=true` or missing `ConsistencyLevel: eventual` header | add both; Graph silently drops the count without the consistency header |
| `HTTP - Get thread count` returns 403 | App Registration missing `Mail.Read` application permission, or admin consent not granted | grant admin consent in Entra ID -- App registrations -- AP Tracker |
| `ThreadMessageCount` blank in SharePoint despite HTTP returning correct value | `@odata.count` label in dynamic content picker is unreliable due to `@` prefix | in Create item and Update item, use Expression tab and paste `body('Parse_JSON_thread_count')?['@odata.count']` directly |
| `HTTP - Check duplicate` returns `400 invalidRequest` -- Field 'EmailID' cannot be referenced in filter | `EmailID` column is not indexed in the SharePoint list | go to List Settings -- Columns -- EmailID -- set Indexed to Yes. Or add `Prefer: HonorNonIndexedQueriesWarningMayFailRandomly` header as a workaround |
| `HTTP - Check duplicate` returns 403 | App Registration missing `Sites.ReadWrite.All` permission, or admin consent not granted | grant admin consent in Entra ID -- App registrations -- AP Tracker |
| `HTTP - Check duplicate` returns 200 but `value` array is always empty | site GUID or list ID in the URI is wrong | cross-check against Reference IDs table at the top of this guide |
| SharePoint list has multiples of 36 rows after a test run | recurrence fired automatically while the list was cleared and manually tested | turn the flow off before clearing the list; turn it back on after the manual test confirms correct row count |
| `Parse JSON` validation failed | upstream HTTP action returned an error body with a different schema | open the run history and paste the failing response |
| `Create item` returns 400 | column internal name mismatch, or a non-string value in a text column | cross-check column names against `src/sharepoint.py SCHEMA_COLUMNS` |
| `Update item` returns 400 on `Id` | `int()` conversion failed because `Parse_JSON_dedup` returned null | confirm `HTTP - Check duplicate` returned a valid 200 response with a `value` array |
| `Condition 2` routes everything to If no | `HTTP - Check duplicate` is returning 200 but `value` always has one item | check that the EmailID filter in the URI is correctly quoting the ID value with escaped apostrophes |
| Flow processes 36 of 40 emails -- 4 missing | working as designed | the 4 RE:/FW: reply chain emails are correctly excluded by Condition 1; see note above |

---

## Phase 3 checklist

- [x] Flow created (Step 1-2)
- [x] Token fetch and parse live (Step 3-4)
- [x] Get emails (V3) -- Top 50, Fetch Only Unread = No (Step 5)
- [x] Core loop rebuilt action-by-action (Step 6-13)
- [x] HTTP Get message details returning flag and categories (Step 9-10)
- [x] Graph HTTP thread count live returning `@odata.count` -- all-mailbox scope (Step 14-15)
- [x] Graph HTTP dedup check replacing SharePoint connector (Step 16-17)
- [x] Condition 2 referencing `Parse_JSON_dedup` (Step 18)
- [x] Create item writing all 12 fields with corrected ApprovalStatus and ApproverCategory (Step 19)
- [x] ApprovalStatus column updated in SharePoint to Unopened / flagged / complete (Step 20)
- [x] Update item live in If no branch with Graph-sourced integer ID (Step 20)
- [x] First test run green end-to-end with flow turned off during test (Step 21)
- [x] SharePoint confirmed 36 rows with ThreadMessageCount, ConversationID, ApproverCategory, and ApprovalStatus all populated (Step 21)
- [x] Existing rows confirmed updating on re-run (Step 21)
- [x] Portfolio screenshots captured (Step 22)

Phase 3 is done -- proceed to Phase 4 (Make.com enrichment).
