# ============================================================
# run_licence_and_emails.ps1
# 1. Connect to Graph
# 2. Assign licences to supplier accounts
# 3. Run script 07 (send test emails)
# 4. Verify inbox received emails
# ============================================================

Set-Location $PSScriptRoot\..\..

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Licence Assignment + Email Send Sequence" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Step 1: Connect to Graph ---
Write-Host ""
Write-Host "========== CONNECTING TO GRAPH ==========" -ForegroundColor Magenta
. .\powershell\core\02_connect_services.ps1

$ctx = Get-MgContext
if (-not $ctx) {
    Write-Host "FATAL -- Graph connection failed." -ForegroundColor Red
    exit 1
}

# --- Step 2: Assign licences ---
Write-Host ""
Write-Host "========== ASSIGNING LICENCES ==========" -ForegroundColor Magenta
. .\powershell\helpers\assign_supplier_licences.ps1

# --- Step 3: Send test emails ---
Write-Host ""
Write-Host "========== SENDING TEST EMAILS ==========" -ForegroundColor Magenta
. .\powershell\core\07_send_test_emails.ps1

# --- Step 4: Verify inbox ---
Write-Host ""
Write-Host "========== VERIFYING INBOX ==========" -ForegroundColor Magenta
Write-Host ""

$sharedMailbox = "sharedinbox@APdatademo.onmicrosoft.com"

Write-Host "  Waiting 30 seconds for email delivery..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

try {
    $inboxMessages = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/users/$sharedMailbox/mailFolders/inbox/messages?`$count=true&`$top=1" `
        -Headers @{ ConsistencyLevel = "eventual" }

    $totalCount = $inboxMessages.'@odata.count'
    Write-Host "  Total emails in AP inbox: $totalCount" -ForegroundColor Green

    Write-Host ""
    Write-Host "  Breakdown by sender:" -ForegroundColor Cyan
    $senders = @(
        "apexsiteworks@APdatademo.onmicrosoft.com",
        "clearwaterenv@APdatademo.onmicrosoft.com",
        "bridgepointcivil@APdatademo.onmicrosoft.com",
        "halcyonelectrical@APdatademo.onmicrosoft.com"
    )

    foreach ($sender in $senders) {
        $senderMessages = Invoke-MgGraphRequest `
            -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/users/$sharedMailbox/mailFolders/inbox/messages?`$filter=from/emailAddress/address eq '$sender'&`$count=true&`$top=1" `
            -Headers @{ ConsistencyLevel = "eventual" }
        $count = $senderMessages.'@odata.count'
        Write-Host "    $sender : $count emails" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ERROR -- Could not access inbox: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  SEQUENCE COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
