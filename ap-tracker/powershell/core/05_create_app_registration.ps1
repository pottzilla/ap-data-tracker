# ============================================================
# 05_create_app_registration.ps1
# Create Azure AD App Registration for AP Tracker
# Grant Graph API permissions and create client secret
# Outputs credentials to credentials.txt
# Run after 04_create_shared_mailbox.ps1
# ============================================================

Write-Host "`n[05] Creating Azure App Registration..." -ForegroundColor Cyan

$appName  = "AP Tracker"
$tenantId = Get-Content ".\tenant_id.txt" -ErrorAction SilentlyContinue
if (-not $tenantId) {
    $tenantId = (Get-MgContext).TenantId
}

Write-Host "  App Name : $appName" -ForegroundColor Yellow
Write-Host "  Tenant ID: $tenantId`n" -ForegroundColor Yellow

# --- Check if app already exists ---
$existingApp = Get-MgApplication -Filter "displayName eq '$appName'" -ErrorAction SilentlyContinue
if ($existingApp) {
    Write-Host "  App Registration already exists — using existing." -ForegroundColor Yellow
    $app = $existingApp
} else {
    # --- Create App Registration ---
    Write-Host "  Creating App Registration..." -ForegroundColor Yellow
    $app = New-MgApplication -DisplayName $appName
    Write-Host "  App Registration created." -ForegroundColor Green
}

Write-Host "  Client ID   : $($app.AppId)" -ForegroundColor Green
Write-Host "  Object ID   : $($app.Id)" -ForegroundColor Green

# --- Define required Graph API permissions ---
Write-Host "`n  Defining API permissions..." -ForegroundColor Yellow

# Get Microsoft Graph service principal
$graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

# Define permission names to assign
$permissionNames = @(
    "Mail.Read",
    "Mail.Send",
    "Sites.ReadWrite.All",
    "MailboxSettings.Read"
)

# Find permission IDs from Graph service principal
$requiredPermissions = @()
foreach ($permName in $permissionNames) {
    $appRole = $graphSp.AppRoles | Where-Object {
        $_.Value -eq $permName -and $_.AllowedMemberTypes -contains "Application"
    }
    if ($appRole) {
        $requiredPermissions += @{
            Id   = $appRole.Id
            Type = "Role"
        }
        Write-Host "  Found permission: $permName ($($appRole.Id))" -ForegroundColor Green
    } else {
        Write-Host "  WARNING — Permission not found: $permName" -ForegroundColor Red
    }
}

# --- Add permissions to app ---
Write-Host "`n  Adding permissions to App Registration..." -ForegroundColor Yellow
$resourceAccess = @{
    ResourceAppId  = "00000003-0000-0000-c000-000000000000"
    ResourceAccess = $requiredPermissions
}

Update-MgApplication -ApplicationId $app.Id -RequiredResourceAccess @($resourceAccess)
Write-Host "  Permissions added." -ForegroundColor Green

# --- Create service principal for the app ---
Write-Host "`n  Creating service principal..." -ForegroundColor Yellow
$sp = Get-MgServicePrincipal -Filter "appId eq '$($app.AppId)'" -ErrorAction SilentlyContinue
if (-not $sp) {
    $sp = New-MgServicePrincipal -AppId $app.AppId
    Write-Host "  Service principal created." -ForegroundColor Green
} else {
    Write-Host "  Service principal already exists." -ForegroundColor Green
}

# --- Grant admin consent ---
Write-Host "`n  Granting admin consent for all permissions..." -ForegroundColor Yellow
$graphSpId = $graphSp.Id

foreach ($permission in $requiredPermissions) {
    $existingGrant = Get-MgServicePrincipalAppRoleAssignment `
        -ServicePrincipalId $sp.Id `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.AppRoleId -eq $permission.Id }

    if (-not $existingGrant) {
        New-MgServicePrincipalAppRoleAssignment `
            -ServicePrincipalId $sp.Id `
            -PrincipalId $sp.Id `
            -ResourceId $graphSpId `
            -AppRoleId $permission.Id | Out-Null
        Write-Host "  Admin consent granted for permission ID: $($permission.Id)" -ForegroundColor Green
    } else {
        Write-Host "  Admin consent already granted for permission ID: $($permission.Id)" -ForegroundColor Yellow
    }
}

# --- Create client secret ---
Write-Host "`n  Creating client secret (90 day expiry)..." -ForegroundColor Yellow
$secretStartDate = Get-Date
$secretEndDate   = $secretStartDate.AddDays(90)

$secret = Add-MgApplicationPassword `
    -ApplicationId $app.Id `
    -PasswordCredential @{
        DisplayName = "AP Tracker Secret"
        StartDateTime = $secretStartDate
        EndDateTime   = $secretEndDate
    }

Write-Host "  Client secret created." -ForegroundColor Green
Write-Host "  Secret expires: $secretEndDate" -ForegroundColor Yellow

# --- Output credentials to file ---
Write-Host "`n  Writing credentials to credentials.txt..." -ForegroundColor Yellow

$credentialsContent = @"
# AP Tracker — Azure App Registration Credentials
# Generated: $(Get-Date)
# IMPORTANT: Add credentials.txt to .gitignore immediately
# NEVER commit this file to GitHub

AZURE_TENANT_ID=$tenantId
AZURE_CLIENT_ID=$($app.AppId)
AZURE_CLIENT_SECRET=$($secret.SecretText)
AP_MAILBOX_ADDRESS=sharedinbox@APdatademo.onmicrosoft.com
"@

$credentialsContent | Out-File -FilePath ".\credentials.txt" -Encoding UTF8

Write-Host "  Credentials written to credentials.txt" -ForegroundColor Green

# --- Display summary ---
Write-Host "`n  ============================================" -ForegroundColor Cyan
Write-Host "  APP REGISTRATION SUMMARY" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  App Name     : $appName" -ForegroundColor White
Write-Host "  Tenant ID    : $tenantId" -ForegroundColor White
Write-Host "  Client ID    : $($app.AppId)" -ForegroundColor White
Write-Host "  Secret Expiry: $secretEndDate" -ForegroundColor White
Write-Host "  Permissions  : Mail.Read, Mail.Send, Sites.ReadWrite.All, MailboxSettings.Read" -ForegroundColor White
Write-Host "  ============================================`n" -ForegroundColor Cyan

Write-Host "  WARNING: credentials.txt contains your client secret." -ForegroundColor Red
Write-Host "  Add it to .gitignore before creating your GitHub repository." -ForegroundColor Red

Write-Host "`n[05] COMPLETE — App Registration created with admin consent granted." -ForegroundColor Green
Write-Host "  Run 06_create_sharepoint_list.ps1 next.`n" -ForegroundColor Cyan
