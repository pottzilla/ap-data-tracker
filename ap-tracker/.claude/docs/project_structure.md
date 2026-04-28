## Project Structure

```
ap-tracker/
|-- .env                          # API keys and credentials -- never commit
|-- .gitignore                    # Excludes .env, __pycache__, credentials.txt
|-- requirements.txt              # Python dependencies with versions
|-- README.md                     # Professional portfolio README
|-- CLAUDE.md                     # This file -- full project context
|
|-- config/
|   `-- settings.py               # Load and validate all env variables
|
|-- src/
|   |-- auth.py                   # OAuth2 token retrieval and caching
|   |-- graph_client.py           # Shared Graph HTTP helpers (retry, 401 refresh, pagination)
|   |-- email_monitor.py          # Graph API email retrieval with pagination
|   |-- cycle_time.py             # Datetime-based cycle time calculation
|   |-- sharepoint.py             # SharePoint duplicate check and write
|   |-- claude_enrichment.py      # Anthropic SDK classification
|   |-- weekly_summary.py         # Weekly AP performance summary via Claude
|   `-- pipeline.py               # Orchestrates all modules in sequence
|
|-- powershell/
|   |-- 01_install_modules.ps1    # Install Microsoft.Graph and ExchangeOnlineManagement
|   |-- 02_connect_services.ps1   # Authenticate against Graph and Exchange Online
|   |-- 03_create_users.ps1       # Create all tenant user accounts
|   |-- 04_create_shared_mailbox.ps1  # Convert AP inbox to shared mailbox
|   |-- 05_create_app_registration.ps1  # App Registration and API permissions
|   |-- 06_create_sharepoint_list.ps1   # SharePoint site and list schema
|   |-- 07_send_test_emails.ps1   # Populate AP inbox with 40 supplier emails
|   |-- 08_verify_environment.ps1 # Full environment verification report
|   |-- assign_supplier_licences.ps1  # Assign M365 licences to supplier accounts
|   |-- resend_failed.ps1         # Retry failed email sends
|   |-- run_all.ps1               # Run full infrastructure provisioning sequence
|   |-- run_fix_and_send.ps1      # Fix issues then send emails
|   |-- run_fix_and_verify.ps1    # Fix issues then verify environment
|   |-- run_licence_and_emails.ps1 # Assign licences then send emails
|   |-- run_send_emails.ps1       # Run email sending only
|   `-- run_verify.ps1            # Run verification only
|
|-- sandbox/
|   |-- generate_dataset.py       # Generate 100 synthetic SharePoint records
|   `-- send_test_emails.py       # Python equivalent of PS email sender
|
|-- make.com/
|   |-- PHASE4_GUIDE.md           # Step-by-step build guide for Make.com Scenario 1
|   `-- claude_api_modules.md     # Anthropic Claude module configuration reference
|
|-- main.py                       # Entry point with --run --schedule --sandbox --summary modes
|
|-- credentials.txt               # App Registration credentials (gitignored)
|-- tenant_id.txt                 # Tenant ID reference
|-- sharepoint_ids.txt            # SharePoint site/list IDs
|-- email_send_log.csv            # Log of 40 test email send results
`-- environment_verification_report.csv  # Latest verification results
```

## Environment Variables -- .env Structure

```
# Azure App Registration
AZURE_CLIENT_ID=
AZURE_TENANT_ID=
AZURE_CLIENT_SECRET=

# SharePoint
SHAREPOINT_SITE_ID=
SHAREPOINT_LIST_ID=

# Mailbox
AP_MAILBOX_ADDRESS=sharedinbox@APdatademo.onmicrosoft.com

# Anthropic
ANTHROPIC_API_KEY=

# Supplier accounts (for sandbox email sending)
SUPPLIER_1=apexsiteworks@APdatademo.onmicrosoft.com
SUPPLIER_2=clearwaterenv@APdatademo.onmicrosoft.com
SUPPLIER_3=bridgepointcivil@APdatademo.onmicrosoft.com
SUPPLIER_4=halcyonelectrical@APdatademo.onmicrosoft.com
```
