# ============================================================================
# Deploy Compliance Reporting Watchlists to Microsoft Sentinel (REST API)
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName
)

# Connect to Azure
Write-Host "Connecting to Azure..." -ForegroundColor Cyan
Connect-AzAccount
Set-AzContext -SubscriptionId $SubscriptionId

# Get access token for Azure REST API
$token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# API version
$apiVersion = "2021-10-01"

# Base URL for Sentinel watchlists
$baseUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/providers/Microsoft.SecurityInsights/watchlists"

# Define watchlists
$watchlists = @(
    @{
        Name = "ComplianceReports_Identity"
        DisplayName = "Compliance Reports - Identity & Access Management"
        Description = "Identity and access management compliance findings from automated reports"
        Provider = "SecOps Compliance Reporting Agent"
        Source = "Local file"
        ItemsSearchKey = "UserPrincipalName"
        Schema = @"
TimeGenerated,ControlID,Framework,Severity,FindingType,UserPrincipalName,UserDisplayName,FindingDetails,RemediationRequired,ReportDate,Status
2024-01-01T00:00:00Z,AC-2,NIST 800-53,High,Sample,user@domain.com,User Name,{},Review,2024-01-01,Open
"@
    },
    @{
        Name = "ComplianceReports_Threats"
        DisplayName = "Compliance Reports - Threat Detection & Response"
        Description = "Threat detection and response compliance findings with threat intel enrichment"
        Provider = "SecOps Compliance Reporting Agent"
        Source = "Local file"
        ItemsSearchKey = "AlertName"
        Schema = @"
TimeGenerated,ControlID,Framework,Severity,FindingType,AlertName,AlertSeverity,CompromisedEntity,Tactics,Techniques,ThreatIntelEnrichment,RemediationRequired,Status
2024-01-01T00:00:00Z,SI-4,NIST 800-53,Critical,Sample,Sample Alert,High,entity1,[],[],{},Yes,Open
"@
    },
    @{
        Name = "ComplianceReports_Audit"
        DisplayName = "Compliance Reports - Audit & Logging"
        Description = "Audit and logging compliance findings from automated reports"
        Provider = "SecOps Compliance Reporting Agent"
        Source = "Local file"
        ItemsSearchKey = "Operation"
        Schema = @"
TimeGenerated,ControlID,Framework,Severity,FindingType,Operation,InitiatedBy,ResourceAffected,RemediationRequired,Status
2024-01-01T00:00:00Z,AU-6,NIST 800-53,High,Sample,Sample Operation,user@domain.com,resource1,Review,Open
"@
    },
    @{
        Name = "ComplianceReports_Network"
        DisplayName = "Compliance Reports - Network Security"
        Description = "Network security compliance findings from automated reports"
        Provider = "SecOps Compliance Reporting Agent"
        Source = "Local file"
        ItemsSearchKey = "SourceIP"
        Schema = @"
TimeGenerated,ControlID,Framework,Severity,FindingType,SourceIP,DestinationIP,Protocol,Port,Action,RemediationRequired,Status
2024-01-01T00:00:00Z,AC-17,NIST 800-53,Medium,Sample,1.2.3.4,5.6.7.8,TCP,443,Allow,Review,Open
"@
    },
    @{
        Name = "ComplianceReports_Vulnerabilities"
        DisplayName = "Compliance Reports - Vulnerability Management"
        Description = "Vulnerability management compliance findings from automated reports"
        Provider = "SecOps Compliance Reporting Agent"
        Source = "Local file"
        ItemsSearchKey = "CVE"
        Schema = @"
TimeGenerated,ControlID,Framework,Severity,FindingType,CVE,Title,AffectedResources,CVSS,PatchAvailable,RemediationRequired,Status
2024-01-01T00:00:00Z,SI-2,NIST 800-53,Critical,Sample,CVE-2024-0000,Sample Vulnerability,[],9.8,Yes,Yes,Open
"@
    },
    @{
        Name = "ComplianceReports_DataProtection"
        DisplayName = "Compliance Reports - Data Protection"
        Description = "Data protection and privacy compliance findings from automated reports"
        Provider = "SecOps Compliance Reporting Agent"
        Source = "Local file"
        ItemsSearchKey = "ResourceId"
        Schema = @"
TimeGenerated,ControlID,Framework,Severity,FindingType,ResourceId,ResourceType,DataClassification,EncryptionStatus,RemediationRequired,Status
2024-01-01T00:00:00Z,PR.DS-01,NIST CSF 2.0,High,Sample,/subscriptions/xxx/resourceGroups/xxx/providers/xxx,Storage,Confidential,Not Encrypted,Yes,Open
"@
    },
    @{
        Name = "ComplianceReports_Assets"
        DisplayName = "Compliance Reports - Asset Inventory"
        Description = "Asset inventory compliance findings from automated reports"
        Provider = "SecOps Compliance Reporting Agent"
        Source = "Local file"
        ItemsSearchKey = "AssetId"
        Schema = @"
TimeGenerated,ControlID,Framework,Severity,FindingType,AssetId,AssetName,AssetType,Owner,LastSeen,RemediationRequired,Status
2024-01-01T00:00:00Z,ID.AM-01,NIST CSF 2.0,Medium,Sample,asset-001,Sample Asset,Virtual Machine,owner@domain.com,2024-01-01,Review,Open
"@
    },
    @{
        Name = "ComplianceReports_Incidents"
        DisplayName = "Compliance Reports - Incident Response"
        Description = "Incident response compliance findings and metrics"
        Provider = "SecOps Compliance Reporting Agent"
        Source = "Local file"
        ItemsSearchKey = "IncidentNumber"
        Schema = @"
TimeGenerated,ControlID,Framework,Severity,FindingType,IncidentNumber,IncidentTitle,Status,AssignedTo,CreatedTime,ResolvedTime,MTTR,RemediationRequired
2024-01-01T00:00:00Z,RS.MA-01,NIST CSF 2.0,Critical,Sample,INC-001,Sample Incident,Open,analyst@domain.com,2024-01-01,,,Yes
"@
    }
)

# Create each watchlist
$createdWatchlists = @()
$errorCount = 0

foreach ($watchlist in $watchlists) {
    Write-Host "`nCreating watchlist: $($watchlist.Name)" -ForegroundColor Yellow

    try {
        # Prepare the raw CSV content
        $rawContent = $watchlist.Schema

        # Create watchlist body with rawContent
        $watchlistBody = @{
            properties = @{
                displayName = $watchlist.DisplayName
                description = $watchlist.Description
                provider = $watchlist.Provider
                source = $watchlist.Source
                itemsSearchKey = $watchlist.ItemsSearchKey
                contentType = "text/csv"
                rawContent = $rawContent
                numberOfLinesToSkip = 0
            }
        } | ConvertTo-Json -Depth 10

        # Create/Update watchlist
        $watchlistUrl = "$baseUrl/$($watchlist.Name)?api-version=$apiVersion"
        Write-Host "  Sending request to: $watchlistUrl" -ForegroundColor Gray

        $response = Invoke-RestMethod -Uri $watchlistUrl -Method Put -Headers $headers -Body $watchlistBody

        Write-Host "  Watchlist created successfully with initial data" -ForegroundColor Green

        $createdWatchlists += $watchlist.Name
    }
    catch {
        $errorCount++
        Write-Host "Error creating watchlist $($watchlist.Name):" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $reader.BaseStream.Position = 0
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response body: $responseBody" -ForegroundColor Red
        }
    }
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "Watchlist deployment completed!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan

# Display summary
Write-Host "`nSuccessfully Created/Updated Watchlists ($($createdWatchlists.Count)):" -ForegroundColor Yellow
$createdWatchlists | ForEach-Object {
    Write-Host "  - $_" -ForegroundColor Green
}

if ($errorCount -gt 0) {
    Write-Host "`nFailed Watchlists: $errorCount" -ForegroundColor Red
}

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Configure Security Copilot agent to write query results to these watchlists" -ForegroundColor White
Write-Host "2. Deploy the Sentinel workbook for visualization" -ForegroundColor White
Write-Host "3. Set up scheduled triggers in the Security Copilot agent" -ForegroundColor White
