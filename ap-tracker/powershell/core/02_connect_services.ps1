# ============================================================
# 02_connect_services.ps1
# Authenticate against Microsoft Graph (device code flow)
# Run after 01_install_modules.ps1
# ============================================================

Write-Host ""
Write-Host "[02] Connecting to Microsoft services..." -ForegroundColor Cyan
Write-Host "  Tenant: APdatademo.onmicrosoft.com" -ForegroundColor Yellow
Write-Host "  Admin:  gp@APdatademo.onmicrosoft.com" -ForegroundColor Yellow
Write-Host ""

# --- Disconnect any existing sessions ---
try { Disconnect-MgGraph -ErrorAction SilentlyContinue } catch {}

# --- Connect to Microsoft Graph (device code flow) ---
Write-Host "  Connecting to Microsoft Graph via device code flow..." -ForegroundColor Yellow
Write-Host "  You will see a code below -- open https://microsoft.com/devicelogin" -ForegroundColor Yellow
Write-Host "  and sign in with gp@APdatademo.onmicrosoft.com" -ForegroundColor Yellow
Write-Host ""

$scopes = @(
    "User.ReadWrite.All",
    "Mail.ReadWrite",
    "Mail.Send",
    "Sites.ReadWrite.All",
    "Directory.ReadWrite.All",
    "AppRoleAssignment.ReadWrite.All",
    "Application.ReadWrite.All",
    "RoleManagement.ReadWrite.Directory",
    "Organization.Read.All"
)

Connect-MgGraph -Scopes $scopes -TenantId "APdatademo.onmicrosoft.com" -UseDeviceCode -NoWelcome -ContextScope Process

Write-Host ""
Write-Host "  Microsoft Graph connected." -ForegroundColor Green

# --- Confirm tenant ---
$context = Get-MgContext
Write-Host ""
Write-Host "  Authenticated as: $($context.Account)" -ForegroundColor Green
Write-Host "  Tenant ID: $($context.TenantId)" -ForegroundColor Green

# --- Save tenant ID for use in subsequent scripts ---
$tenantId = $context.TenantId
$tenantId | Out-File -FilePath '.\tenant_id.txt' -Encoding UTF8
Write-Host "  Tenant ID saved to tenant_id.txt" -ForegroundColor Green

Write-Host ""
Write-Host "[02] COMPLETE -- Microsoft Graph connected." -ForegroundColor Green
Write-Host "  Run 03_create_users.ps1 next." -ForegroundColor Cyan
Write-Host ""
