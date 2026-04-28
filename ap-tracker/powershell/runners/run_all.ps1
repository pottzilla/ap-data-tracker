# ============================================================
# run_all.ps1
# Execute scripts 02 through 08 in a single PowerShell session
# so the Graph connection persists across all scripts.
# ============================================================

param(
    [int]$StartFrom = 2
)

Set-Location $PSScriptRoot\..\..

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  AP Tracker -- Build Sequence Runner" -ForegroundColor Cyan
Write-Host "  Starting from script: $StartFrom" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$scripts = @(
    @{ Num = 2; File = ".\powershell\core\02_connect_services.ps1" },
    @{ Num = 3; File = ".\powershell\core\03_create_users.ps1" },
    @{ Num = 4; File = ".\powershell\core\04_create_shared_mailbox.ps1" },
    @{ Num = 5; File = ".\powershell\core\05_create_app_registration.ps1" },
    @{ Num = 6; File = ".\powershell\core\06_create_sharepoint_list.ps1" },
    @{ Num = 7; File = ".\powershell\core\07_send_test_emails.ps1" },
    @{ Num = 8; File = ".\powershell\core\08_verify_environment.ps1" }
)

foreach ($script in $scripts) {
    if ($script.Num -lt $StartFrom) { continue }

    Write-Host ""
    Write-Host "========== RUNNING SCRIPT $($script.Num) ==========" -ForegroundColor Magenta
    Write-Host ""

    # Verify Graph connection before each script (except 02 which establishes it)
    if ($script.Num -gt 2) {
        $ctx = Get-MgContext
        if (-not $ctx) {
            Write-Host "FATAL -- Graph connection lost before script $($script.Num)." -ForegroundColor Red
            Write-Host "Re-run the full sequence from script 02." -ForegroundColor Red
            exit 1
        }
        Write-Host "  Graph session active: $($ctx.Account)" -ForegroundColor Gray
    }

    . $script.File

    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "FATAL -- Script $($script.Num) exited with code $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Stopping build sequence. Fix the error and re-run with:" -ForegroundColor Red
        Write-Host "  .\powershell\run_all.ps1 -StartFrom $($script.Num)" -ForegroundColor Yellow
        exit 1
    }

    Write-Host ""
    Write-Host "========== SCRIPT $($script.Num) FINISHED ==========" -ForegroundColor Magenta
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  BUILD SEQUENCE COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
