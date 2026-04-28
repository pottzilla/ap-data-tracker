# ============================================================
# run_verify.ps1
# Connect via App Registration client credentials, then run
# script 08 to verify the full environment.
# ============================================================

Set-Location $PSScriptRoot\..\..

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

$ctx = Get-MgContext
if (-not $ctx) {
    Write-Host "FATAL -- Graph connection failed." -ForegroundColor Red
    exit 1
}
Write-Host "Connected via App Registration (application permissions)." -ForegroundColor Green
Write-Host ""

# --- Run verification ---
. .\powershell\core\08_verify_environment.ps1
