# ============================================================
# create_sharepoint_list_direct.ps1
# Connects with app creds, adds app as group owner, then
# creates the Approval Tracker list on the group site.
# ============================================================

Set-Location $PSScriptRoot\..\..

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Create SharePoint List (Direct)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Connect via app credentials ---
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
Write-Host "  Connected (app auth)." -ForegroundColor Green

$tenantName = "APdatademo"
$siteAlias  = "aptrackerdem"
$siteName   = "APTrackerDemo"
$listName   = "Approval Tracker"
$siteUrl    = "https://$tenantName.sharepoint.com/sites/$siteAlias"

# --- Get site ID ---
$site = Invoke-MgGraphRequest `
    -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/sites/${tenantName}.sharepoint.com:/sites/${siteAlias}"
$siteId = $site.id
Write-Host "  Site ID: $siteId" -ForegroundColor Green

# --- Find the M365 Group ---
Write-Host ""
Write-Host "  Looking up M365 Group..." -ForegroundColor Yellow
$groups = Invoke-MgGraphRequest `
    -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=mailNickname eq '$siteAlias'"
$group = $groups.value | Select-Object -First 1

if ($group) {
    $groupId = $group.id
    Write-Host "  Group ID: $groupId" -ForegroundColor Green

    # Add the app's service principal as group owner
    Write-Host "  Adding app service principal as group owner..." -ForegroundColor Yellow
    $appSp = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$clientId'"
    $spId = $appSp.value[0].id
    Write-Host "  App SP ID: $spId" -ForegroundColor Green

    try {
        $ownerBody = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/servicePrincipals/$spId"
        } | ConvertTo-Json
        Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/owners/`$ref" `
            -Body $ownerBody `
            -ContentType "application/json"
        Write-Host "  App added as group owner." -ForegroundColor Green
    } catch {
        Write-Host "  Could not add as owner (may already be): $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Also add admin user as owner
    Write-Host "  Adding admin as group owner..." -ForegroundColor Yellow
    try {
        $adminUser = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/gp@APdatademo.onmicrosoft.com"
        $adminBody = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($adminUser.id)"
        } | ConvertTo-Json
        Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/owners/`$ref" `
            -Body $adminBody `
            -ContentType "application/json"
        Write-Host "  Admin added as group owner." -ForegroundColor Green
    } catch {
        Write-Host "  Admin owner add result: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Also add admin as member
    try {
        $memberBody = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($adminUser.id)"
        } | ConvertTo-Json
        Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/members/`$ref" `
            -Body $memberBody `
            -ContentType "application/json"
        Write-Host "  Admin added as group member." -ForegroundColor Green
    } catch {
        Write-Host "  Admin member add result: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Write-Host "  Waiting 15 seconds for group membership propagation..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15
} else {
    Write-Host "  WARNING -- Group not found for alias: $siteAlias" -ForegroundColor Red
}

# --- Try creating list via Graph ---
Write-Host ""
Write-Host "  Checking for existing list..." -ForegroundColor Yellow

$existingLists = Invoke-MgGraphRequest `
    -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists"

$existingList = $existingLists.value | Where-Object { $_.displayName -eq $listName }

if ($existingList) {
    Write-Host "  List already exists." -ForegroundColor Green
    $listId = $existingList.id
} else {
    Write-Host "  Creating list: $listName..." -ForegroundColor Yellow

    $listBody = @{
        displayName = $listName
        list        = @{ template = "genericList" }
    } | ConvertTo-Json

    try {
        $list = Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists" `
            -Body $listBody `
            -ContentType "application/json" `
            -ErrorAction Stop
        $listId = $list.id
        Write-Host "  List created. ID: $listId" -ForegroundColor Green
    } catch {
        Write-Host "  Direct site endpoint failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Trying via group endpoint..." -ForegroundColor Yellow

        try {
            $list = Invoke-MgGraphRequest `
                -Method POST `
                -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/sites/root/lists" `
                -Body $listBody `
                -ContentType "application/json" `
                -ErrorAction Stop
            $listId = $list.id
            Write-Host "  List created via group endpoint. ID: $listId" -ForegroundColor Green
        } catch {
            Write-Host "  Group endpoint also failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "  Trying New-MgSiteList cmdlet..." -ForegroundColor Yellow
            try {
                $newList = New-MgSiteList -SiteId $siteId -DisplayName $listName -ListTemplate "genericList" -ErrorAction Stop
                $listId = $newList.Id
                Write-Host "  List created via cmdlet. ID: $listId" -ForegroundColor Green
            } catch {
                Write-Host "  Cmdlet also failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "  FATAL -- Cannot create list. Check SharePoint tenant settings." -ForegroundColor Red
                exit 1
            }
        }
    }
}

Write-Host "  List ID: $listId" -ForegroundColor Green

# --- Add columns ---
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
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  SHAREPOINT SUMMARY" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  Site  : $siteUrl" -ForegroundColor White
Write-Host "  SiteID: $siteId" -ForegroundColor White
Write-Host "  ListID: $listId" -ForegroundColor White
Write-Host "  ============================================" -ForegroundColor Cyan

# --- Run verification ---
Write-Host ""
Write-Host "========== FULL VERIFICATION ==========" -ForegroundColor Magenta
. .\powershell\core\08_verify_environment.ps1
