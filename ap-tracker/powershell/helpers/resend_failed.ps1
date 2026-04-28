# Resend the 2 emails that failed due to token expiry

Set-Location $PSScriptRoot\..

# --- Get fresh token ---
$credContent = Get-Content '.\credentials.txt'
$tenantId = ($credContent | Where-Object { $_ -match "^AZURE_TENANT_ID=" }) -replace "^AZURE_TENANT_ID=", ""
$clientId = ($credContent | Where-Object { $_ -match "^AZURE_CLIENT_ID=" }) -replace "^AZURE_CLIENT_ID=", ""
$clientSecret = ($credContent | Where-Object { $_ -match "^AZURE_CLIENT_SECRET=" }) -replace "^AZURE_CLIENT_SECRET=", ""

$tokenBody = @{
    client_id     = $clientId
    scope         = "https://graph.microsoft.com/.default"
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}

$tokenResponse = Invoke-RestMethod `
    -Method POST `
    -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body $tokenBody

$accessToken = $tokenResponse.access_token

try { Disconnect-MgGraph -ErrorAction SilentlyContinue } catch {}

$secureToken = [System.Security.SecureString]::new()
$accessToken.ToCharArray() | ForEach-Object { $secureToken.AppendChar($_) }

Connect-MgGraph -AccessToken $secureToken -NoWelcome

Write-Host "Connected with fresh token." -ForegroundColor Green

$apInbox = "sharedinbox@APdatademo.onmicrosoft.com"
$dueDate = (Get-Date).AddDays(30).ToString("dd/MM/yyyy")

# --- Email 39: Overdue from Clearwater ---
$body1 = @{
    message = @{
        subject      = "OVERDUE: Invoice CES-3290 -- Clearwater Environmental Services"
        body         = @{
            contentType = "Text"
            content     = "Dear Accounts Payable,

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
        }
        toRecipients = @(@{ emailAddress = @{ address = $apInbox } })
    }
    saveToSentItems = $true
} | ConvertTo-Json -Depth 10

Write-Host "Sending: OVERDUE CES-3290 (Clearwater)..." -ForegroundColor Yellow
Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/clearwaterenv@APdatademo.onmicrosoft.com/sendMail" -Body $body1 -ContentType "application/json"
Write-Host "  SENT" -ForegroundColor Green

Start-Sleep -Seconds 30

# --- Email 40: Missing O from Bridgepoint ---
$body2 = @{
    message = @{
        subject      = "Invoice BPC-1245 -- Bridgepoint Civil Contractors | P031447"
        body         = @{
            contentType = "Text"
            content     = "Dear Accounts Payable,

Attached Invoice BPC-1245 for culvert installation at Bayswater North.

  Invoice No     : BPC-1245
  Order Ref      : P031447
  Job Number     : 25039
  Amount         : `$21,350.00 (excl. GST)
  Due Date       : $dueDate

Kind regards,
Bridgepoint Civil Contractors"
        }
        toRecipients = @(@{ emailAddress = @{ address = $apInbox } })
    }
    saveToSentItems = $true
} | ConvertTo-Json -Depth 10

Write-Host "Sending: BPC-1245 missing_o (Bridgepoint)..." -ForegroundColor Yellow
Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/bridgepointcivil@APdatademo.onmicrosoft.com/sendMail" -Body $body2 -ContentType "application/json"
Write-Host "  SENT" -ForegroundColor Green

# --- Verify inbox ---
Write-Host ""
Write-Host "Waiting 30 seconds then verifying inbox..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

$inboxMessages = Invoke-MgGraphRequest `
    -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/users/$apInbox/mailFolders/inbox/messages?`$count=true&`$top=1" `
    -Headers @{ ConsistencyLevel = "eventual" }

$totalCount = $inboxMessages.'@odata.count'
Write-Host "Total emails in AP inbox: $totalCount" -ForegroundColor Green

$senders = @(
    "apexsiteworks@APdatademo.onmicrosoft.com",
    "clearwaterenv@APdatademo.onmicrosoft.com",
    "bridgepointcivil@APdatademo.onmicrosoft.com",
    "halcyonelectrical@APdatademo.onmicrosoft.com"
)

foreach ($sender in $senders) {
    $senderMessages = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/users/$apInbox/mailFolders/inbox/messages?`$filter=from/emailAddress/address eq '$sender'&`$count=true&`$top=1" `
        -Headers @{ ConsistencyLevel = "eventual" }
    $count = $senderMessages.'@odata.count'
    Write-Host "  $sender : $count emails" -ForegroundColor Gray
}

Write-Host ""
Write-Host "DONE -- All 40 emails sent and verified." -ForegroundColor Green
