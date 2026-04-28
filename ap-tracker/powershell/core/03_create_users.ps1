# ============================================================
# 03_create_users.ps1
# Create all sandbox user accounts in the tenant
# Run after 02_connect_services.ps1
# ============================================================

Write-Host "`n[03] Creating tenant user accounts..." -ForegroundColor Cyan

# --- Read password from .env file ---
$envFile = Join-Path $PSScriptRoot "..\.env"
if (-not (Test-Path $envFile)) {
    Write-Host "  ERROR — .env file not found at $envFile" -ForegroundColor Red
    Write-Host "  Create .env with SANDBOX_ACCOUNT_PASSWORD=YourPassword" -ForegroundColor Red
    exit 1
}

$envContent = Get-Content $envFile
$passwordLine = $envContent | Where-Object { $_ -match "^SANDBOX_ACCOUNT_PASSWORD=" }
if (-not $passwordLine) {
    Write-Host "  ERROR — SANDBOX_ACCOUNT_PASSWORD not found in .env" -ForegroundColor Red
    exit 1
}

$plainPassword = $passwordLine -replace "^SANDBOX_ACCOUNT_PASSWORD=", ""
if ([string]::IsNullOrWhiteSpace($plainPassword)) {
    Write-Host "  ERROR — SANDBOX_ACCOUNT_PASSWORD is empty in .env" -ForegroundColor Red
    exit 1
}

Write-Host "  Password loaded from .env" -ForegroundColor Green

$passwordProfile = @{
    Password                      = $plainPassword
    ForceChangePasswordNextSignIn = $false
}

# --- Define accounts ---
$accounts = @(
    @{
        FirstName   = "Shared"
        LastName    = "Inbox"
        Username    = "sharedinbox"
        DisplayName = "AP Shared Inbox"
        AssignLicence = $true
    },
    @{
        FirstName   = "Apex"
        LastName    = "SiteWorks"
        Username    = "apexsiteworks"
        DisplayName = "Apex Site Works Pty Ltd"
        AssignLicence = $false
    },
    @{
        FirstName   = "Clearwater"
        LastName    = "Environmental"
        Username    = "clearwaterenv"
        DisplayName = "Clearwater Environmental Services"
        AssignLicence = $false
    },
    @{
        FirstName   = "Bridgepoint"
        LastName    = "Civil"
        Username    = "bridgepointcivil"
        DisplayName = "Bridgepoint Civil Contractors"
        AssignLicence = $false
    },
    @{
        FirstName   = "Halcyon"
        LastName    = "Electrical"
        Username    = "halcyonelectrical"
        DisplayName = "Halcyon Electrical Group"
        AssignLicence = $false
    }
)

# --- Get licence SKU for Business Premium ---
Write-Host "`n  Retrieving available licences..." -ForegroundColor Yellow
$licenceSku = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -like "*BUSINESS_PREMIUM*" }
if (-not $licenceSku) {
    $licenceSku = Get-MgSubscribedSku | Select-Object -First 1
    Write-Host "  Business Premium SKU not found — using first available SKU: $($licenceSku.SkuPartNumber)" -ForegroundColor Yellow
} else {
    Write-Host "  Found licence SKU: $($licenceSku.SkuPartNumber)" -ForegroundColor Green
}

# --- Create each account ---
foreach ($account in $accounts) {
    $upn = "$($account.Username)@APdatademo.onmicrosoft.com"

    # Check if user already exists
    $existing = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "`n  SKIP — User already exists: $upn" -ForegroundColor Yellow
        continue
    }

    Write-Host "`n  Creating: $upn" -ForegroundColor Yellow

    $newUser = New-MgUser `
        -DisplayName $account.DisplayName `
        -GivenName $account.FirstName `
        -Surname $account.LastName `
        -UserPrincipalName $upn `
        -MailNickname $account.Username `
        -PasswordProfile $passwordProfile `
        -AccountEnabled:$true `
        -UsageLocation "AU"

    Write-Host "  Created: $($newUser.DisplayName) — $upn" -ForegroundColor Green

    # Assign licence to shared inbox only
    if ($account.AssignLicence -and $licenceSku) {
        Write-Host "  Assigning licence to $upn..." -ForegroundColor Yellow
        Set-MgUserLicense -UserId $newUser.Id `
            -AddLicenses @{ SkuId = $licenceSku.SkuId } `
            -RemoveLicenses @()
        Write-Host "  Licence assigned." -ForegroundColor Green
    }
}

Write-Host "`n[03] COMPLETE — All accounts created." -ForegroundColor Green
Write-Host "  Accounts in tenant:" -ForegroundColor Cyan

Get-MgUser -Filter "startswith(userPrincipalName,'sharedinbox') or
    startswith(userPrincipalName,'apexsiteworks') or
    startswith(userPrincipalName,'clearwaterenv') or
    startswith(userPrincipalName,'bridgepointcivil') or
    startswith(userPrincipalName,'halcyonelectrical')" |
    Select-Object DisplayName, UserPrincipalName |
    Format-Table -AutoSize

Write-Host "  Run 04_create_shared_mailbox.ps1 next.`n" -ForegroundColor Cyan
