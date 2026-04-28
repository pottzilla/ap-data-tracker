## The Sandbox Build -- What We Are Building Now

This project is a complete reconstruction and extension of the original flow in a controlled sandbox environment. Every gap from the original build is closed. Every pending dependency is resolved.

### Environment

**Tenant:** Microsoft 365 Business Premium trial tenant
**Tenant domain:** `APdatademo.onmicrosoft.com`
**Global admin:** `gp@APdatademo.onmicrosoft.com`

**Sandbox accounts:**

| Purpose | Account | Compliance Rate |
|---------|---------|----------------|
| Shared AP Inbox | sharedinbox@APdatademo.onmicrosoft.com | N/A |
| Supplier 1 -- Apex Site Works | apexsiteworks@APdatademo.onmicrosoft.com | 80% |
| Supplier 2 -- Clearwater Environmental | clearwaterenv@APdatademo.onmicrosoft.com | 60% |
| Supplier 3 -- Bridgepoint Civil | bridgepointcivil@APdatademo.onmicrosoft.com | 90% |
| Supplier 4 -- Halcyon Electrical | halcyonelectrical@APdatademo.onmicrosoft.com | 40% |
| Global Admin | gp@APdatademo.onmicrosoft.com | N/A |

**Azure App Registration:** AP Tracker
- `Mail.Read` -- application permission
- `Mail.Send` -- application permission
- `Sites.ReadWrite.All` -- application permission
- `MailboxSettings.Read` -- application permission
- Admin consent granted

### Target Architecture

```
Supplier Sandbox Accounts (x4)
         | Graph API sendMail (automated via PowerShell)
         v
Shared AP Inbox (sharedinbox@APdatademo.onmicrosoft.com)
         |
         v
Power Automate (every 15 minutes)
-- Subject line filter: contains(toLower(subject), 'invoice')
-- Exclude RE: and FW: reply chains
-- Get_email_(V2) for receivedDateTime
-- Ticks-based cycle time calculation
-- Message ID duplicate check
-- SharePoint write
         |
         v
SharePoint Approval Tracker List
         |
         v
Python Pipeline (VS Code)
-- Graph API email monitor (replaces standard connector)
-- Thread message count retrieval (closes original gap)
-- Category metadata retrieval (closes original gap)
-- ConversationID tracking (new capability)
-- Cycle time calculation via Python datetime
-- Duplicate check via Message ID
-- SharePoint write via Graph API
         |
         v
Make.com Enrichment Layer
-- Trigger on new SharePoint record (Watch Items, every 15 min)
-- Claude API classification per record (has_po, supplier_risk, anomaly_reason, compliance_status)
-- Enriched fields written back to SharePoint (ComplianceStatus, SupplierRisk, AnomalyReason)
         |
         v
Enriched SharePoint Dataset
```

### SharePoint List Schema -- Approval Tracker

| Column             | Type        | Source             | Status                |
|--------------------|-------------|--------------------|-----------------------|
| Title              | Single line | EmailSubject       | Original              |
| EmailSubject       | Single line | Flow               | Original              |
| SenderEmail        | Single line | Flow               | Original              |
| ReceivedDate       | Date/time   | Flow               | Original              |
| ApprovalDate       | Date/time   | Flow               | Original              |
| DaysToApprove      | Number      | Ticks expression   | Original              |
| HoursToApprove     | Number      | Ticks expression   | Original              |
| ThreadMessageCount | Number      | Graph API          | Gap closed in sandbox |
| ApproverCategory   | Single line | Graph API          | Gap closed in sandbox |
| EmailID            | Single line | Flow -- dedup key  | Original -- hidden from list view (column retained, data intact) |
| ConversationID     | Single line | Graph API          | New in sandbox -- hidden from list view (column retained, data intact) |
| ApprovalStatus     | Choice      | Manual / Flow      | Original              |
| ComplianceStatus   | Choice      | Claude API         | New in sandbox -- populated by Make.com Phase 4 |
| SupplierRisk       | Choice      | Claude API         | New in sandbox -- populated by Make.com Phase 4 |
| AnomalyReason      | Single line | Claude API         | New in sandbox -- populated by Make.com Phase 4 |
