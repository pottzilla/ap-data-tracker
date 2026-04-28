## Current Status

### Phase 1 -- Tenant and Infrastructure -- COMPLETE
All 42 verification checks PASS as of 2026-04-17.

- [x] M365 Business Premium trial signed up
- [x] New Microsoft account created -- gp@APdatademo.onmicrosoft.com
- [x] Tenant domain confirmed -- APdatademo.onmicrosoft.com
- [x] VS Code project folder created -- ap-tracker
- [x] PowerShell scripts created (01-08) plus helper scripts (assign_supplier_licences, resend_failed, run_all, run_fix_and_send, run_fix_and_verify, run_licence_and_emails, run_send_emails, run_verify)
- [x] CLAUDE.md added to project root
- [x] Script 01 -- Modules installed
- [x] Script 02 -- Services connected
- [x] Script 03 -- Users created -- all 5 accounts verified with IDs
- [x] Script 04 -- Shared mailbox configured -- inbox folder ID confirmed, timezone AUS Eastern Standard Time
- [x] Script 05 -- App Registration created -- Client ID in .env (AZURE_CLIENT_ID), 7 permission assignments confirmed (Mail.Read, Mail.Send, Sites.ReadWrite.All, MailboxSettings.Read), client secret expiry in credentials.txt
- [x] Script 06 -- SharePoint site and list created -- site ID and list ID in .env (SHAREPOINT_SITE_ID, SHAREPOINT_LIST_ID), all 16 columns verified
- [x] Script 07 -- Test emails sent -- 40 emails in AP inbox confirmed. 38/40 initial sends succeeded; 2 failed (sequence 39: Clearwater overdue, sequence 40: Bridgepoint missing_o). Log in email_send_log.csv
- [x] Script 08 -- Full verification passed -- all checks PASS. Report in environment_verification_report.csv

**Credentials state:** Azure credentials live in credentials.txt. `.env` currently only contains `SANDBOX_ACCOUNT_PASSWORD`. SharePoint IDs are in sharepoint_ids.txt. Full `.env` population with all Azure + SharePoint values is the first task in Phase 2.

**Revisions from planned build sequence:**

| Step | Original plan | What actually happened | Resolution |
| --- | --- | --- | --- |
| Script 03 (user creation) | Create accounts -- no further action | Accounts created but Exchange mailboxes not provisioned -- no licence assignment in original plan | Created `assign_supplier_licences.ps1`; inserted as prerequisite before Script 07 |
| Script 06 (SharePoint list) | Single script creates site and list via application auth | 403 on list creation -- `Sites.ReadWrite.All` insufficient for M365 group-backed team site without app service principal as group member | Created `create_sharepoint_list_direct.ps1` and `create_list_delegated.ps1`; delegated approach succeeded |
| Script 07 (email send) | Single 40-email send via Graph sendMail | Two emails (seq 39, 40) failed due to token expiry late in the run | Created `resend_failed.ps1` to acquire a fresh token and resend only the 2 failed emails; inbox confirmed at 40 |
| Auth approach (all cross-user scripts) | Device code delegated auth (`-UseDeviceCode`) for all operations | Device code flow cannot call `sendMail` on other users' mailboxes without explicit Send As grants | Switched all cross-user and application-level operations to client credentials REST token flow |
| Script encoding | Write tool produces .ps1 files | Em dashes and backtick-n sequences in generated scripts caused PowerShell parse errors | All scripts standardised to plain ASCII; double hyphens (--) used throughout |

---

### Phase 2 -- Python Pipeline -- COMPLETE (pending live enrichment test)

- [x] config/settings.py
- [x] src/auth.py -- token retrieval tested live
- [x] src/graph_client.py -- shared Graph HTTP helpers (retry, 401 refresh, pagination)
- [x] src/email_monitor.py -- tested against live mailbox
- [x] src/cycle_time.py
- [x] src/sharepoint.py -- duplicate check and write tested live
- [~] src/claude_enrichment.py -- written; blocked on live sample-email test (zero credit balance on ANTHROPIC_API_KEY as of 2026-04-17). Safe-default fallback path verified.
- [x] src/pipeline.py -- orchestrator wired, imports clean
- [x] src/weekly_summary.py -- written, imports clean
- [x] sandbox/generate_dataset.py -- smoke-tested with seed=42, 5-record spot check
- [x] main.py -- four modes (--run, --schedule, --sandbox, --summary), argparse wired

All Phase 2 modules written. Remaining: top up Anthropic credits and rerun `test_enrichment.py` to tick claude_enrichment.py, then end-to-end live test of `--run` against the shared mailbox.

**Revisions from planned build sequence:**

| Module | Original plan | What actually happened | Resolution |
| --- | --- | --- | --- |
| src/claude_enrichment.py | Write module, test live against a sample email | Written and imports clean; live test blocked by zero credit balance on ANTHROPIC_API_KEY | Safe-default fallback verified independently; marked `[~]` pending credit top-up and live test rerun |
| End-to-end `--run` test | Run pipeline against live shared mailbox after all modules written | Deferred -- enrichment module not fully confirmed live | Planned as immediate next step once Anthropic credits are restored |

---

### Phase 3 -- Power Automate -- COMPLETE
Flow built, tested, and producing 36 rows in SharePoint Approval Tracker as of 2026-04-24.

- [x] Flow created from scratch in Power Automate designer (sandbox tenant -- no import zip)
- [x] Token fetch outside loop live (`HTTP - Get Graph token`, `Parse_JSON_token`)
- [x] Get emails (V3) -- Top 50, Fetch Only Unread Messages = No
- [x] Apply to each loop wired on `body/value`
- [x] Condition 1 -- invoice filter plus RE:/FW: exclusion confirmed working (36 of 40 emails passing -- 4 reply chains correctly excluded)
- [x] Get email (V2) wired for full-precision receivedDateTime and conversationId
- [x] HTTP Get message details live (`HTTP - Get message details`, `Parse_JSON_message_details`) -- returns flag and categories
- [x] Cycle time calculated via ticks expressions (Compose / Compose_2)
- [x] Graph HTTP thread count live (`HTTP - Get thread count`, `Parse_JSON_thread_count`, `@odata.count` populated) -- all-mailbox scope
- [x] Dedup check via Graph HTTP (`HTTP - Check duplicate`, `Parse_JSON_dedup`) -- SharePoint connector replaced
- [x] Condition 2 referencing `Parse_JSON_dedup` correctly routing new vs existing emails
- [x] Create item writing all 12 fields including ThreadMessageCount, ConversationID, ApproverCategory, ApprovalStatus
- [x] ApprovalStatus column updated in SharePoint to Unopened / flagged / complete
- [x] Update item live in If no branch with Graph-sourced integer ID
- [x] All 36 qualifying rows confirmed with ThreadMessageCount, ConversationID, ApproverCategory, and ApprovalStatus populated

**Revisions from planned build sequence:**

| Step | Original plan | What actually happened | Resolution |
| --- | --- | --- | --- |
| Step 14 (dedup check) | SharePoint connector `Get items` with EmailID filter | Platform-level connector caching (`x-ms-apihub-cached-response: true`) returned stale responses -- false positive duplicate detections | Replaced with `HTTP - Check duplicate` (direct Graph API GET) + `Parse_JSON_dedup` |
| Condition 2 expression | `length(body('Get_items')?['value'])` | `Get_items` removed; expression referenced a non-existent action | Updated to `length(body('Parse_JSON_dedup')?['value'])` |
| Update item Id | `first(body('Get_items')?['value'])?['ID']` (SharePoint integer) | Graph dedup response returns item ID as a string in `id` field | Updated to `int(body('Parse_JSON_dedup')?['value']?[0]?['id'])` |
| EmailID filter (dedup) | No special handling required | Graph returned `400 invalidRequest` -- EmailID column not indexed | Added `Prefer: HonorNonIndexedQueriesWarningMayFailRandomly` header |
| Get emails (V3) Top setting | `Top: 25` (guide default) | 25 insufficient -- inbox has 40 emails; emails beyond position 25 silently excluded | Increased to `50`; confirmed `Fetch Only Unread Messages` must be `No` |
| ApproverCategory source | `string(items('Apply_to_each')?['categories'])` from V3 connector | V3 connector response does not return `categories` field; V2 response also does not return it | Added `HTTP - Get message details` (Graph API `GET /messages/{id}?$select=flag,categories`) |
| ApprovalStatus source | `items('Apply_to_each')?['flag']?['flagStatus']` from V3 connector | V3 connector response does not return `flag` field | Mapped from `body('Parse_JSON_message_details')?['flag']?['flagStatus']` |
| ApprovalStatus logic | `if(equals(flagStatus, 'notFlagged'), 'Unopened', flagStatus)` | All non-flagged emails showing as `Unopened` including read emails | Corrected to nested-if using `isRead` from V3 item |
| Thread count scope | `mailFolders/inbox/messages` | Sent replies not counted -- they land in Sent Items, not Inbox | Changed URI to `/messages` (all folders) |
| Test run procedure | Run manually, verify row count | Recurrence fired automatically during testing -- produced 63 and 99 rows on separate test runs | Established procedure: turn flow off before clearing list, test manually, turn back on |
| Flow built from import | Original plan assumed importing Senversa JSON export | JSON export approach abandoned; flow rebuilt action-by-action from scratch | Cleaner outcome -- every action reviewed and configured for sandbox targets |
| Email count expectation | 40 emails processed | 36 emails entered the If yes branch; 4 appeared missing | Confirmed correct -- 4 are RE:/FW: reply chains correctly excluded by Condition 1 |

---

### Phase 3 additional fixes -- completed 2026-04-27
- [x] Fix 1 -- Thread count URI updated to /messages (all-mailbox scope)
- [x] Fix 2 -- ApprovalStatus corrected to nested-if using isRead
- [x] EmailID column indexed via SharePoint list settings
- [x] Dedup fixed -- encodeUriComponent() applied to email ID in HTTP - Check duplicate URI
- [x] Portfolio screenshots captured (Step 22)

### Phase 4 -- Make.com -- COMPLETE

Scenario 1 built and live as of 2026-04-28. Three-module structure: SharePoint Online (Watch Items) -> Anthropic Claude (Create a Message) -> SharePoint Online (Update an Item). No HTTP module or JSON parse modules -- native Claude module used with parseJSON() inline field mapping. ApproverName and AnomalyFlag removed from schema. EmailID and ConversationID hidden from SharePoint list view (columns retained, data intact). Portfolio screenshots captured.

- [x] Scenario 1 -- real-time enrichment live (3 modules: SharePoint Watch -> Anthropic Claude -> SharePoint Update)
- [x] SharePoint rows enriched -- ComplianceStatus, SupplierRisk, AnomalyReason populated
- [x] Portfolio screenshots captured (scenario canvas, run history, Claude module config/output, enriched SP row)

Scenario 2 (weekly summary) -- not built. Descoped in favour of a cleaner, demonstrable single-scenario build.

### Phase 5 -- Completion
- [ ] Synthetic dataset generated and imported
- [ ] Live pipeline running for 2+ weeks
- [ ] Full dataset reviewed and validated
- [ ] GitHub repository published with README
- [ ] Portfolio document complete

---

*Last updated: 2026-04-24*
