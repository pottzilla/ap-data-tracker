# ============================================================
# run_fix_and_verify.ps1
# 1. Connect via device code (delegated) for admin operations
# 2. Add missing permissions to App Registration
# 3. Run script 06 (SharePoint site + list)
# 4. Reconnect via app credentials (application perms)
# 5. Run script 08 (full verification)
# ============================================================

Set-Location $PSScriptRoot\..\..

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Fix Permissions + SharePoint + Verify" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Step 1: Connect via device code ---
Write-Host ""
Write-Host "========== STEP 1: DELEGATED AUTH ==========" -ForegroundColor Magenta
. .\powershell\core\02_connect_services.ps1

$ctx = Get-MgContext
if (-not $ctx) {
    Write-Host "FATAL -- Graph connection failed." -ForegroundColor Red
    exit 1
}

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

# Update the app's requiredResourceAccess to include all permissions
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

# --- Step 3: Run script 06 (SharePoint) ---
Write-Host ""
Write-Host "========== STEP 3: SHAREPOINT SETUP ==========" -ForegroundColor Magenta
. .\powershell\core\06_create_sharepoint_list.ps1

# --- Step 4: Wait for permission propagation ---
Write-Host ""
Write-Host "  Waiting 60 seconds for permission propagation..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# --- Step 5: Reconnect via app credentials ---
Write-Host ""
Write-Host "========== STEP 4: APPLICATION AUTH ==========" -ForegroundColor Magenta

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
Write-Host "  Connected with application permissions (expanded)." -ForegroundColor Green

# --- Step 6: Run verification ---
Write-Host ""
Write-Host "========== STEP 5: FULL VERIFICATION ==========" -ForegroundColor Magenta
. .\powershell\core\08_verify_environment.ps1
