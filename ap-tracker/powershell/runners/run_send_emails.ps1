# ============================================================
# run_send_emails.ps1
# Connect using App Registration client credentials via REST
# token, then send all 40 test emails with application-level
# Mail.Send permission.
# ============================================================

Set-Location $PSScriptRoot\..\..

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Send Test Emails (Application Auth)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Load credentials from credentials.txt ---
Write-Host ""
Write-Host "  Loading credentials..." -ForegroundColor Yellow

if (-not (Test-Path '.\credentials.txt')) {
    Write-Host "FATAL -- credentials.txt not found." -ForegroundColor Red
    exit 1
}

$credContent = Get-Content '.\credentials.txt'
$tenantId = ($credContent | Where-Object { $_ -match "^AZURE_TENANT_ID=" }) -replace "^AZURE_TENANT_ID=", ""
$clientId = ($credContent | Where-Object { $_ -match "^AZURE_CLIENT_ID=" }) -replace "^AZURE_CLIENT_ID=", ""
$clientSecret = ($credContent | Where-Object { $_ -match "^AZURE_CLIENT_SECRET=" }) -replace "^AZURE_CLIENT_SECRET=", ""

Write-Host "  Tenant ID : $tenantId" -ForegroundColor Green
Write-Host "  Client ID : $clientId" -ForegroundColor Green
Write-Host "  Secret    : ****$(($clientSecret).Substring($clientSecret.Length - 4))" -ForegroundColor Green

# --- Get OAuth2 access token via REST ---
Write-Host ""
Write-Host "  Acquiring access token via client credentials flow..." -ForegroundColor Yellow

$tokenBody = @{
    client_id     = $clientId
    scope         = "https://graph.microsoft.com/.default"
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}

try {
    $tokenResponse = Invoke-RestMethod `
        -Method POST `
        -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
        -ContentType "application/x-www-form-urlencoded" `
        -Body $tokenBody

    $accessToken = $tokenResponse.access_token
    Write-Host "  Access token acquired." -ForegroundColor Green
    Write-Host "  Token expires in: $($tokenResponse.expires_in) seconds" -ForegroundColor Green
} catch {
    Write-Host "FATAL -- Token acquisition failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# --- Connect to Graph using access token ---
Write-Host ""
Write-Host "  Connecting to Microsoft Graph with application permissions..." -ForegroundColor Yellow

try { Disconnect-MgGraph -ErrorAction SilentlyContinue } catch {}

$secureToken = [System.Security.SecureString]::new()
$accessToken.ToCharArray() | ForEach-Object { $secureToken.AppendChar($_) }

Connect-MgGraph -AccessToken $secureToken -NoWelcome

$ctx = Get-MgContext
if ($ctx) {
    Write-Host "  Connected." -ForegroundColor Green
    Write-Host "  Auth type: $($ctx.AuthType)" -ForegroundColor Green
} else {
    Write-Host "FATAL -- Graph connection failed." -ForegroundColor Red
    exit 1
}

# --- Send test emails ---
Write-Host ""
Write-Host "========== SENDING TEST EMAILS ==========" -ForegroundColor Magenta
. .\powershell\core\07_send_test_emails.ps1

# --- Verify inbox ---
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
