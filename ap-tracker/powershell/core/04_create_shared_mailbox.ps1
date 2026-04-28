# ============================================================
# 04_create_shared_mailbox.ps1
# Verify AP shared inbox user exists, is licensed, and all
# supplier accounts are in place.
# Mailbox access testing deferred to 08_verify_environment.ps1
# (requires app registration application permissions from 05)
# Run after 03_create_users.ps1
# ============================================================

Write-Host ""
Write-Host "[04] Verifying AP shared inbox setup..." -ForegroundColor Cyan

$sharedMailbox  = "sharedinbox@APdatademo.onmicrosoft.com"
$adminAccount   = "gp@APdatademo.onmicrosoft.com"

# --- Verify shared inbox user exists ---
Write-Host ""
Write-Host "  Verifying sharedinbox user exists..." -ForegroundColor Yellow
$user = Get-MgUser -Filter "userPrincipalName eq '$sharedMailbox'" -Property "Id,DisplayName,UserPrincipalName,AccountEnabled,AssignedLicenses" -ErrorAction SilentlyContinue
if (-not $user) {
    Write-Host "  ERROR -- User not found: $sharedMailbox" -ForegroundColor Red
    Write-Host "  Ensure 03_create_users.ps1 completed successfully." -ForegroundColor Red
    exit 1
}
Write-Host "  User found: $($user.DisplayName)" -ForegroundColor Green
Write-Host "  User ID: $($user.Id)" -ForegroundColor Green
Write-Host "  Account enabled: $($user.AccountEnabled)" -ForegroundColor Green

# --- Verify licence is assigned ---
Write-Host ""
Write-Host "  Checking licence assignment..." -ForegroundColor Yellow
$licences = Get-MgUserLicenseDetail -UserId $user.Id -ErrorAction SilentlyContinue
if ($licences) {
    Write-Host "  Licence assigned: $($licences.SkuPartNumber -join ', ')" -ForegroundColor Green
} else {
    Write-Host "  WARNING -- No licence found. Mailbox may not provision." -ForegroundColor Red
    Write-Host "  Check licence assignment in Microsoft 365 admin center." -ForegroundColor Red
}

# --- Verify admin account exists ---
Write-Host ""
Write-Host "  Verifying admin account..." -ForegroundColor Yellow
$admin = Get-MgUser -Filter "userPrincipalName eq '$adminAccount'" -ErrorAction SilentlyContinue
if ($admin) {
    Write-Host "  Admin account confirmed: $($admin.DisplayName)" -ForegroundColor Green
} else {
    Write-Host "  WARNING -- Admin account not found: $adminAccount" -ForegroundColor Red
}

# --- Verify all supplier accounts exist ---
Write-Host ""
Write-Host "  Verifying supplier accounts..." -ForegroundColor Yellow
$supplierAccounts = @(
    "apexsiteworks@APdatademo.onmicrosoft.com",
    "clearwaterenv@APdatademo.onmicrosoft.com",
    "bridgepointcivil@APdatademo.onmicrosoft.com",
    "halcyonelectrical@APdatademo.onmicrosoft.com"
)

$allSuppliersOk = $true
foreach ($upn in $supplierAccounts) {
    $supplier = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
    if ($supplier) {
        Write-Host "  OK -- $($supplier.DisplayName) ($upn)" -ForegroundColor Green
    } else {
        Write-Host "  MISSING -- $upn" -ForegroundColor Red
        $allSuppliersOk = $false
    }
}

if (-not $allSuppliersOk) {
    Write-Host ""
    Write-Host "  ERROR -- One or more supplier accounts missing." -ForegroundColor Red
    Write-Host "  Re-run 03_create_users.ps1 to create missing accounts." -ForegroundColor Red
    exit 1
}

# --- Summary ---
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  SHARED INBOX SUMMARY" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  Mailbox User  : $sharedMailbox" -ForegroundColor White
Write-Host "  User ID       : $($user.Id)" -ForegroundColor White
Write-Host "  Licensed      : $(if ($licences) { 'Yes' } else { 'No' })" -ForegroundColor White
Write-Host "  Admin Account : $adminAccount" -ForegroundColor White
Write-Host "  Suppliers     : 4/4 confirmed" -ForegroundColor White
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  NOTE: Mailbox provisioning takes 3-10 minutes after licence" -ForegroundColor Yellow
Write-Host "  assignment. Mailbox access will be verified in script 08" -ForegroundColor Yellow
Write-Host "  using app registration application permissions." -ForegroundColor Yellow

Write-Host ""
Write-Host "[04] COMPLETE -- AP shared inbox user verified." -ForegroundColor Green
Write-Host "  Run 05_create_app_registration.ps1 next." -ForegroundColor Cyan
Write-Host ""
