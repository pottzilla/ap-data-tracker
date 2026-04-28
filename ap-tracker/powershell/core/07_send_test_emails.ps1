# ============================================================
# 07_send_test_emails.ps1
# Send 40 realistic invoice emails from supplier accounts
# to the shared AP inbox with exact compliance distribution.
# Run after 06_create_sharepoint_list.ps1
# ============================================================

Write-Host ""
Write-Host "[07] Sending sandbox invoice emails..." -ForegroundColor Cyan
Write-Host "  40 emails across 4 supplier accounts." -ForegroundColor Yellow
Write-Host "  30 second delay between each send." -ForegroundColor Yellow
Write-Host ""

$apInbox = "sharedinbox@APdatademo.onmicrosoft.com"
$dueDate = (Get-Date).AddDays(30).ToString("dd/MM/yyyy")

# ============================================================
# EMAIL DEFINITIONS — 40 emails with exact distribution
# ============================================================
# Category counts:
#   Fully compliant (PO + 6 digits):  16
#   No PO (job only):                  6
#   Contact only (no job, no PO):      4
#   Missing PO prefix (digits only):   4
#   Missing O in PO (P + digits):      4
#   Overdue reminder (no PO):          2
#   Reply chains (RE:/FW:):            4
#                                     --
#   Total:                            40
#
# Per supplier (10 each):
#   Bridgepoint Civil (90%):  6 compliant, 1 no_po, 1 missing_prefix, 1 missing_o, 1 reply
#   Apex Site Works (80%):    5 compliant, 1 no_po, 1 contact_only, 1 missing_prefix, 1 missing_o, 1 reply  -- that's 11, let me fix
# Actually with 10 emails each:
#   Bridgepoint (best):  6 compliant, 1 no_po, 1 missing_prefix, 1 missing_o, 1 reply
#   Apex (good):         5 compliant, 1 no_po, 1 contact_only, 1 missing_prefix, 1 missing_o -- wait that's 10 with no reply
# Let me just define all 40 explicitly.
# ============================================================

$emails = @(

    # ===== BRIDGEPOINT CIVIL CONTRACTORS (10 emails, ~90% compliant) =====
    # 6 compliant, 1 no_po, 1 missing_prefix, 1 missing_o, 1 reply

    @{
        Sender  = "bridgepointcivil@APdatademo.onmicrosoft.com"
        Name    = "Bridgepoint Civil Contractors"
        Type    = "compliant"
        Subject = "Invoice BPC-1187 -- Bridgepoint Civil Contractors | PO029841"
        Body    = "Dear Accounts Payable,

Please find attached Invoice BPC-1187 for drainage works completed at the Ringwood East site.

Invoice Details:
  Supplier       : Bridgepoint Civil Contractors
  Invoice No     : BPC-1187
  Purchase Order : PO029841
  Job Number     : 25014
  Amount         : `$18,750.00 (excl. GST)
  Due Date       : $dueDate

Please process at your earliest convenience.

Kind regards,
Bridgepoint Civil Contractors -- Accounts Receivable"
    },
    @{
        Sender  = "bridgepointcivil@APdatademo.onmicrosoft.com"
        Name    = "Bridgepoint Civil Contractors"
        Type    = "compliant"
        Subject = "Invoice BPC-1204 -- Bridgepoint Civil | PO031522"
        Body    = "Dear Accounts Payable,

Invoice BPC-1204 attached for concrete works on Job 25031.

  Supplier       : Bridgepoint Civil Contractors
  Invoice No     : BPC-1204
  Purchase Order : PO031522
  Job Number     : 25031
  Amount         : `$42,100.00 (excl. GST)
  Due Date       : $dueDate

Regards,
Accounts -- Bridgepoint Civil"
    },
    @{
        Sender  = "bridgepointcivil@APdatademo.onmicrosoft.com"
        Name    = "Bridgepoint Civil Contractors"
        Type    = "compliant"
        Subject = "Invoice BPC-1210 -- Bridgepoint Civil Contractors | PO028774"
        Body    = "Hi,

Please find Invoice BPC-1210 for kerb and channel installation at Dandenong South.

  Invoice No     : BPC-1210
  Purchase Order : PO028774
  Job Number     : 25008
  Amount         : `$6,320.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Bridgepoint Civil Contractors"
    },
    @{
        Sender  = "bridgepointcivil@APdatademo.onmicrosoft.com"
        Name    = "Bridgepoint Civil Contractors"
        Type    = "compliant"
        Subject = "Invoice BPC-1215 | PO030169 -- Bridgepoint Civil"
        Body    = "Dear AP Team,

Attached is Invoice BPC-1215 for road base preparation.

  Supplier       : Bridgepoint Civil Contractors
  Invoice No     : BPC-1215
  Purchase Order : PO030169
  Job Number     : 25022
  Amount         : `$27,500.00 (excl. GST)
  Due Date       : $dueDate

Please do not hesitate to contact us with any queries.

Regards,
Bridgepoint Civil -- Accounts"
    },
    @{
        Sender  = "bridgepointcivil@APdatademo.onmicrosoft.com"
        Name    = "Bridgepoint Civil Contractors"
        Type    = "compliant"
        Subject = "Invoice BPC-1221 -- Bridgepoint Civil Contractors | PO033017"
        Body    = "Dear Accounts Payable,

Invoice BPC-1221 for stormwater pit installation -- Job 25045.

  Invoice No     : BPC-1221
  Purchase Order : PO033017
  Job Number     : 25045
  Amount         : `$11,200.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Bridgepoint Civil Contractors -- AR"
    },
    @{
        Sender  = "bridgepointcivil@APdatademo.onmicrosoft.com"
        Name    = "Bridgepoint Civil Contractors"
        Type    = "compliant"
        Subject = "Invoice BPC-1228 -- Bridgepoint Civil | PO029103"
        Body    = "Hi,

Please process Invoice BPC-1228 for retaining wall works at Lilydale.

  Invoice No     : BPC-1228
  Purchase Order : PO029103
  Job Number     : 25019
  Amount         : `$34,800.00 (excl. GST)
  Due Date       : $dueDate

Regards,
Bridgepoint Civil"
    },
    @{
        Sender  = "bridgepointcivil@APdatademo.onmicrosoft.com"
        Name    = "Bridgepoint Civil Contractors"
        Type    = "no_po"
        Subject = "Invoice BPC-1233 -- Bridgepoint Civil Contractors"
        Body    = "Dear Accounts Payable,

Please find attached Invoice BPC-1233 for additional earthworks on Job 25027.

  Supplier       : Bridgepoint Civil Contractors
  Invoice No     : BPC-1233
  Job Number     : 25027
  Amount         : `$8,400.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Bridgepoint Civil Contractors -- Accounts Receivable"
    },
    @{
        Sender  = "bridgepointcivil@APdatademo.onmicrosoft.com"
        Name    = "Bridgepoint Civil Contractors"
        Type    = "missing_prefix"
        Subject = "Invoice BPC-1240 -- Bridgepoint Civil | Ref: 030891"
        Body    = "Dear AP,

Invoice BPC-1240 for footpath works at Croydon.

  Invoice No     : BPC-1240
  Reference      : 030891
  Job Number     : 25033
  Amount         : `$15,600.00 (excl. GST)
  Due Date       : $dueDate

Regards,
Bridgepoint Civil"
    },
    @{
        Sender  = "bridgepointcivil@APdatademo.onmicrosoft.com"
        Name    = "Bridgepoint Civil Contractors"
        Type    = "missing_o"
        Subject = "Invoice BPC-1245 -- Bridgepoint Civil Contractors | P031447"
        Body    = "Dear Accounts Payable,

Attached Invoice BPC-1245 for culvert installation at Bayswater North.

  Invoice No     : BPC-1245
  Order Ref      : P031447
  Job Number     : 25039
  Amount         : `$21,350.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Bridgepoint Civil Contractors"
    },
    @{
        Sender  = "bridgepointcivil@APdatademo.onmicrosoft.com"
        Name    = "Bridgepoint Civil Contractors"
        Type    = "reply_chain"
        Subject = "RE: Invoice BPC-1187 -- Bridgepoint Civil Contractors | PO029841"
        Body    = "Hi,

Just following up on the below -- has this been processed?

Regards,
Bridgepoint Civil"
    },

    # ===== APEX SITE WORKS PTY LTD (10 emails, ~80% compliant) =====
    # 5 compliant, 1 no_po, 1 contact_only, 1 missing_prefix, 1 missing_o, 1 reply

    @{
        Sender  = "apexsiteworks@APdatademo.onmicrosoft.com"
        Name    = "Apex Site Works Pty Ltd"
        Type    = "compliant"
        Subject = "Invoice ASW-7712 -- Apex Site Works | PO027394"
        Body    = "Dear Accounts Payable,

Please find attached Invoice ASW-7712 for site clearing and demolition works at Heidelberg.

Invoice Details:
  Supplier       : Apex Site Works Pty Ltd
  Invoice No     : ASW-7712
  Purchase Order : PO027394
  Job Number     : 25003
  Amount         : `$23,400.00 (excl. GST)
  Due Date       : $dueDate

Please process at your earliest convenience.

Kind regards,
Apex Site Works Pty Ltd -- Accounts Receivable"
    },
    @{
        Sender  = "apexsiteworks@APdatademo.onmicrosoft.com"
        Name    = "Apex Site Works Pty Ltd"
        Type    = "compliant"
        Subject = "Invoice ASW-7718 | PO030244 -- Apex Site Works"
        Body    = "Hi,

Invoice ASW-7718 for bulk excavation at Epping.

  Invoice No     : ASW-7718
  Purchase Order : PO030244
  Job Number     : 25011
  Amount         : `$49,200.00 (excl. GST)
  Due Date       : $dueDate

Regards,
Apex Site Works"
    },
    @{
        Sender  = "apexsiteworks@APdatademo.onmicrosoft.com"
        Name    = "Apex Site Works Pty Ltd"
        Type    = "compliant"
        Subject = "Invoice ASW-7724 -- Apex Site Works Pty Ltd | PO028817"
        Body    = "Dear AP Team,

Attached is Invoice ASW-7724 for topsoil supply and spread at South Morang.

  Supplier       : Apex Site Works Pty Ltd
  Invoice No     : ASW-7724
  Purchase Order : PO028817
  Job Number     : 25016
  Amount         : `$3,150.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Apex Site Works -- AR"
    },
    @{
        Sender  = "apexsiteworks@APdatademo.onmicrosoft.com"
        Name    = "Apex Site Works Pty Ltd"
        Type    = "compliant"
        Subject = "Invoice ASW-7730 -- Apex Site Works | PO032618"
        Body    = "Dear Accounts Payable,

Invoice ASW-7730 for rock hammering works -- Job 25029.

  Invoice No     : ASW-7730
  Purchase Order : PO032618
  Job Number     : 25029
  Amount         : `$16,800.00 (excl. GST)
  Due Date       : $dueDate

Regards,
Apex Site Works Pty Ltd"
    },
    @{
        Sender  = "apexsiteworks@APdatademo.onmicrosoft.com"
        Name    = "Apex Site Works Pty Ltd"
        Type    = "compliant"
        Subject = "Invoice ASW-7735 -- Apex Site Works Pty Ltd | PO029550"
        Body    = "Hi,

Please process Invoice ASW-7735 for temporary fencing and hoarding at Mitcham.

  Invoice No     : ASW-7735
  Purchase Order : PO029550
  Job Number     : 25024
  Amount         : `$1,980.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Apex Site Works"
    },
    @{
        Sender  = "apexsiteworks@APdatademo.onmicrosoft.com"
        Name    = "Apex Site Works Pty Ltd"
        Type    = "no_po"
        Subject = "Invoice ASW-7741 -- Apex Site Works Pty Ltd"
        Body    = "Dear Accounts Payable,

Please find attached Invoice ASW-7741 for additional tree removal on Job 25037.

  Supplier       : Apex Site Works Pty Ltd
  Invoice No     : ASW-7741
  Job Number     : 25037
  Amount         : `$4,600.00 (excl. GST)
  Due Date       : $dueDate

Please do not hesitate to contact us with any queries.

Kind regards,
Apex Site Works Pty Ltd -- Accounts Receivable"
    },
    @{
        Sender  = "apexsiteworks@APdatademo.onmicrosoft.com"
        Name    = "Apex Site Works Pty Ltd"
        Type    = "contact_only"
        Subject = "Invoice ASW-7748 -- Apex Site Works Pty Ltd"
        Body    = "Dear Accounts Payable,

Please find attached Invoice ASW-7748 for emergency site works as discussed with Mark Thompson.

  Supplier       : Apex Site Works Pty Ltd
  Invoice No     : ASW-7748
  Contact        : Mark Thompson
  Amount         : `$7,250.00 (excl. GST)
  Due Date       : $dueDate

Mark authorised the works on-site last Thursday. Please contact him for the job details.

Kind regards,
Apex Site Works Pty Ltd"
    },
    @{
        Sender  = "apexsiteworks@APdatademo.onmicrosoft.com"
        Name    = "Apex Site Works Pty Ltd"
        Type    = "missing_prefix"
        Subject = "Invoice ASW-7753 -- Apex Site Works | Ref: 028104"
        Body    = "Dear AP,

Invoice ASW-7753 for sediment control installation at Templestowe.

  Invoice No     : ASW-7753
  Order Ref      : 028104
  Job Number     : 25009
  Amount         : `$2,340.00 (excl. GST)
  Due Date       : $dueDate

Regards,
Apex Site Works"
    },
    @{
        Sender  = "apexsiteworks@APdatademo.onmicrosoft.com"
        Name    = "Apex Site Works Pty Ltd"
        Type    = "missing_o"
        Subject = "Invoice ASW-7759 -- Apex Site Works Pty Ltd | P030772"
        Body    = "Dear Accounts Payable,

Attached Invoice ASW-7759 for access road construction at Mill Park.

  Invoice No     : ASW-7759
  Ref            : P030772
  Job Number     : 25041
  Amount         : `$13,500.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Apex Site Works"
    },
    @{
        Sender  = "apexsiteworks@APdatademo.onmicrosoft.com"
        Name    = "Apex Site Works Pty Ltd"
        Type    = "reply_chain"
        Subject = "FW: Invoice ASW-7741 -- Apex Site Works Pty Ltd"
        Body    = "Hi AP team,

Forwarding this again as we haven't received confirmation of receipt.

Regards,
Apex Site Works -- AR"
    },

    # ===== CLEARWATER ENVIRONMENTAL SERVICES (10 emails, ~60% compliant) =====
    # 3 compliant, 2 no_po, 1 contact_only, 1 missing_prefix, 1 missing_o, 1 overdue, 1 reply

    @{
        Sender  = "clearwaterenv@APdatademo.onmicrosoft.com"
        Name    = "Clearwater Environmental Services"
        Type    = "compliant"
        Subject = "Invoice CES-3304 -- Clearwater Environmental | PO031880"
        Body    = "Dear Accounts Payable,

Please find attached Invoice CES-3304 for contaminated soil removal at Footscray.

Invoice Details:
  Supplier       : Clearwater Environmental Services
  Invoice No     : CES-3304
  Purchase Order : PO031880
  Job Number     : 25018
  Amount         : `$31,200.00 (excl. GST)
  Due Date       : $dueDate

Please process at your earliest convenience.

Kind regards,
Clearwater Environmental Services -- Accounts Receivable"
    },
    @{
        Sender  = "clearwaterenv@APdatademo.onmicrosoft.com"
        Name    = "Clearwater Environmental Services"
        Type    = "compliant"
        Subject = "Invoice CES-3311 -- Clearwater Environmental Services | PO029667"
        Body    = "Hi,

Invoice CES-3311 for groundwater monitoring -- Job 25006.

  Invoice No     : CES-3311
  Purchase Order : PO029667
  Job Number     : 25006
  Amount         : `$8,900.00 (excl. GST)
  Due Date       : $dueDate

Regards,
Clearwater Environmental"
    },
    @{
        Sender  = "clearwaterenv@APdatademo.onmicrosoft.com"
        Name    = "Clearwater Environmental Services"
        Type    = "compliant"
        Subject = "Invoice CES-3318 | PO032204 -- Clearwater Environmental"
        Body    = "Dear AP Team,

Attached is Invoice CES-3318 for asbestos survey and sampling at Sunshine West.

  Supplier       : Clearwater Environmental Services
  Invoice No     : CES-3318
  Purchase Order : PO032204
  Job Number     : 25035
  Amount         : `$4,750.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Clearwater Environmental Services"
    },
    @{
        Sender  = "clearwaterenv@APdatademo.onmicrosoft.com"
        Name    = "Clearwater Environmental Services"
        Type    = "no_po"
        Subject = "Invoice CES-3325 -- Clearwater Environmental Services"
        Body    = "Dear Accounts Payable,

Please find Invoice CES-3325 for dewatering services at Altona North on Job 25042.

  Supplier       : Clearwater Environmental Services
  Invoice No     : CES-3325
  Job Number     : 25042
  Amount         : `$14,300.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Clearwater Environmental -- AR"
    },
    @{
        Sender  = "clearwaterenv@APdatademo.onmicrosoft.com"
        Name    = "Clearwater Environmental Services"
        Type    = "no_po"
        Subject = "Invoice CES-3332 -- Clearwater Environmental"
        Body    = "Hi,

Invoice CES-3332 attached for waste classification and disposal -- Job 25026.

  Invoice No     : CES-3332
  Job Number     : 25026
  Amount         : `$19,800.00 (excl. GST)
  Due Date       : $dueDate

Regards,
Clearwater Environmental Services"
    },
    @{
        Sender  = "clearwaterenv@APdatademo.onmicrosoft.com"
        Name    = "Clearwater Environmental Services"
        Type    = "contact_only"
        Subject = "Invoice CES-3340 -- Clearwater Environmental Services"
        Body    = "Dear Accounts Payable,

Please find attached Invoice CES-3340 for emergency spill response as arranged with Sarah Chen.

  Supplier       : Clearwater Environmental Services
  Invoice No     : CES-3340
  Contact        : Sarah Chen
  Amount         : `$5,800.00 (excl. GST)
  Due Date       : $dueDate

Sarah called our team out on short notice. She can confirm the job details and provide a PO.

Kind regards,
Clearwater Environmental Services"
    },
    @{
        Sender  = "clearwaterenv@APdatademo.onmicrosoft.com"
        Name    = "Clearwater Environmental Services"
        Type    = "missing_prefix"
        Subject = "Invoice CES-3347 -- Clearwater Environmental | Ref: 031205"
        Body    = "Dear AP,

Invoice CES-3347 for soil sampling at Laverton.

  Invoice No     : CES-3347
  Reference      : 031205
  Job Number     : 25013
  Amount         : `$2,100.00 (excl. GST)
  Due Date       : $dueDate

Regards,
Clearwater Environmental"
    },
    @{
        Sender  = "clearwaterenv@APdatademo.onmicrosoft.com"
        Name    = "Clearwater Environmental Services"
        Type    = "missing_o"
        Subject = "Invoice CES-3354 -- Clearwater Environmental Services | P044821"
        Body    = "Dear Accounts Payable,

Attached Invoice CES-3354 for site remediation at Yarraville.

  Invoice No     : CES-3354
  Order Ref      : P044821
  Job Number     : 25048
  Amount         : `$26,400.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Clearwater Environmental Services"
    },
    @{
        Sender  = "clearwaterenv@APdatademo.onmicrosoft.com"
        Name    = "Clearwater Environmental Services"
        Type    = "overdue"
        Subject = "OVERDUE: Invoice CES-3290 -- Clearwater Environmental Services"
        Body    = "Dear Accounts Payable,

This is a reminder that Invoice CES-3290 is now 14 days overdue.

  Supplier       : Clearwater Environmental Services
  Invoice No     : CES-3290
  Job Number     : 25002
  Amount         : `$11,500.00 (excl. GST)
  Original Due   : 01/03/2026
  Days Overdue   : 14

Please arrange payment as a matter of urgency. If this has already been processed, kindly disregard.

Kind regards,
Clearwater Environmental Services -- Credit Control"
    },
    @{
        Sender  = "clearwaterenv@APdatademo.onmicrosoft.com"
        Name    = "Clearwater Environmental Services"
        Type    = "reply_chain"
        Subject = "RE: Invoice CES-3325 -- Clearwater Environmental Services"
        Body    = "Hi,

Following up -- has this been allocated for processing?

Regards,
Clearwater Environmental"
    },

    # ===== HALCYON ELECTRICAL GROUP (10 emails, ~40% compliant) =====
    # 2 compliant, 2 no_po, 2 contact_only, 1 missing_prefix, 1 missing_o, 1 overdue, 1 reply

    @{
        Sender  = "halcyonelectrical@APdatademo.onmicrosoft.com"
        Name    = "Halcyon Electrical Group"
        Type    = "compliant"
        Subject = "Invoice HEG-0558 -- Halcyon Electrical Group | PO028390"
        Body    = "Dear Accounts Payable,

Please find attached Invoice HEG-0558 for switchboard upgrade at the Tullamarine depot.

Invoice Details:
  Supplier       : Halcyon Electrical Group
  Invoice No     : HEG-0558
  Purchase Order : PO028390
  Job Number     : 25005
  Amount         : `$9,750.00 (excl. GST)
  Due Date       : $dueDate

Please process at your earliest convenience.

Kind regards,
Halcyon Electrical Group -- Accounts Receivable"
    },
    @{
        Sender  = "halcyonelectrical@APdatademo.onmicrosoft.com"
        Name    = "Halcyon Electrical Group"
        Type    = "compliant"
        Subject = "Invoice HEG-0564 -- Halcyon Electrical | PO033501"
        Body    = "Hi,

Invoice HEG-0564 for emergency lighting installation -- Job 25044.

  Invoice No     : HEG-0564
  Purchase Order : PO033501
  Job Number     : 25044
  Amount         : `$3,400.00 (excl. GST)
  Due Date       : $dueDate

Regards,
Halcyon Electrical Group"
    },
    @{
        Sender  = "halcyonelectrical@APdatademo.onmicrosoft.com"
        Name    = "Halcyon Electrical Group"
        Type    = "no_po"
        Subject = "Invoice HEG-0571 -- Halcyon Electrical Group"
        Body    = "Dear Accounts Payable,

Please find Invoice HEG-0571 for general power outlet installation on Job 25020.

  Supplier       : Halcyon Electrical Group
  Invoice No     : HEG-0571
  Job Number     : 25020
  Amount         : `$1,250.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Halcyon Electrical Group -- AR"
    },
    @{
        Sender  = "halcyonelectrical@APdatademo.onmicrosoft.com"
        Name    = "Halcyon Electrical Group"
        Type    = "no_po"
        Subject = "Invoice HEG-0577 -- Halcyon Electrical"
        Body    = "Hi,

Invoice HEG-0577 for data cabling at Craigieburn -- Job 25038.

  Invoice No     : HEG-0577
  Job Number     : 25038
  Amount         : `$6,900.00 (excl. GST)
  Due Date       : $dueDate

Regards,
Halcyon Electrical Group"
    },
    @{
        Sender  = "halcyonelectrical@APdatademo.onmicrosoft.com"
        Name    = "Halcyon Electrical Group"
        Type    = "contact_only"
        Subject = "Invoice HEG-0583 -- Halcyon Electrical Group"
        Body    = "Dear Accounts Payable,

Attached is Invoice HEG-0583 for after-hours callout as arranged with David Kowalski.

  Supplier       : Halcyon Electrical Group
  Invoice No     : HEG-0583
  Contact        : David Kowalski
  Amount         : `$890.00 (excl. GST)
  Due Date       : $dueDate

David called us out for a tripped main at one of the sites. He should be able to provide the job and PO details.

Kind regards,
Halcyon Electrical Group"
    },
    @{
        Sender  = "halcyonelectrical@APdatademo.onmicrosoft.com"
        Name    = "Halcyon Electrical Group"
        Type    = "contact_only"
        Subject = "Invoice HEG-0589 -- Halcyon Electrical Group"
        Body    = "Dear AP Team,

Invoice HEG-0589 for safety switch testing as discussed with James Nguyen.

  Supplier       : Halcyon Electrical Group
  Invoice No     : HEG-0589
  Contact        : James Nguyen
  Amount         : `$2,200.00 (excl. GST)
  Due Date       : $dueDate

James organised the compliance testing across three sites. He can advise on the job numbers.

Regards,
Halcyon Electrical"
    },
    @{
        Sender  = "halcyonelectrical@APdatademo.onmicrosoft.com"
        Name    = "Halcyon Electrical Group"
        Type    = "missing_prefix"
        Subject = "Invoice HEG-0594 -- Halcyon Electrical | Ref: 029773"
        Body    = "Dear AP,

Invoice HEG-0594 for conduit installation at Broadmeadows.

  Invoice No     : HEG-0594
  Reference      : 029773
  Job Number     : 25012
  Amount         : `$4,100.00 (excl. GST)
  Due Date       : $dueDate

Regards,
Halcyon Electrical Group"
    },
    @{
        Sender  = "halcyonelectrical@APdatademo.onmicrosoft.com"
        Name    = "Halcyon Electrical Group"
        Type    = "missing_o"
        Subject = "Invoice HEG-0600 -- Halcyon Electrical Group | P032188"
        Body    = "Dear Accounts Payable,

Attached Invoice HEG-0600 for LED lighting retrofit at Reservoir.

  Invoice No     : HEG-0600
  Ref            : P032188
  Job Number     : 25046
  Amount         : `$17,600.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Halcyon Electrical Group"
    },
    @{
        Sender  = "halcyonelectrical@APdatademo.onmicrosoft.com"
        Name    = "Halcyon Electrical Group"
        Type    = "overdue"
        Subject = "URGENT OVERDUE: Invoice HEG-0540 -- Halcyon Electrical Group"
        Body    = "Dear Accounts Payable,

Invoice HEG-0540 is now 21 days past due. This is our second reminder.

  Supplier       : Halcyon Electrical Group
  Invoice No     : HEG-0540
  Job Number     : 25001
  Amount         : `$14,200.00 (excl. GST)
  Original Due   : 22/02/2026
  Days Overdue   : 21

We require immediate payment or confirmation that this invoice has been scheduled for the next payment run.

Regards,
Halcyon Electrical Group -- Credit Control"
    },
    @{
        Sender  = "halcyonelectrical@APdatademo.onmicrosoft.com"
        Name    = "Halcyon Electrical Group"
        Type    = "reply_chain"
        Subject = "RE: Invoice HEG-0571 -- Halcyon Electrical Group"
        Body    = "Hi,

Any update on this one? It has been over a week since we sent this through.

Regards,
Halcyon Electrical -- AR"
    }
)

# --- Shuffle emails for realistic send order ---
$emails = $emails | Sort-Object { Get-Random }

# --- Print distribution summary ---
Write-Host "  Email distribution:" -ForegroundColor Cyan
$emails | Group-Object Type | Sort-Object Name | ForEach-Object {
    Write-Host "    $($_.Name): $($_.Count)" -ForegroundColor Gray
}
Write-Host ""

# --- Send each email ---
$sentCount    = 0
$failedCount  = 0
$summaryLog   = @()

foreach ($email in $emails) {
    $sender    = $email.Sender
    $subject   = $email.Subject
    $body      = $email.Body
    $emailType = $email.Type
    $name      = $email.Name

    Write-Host "  [$($sentCount + $failedCount + 1)/40] [$emailType]" -ForegroundColor Yellow
    Write-Host "    From   : $name" -ForegroundColor White
    Write-Host "    Subject: $subject" -ForegroundColor White

    $messageBody = @{
        message = @{
            subject      = $subject
            body         = @{
                contentType = "Text"
                content     = $body
            }
            toRecipients = @(
                @{
                    emailAddress = @{
                        address = $apInbox
                    }
                }
            )
        }
        saveToSentItems = $true
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/users/$sender/sendMail" `
            -Body $messageBody `
            -ContentType "application/json"

        Write-Host "    SENT" -ForegroundColor Green
        $sentCount++

        $summaryLog += [PSCustomObject]@{
            Sequence = $sentCount + $failedCount
            Supplier = $name
            Sender   = $sender
            Subject  = $subject
            Type     = $emailType
            Status   = "Sent"
        }
    } catch {
        Write-Host "    FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $failedCount++

        $summaryLog += [PSCustomObject]@{
            Sequence = $sentCount + $failedCount
            Supplier = $name
            Sender   = $sender
            Subject  = $subject
            Type     = $emailType
            Status   = "Failed"
        }
    }

    # Stagger sends
    if (($sentCount + $failedCount) -lt 40) {
        Write-Host "    Waiting 30 seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds 30
    }
}

# --- Print summary ---
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  EMAIL SEND SUMMARY" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  Total sent   : $sentCount" -ForegroundColor Green
Write-Host "  Total failed : $failedCount" -ForegroundColor Red
Write-Host ""
Write-Host "  By supplier:" -ForegroundColor Cyan

$summaryLog | Where-Object { $_.Status -eq "Sent" } | Group-Object Supplier | ForEach-Object {
    Write-Host "    $($_.Name): $($_.Count) sent" -ForegroundColor White
    $_.Group | Group-Object Type | ForEach-Object {
        Write-Host "      $($_.Name): $($_.Count)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "  By compliance type:" -ForegroundColor Cyan
$summaryLog | Where-Object { $_.Status -eq "Sent" } | Group-Object Type | Sort-Object Name | ForEach-Object {
    Write-Host "    $($_.Name): $($_.Count)" -ForegroundColor Gray
}

# --- Export summary log ---
$summaryLog | Export-Csv -Path '.\email_send_log.csv' -NoTypeInformation
Write-Host ""
Write-Host "  Full log exported to email_send_log.csv" -ForegroundColor Green

Write-Host ""
Write-Host "[07] COMPLETE -- Sandbox emails sent to AP inbox." -ForegroundColor Green
Write-Host "  Run 08_verify_environment.ps1 next." -ForegroundColor Cyan
Write-Host ""
