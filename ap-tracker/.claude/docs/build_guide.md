## PowerShell Infrastructure Scripts

All infrastructure is provisioned via PowerShell before any Python code runs. Scripts are executed in order. Each script is independently runnable and includes progress logging and error handling.

### Execution Order
```
01_install_modules.ps1        # Install Microsoft.Graph + ExchangeOnlineManagement
02_connect_services.ps1       # Authenticate interactively
03_create_users.ps1           # Create all 5 tenant accounts
04_create_shared_mailbox.ps1  # Convert AP inbox to shared mailbox
05_create_app_registration.ps1 # App Registration + permissions + client secret
06_create_sharepoint_list.ps1  # SharePoint site + full list schema
07_send_test_emails.ps1       # Send 40 supplier emails to AP inbox
08_verify_environment.ps1     # Full verification report
```

Credentials output from `05_create_app_registration.ps1` to `credentials.txt`:
- Tenant ID
- Client ID
- Client Secret

`credentials.txt` must be added to `.gitignore` immediately. Never commit credentials to GitHub.

---

## Make.com Enrichment Layer -- COMPLETE

### Scenario 1 -- Real-time Record Enrichment (built and live)
**Trigger:** SharePoint Online: Watch Items (new items only)
**Module 2:** Anthropic Claude: Create a Message -- classifies invoice using subject + sender
**Module 3:** SharePoint Online: Update an Item -- writes enriched fields via parseJSON() inline mapping
**Run frequency:** Every 15 minutes
**Fields written:** ComplianceStatus, SupplierRisk, AnomalyReason
**Full spec:** `make.com/PHASE4_GUIDE.md`, `make.com/claude_api_modules.md`

Scenario 2 (weekly summary) -- descoped. Not built.

---

## Build Sequence

Follow this exact order. Test each component before proceeding to the next:

```
Phase 1 -- Infrastructure (PowerShell)
  01 -> 02 -> 03 -> 04 -> 05 -> 06 -> 08 (verify before proceeding)
  07 -> verify inbox in Outlook Web App

Phase 2 -- Python Pipeline (VS Code)
  config/settings.py -> src/auth.py -> test token retrieval
  -> src/email_monitor.py -> test against live mailbox
  -> src/cycle_time.py
  -> src/sharepoint.py -> test duplicate check and write independently
  -> src/claude_enrichment.py -> test with hardcoded sample email
  -> src/pipeline.py
  -> src/weekly_summary.py
  -> sandbox/generate_dataset.py
  -> main.py

Phase 3 -- Power Automate (Browser + Claude Review)
  Import original JSON -> Claude review and correction
  -> Remap connections to sandbox tenant
  -> First test run -> paste run history to Claude for diagnosis
  -> Add Graph API HTTP actions -> Claude review
  -> Verify SharePoint writes

Phase 4 -- Make.com (Browser) -- COMPLETE
  Scenario 1 built and live -- SharePoint Watch -> Anthropic Claude -> SharePoint Update

Phase 5 -- Completion
  Run python main.py --sandbox to populate synthetic historical data
  Let live pipeline run for 2+ weeks to accumulate real cycle time data
  Verify all fields populating correctly including ThreadMessageCount,
  ApproverCategory, ConversationID, ComplianceStatus, SupplierRisk, AnomalyReason
  GitHub repository published with README
  Portfolio document complete
```
