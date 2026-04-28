1# Graph API HTTP Action Specs — Power Automate

Copy-paste reference for the three HTTP actions added in Phase 3 Step 5. Keep these inside the **Apply to each** loop, placed between **Get email (V2)** and **Get items**.

Any value written as `@{...}` is a Power Automate dynamic expression — paste it through the **Expression** tab, not as literal text.

---

## Prerequisites

You need these three values from the App Registration created by `05_create_app_registration.ps1`. They live in `credentials.txt`:

- **Tenant ID** (GUID)
- **Client ID** (GUID) — ends `367ded`
- **Client secret** (plaintext)

Best practice in Power Automate: save the client secret into the Power Platform **Environment Variables** (Admin center → Environment → Variables) rather than hardcoding it in the HTTP body. This guide uses the inline form for clarity — swap to `@{variables('clientSecret')}` once the env variable is registered.

---

## Action 1 — HTTP: Get OAuth token

Renames to **HTTP - Get Graph token**.

| Field | Value |
| --- | --- |
| Method | POST |
| URI | `https://login.microsoftonline.com/{{TENANT_ID}}/oauth2/v2.0/token` |
| Headers | `Content-Type` = `application/x-www-form-urlencoded` |
| Body | `grant_type=client_credentials&client_id={{CLIENT_ID}}&client_secret={{CLIENT_SECRET}}&scope=https%3A%2F%2Fgraph.microsoft.com%2F.default` |

Replace `{{TENANT_ID}}`, `{{CLIENT_ID}}`, `{{CLIENT_SECRET}}` with the real values from `credentials.txt`. Do not URL-encode them yourself — the values are plain GUIDs/strings; only the `scope` value is pre-encoded above.

Expected 200 response body:
```json
{
  "token_type": "Bearer",
  "expires_in": 3599,
  "access_token": "eyJ0eXAiOi..."
}
```

Follow with a **Parse JSON** action (schema below) so `access_token` is available as dynamic content.

### Parse JSON for the token response

| Field | Value |
| --- | --- |
| Content | Body from `HTTP - Get Graph token` |
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

After this, `access_token` appears in the dynamic content picker for downstream actions.

---

## Action 2 — HTTP: Get thread message count

Renames to **HTTP - Get thread count**.

The inbox-scoped filter matches how `src/email_monitor.get_thread_message_count` queries Graph so Python and Power Automate produce the same number.

| Field | Value |
| --- | --- |
| Method | GET |
| URI | expression below |
| Headers (1) | `Authorization` = `@{concat('Bearer ', body('Parse_JSON_token')?['access_token'])}` |
| Headers (2) | `ConsistencyLevel` = `eventual` |
| Headers (3) | `Accept` = `application/json` |

### URI expression (paste into the Expression tab)

```
concat(
  'https://graph.microsoft.com/v1.0/users/sharedinbox@APdatademo.onmicrosoft.com',
  '/mailFolders/inbox/messages',
  '?$filter=conversationId eq ''', body('Get_email_(V2)')?['conversationId'], '''',
  '&$count=true&$top=1&$select=id'
)
```

The three single quotes in a row escape a literal apostrophe inside the filter string — Power Automate's expression language requires the double-apostrophe form.

Expected 200 response body:
```json
{
  "@odata.context": "...",
  "@odata.count": 3,
  "value": [ { "id": "..." } ]
}
```

### Parse JSON for the thread count response

| Field | Value |
| --- | --- |
| Content | Body from `HTTP - Get thread count` |
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
        "properties": {
          "id": { "type": "string" }
        }
      }
    }
  },
  "required": ["@odata.count"]
}
```

Dynamic content then exposes `@odata.count` under the friendly name `odata count`. Feed that into the Create item action as `ThreadMessageCount`.

---

## Action 3 — (Optional) Enrichment callback via Make.com

The AI enrichment fields (`ComplianceStatus`, `SupplierRisk`, `ApproverName`, `AnomalyFlag`, `AnomalyReason`) are populated by the Make.com real-time scenario (Phase 4), not by Power Automate. If you want Power Automate to trigger the enrichment immediately after the SharePoint item is created, add a fourth HTTP action:

| Field | Value |
| --- | --- |
| Method | POST |
| URI | Make.com webhook URL (from Phase 4 Scenario 1) |
| Headers | `Content-Type` = `application/json` |
| Body | `{ "sharepoint_item_id": "@{body('Create_item')?['ID']}", "email_id": "@{items('Apply_to_each')?['id']}", "subject": "@{items('Apply_to_each')?['subject']}", "sender": "@{items('Apply_to_each')?['from']}", "body_preview": "@{items('Apply_to_each')?['bodyPreview']}" }` |

Skip this for the Phase 3 milestone; revisit after Phase 4 Scenario 1 is live and its webhook URL is known.

---

## Updating the Create item field mapping

After Actions 1 and 2 are in place, edit the Create item action:

| SharePoint column | New dynamic content |
| --- | --- |
| ThreadMessageCount | `@odata.count` from `Parse_JSON_thread_count` |
| ConversationID | `body('Get_email_(V2)')?['conversationId']` |
| ApproverName | leave blank (Make.com fills this) |
| ComplianceStatus | leave blank (Make.com fills this) |
| SupplierRisk | leave blank (Make.com fills this) |
| AnomalyFlag | leave blank (Make.com fills this) |
| AnomalyReason | leave blank (Make.com fills this) |

Save and rerun the flow with one test email. Every row in the Approval Tracker list should now carry a real conversation ID and a thread count. Those two columns were the "pending — IT blocked" gap in the original Senversa build; closing them is the headline Phase 3 deliverable.

---

## Debugging tips

- If **HTTP - Get Graph token** returns 401 `AADSTS7000215 invalid client secret`, the secret has expired. Regenerate via `05_create_app_registration.ps1` and update the HTTP body.
- If **HTTP - Get thread count** returns 200 but `@odata.count` is null, the response used the non-count code path. Check `$count=true` is present and the `ConsistencyLevel: eventual` header is set — both are required.
- If **Parse JSON** fails with "validation failed", the upstream HTTP action returned an error body with a different schema. Open the run history and paste the failing response to me.
- To avoid hammering `/token` on every loop iteration, move the token fetch *outside* the Apply to each (before the loop begins). Tokens are valid for ~60 minutes, far longer than any single flow run.
