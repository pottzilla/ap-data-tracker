## Module Specifications

### config/settings.py
Load all environment variables via python-dotenv. Export as constants. Raise a descriptive error on startup if any required variable is missing -- do not allow the pipeline to run with incomplete credentials.

### src/auth.py
Implement `get_access_token()` using client credentials OAuth2 flow.

Endpoint:
```
POST https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token
```
Scope: `https://graph.microsoft.com/.default`

Implement token caching -- store the token and its expiry time, return the cached token if still valid, re-authenticate only when expired. This prevents unnecessary authentication calls on each 15-minute pipeline run.

### src/email_monitor.py
Implement `get_invoice_emails(access_token, mailbox)` using Microsoft Graph API.

Endpoint:
```
GET https://graph.microsoft.com/v1.0/users/{mailbox}/messages
```

Parameters:
```
$filter: contains(tolower(subject), 'invoice')
$select: id,subject,from,receivedDateTime,conversationId,categories,bodyPreview
$top: 50
```

- Handle pagination via `@odata.nextLink`
- Exclude emails where subject starts with `RE:` or `FW:` to prevent reply chain duplicates
- Return full list of qualifying email objects

For each qualifying email, make a second call to retrieve thread message count:
```
GET https://graph.microsoft.com/v1.0/users/{mailbox}/messages
?$filter=conversationId eq '{conversationId}'&$count=true
```

This is the Graph API call that was pending IT provisioning in the original build. It is now executable because we own the App Registration.

### src/cycle_time.py
Implement `calculate_cycle_time(received_datetime_str)`:
- Parse receivedDateTime ISO string from Graph API response
- Calculate delta between received time and current UTC time using Python datetime
- Return tuple of `(hours_elapsed: float, days_elapsed: float)` rounded to 2 decimal places

This replaces the ticks-based expression from the original Power Automate flow with clean, readable Python logic producing identical output.

### src/sharepoint.py
Implement two functions:

`check_duplicate(access_token, site_id, list_id, email_id)`:
- Query SharePoint list filtering on EmailID field via Graph API
- Return True if record exists, False if not

`write_record(access_token, site_id, list_id, record: dict)`:
- POST new item to SharePoint list via Graph API
- Map all record fields to SharePoint column names exactly as defined in schema
- Handle 400/403 errors with descriptive error messages

Graph API SharePoint endpoint:
```
POST https://graph.microsoft.com/v1.0/sites/{site_id}/lists/{list_id}/items
```

### src/claude_enrichment.py
Implement `classify_invoice(subject, sender, body_preview)` using the Anthropic Python SDK.

Model: `claude-opus-4-7` with adaptive thinking (`thinking={"type": "adaptive"}`)
Max tokens: 500

Store the prompt as a module-level constant so it can be modified without touching function logic:

```python
CLASSIFICATION_PROMPT = """
You are an accounts payable analyst. Analyse this invoice email and return 
a JSON object with exactly these fields:
- has_po: boolean -- true if a PO or work order reference is present
- supplier_risk: "low" / "medium" / "high" -- based on subject and sender
- anomaly_reason: string or null -- describe anything unusual; null if nothing unusual
- compliance_status: "compliant" / "non_compliant" / "unclear"

Email subject: {subject}
Sender: {sender}
Body preview: {body_preview}

Return JSON only. No preamble. No markdown formatting. No explanation.
"""
```

Wrap JSON parse in try/except -- if parsing fails return a safe default dict with all fields set to null or false. Never allow a failed enrichment call to break the pipeline.

### src/weekly_summary.py
Implement `generate_weekly_summary(access_token, site_id, list_id)`:
- Retrieve all SharePoint records from the past 7 days via Graph API
- Pass full dataset as JSON string to Claude
- Prompt Claude to return a plain English AP performance summary covering:
  - Average cycle time in hours and days
  - Worst performing suppliers by cycle time and compliance rate
  - Overall compliance rate for the week
  - Anomaly count and descriptions
  - Recommended actions
- Return summary string

### src/pipeline.py
Implement `run_pipeline()` orchestrating all modules:
1. Get access token
2. Retrieve invoice emails from shared mailbox
3. For each email:
   - Check duplicate -- skip if exists
   - Calculate cycle time
   - Retrieve thread message count
   - Classify via Claude enrichment
   - Build complete record dict
   - Write to SharePoint
4. Log each action with timestamp using Python logging module

### sandbox/generate_dataset.py
Generate 100 synthetic SharePoint records simulating 60 days of AP invoice history.

Supplier profiles:
```python
SUPPLIERS = [
    {
        "name": "Apex Site Works Pty Ltd",
        "email": "apexsiteworks@APdatademo.onmicrosoft.com",
        "compliance_rate": 0.80,
        "risk": "low"
    },
    {
        "name": "Clearwater Environmental Services",
        "email": "clearwaterenv@APdatademo.onmicrosoft.com",
        "compliance_rate": 0.60,
        "risk": "medium"
    },
    {
        "name": "Bridgepoint Civil Contractors",
        "email": "bridgepointcivil@APdatademo.onmicrosoft.com",
        "compliance_rate": 0.90,
        "risk": "low"
    },
    {
        "name": "Halcyon Electrical Group",
        "email": "halcyonelectrical@APdatademo.onmicrosoft.com",
        "compliance_rate": 0.40,
        "risk": "high"
    }
]
```

For each record generate:
- Realistic subject line based on compliance status
- Random received timestamp within past 60 days with hour/minute variation
- Cycle time hours between 0.5 and 96 distributed realistically
- Compliance status and supplier risk derived from compliance rate
- Approval status weighted: 60% Approved, 30% Pending, 10% Rejected
- AnomalyReason populated on approximately 10% of records with a descriptive string; null on the rest

Output as both CSV and direct SharePoint write using `write_record` from sharepoint.py.

### main.py
Entry point with four execution modes:
```
python main.py --run        # Execute pipeline once immediately
python main.py --schedule   # Run pipeline every 15 minutes via schedule library
python main.py --sandbox    # Run generate_dataset.py and send_test_emails.py
python main.py --summary    # Generate and print weekly performance summary
```
