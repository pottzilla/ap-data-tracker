# Connect to Graph with device code, then confirm
$scopes = @(
    "User.ReadWrite.All", "Mail.ReadWrite", "Mail.Send",
    "Sites.ReadWrite.All", "Directory.ReadWrite.All",
    "AppRoleAssignment.ReadWrite.All", "Application.ReadWrite.All",
    "RoleManagement.ReadWrite.Directory", "Organization.Read.All",
    "Group.ReadWrite.All"
)

Write-Host "Connecting to Graph via device code..." -ForegroundColor Yellow
Write-Host "Complete the login at https://microsoft.com/devicelogin" -ForegroundColor Cyan

Connect-MgGraph -Scopes $scopes -TenantId "APdatademo.onmicrosoft.com" -UseDeviceCode -NoWelcome -ContextScope Process

$ctx = Get-MgContext
if (-not $ctx) {
    Write-Host "AUTH FAILED" -ForegroundColor Red
    exit 1
}

Write-Host "AUTH OK: $($ctx.Account)" -ForegroundColor Green
Write-Host "Tenant: $($ctx.TenantId)" -ForegroundColor Green
