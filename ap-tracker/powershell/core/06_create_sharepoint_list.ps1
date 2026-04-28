# ============================================================
# 06_create_sharepoint_list.ps1
# Create SharePoint team site (via M365 Group) and Approval
# Tracker list with full schema.
# Run after 05_create_app_registration.ps1
# ============================================================

Write-Host ""
Write-Host "[06] Creating SharePoint site and Approval Tracker list..." -ForegroundColor Cyan

$tenantName = "APdatademo"
$siteAlias  = "aptrackerdem"
$siteName   = "APTrackerDemo"
$listName   = "Approval Tracker"
$siteUrl    = "https://$tenantName.sharepoint.com/sites/$siteAlias"

# --- Check if site already exists ---
Write-Host ""
Write-Host "  Checking for existing site: $siteUrl" -ForegroundColor Yellow

$site = $null
try {
    $site = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/sites/${tenantName}.sharepoint.com:/sites/${siteAlias}" `
        -ErrorAction Stop
    Write-Host "  Site already exists." -ForegroundColor Green
} catch {
    Write-Host "  Site not found -- will create." -ForegroundColor Yellow
}

if (-not $site) {
    # Create via M365 Group (which provisions a SharePoint team site)
    Write-Host "  Creating M365 Group to provision SharePoint site..." -ForegroundColor Yellow

    $groupBody = @{
        displayName     = $siteName
        mailNickname    = $siteAlias
        description     = "AP Invoice Tracker Demo Site"
        groupTypes      = @("Unified")
        mailEnabled     = $true
        securityEnabled = $false
        visibility      = "Private"
    } | ConvertTo-Json -Depth 5

    try {
        $group = Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/groups" `
            -Body $groupBody `
            -ContentType "application/json"

        $groupId = $group.id
        Write-Host "  Group created: $groupId" -ForegroundColor Green
    } catch {
        # Group might already exist
        Write-Host "  Group creation failed -- checking if it already exists..." -ForegroundColor Yellow
        $existingGroup = Invoke-MgGraphRequest `
            -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=mailNickname eq '$siteAlias'" `
            -ErrorAction SilentlyContinue

        if ($existingGroup.value -and $existingGroup.value.Count -gt 0) {
            $groupId = $existingGroup.value[0].id
            Write-Host "  Found existing group: $groupId" -ForegroundColor Green
        } else {
            Write-Host "  FATAL -- Could not create or find group." -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }

    # Wait for SharePoint site provisioning
    Write-Host "  Waiting for SharePoint site to provision (up to 120 seconds)..." -ForegroundColor Yellow
    $retries = 0
    $maxRetries = 12
    $site = $null

    while ($retries -lt $maxRetries) {
        Start-Sleep -Seconds 10
        $retries++
        try {
            $site = Invoke-MgGraphRequest `
                -Method GET `
                -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/sites/root" `
                -ErrorAction Stop
            Write-Host "  Site provisioned after $($retries * 10) seconds." -ForegroundColor Green
            break
        } catch {
            Write-Host "  Attempt $retries/$maxRetries -- site not ready yet..." -ForegroundColor Gray
        }
    }

    if (-not $site) {
        Write-Host "  FATAL -- SharePoint site did not provision within 120 seconds." -ForegroundColor Red
        exit 1
    }
}

$siteId = $site.id
Write-Host "  Site ID: $siteId" -ForegroundColor Green

# --- Check if list already exists ---
Write-Host ""
Write-Host "  Checking for existing list: $listName" -ForegroundColor Yellow

$existingLists = Invoke-MgGraphRequest `
    -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists"

$existingList = $existingLists.value | Where-Object { $_.displayName -eq $listName }

if ($existingList) {
    Write-Host "  List already exists -- skipping creation." -ForegroundColor Yellow
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
    Write-Host "  List created." -ForegroundColor Green
}

Write-Host "  List ID: $listId" -ForegroundColor Green

# --- Define columns ---
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
    @{
        name    = "ApprovalStatus"
        choices = @("Pending", "Approved", "Rejected")
    },
    @{
        name    = "ComplianceStatus"
        choices = @("Compliant", "Non-Compliant", "Unclear")
    },
    @{
        name    = "SupplierRisk"
        choices = @("Low", "Medium", "High")
    }
)

$boolColumns = @("AnomalyFlag")

# --- Get existing columns to avoid duplicates ---
Write-Host ""
Write-Host "  Retrieving existing columns..." -ForegroundColor Yellow
$existingColumns = Invoke-MgGraphRequest `
    -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$listId/columns"
$existingColumnNames = $existingColumns.value | ForEach-Object { $_.name }

# --- Add text, number, and dateTime columns ---
Write-Host "  Adding columns..." -ForegroundColor Yellow
foreach ($col in $columns) {
    if ($existingColumnNames -contains $col.name) {
        Write-Host "  SKIP -- Column exists: $($col.name)" -ForegroundColor Yellow
        continue
    }

    if ($col.type -eq "text") {
        $body = @{ name = $col.name; text = @{} } | ConvertTo-Json
    } elseif ($col.type -eq "number") {
        $body = @{ name = $col.name; number = @{} } | ConvertTo-Json
    } elseif ($col.type -eq "dateTime") {
        $body = @{ name = $col.name; dateTime = @{ displayAs = "default"; format = "dateTime" } } | ConvertTo-Json
    }

    Invoke-MgGraphRequest `
        -Method POST `
        -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$listId/columns" `
        -Body $body `
        -ContentType "application/json" | Out-Null

    Write-Host "  Added column: $($col.name) [$($col.type)]" -ForegroundColor Green
}

# --- Add choice columns ---
foreach ($col in $choiceColumns) {
    if ($existingColumnNames -contains $col.name) {
        Write-Host "  SKIP -- Column exists: $($col.name)" -ForegroundColor Yellow
        continue
    }

    $body = @{
        name   = $col.name
        choice = @{
            allowTextEntry = $false
            choices        = $col.choices
        }
    } | ConvertTo-Json -Depth 5

    Invoke-MgGraphRequest `
        -Method POST `
        -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$listId/columns" `
        -Body $body `
        -ContentType "application/json" | Out-Null

    Write-Host "  Added column: $($col.name) [choice: $($col.choices -join ', ')]" -ForegroundColor Green
}

# --- Add boolean columns ---
foreach ($colName in $boolColumns) {
    if ($existingColumnNames -contains $colName) {
        Write-Host "  SKIP -- Column exists: $colName" -ForegroundColor Yellow
        continue
    }

    $body = @{ name = $colName; boolean = @{} } | ConvertTo-Json

    Invoke-MgGraphRequest `
        -Method POST `
        -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$listId/columns" `
        -Body $body `
        -ContentType "application/json" | Out-Null

    Write-Host "  Added column: $colName [boolean]" -ForegroundColor Green
}

# --- Save site and list IDs ---
Write-Host ""
Write-Host "  Saving Site ID and List ID..." -ForegroundColor Yellow
$spConfig = @"
SHAREPOINT_SITE_ID=$siteId
SHAREPOINT_LIST_ID=$listId
SHAREPOINT_SITE_URL=$siteUrl
"@
$spConfig | Out-File -FilePath ".\sharepoint_ids.txt" -Encoding UTF8
Write-Host "  Saved to sharepoint_ids.txt" -ForegroundColor Green

# --- Summary ---
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  SHAREPOINT SUMMARY" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  Site Name : $siteName" -ForegroundColor White
Write-Host "  Site URL  : $siteUrl" -ForegroundColor White
Write-Host "  Site ID   : $siteId" -ForegroundColor White
Write-Host "  List Name : $listName" -ForegroundColor White
Write-Host "  List ID   : $listId" -ForegroundColor White
Write-Host "  ============================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "[06] COMPLETE -- SharePoint site and list created with full schema." -ForegroundColor Green
Write-Host "  Run 07_send_test_emails.ps1 next." -ForegroundColor Cyan
Write-Host ""
