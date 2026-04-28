# ============================================================
# 01_install_modules.ps1
# Install and import required PowerShell modules
# Run this first before any other script
# ============================================================

Write-Host "`n[01] Installing required PowerShell modules..." -ForegroundColor Cyan

# --- Microsoft.Graph ---
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Write-Host "  Installing Microsoft.Graph..." -ForegroundColor Yellow
    Install-PSResource Microsoft.Graph -Scope CurrentUser -TrustRepository -Quiet
    Write-Host "  Microsoft.Graph installed." -ForegroundColor Green
} else {
    Write-Host "  Microsoft.Graph already installed." -ForegroundColor Green
}

# --- Import modules ---
Write-Host "`n  Importing modules..." -ForegroundColor Yellow
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Applications
Import-Module Microsoft.Graph.Sites

Write-Host "`n[01] COMPLETE — All modules installed and imported." -ForegroundColor Green
Write-Host "  Run 02_connect_services.ps1 next.`n" -ForegroundColor Cyan
