# ============================================================
# run_fix_and_send.ps1
# 1. Connect to Graph (delegated) to manage App Registration
# 2. Verify/create App Registration with Mail.Send consent
# 3. Reconnect using client credentials (application perms)
# 4. Send all 40 test emails
# 5. Verify inbox
# ============================================================

Set-Location $PSScriptRoot\..\..

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Fix Permissions + Send Emails" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Step 1: Connect via device code (delegated) ---
Write-Host ""
Write-Host "========== STEP 1: CONNECT (DELEGATED) ==========" -ForegroundColor Magenta
. .\powershell\core\02_connect_services.ps1

$ctx = Get-MgContext
if (-not $ctx) {
    Write-Host "FATAL -- Graph connection failed." -ForegroundColor Red
    exit 1
}

# --- Step 2: Check/create App Registration ---
Write-Host ""
Write-Host "========== STEP 2: APP REGISTRATION ==========" -ForegroundColor Magenta

$appName = "AP Tracker"
$tenantId = (Get-MgContext).TenantId

# Check if app exists
$app = Get-MgApplication -Filter "displayName eq '$appName'" -ErrorAction SilentlyContinue
if (-not $app) {
    Write-Host "  App Registration not found -- running script 05..." -ForegroundColor Yellow
    . .\powershell\core\05_create_app_registration.ps1
    $app = Get-MgApplication -Filter "displayName eq '$appName'" -ErrorAction SilentlyContinue
}

if (-not $app) {
    Write-Host "FATAL -- App Registration could not be created." -ForegroundColor Red
    exit 1
}

Write-Host "  App Registration: $appName" -ForegroundColor Green
Write-Host "  Client ID: $($app.AppId)" -ForegroundColor Green

# Check service principal
$sp = Get-MgServicePrincipal -Filter "appId eq '$($app.AppId)'" -ErrorAction SilentlyContinue
if (-not $sp) {
    Write-Host "  Creating service principal..." -ForegroundColor Yellow
    $sp = New-MgServicePrincipal -AppId $app.AppId
}
Write-Host "  Service Principal ID: $($sp.Id)" -ForegroundColor Green

# Get Microsoft Graph service principal
$graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

# Check and grant Mail.Send application permission
$requiredPermissions = @("Mail.Read", "Mail.Send", "Sites.ReadWrite.All", "MailboxSettings.Read")

Write-Host ""
Write-Host "  Checking application permissions..." -ForegroundColor Yellow
$assignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -ErrorAction SilentlyContinue

foreach ($permName in $requiredPermissions) {
    $appRole = $graphSp.AppRoles | Where-Object {
        $_.Value -eq $permName -and $_.AllowedMemberTypes -contains "Application"
    }

    if (-not $appRole) {
        Write-Host "  WARNING -- Role definition not found: $permName" -ForegroundColor Red
        continue
    }

    $existingGrant = $assignments | Where-Object { $_.AppRoleId -eq $appRole.Id }

    if ($existingGrant) {
        Write-Host "  [OK] $permName -- admin consent granted" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $permName -- granting admin consent..." -ForegroundColor Yellow
        try {
            New-MgServicePrincipalAppRoleAssignment `
                -ServicePrincipalId $sp.Id `
                -PrincipalId $sp.Id `
                -ResourceId $graphSp.Id `
                -AppRoleId $appRole.Id | Out-Null
            Write-Host "  [GRANTED] $permName" -ForegroundColor Green
        } catch {
            Write-Host "  [FAILED] $permName -- $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Ensure a valid client secret exists
Write-Host ""
Write-Host "  Checking client secret..." -ForegroundColor Yellow
$secrets = Get-MgApplicationPassword -ApplicationId $app.Id -ErrorAction SilentlyContinue
$validSecret = $secrets | Where-Object { $_.EndDateTime -gt (Get-Date) } | Select-Object -First 1

$clientSecretText = $null

if ($validSecret) {
    Write-Host "  Active secret exists (expires: $($validSecret.EndDateTime))" -ForegroundColor Green

    # Try to read secret from credentials.txt
    if (Test-Path '.\credentials.txt') {
        $credContent = Get-Content '.\credentials.txt'
        $secretLine = $credContent | Where-Object { $_ -match "^AZURE_CLIENT_SECRET=" }
        if ($secretLine) {
            $clientSecretText = $secretLine -replace "^AZURE_CLIENT_SECRET=", ""
            Write-Host "  Client secret loaded from credentials.txt" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  No active secret found -- creating new one..." -ForegroundColor Yellow
}

# If we don't have the secret text, create a new one
if (-not $clientSecretText) {
    Write-Host "  Creating new client secret (90 day expiry)..." -ForegroundColor Yellow
    $newSecret = Add-MgApplicationPassword `
        -ApplicationId $app.Id `
        -PasswordCredential @{
            DisplayName   = "AP Tracker Secret"
            StartDateTime = (Get-Date)
            EndDateTime   = (Get-Date).AddDays(90)
        }

    $clientSecretText = $newSecret.SecretText
    Write-Host "  New client secret created." -ForegroundColor Green

    # Update credentials.txt
    $credentialsContent = @"
# AP Tracker -- Azure App Registration Credentials
# Generated: $(Get-Date)
# NEVER commit this file to GitHub

AZURE_TENANT_ID=$tenantId
AZURE_CLIENT_ID=$($app.AppId)
AZURE_CLIENT_SECRET=$clientSecretText
AP_MAILBOX_ADDRESS=sharedinbox@APdatademo.onmicrosoft.com
"@
    $credentialsContent | Out-File -FilePath '.\credentials.txt' -Encoding UTF8
    Write-Host "  credentials.txt updated." -ForegroundColor Green
}

# --- Step 3: Wait for permission propagation ---
Write-Host ""
Write-Host "  Waiting 2 minutes for permission propagation..." -ForegroundColor Yellow
Start-Sleep -Seconds 120

# --- Step 4: Reconnect using client credentials (application perms) ---
Write-Host ""
Write-Host "========== STEP 3: CONNECT (APPLICATION) ==========" -ForegroundColor Magenta

try { Disconnect-MgGraph -ErrorAction SilentlyContinue } catch {}

$secureSecret = ConvertTo-SecureString -String $clientSecretText -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($app.AppId, $secureSecret)

Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $credential -NoWelcome -ContextScope Process

$ctx = Get-MgContext
if ($ctx) {
    Write-Host "  Connected with application permissions." -ForegroundColor Green
    Write-Host "  Auth type: $($ctx.AuthType)" -ForegroundColor Green
    Write-Host "  App name : $($ctx.AppName)" -ForegroundColor Green
} else {
    Write-Host "FATAL -- Application auth failed." -ForegroundColor Red
    exit 1
}

# --- Step 5: Send test emails ---
Write-Host ""
Write-Host "========== STEP 4: SEND TEST EMAILS ==========" -ForegroundColor Magenta
. .\powershell\core\07_send_test_emails.ps1

# --- Step 6: Verify inbox ---
Write-Host ""
Write-Host "========== STEP 5: VERIFY INBOX ==========" -ForegroundColor Magenta
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
