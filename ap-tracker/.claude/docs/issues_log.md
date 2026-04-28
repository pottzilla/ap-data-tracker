## Issues Encountered

A running log of every problem hit during the build, the investigation that identified the cause, and the resolution applied. Ordered by phase. Included as part of the portfolio record -- these are the kinds of problems that only surface when you build against a real environment, and navigating them is part of what the project demonstrates.

---

### Phase 1 -- Infrastructure (PowerShell)

#### Issue 1.1 -- SharePoint list creation failing under application credentials

**Symptom:** Script 06 (`06_create_sharepoint_list.ps1`) returned a 403 or permissions error when attempting to create the Approval Tracker list on the team site, despite the App Registration holding `Sites.ReadWrite.All` with admin consent granted.

**Cause:** `Sites.ReadWrite.All` as an application permission is sufficient to read and write list items but is not always sufficient to create a new list on a Microsoft 365 group-backed team site. The SharePoint site is backed by an M365 group, and the app service principal was not a member of that group. Graph treats list creation on group sites as a group operation, not a plain sites operation.

**Resolution:** Created two additional scripts to navigate this:
- `create_sharepoint_list_direct.ps1` -- connects with app credentials, queries the M365 group by mail nickname, adds the app service principal as group owner and the admin user as group owner and member, waits 15 seconds for propagation, then retries list creation via three fallback endpoints in order.
- `create_list_delegated.ps1` -- uses delegated device code auth as the global admin to create the list with a full user context, bypassing the group membership requirement entirely.

The delegated approach succeeded. Once the list existed, all subsequent column creation and data operations functioned correctly under application auth.

**Artefact:** `powershell/create_sharepoint_list_direct.ps1`, `powershell/create_list_delegated.ps1`

---

#### Issue 1.2 -- Supplier accounts unable to send email -- Exchange mailboxes not provisioned

**Symptom:** Script 07 (`07_send_test_emails.ps1`) failed when attempting to call `sendMail` via Graph API on behalf of supplier accounts. Accounts existed and were confirmed in the tenant but Graph returned errors indicating no mailbox was found.

**Cause:** Creating a user account in M365 does not provision an Exchange mailbox. A licence assignment is required, and Exchange mailbox provisioning occurs asynchronously after licence assignment -- typically 1 to 3 minutes per account but occasionally longer. Script 03 created the accounts but did not assign licences; no licence assignment step existed in the original build sequence.

**Resolution:** Created `assign_supplier_licences.ps1` which retrieves the tenant's Business Premium SKU, skips already-licensed accounts, assigns the licence to each of the four supplier accounts, waits 3 minutes then polls Exchange provisioning status via `ProvisionedPlans` on each user, retrying every 30 seconds up to 8 times. Created `run_licence_and_emails.ps1` to sequence licence assignment followed by email sending as a single operation.

**Artefact:** `powershell/assign_supplier_licences.ps1`, `powershell/run_licence_and_emails.ps1`

---

#### Issue 1.3 -- Graph API token expiry during bulk email send -- 2 of 40 failed

**Symptom:** During the 40-email send in Script 07, sequences 39 and 40 failed. The first 38 sent successfully.

**Cause:** The Graph API access token obtained at the start of the session expired mid-run during a long bulk operation. The token has a fixed TTL (typically 3600 seconds) and a long-running interactive PowerShell session that includes connection steps, licence assignment waits, and mailbox provisioning polling can exhaust it before all sends complete.

**Resolution:** Created `resend_failed.ps1` which acquires a completely fresh token via `Invoke-RestMethod` against the token endpoint before sending only the 2 failed emails. Includes a 30-second wait followed by inbox count verification to confirm the total reaches 40. The script is idempotent -- it can be re-run safely if further sends fail.

**Artefact:** `powershell/resend_failed.ps1`, `email_send_log.csv`

---

#### Issue 1.4 -- PowerShell script execution errors from encoding artefacts

**Symptom:** Several `.ps1` scripts written by the Write tool failed on execution with unexpected character errors. Some scripts contained em dashes instead of double hyphens, and backtick-n sequences misinterpreted by the PowerShell parser.

**Cause:** The Write tool outputs UTF-8 content and can introduce typographic characters (em dashes from autocorrect or encoding conversion) and escape sequences that are valid in document text but invalid in PowerShell syntax.

**Resolution:** All scripts standardised to plain ASCII. Em dashes replaced with double hyphens (--). Backtick-n sequences replaced with explicit newlines in here-strings. Convention established for all subsequent scripts: no typographic punctuation, no backtick escape sequences in script bodies.

---

#### Issue 1.5 -- Device code auth not suitable for cross-user sendMail operations

**Symptom:** Early attempts to send emails from supplier accounts using `Connect-MgGraph -UseDeviceCode` (delegated auth as `gp@APdatademo.onmicrosoft.com`) returned permission errors on `sendMail` calls targeting other users' mailboxes.

**Cause:** Delegated auth with device code authenticates as the signed-in user. That user can only call `sendMail` on their own mailbox unless explicitly granted `Send As` or `Send on Behalf Of` permissions on each target mailbox. The global admin account does not inherit `Send As` rights on supplier accounts by default.

**Resolution:** Cross-user and application-level operations switched to client credentials flow -- `Invoke-RestMethod` against the token endpoint with `grant_type=client_credentials`, then `Connect-MgGraph -AccessToken`. Application permissions (`Mail.Send`) cover all mailboxes in the tenant without per-mailbox grants. `connect_only.ps1` retained for interactive sessions where delegated auth is appropriate.

**Artefact:** `powershell/connect_only.ps1`, `powershell/resend_failed.ps1`

---

### Phase 2 -- Python Pipeline

#### Issue 2.1 -- Claude enrichment live test blocked by zero Anthropic credit balance

**Symptom:** `test_enrichment.py` failed at runtime with an authentication/billing error from the Anthropic API. `src/claude_enrichment.py` was fully written and all imports clean, but the live classification test could not execute.

**Cause:** The `ANTHROPIC_API_KEY` in `.env` had a zero credit balance. The key itself was valid; the account had no available spend.

**Resolution:** The safe-default fallback path in `claude_enrichment.py` was verified independently -- the `try/except` around `json.loads` confirmed it returns a fully populated default dict (all fields null or false) without raising or blocking the pipeline. Live test deferred to when credits are topped up. `claude_enrichment.py` is marked `[~]` in Phase 2 status until the live test is run and confirmed.

---

### Phase 3 -- Power Automate

#### Issue 3.1 -- SharePoint connector caching causing false positive duplicate detection

**Symptom:** On repeated flow runs, only 27 of 36 qualifying emails produced new SharePoint rows. Run history showed 9 emails routing to `Update item` on their first pass through the flow -- before any row for those emails had been written.

**Investigation:** The response headers on the `Get items` SharePoint connector action showed `x-ms-apihub-cached-response: true`. Multiple cache-busting attempts were made -- encoding the EmailID filter value differently, appending a redundant OData clause, varying the `Top Count` -- none forced a fresh query.

**Cause:** Power Automate's SharePoint connector caches `Get items` responses at the platform level. There is no per-action setting to disable it.

**Resolution:** Replaced the `Get_items` SharePoint connector action with `HTTP - Check duplicate` (direct Graph API GET) + `Parse_JSON_dedup`. Graph HTTP calls are not subject to connector-level caching. Condition 2 updated to read `length(body('Parse_JSON_dedup')?['value'])`. Update item ID reference updated to `int(body('Parse_JSON_dedup')?['value']?[0]?['id'])`.

**Result:** All 36 qualifying emails now produce rows on first pass.

---

#### Issue 3.2 -- 36 of 40 emails processing -- investigated, confirmed correct behaviour

**Symptom:** After resolving the caching issue, 36 of 40 inbox emails were observed entering the `If yes` branch of Condition 1. 4 emails were not being processed.

**Cause:** None. The 4 unprocessed emails are sequences 6, 11, 14, and 38 -- the `reply_chain` type emails. They are correctly excluded by the RE:/FW: clauses in Condition 1. They were included specifically to prove the filter works.

**Resolution:** No change required. 36 rows is the correct final count.

---

#### Issue 3.3 -- HTTP Check duplicate returning 400 invalidRequest on EmailID filter

**Symptom:** `HTTP - Check duplicate` returned `400 invalidRequest` with the message: `Field 'EmailID' cannot be referenced in filter or orderby as it is not indexed`.

**Cause:** Graph API enforces column indexing for OData `$filter` operations on SharePoint list fields. The `EmailID` column was not indexed.

**Resolution:** Added `Prefer: HonorNonIndexedQueriesWarningMayFailRandomly` as a header on `HTTP - Check duplicate`. Safe for the sandbox list (36 rows). The proper permanent fix is to index the column via SharePoint List Settings -- Columns -- EmailID -- Indexed: Yes.

---

#### Issue 3.4 -- Recurrence firing during manual test runs -- duplicate rows written

**Symptom:** After clearing the SharePoint list and running a manual test, the list contained 63 rows on one run and 99 rows on another instead of the expected 36.

**Cause:** The flow's 15-minute recurrence trigger continued firing automatically in the background while manual test runs were being executed. Each automatic run saw an empty list and wrote another batch of rows before the dedup check could catch them.

**Resolution:** Established test procedure: turn the flow off before clearing the list, run the manual test, confirm 36 rows, then turn the flow back on.

---

#### Issue 3.5 -- ApprovalStatus and ApproverCategory blank -- connector does not return flag or categories fields

**Symptom:** All 36 SharePoint rows had blank `ApprovalStatus` and `ApproverCategory` fields despite emails having been flagged, ticked, and colour-categorised in Outlook.

**Cause:** The Office 365 Outlook connector (both V2 and V3) does not expose `flag` or `categories` in its response schema. These fields require a direct Graph API call to the messages endpoint with explicit `$select`.

**Resolution:** Added two new actions to the loop immediately after `Get_email_(V2)`:
- `HTTP - Get message details` -- `GET /users/{mailbox}/messages/{id}?$select=flag,categories`
- `Parse_JSON_message_details` -- parses `flag.flagStatus` and `categories` array

All `ApprovalStatus` and `ApproverCategory` mappings updated to reference `body('Parse_JSON_message_details')`.

---

#### Issue 3.6 -- ApprovalStatus showing Unopened for read emails

**Symptom:** Emails that had been opened and reviewed in Outlook (but not flagged or ticked) were appearing as `Unopened` in the SharePoint list.

**Cause:** The original expression `if(equals(flagStatus, 'notFlagged'), 'Unopened', flagStatus)` mapped every non-flagged email -- including read emails -- to `Unopened`.

**Resolution:** Updated to a nested-if expression using `isRead` from the V3 item:
- `flagStatus = 'flagged'` -- `flagged`
- `flagStatus = 'complete'` -- `complete`
- `isRead = false` -- `Unopened`
- `isRead = true` and not flagged/complete -- `null`

---

#### Issue 3.8 -- Dedup filter always returning empty -- EmailID URL encoding mismatch

**Symptom:** Every flow run created 36 new rows regardless of how many rows already existed. `HTTP - Check duplicate` returned a 200 response with an empty `value` array on every iteration, routing all emails to Create_item every run.

**Investigation:** PowerShell test retrieved a stored EmailID from SharePoint and queried the list with the exact stored value as the OData filter -- returned 0 results. Repeated with `[Uri]::EscapeDataString()` applied to the filter expression -- returned 1 result. Confirmed the stored EmailID ends in `%3D` (154 characters).

**Cause:** Exchange message IDs contain Base64 padding (`=`), returned by the V3 connector as `%3D` (URL-encoded). SharePoint stores the value as literal `%3D`. When the dedup filter URL is built with `concat()`, the URL contains `%3D` inside the OData filter string. The HTTP layer decodes `%3D` to `=` before the OData parser sees it -- filter looks for `=` but stored value is `%3D`. No match. Indexing the EmailID column does not fix this.

**Resolution:** Wrapped the email ID with `encodeUriComponent()` in the dedup URI: `encodeUriComponent(items('Apply_to_each')?['id'])`. This double-encodes `%3D` to `%253D` in the URL. HTTP layer decodes to `%3D`, OData parser matches the stored value.

---

#### Issue 3.7 -- ThreadMessageCount not counting sent replies from the shared mailbox

**Symptom:** After replying to an invoice email from the shared inbox, `ThreadMessageCount` still showed `1` -- the sent reply was not reflected in the count.

**Cause:** The `HTTP - Get thread count` URI was scoped to `mailFolders/inbox/messages`. Replies sent from the shared mailbox land in Sent Items, not Inbox.

**Resolution:** Changed the URI from `/mailFolders/inbox/messages` to `/messages` (all folders). This queries across Inbox, Sent Items, and Drafts, giving a true thread message count regardless of folder.
