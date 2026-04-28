# ============================================================
# run_fix_and_verify_v2.ps1
# All-in-one: auth, fix permissions, create SharePoint, verify
# Order: delegated auth -> fix perms -> app auth -> SharePoint -> verify
# ============================================================

Set-Location $PSScriptRoot\..\..

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Fix Permissions + SharePoint + Verify" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Step 1: Connect via device code ---
Write-Host ""
Write-Host "========== STEP 1: DELEGATED AUTH ==========" -ForegroundColor Magenta

$scopes = @(
    "User.ReadWrite.All", "Mail.ReadWrite", "Mail.Send",
    "Sites.ReadWrite.All", "Directory.ReadWrite.All",
    "AppRoleAssignment.ReadWrite.All", "Application.ReadWrite.All",
    "RoleManagement.ReadWrite.Directory", "Organization.Read.All",
    "Group.ReadWrite.All"
)

Connect-MgGraph -Scopes $scopes -TenantId "APdatademo.onmicrosoft.com" -UseDeviceCode -NoWelcome -ContextScope Process

$ctx = Get-MgContext
if (-not $ctx) {
    Write-Host "FATAL -- Graph connection failed." -ForegroundColor Red
    exit 1
}
Write-Host "  Connected as: $($ctx.Account)" -ForegroundColor Green

# --- Step 2: Add missing permissions to App Registration ---
Write-Host ""
Write-Host "========== STEP 2: ADD MISSING PERMISSIONS ==========" -ForegroundColor Magenta

$appName = "AP Tracker"
$app = Get-MgApplication -Filter "displayName eq '$appName'" -ErrorAction SilentlyContinue
if (-not $app) {
    Write-Host "FATAL -- App Registration not found." -ForegroundColor Red
    exit 1
}

$sp = Get-MgServicePrincipal -Filter "appId eq '$($app.AppId)'" -ErrorAction SilentlyContinue
$graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

$existingAssignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -ErrorAction SilentlyContinue

$allPermissions = @(
    "Mail.Read",
    "Mail.Send",
    "Sites.ReadWrite.All",
    "MailboxSettings.Read",
    "User.Read.All",
    "Application.Read.All",
    "Directory.Read.All"
)

foreach ($permName in $allPermissions) {
    $appRole = $graphSp.AppRoles | Where-Object {
        $_.Value -eq $permName -and $_.AllowedMemberTypes -contains "Application"
    }

    if (-not $appRole) {
        Write-Host "  WARNING -- Role not found: $permName" -ForegroundColor Red
        continue
    }

    $existingGrant = $existingAssignments | Where-Object { $_.AppRoleId -eq $appRole.Id }

    if ($existingGrant) {
        Write-Host "  [OK] $permName" -ForegroundColor Green
    } else {
        Write-Host "  [ADDING] $permName..." -ForegroundColor Yellow
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

# Update the app manifest requiredResourceAccess
$allRoleIds = @()
foreach ($permName in $allPermissions) {
    $appRole = $graphSp.AppRoles | Where-Object {
        $_.Value -eq $permName -and $_.AllowedMemberTypes -contains "Application"
    }
    if ($appRole) {
        $allRoleIds += @{ Id = $appRole.Id; Type = "Role" }
    }
}

$resourceAccess = @{
    ResourceAppId  = "00000003-0000-0000-c000-000000000000"
    ResourceAccess = $allRoleIds
}
Update-MgApplication -ApplicationId $app.Id -RequiredResourceAccess @($resourceAccess)
Write-Host ""
Write-Host "  App Registration permissions updated." -ForegroundColor Green

# --- Step 3: Switch to app credentials ---
Write-Host ""
Write-Host "========== STEP 3: APPLICATION AUTH ==========" -ForegroundColor Magenta

Write-Host "  Waiting 30 seconds for permission propagation..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

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
Write-Host "  Connected with application permissions." -ForegroundColor Green

# --- Step 4: Create SharePoint site + list ---
Write-Host ""
Write-Host "========== STEP 4: SHAREPOINT SETUP ==========" -ForegroundColor Magenta
. .\powershell\core\06_create_sharepoint_list.ps1

# --- Step 5: Run verification ---
Write-Host ""
Write-Host "========== STEP 5: FULL VERIFICATION ==========" -ForegroundColor Magenta
. .\powershell\core\08_verify_environment.ps1
