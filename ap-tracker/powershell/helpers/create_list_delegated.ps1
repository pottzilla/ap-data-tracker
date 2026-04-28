# ============================================================
# create_list_delegated.ps1
# Uses delegated auth to create the list on the group site,
# then switches to app auth and runs verification.
# ============================================================

Set-Location $PSScriptRoot\..

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Create SharePoint List (Delegated Auth)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Step 1: Delegated auth ---
Write-Host ""
Write-Host "========== DELEGATED AUTH ==========" -ForegroundColor Magenta

$scopes = @(
    "Sites.ReadWrite.All", "Sites.Manage.All",
    "Group.ReadWrite.All", "Directory.ReadWrite.All"
)

Connect-MgGraph -Scopes $scopes -TenantId "APdatademo.onmicrosoft.com" -UseDeviceCode -NoWelcome -ContextScope Process

$ctx = Get-MgContext
if (-not $ctx) {
    Write-Host "FATAL -- Graph connection failed." -ForegroundColor Red
    exit 1
}
Write-Host "  Connected as: $($ctx.Account)" -ForegroundColor Green

# --- Step 2: Create list ---
Write-Host ""
Write-Host "========== CREATE LIST ==========" -ForegroundColor Magenta

$tenantName = "APdatademo"
$siteAlias  = "aptrackerdem"
$listName   = "Approval Tracker"
$siteUrl    = "https://$tenantName.sharepoint.com/sites/$siteAlias"

# Get site
$site = Invoke-MgGraphRequest `
    -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/sites/${tenantName}.sharepoint.com:/sites/${siteAlias}"
$siteId = $site.id
Write-Host "  Site ID: $siteId" -ForegroundColor Green

# Check existing lists
$existingLists = Invoke-MgGraphRequest `
    -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists"

Write-Host "  Existing lists:" -ForegroundColor Gray
foreach ($l in $existingLists.value) {
    Write-Host "    - $($l.displayName) ($($l.id))" -ForegroundColor Gray
}

$existingList = $existingLists.value | Where-Object { $_.displayName -eq $listName }

if ($existingList) {
    Write-Host "  List '$listName' already exists." -ForegroundColor Green
    $listId = $existingList.id
} else {
    Write-Host "  Creating list: $listName..." -ForegroundColor Yellow

    $listBody = @{
        displayName = $listName
        list        = @{ template = "genericList" }
    } | ConvertTo-Json

    $list = Invoke-MgGraphRequest `
        -Method POST `
        -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists" `
        -Body $listBody `
        -ContentType "application/json"

    $listId = $list.id
    Write-Host "  List created. ID: $listId" -ForegroundColor Green
}

# --- Step 3: Add columns ---
Write-Host ""
Write-Host "  Retrieving existing columns..." -ForegroundColor Yellow
$existingColumns = Invoke-MgGraphRequest `
    -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$listId/columns"
$existingColumnNames = $existingColumns.value | ForEach-Object { $_.name }

$columns = @(
    @{ name = "EmailSubject";       type = "text" },
    @{ name = "SenderEmail";        type = "text" },
    @{ name = "ReceivedDate";       type = "dateTime" },
    @{ name = "ApprovalDate";       type = "dateTime" },
    @{ name = "DaysToApprove";      type = "number" },
    @{ name = "HoursToApprove";     type = "number" },
    @{ name = "ThreadMessageCount"; type = "number" },
    @{ name = "ApproverCategory";   type = "text" },
    @{ name = "ApproverName";       type = "text" },
    @{ name = "EmailID";            type = "text" },
    @{ name = "ConversationID";     type = "text" },
    @{ name = "AnomalyReason";      type = "text" }
)

$choiceColumns = @(
    @{ name = "ApprovalStatus";    choices = @("Pending", "Approved", "Rejected") },
    @{ name = "ComplianceStatus";  choices = @("Compliant", "Non-Compliant", "Unclear") },
    @{ name = "SupplierRisk";      choices = @("Low", "Medium", "High") }
)

$boolColumns = @("AnomalyFlag")

Write-Host "  Adding columns..." -ForegroundColor Yellow

foreach ($col in $columns) {
    if ($existingColumnNames -contains $col.name) {
        Write-Host "  SKIP -- $($col.name)" -ForegroundColor Yellow
        continue
    }
    if ($col.type -eq "text") {
        $body = @{ name = $col.name; text = @{} } | ConvertTo-Json
    } elseif ($col.type -eq "number") {
        $body = @{ name = $col.name; number = @{} } | ConvertTo-Json
    } elseif ($col.type -eq "dateTime") {
        $body = @{ name = $col.name; dateTime = @{ displayAs = "default"; format = "dateTime" } } | ConvertTo-Json
    }
    try {
        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$listId/columns" `
            -Body $body -ContentType "application/json" | Out-Null
        Write-Host "  [OK] $($col.name) [$($col.type)]" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] $($col.name) -- $($_.Exception.Message)" -ForegroundColor Red
    }
}

foreach ($col in $choiceColumns) {
    if ($existingColumnNames -contains $col.name) {
        Write-Host "  SKIP -- $($col.name)" -ForegroundColor Yellow
        continue
    }
    $body = @{
        name   = $col.name
        choice = @{ allowTextEntry = $false; choices = $col.choices }
    } | ConvertTo-Json -Depth 5
    try {
        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$listId/columns" `
            -Body $body -ContentType "application/json" | Out-Null
        Write-Host "  [OK] $($col.name) [choice]" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] $($col.name) -- $($_.Exception.Message)" -ForegroundColor Red
    }
}

foreach ($colName in $boolColumns) {
    if ($existingColumnNames -contains $colName) {
        Write-Host "  SKIP -- $colName" -ForegroundColor Yellow
        continue
    }
    $body = @{ name = $colName; boolean = @{} } | ConvertTo-Json
    try {
        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$listId/columns" `
            -Body $body -ContentType "application/json" | Out-Null
        Write-Host "  [OK] $colName [boolean]" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] $colName -- $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- Save IDs ---
Write-Host ""
$spConfig = @"
SHAREPOINT_SITE_ID=$siteId
SHAREPOINT_LIST_ID=$listId
SHAREPOINT_SITE_URL=$siteUrl
"@
$spConfig | Out-File -FilePath ".\sharepoint_ids.txt" -Encoding UTF8
Write-Host "  Saved to sharepoint_ids.txt" -ForegroundColor Green

Write-Host ""
Write-Host "  SHAREPOINT SETUP COMPLETE" -ForegroundColor Green
Write-Host "  Site : $siteUrl" -ForegroundColor White
Write-Host "  List : $listName ($listId)" -ForegroundColor White
Write-Host ""
Write-Host "  Now run run_verify.ps1 to verify everything." -ForegroundColor Cyan
