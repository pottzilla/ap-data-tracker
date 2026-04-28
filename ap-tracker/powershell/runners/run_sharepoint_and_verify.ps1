# ============================================================
# run_sharepoint_and_verify.ps1
# Fresh process: app credentials -> create SharePoint list -> verify
# Permissions were already granted in the previous run.
# ============================================================

Set-Location $PSScriptRoot\..\..

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SharePoint Setup + Verify (App Auth)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Connect via app credentials ---
Write-Host ""
Write-Host "========== STEP 1: APPLICATION AUTH ==========" -ForegroundColor Magenta

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

$secureToken = [System.Security.SecureString]::new()
$accessToken.ToCharArray() | ForEach-Object { $secureToken.AppendChar($_) }

Connect-MgGraph -AccessToken $secureToken -NoWelcome

$ctx = Get-MgContext
if (-not $ctx) {
    Write-Host "FATAL -- Graph connection failed." -ForegroundColor Red
    exit 1
}
Write-Host "  Connected. AuthType: $($ctx.AuthType)" -ForegroundColor Green

# --- Quick test: can we read the site? ---
Write-Host ""
Write-Host "========== STEP 2: SHAREPOINT SETUP ==========" -ForegroundColor Magenta

$tenantName = "APdatademo"
$siteAlias = "aptrackerdem"

Write-Host "  Testing site access..." -ForegroundColor Yellow
try {
    $siteTest = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/sites/${tenantName}.sharepoint.com:/sites/${siteAlias}" `
        -ErrorAction Stop
    Write-Host "  Site accessible. ID: $($siteTest.id)" -ForegroundColor Green
} catch {
    Write-Host "  ERROR accessing site: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  The app may not have Sites.ReadWrite.All. Trying to list all sites..." -ForegroundColor Yellow
    try {
        $allSites = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/sites?search=*"
        Write-Host "  Sites found: $($allSites.value.Count)" -ForegroundColor Yellow
        foreach ($s in $allSites.value) {
            Write-Host "    $($s.displayName) -- $($s.webUrl)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Cannot list sites either: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- Run script 06 ---
. .\powershell\core\06_create_sharepoint_list.ps1

# --- Run verification ---
Write-Host ""
Write-Host "========== STEP 3: FULL VERIFICATION ==========" -ForegroundColor Magenta
. .\powershell\core\08_verify_environment.ps1
