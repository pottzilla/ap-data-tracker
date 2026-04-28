## Who I Am

I am George Potter, an Accounts Payable Officer based in Melbourne, Australia. My background spans AP, AR, credit control, financial planning, technology recruitment, and sales across Melbourne and the UK. My technical toolkit includes Power Automate, Microsoft Graph API, Xero, Deltek PiMS, Oracle, Excel (Pivot Tables, XLOOKUP, Power Query), and CRM platforms.

I am building this project as a portfolio piece to demonstrate workflow automation and process analytics capabilities, supporting a career pivot toward AI workflow automation consulting. This project replicates and extends a Power Automate flow I built professionally at Senversa, a Melbourne-based infrastructure consultancy where I worked as an AP Officer on a contract basis.

---

## Business Context -- The Problem I Was Solving

### The Original Broken Process

Our AP team operated an invoice approval workflow that was almost entirely email-dependent:

1. Invoice arrives from supplier without a PO, but with a job number and/or contact name
2. AP team forwards the invoice to the listed contact requesting a PO number
3. Contact replies with the PO number via email
4. AP team manually processes the invoice in Deltek PiMS and self-approves based on the PO provided

**Bottlenecks this created:**

- If the contact listed on the invoice was incorrect, AP had to locate the correct project manager manually -- sometimes only discovering the error after waiting for a reply that never came
- Field-based contacts were rarely near their inboxes -- emails sat unread for days, requiring multiple chase-ups and eventual escalation to a project director
- Some contacts were chronically unresponsive -- invoices regularly became overdue, aggravating suppliers and damaging relationships
- Email chains of 5-6 messages per invoice were common before a single invoice could be processed
- Emails got buried in busy project managers' inboxes and were simply missed

### The Process Redesign

A new system was implemented to eliminate the email dependency:

1. Project managers were instructed to issue purchase orders to suppliers upfront, before invoicing
2. Suppliers were briefed to include PO references on all invoices and to flag if they had not received a work order
3. Invoices arriving with a valid PO were processed immediately by AP in Deltek PiMS -- no email chain required
4. AP attached the work order and invoice in PiMS but did NOT self-approve
5. The project manager received a PiMS notification of pending documents awaiting their approval
6. The PM reviewed AP's input against the invoice and work order, then approved or rejected with a reason

**What this solved:**

- Email back-and-forth was almost entirely eliminated
- Processing moved out of Outlook and into the CRM system
- PMs approved their own invoices -- increasing accuracy and accountability
- Invoice processing speed increased significantly
- Month-end backlogs reduced
- Supplier statements of accounts became cleaner with fewer outstanding items
- AP could focus attention on genuinely problematic invoices rather than routine processing

### The Gap That Remained

Despite the operational improvement being felt immediately, there were no metrics to quantify it. No data on:

- Reduction in email chain length per invoice
- Invoice cycle times from receipt to approval
- Which suppliers were still non-compliant (no PO, outdated PO, incorrect contact)
- Which approvers were bottlenecks in the approval chain
- What the old system had cost the business in hours
- What dollar value the new system had saved

The process was better. It could not be proved.

---

## What I Built at Senversa -- The Original Flow

I independently built a scheduled Power Automate cloud flow to create the business's first real-time AP performance dataset.

### Technical Specification

**Trigger:** Recurrence -- every 15 minutes

**Connector:** Office 365 Outlook -- shared mailbox `supplieraccounts@senversa.com.au`

**Core Logic:**

```json
{
  "type": "Foreach",
  "foreach": "@outputs('Get_emails_(V3)')?['body/value']",
  "actions": {
    "Condition": {
      "type": "If",
      "expression": {
        "and": [
          {
            "equals": [
              "@contains(toLower(items('Apply_to_each')?['subject']), 'invoice')",
              true
            ]
          }
        ]
      },
      "actions": {
        "Get_email_(V2)": {
          "inputs": {
            "parameters": {
              "messageId": "@items('Apply_to_each')?['id']",
              "mailboxAddress": "supplieraccounts@senversa.com.au",
              "includeAttachments": false
            }
          }
        },
        "Current_time": {},
        "Compose": {
          "inputs": "@div(sub(ticks(outputs('Current_time')?['body']),ticks(body('Get_email_(V2)')?['receivedDateTime'])),36000000000)"
        },
        "Compose_2": {
          "inputs": "@div(outputs('Compose'),24)"
        },
        "Get_items": {
          "inputs": {
            "parameters": {
              "$filter": "@concat('EmailID eq ''', items('Apply_to_each')?['id'], '''')"
            }
          }
        },
        "Condition_2": {
          "expression": {
            "equals": [
              "@length(body('Get_items')?['value'])",
              0
            ]
          },
          "actions": {
            "Create_item": {
              "inputs": {
                "parameters": {
                  "item/Title": "@items('Apply_to_each')?['subject']",
                  "item/EmailSubject": "@items('Apply_to_each')?['subject']",
                  "item/SenderEmail": "@items('Apply_to_each')?['from']",
                  "item/ReceivedDate": "@body('Get_email_(V2)')?['receivedDateTime']",
                  "item/ApprovalDate": "@body('Current_time')",
                  "item/DaysToApprove": "@outputs('Compose_2')",
                  "item/HoursToApprove": "@outputs('Compose')",
                  "item/ApproverCategory": "@string(items('Apply_to_each')?['categories'])",
                  "item/EmailID": "@items('Apply_to_each')?['id']"
                }
              }
            }
          }
        }
      }
    }
  }
}
```

**Key components:**

1. **Subject line filter** -- `contains(toLower(...), 'invoice')` -- case-insensitive filter applied within the foreach loop. This was the working solution after discovering the standard Outlook connector cannot filter on email categories or flags for shared mailboxes without Graph API access
2. **Dual-action email retrieval** -- `Get_emails_(V3)` retrieves the list; `Get_email_(V2)` fires on each qualifying item to retrieve the full message including `receivedDateTime`, which the list endpoint does not return with sufficient granularity
3. **Ticks-based cycle time calculation** -- subtracts received ticks from current ticks and divides by 36,000,000,000 to produce hours elapsed. A second Compose action divides by 24 for days elapsed
4. **Message ID deduplication** -- before any write, a SharePoint Get Items query filters on `EmailID`. A second condition checks if the returned array length equals zero. The Create Item action only fires if no duplicate exists, preventing the 15-minute schedule from writing duplicate records
5. **SharePoint write** -- structured record written to Approval Tracker list on each qualifying, non-duplicate email

**What the dataset was designed to capture:**

- Invoice cycle times from receipt to approval, measured in hours and days
- Conversation thread sizes to quantify how many touchpoints a single invoice was consuming
- Persistent supplier non-compliance -- identifying which suppliers were repeatedly arriving without a PO, with outdated POs, or with incorrect contact details, distinguishing structural problems from one-off errors
- Approver bottlenecks -- surfacing which contacts in the approval chain were consistently slowing throughput
- A verifiable dollar figure on what the process redesign had saved the business

**What was not completed before contract ended:**

Microsoft Graph API integration was scoped and designed -- HTTP actions using OAuth2 authentication through an Azure App Registration -- to retrieve conversation thread counts and category metadata that the standard Outlook connector cannot expose for shared mailboxes. This required an Azure App Registration provisioned by IT admin. The request was submitted but IT could not complete the provisioning before the contract concluded.

As a result, the following SharePoint fields exist in the schema but were not populated:
- `ThreadMessageCount` -- designed to receive thread message count from Graph API
- `ApproverCategory` -- designed to receive Outlook category metadata from Graph API
- `ApproverName` -- designed to receive approver identity from Graph API

The pipeline was live, structured, and running at contract end. The schema was built for the complete vision, not just what the connector could immediately deliver.
