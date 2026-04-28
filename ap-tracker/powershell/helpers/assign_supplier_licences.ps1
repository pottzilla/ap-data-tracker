# ============================================================
# assign_supplier_licences.ps1
# Assign Microsoft 365 Business Premium licences to the four
# supplier accounts so they have active Exchange mailboxes.
# Verifies mailbox provisioning before returning.
# ============================================================

Write-Host ""
Write-Host "[LICENCE] Assigning licences to supplier accounts..." -ForegroundColor Cyan

$supplierAccounts = @(
    "apexsiteworks@APdatademo.onmicrosoft.com",
    "clearwaterenv@APdatademo.onmicrosoft.com",
    "bridgepointcivil@APdatademo.onmicrosoft.com",
    "halcyonelectrical@APdatademo.onmicrosoft.com"
)

# --- Get licence SKU ---
Write-Host ""
Write-Host "  Retrieving available licences..." -ForegroundColor Yellow
$allSkus = Get-MgSubscribedSku
$licenceSku = $allSkus | Where-Object { $_.SkuPartNumber -like "*BUSINESS_PREMIUM*" }
if (-not $licenceSku) {
    $licenceSku = $allSkus | Where-Object { $_.PrepaidUnits.Enabled -gt 0 } | Select-Object -First 1
    Write-Host "  Business Premium not found -- using: $($licenceSku.SkuPartNumber)" -ForegroundColor Yellow
} else {
    Write-Host "  Found SKU: $($licenceSku.SkuPartNumber)" -ForegroundColor Green
}

$available = $licenceSku.PrepaidUnits.Enabled - $licenceSku.ConsumedUnits
Write-Host "  Available licences: $available" -ForegroundColor $(if ($available -ge 4) { "Green" } else { "Red" })

if ($available -lt 4) {
    Write-Host "  WARNING -- Only $available licences available. Need 4." -ForegroundColor Red
    Write-Host "  Some assignments may fail." -ForegroundColor Red
}

# --- Assign licence to each supplier ---
foreach ($upn in $supplierAccounts) {
    Write-Host ""
    Write-Host "  Processing: $upn" -ForegroundColor Yellow

    $user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property "Id,DisplayName,AssignedLicenses" -ErrorAction SilentlyContinue
    if (-not $user) {
        Write-Host "  ERROR -- User not found: $upn" -ForegroundColor Red
        continue
    }

    # Check if already licensed
    $existingLicence = Get-MgUserLicenseDetail -UserId $user.Id -ErrorAction SilentlyContinue
    if ($existingLicence) {
        Write-Host "  Already licensed: $($existingLicence.SkuPartNumber -join ', ')" -ForegroundColor Green
        continue
    }

    # Assign licence
    try {
        Set-MgUserLicense -UserId $user.Id `
            -AddLicenses @(@{ SkuId = $licenceSku.SkuId }) `
            -RemoveLicenses @()
        Write-Host "  Licence assigned to $($user.DisplayName)" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR -- Failed to assign licence: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- Wait for mailbox provisioning ---
Write-Host ""
Write-Host "  Waiting for mailbox provisioning (3 minutes)..." -ForegroundColor Yellow
Start-Sleep -Seconds 180

# --- Verify mailboxes via provisionedPlans ---
Write-Host ""
Write-Host "  Verifying mailbox provisioning..." -ForegroundColor Yellow

$allReady = $true
$maxRetries = 8

foreach ($upn in $supplierAccounts) {
    $ready = $false
    $retries = 0

    while (-not $ready -and $retries -lt $maxRetries) {
        $user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property "Id,DisplayName,ProvisionedPlans" -ErrorAction SilentlyContinue
        $exchangePlan = $user.ProvisionedPlans | Where-Object {
            $_.Service -eq "exchange" -and $_.ProvisioningStatus -eq "Success"
        }

        if ($exchangePlan) {
            Write-Host "  READY -- $upn (Exchange provisioned)" -ForegroundColor Green
            $ready = $true
        } else {
            $retries++
            if ($retries -lt $maxRetries) {
                Write-Host "  PENDING -- $upn (retry $retries/$maxRetries in 30s)..." -ForegroundColor Yellow
                Start-Sleep -Seconds 30
            }
        }
    }

    if (-not $ready) {
        Write-Host "  NOT READY -- $upn (Exchange not provisioned after retries)" -ForegroundColor Red
        $allReady = $false
    }
}

if ($allReady) {
    Write-Host ""
    Write-Host "[LICENCE] COMPLETE -- All supplier mailboxes active." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[LICENCE] WARNING -- Some mailboxes may not be ready yet." -ForegroundColor Yellow
    Write-Host "  Proceeding anyway -- Graph sendMail may fail for unprovisioned mailboxes." -ForegroundColor Yellow
}

Write-Host ""
