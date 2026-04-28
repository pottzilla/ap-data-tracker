# ============================================================
# 08_verify_environment.ps1
# Full environment verification across all components
# Uses Microsoft Graph API exclusively (no Exchange module)
# Run after 07_send_test_emails.ps1
# Outputs environment_verification_report.csv
# ============================================================

Write-Host ""
Write-Host "[08] Running environment verification..." -ForegroundColor Cyan

$tenantDomain   = "APdatademo.onmicrosoft.com"
$sharedMailbox  = "sharedinbox@APdatademo.onmicrosoft.com"
$adminAccount   = "gp@APdatademo.onmicrosoft.com"
$appName        = "AP Tracker"
$siteName       = "APTrackerDemo"
$listName       = "Approval Tracker"

$results = @()
$passCount = 0
$failCount = 0

function Write-Check {
    param(
        [string]$CheckName,
        [bool]$Passed,
        [string]$Detail = ""
    )

    if ($Passed) {
        Write-Host "  [PASS] $CheckName" -ForegroundColor Green
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor Gray }
        $script:passCount++
    } else {
        Write-Host "  [FAIL] $CheckName" -ForegroundColor Red
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor Gray }
        $script:failCount++
    }

    $script:results += [PSCustomObject]@{
        Check  = $CheckName
        Result = if ($Passed) { "PASS" } else { "FAIL" }
        Detail = $Detail
    }
}

Write-Host ""
Write-Host "  --- TENANT USERS ---" -ForegroundColor Cyan

$expectedUsers = @(
    "sharedinbox@APdatademo.onmicrosoft.com",
    "apexsiteworks@APdatademo.onmicrosoft.com",
    "clearwaterenv@APdatademo.onmicrosoft.com",
    "bridgepointcivil@APdatademo.onmicrosoft.com",
    "halcyonelectrical@APdatademo.onmicrosoft.com"
)

foreach ($upn in $expectedUsers) {
    $user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
    Write-Check "User exists: $upn" ($null -ne $user) $(if ($user) { "ID: $($user.Id)" } else { "Not found" })
}

Write-Host ""
Write-Host "  --- SHARED INBOX MAILBOX ---" -ForegroundColor Cyan

try {
    $inboxFolder = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/users/$sharedMailbox/mailFolders/inbox" `
        -ErrorAction Stop

    Write-Check "Shared inbox mailbox accessible" $true "Inbox folder ID: $($inboxFolder.id)"

    # Check mailbox settings to confirm it is functional
    $mailboxSettings = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/users/$sharedMailbox/mailboxSettings" `
        -ErrorAction Stop

    Write-Check "Mailbox settings accessible" $true "Timezone: $($mailboxSettings.timeZone)"
} catch {
    Write-Check "Shared inbox mailbox accessible" $false $_.Exception.Message
}

# --- Check admin has Global Admin role ---
Write-Host ""
Write-Host "  --- ADMIN ACCESS ---" -ForegroundColor Cyan

$adminUser = Get-MgUser -Filter "userPrincipalName eq '$adminAccount'" -ErrorAction SilentlyContinue
Write-Check "Admin account exists" ($null -ne $adminUser) $(if ($adminUser) { "ID: $($adminUser.Id)" })

if ($adminUser) {
    try {
        $roles = Get-MgUserMemberOf -UserId $adminUser.Id -ErrorAction SilentlyContinue
        $isGlobalAdmin = $roles | Where-Object {
            $_.AdditionalProperties.displayName -eq "Global Administrator"
        }
        Write-Check "Admin has Global Administrator role" ($null -ne $isGlobalAdmin)
    } catch {
        Write-Check "Admin role check" $false $_.Exception.Message
    }
}

Write-Host ""
Write-Host "  --- APP REGISTRATION ---" -ForegroundColor Cyan

$app = Get-MgApplication -Filter "displayName eq '$appName'" -ErrorAction SilentlyContinue
Write-Check "App Registration exists: $appName" ($null -ne $app) $(if ($app) { "Client ID: $($app.AppId)" })

if ($app) {
    $sp = Get-MgServicePrincipal -Filter "appId eq '$($app.AppId)'" -ErrorAction SilentlyContinue
    Write-Check "Service principal exists" ($null -ne $sp)

    if ($sp) {
        $assignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -ErrorAction SilentlyContinue
        Write-Check "Admin consent granted (permissions assigned)" ($assignments.Count -gt 0) "Assignments: $($assignments.Count)"

        # Check specific permissions
        $graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
        $requiredPerms = @("Mail.Read", "Mail.Send", "Sites.ReadWrite.All", "MailboxSettings.Read")

        foreach ($permName in $requiredPerms) {
            $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq $permName }
            if ($appRole) {
                $granted = $assignments | Where-Object { $_.AppRoleId -eq $appRole.Id }
                Write-Check "Permission granted: $permName" ($null -ne $granted)
            } else {
                Write-Check "Permission granted: $permName" $false "Role definition not found"
            }
        }
    }

    $appDetail = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications/$($app.Id)" -ErrorAction SilentlyContinue
    $secrets = $appDetail.passwordCredentials
    $validSecret = $secrets | Where-Object { [datetime]$_.endDateTime -gt (Get-Date) }
    Write-Check "Active client secret exists" ($null -ne $validSecret) $(if ($validSecret) { "Expires: $($validSecret[0].endDateTime)" })
}

Write-Host ""
Write-Host "  --- SHAREPOINT ---" -ForegroundColor Cyan

try {
    $site = Get-MgSite -SiteId "APdatademo.sharepoint.com:/sites/aptrackerdem" -ErrorAction Stop
    Write-Check "SharePoint site exists" $true "ID: $($site.Id)"

    $lists = Get-MgSiteList -SiteId $site.Id -ErrorAction SilentlyContinue
    $list  = $lists | Where-Object { $_.DisplayName -eq $listName }
    Write-Check "Approval Tracker list exists" ($null -ne $list) $(if ($list) { "ID: $($list.Id)" })

    if ($list) {
        $columns = Invoke-MgGraphRequest `
            -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/sites/$($site.Id)/lists/$($list.Id)/columns"

        $columnNames       = $columns.value | ForEach-Object { $_.name }
        $expectedColumns   = @(
            "EmailSubject", "SenderEmail", "ReceivedDate", "ApprovalDate",
            "DaysToApprove", "HoursToApprove", "ThreadMessageCount",
            "ApproverCategory", "ApproverName", "EmailID", "ConversationID",
            "ApprovalStatus", "ComplianceStatus", "SupplierRisk",
            "AnomalyFlag", "AnomalyReason"
        )

        foreach ($col in $expectedColumns) {
            Write-Check "Column exists: $col" ($columnNames -contains $col)
        }
    }
} catch {
    Write-Check "SharePoint site exists" $false $_.Exception.Message
}

Write-Host ""
Write-Host "  --- AP INBOX EMAIL COUNT ---" -ForegroundColor Cyan

try {
    $inboxMessages = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/users/$sharedMailbox/mailFolders/inbox/messages?`$count=true&`$top=1" `
        -Headers @{ ConsistencyLevel = "eventual" }

    $totalCount = $inboxMessages.'@odata.count'
    Write-Check "AP inbox has emails" ($totalCount -gt 0) "Total emails in inbox: $totalCount"

    # Breakdown by sender
    Write-Host ""
    Write-Host "  Email breakdown by sender:" -ForegroundColor Cyan
    $senders = @(
        "apexsiteworks@APdatademo.onmicrosoft.com",
        "clearwaterenv@APdatademo.onmicrosoft.com",
        "bridgepointcivil@APdatademo.onmicrosoft.com",
        "halcyonelectrical@APdatademo.onmicrosoft.com"
    )

    foreach ($sender in $senders) {
        $senderMessages = Invoke-MgGraphRequest `
            -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/users/$sharedMailbox/mailFolders/inbox/messages?`$filter=from/emailAddress/address eq '$sender'&`$count=true&`$top=1" `
            -Headers @{ ConsistencyLevel = "eventual" }
        $count = $senderMessages.'@odata.count'
        Write-Host "    $sender : $count emails" -ForegroundColor Gray
    }
} catch {
    Write-Check "AP inbox accessible" $false $_.Exception.Message
}

# --- Credential files ---
Write-Host ""
Write-Host "  --- CREDENTIAL FILES ---" -ForegroundColor Cyan

Write-Check ".env file exists" (Test-Path '.\.env') "Contains SANDBOX_ACCOUNT_PASSWORD"
Write-Check ".gitignore exists" (Test-Path '.\.gitignore')
Write-Check "tenant_id.txt exists" (Test-Path '.\tenant_id.txt')

if (Test-Path '.\credentials.txt') {
    Write-Check "credentials.txt exists" $true "Contains app registration credentials"
} else {
    Write-Check "credentials.txt exists" $false "Will be created by script 05"
}

# --- Final summary ---
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  PASS: $passCount" -ForegroundColor Green
Write-Host "  FAIL: $failCount" -ForegroundColor Red

if ($failCount -eq 0) {
    Write-Host ""
    Write-Host "  ALL CHECKS PASSED -- Environment ready." -ForegroundColor Green
    Write-Host "  You can now proceed to the Python pipeline build in VS Code." -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "  $failCount check(s) failed -- review errors above before proceeding." -ForegroundColor Red
}

# --- Export report ---
$results | Export-Csv -Path '.\environment_verification_report.csv' -NoTypeInformation
Write-Host ""
Write-Host "  Full report exported to environment_verification_report.csv" -ForegroundColor Green

Write-Host ""
Write-Host "[08] COMPLETE -- Environment verification finished." -ForegroundColor Green
Write-Host ""
