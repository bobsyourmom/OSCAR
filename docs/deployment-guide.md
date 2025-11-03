# Deployment Guide - Security Copilot Compliance Reporting Agent

## Overview

This guide provides step-by-step instructions for deploying the automated compliance and security operations reporting solution using Microsoft Security Copilot, Microsoft Sentinel, and integrated threat intelligence agents.

## Prerequisites

### Required Licenses and Permissions
- Microsoft Security Copilot license
- Microsoft Sentinel workspace
- Azure subscription with appropriate permissions:
  - Contributor role on Resource Group
  - Microsoft Sentinel Contributor
  - Security Reader (minimum) or Security Administrator

### Required Tools
- Azure PowerShell module (`Az.SecurityInsights`, `Az.OperationalInsights`)
- Azure CLI (optional)
- Text editor for configuration files

### Microsoft Security Copilot Agents
Ensure access to these agents (preview as of 2025):
- **Threat Intelligence Briefing Agent** - For threat enrichment
- **Phishing Triage Agent** - For email threat triage
- **Vulnerability Remediation Agent** (optional) - For vuln management
- **Conditional Access Optimization Agent** (optional) - For identity insights

## Deployment Steps

### Step 1: Configure Environment Variables

Create a configuration file with your Azure environment details:

```powershell
# config/environment.ps1
$SubscriptionId = "<YOUR_SUBSCRIPTION_ID>"
$ResourceGroupName = "<YOUR_RESOURCE_GROUP>"
$WorkspaceName = "<YOUR_SENTINEL_WORKSPACE>"
$TenantId = "<YOUR_TENANT_ID>"
$Location = "East US"  # Or your preferred region
```

### Step 2: Deploy Sentinel Watchlists

Deploy the watchlists that will store compliance report data:

```powershell
# Navigate to watchlist schemas directory
cd security-reporting-agent/watchlist-schemas

# Load environment configuration
. ../config/environment.ps1

# Run deployment script
./deploy-watchlists.ps1 `
    -SubscriptionId $SubscriptionId `
    -ResourceGroupName $ResourceGroupName `
    -WorkspaceName $WorkspaceName
```

**Expected Output:**
```
Creating watchlist: ComplianceReports_Identity
Successfully created/updated watchlist: ComplianceReports_Identity
Creating watchlist: ComplianceReports_Threats
Successfully created/updated watchlist: ComplianceReports_Threats
...
Watchlist deployment completed!
```

### Step 3: Configure Security Copilot Agent

1. **Update Agent Manifest** with your environment details:

Edit `agent-manifest.yaml` and replace the placeholders:

```yaml
Settings:
  Target: Sentinel
  TenantId: <YOUR_TENANT_ID>          # Replace this
  SubscriptionId: <YOUR_SUBSCRIPTION_ID>  # Replace this
  ResourceGroupName: <YOUR_RESOURCE_GROUP>  # Replace this
  WorkspaceName: <YOUR_WORKSPACE_NAME>  # Replace this
```

Use find-and-replace to update all occurrences:
- `<TENANT_ID>` → Your Azure AD Tenant ID
- `<SUBSCRIPTION_ID>` → Your Azure Subscription ID
- `<RESOURCE_GROUP>` → Your Resource Group name
- `<WORKSPACE_NAME>` → Your Sentinel Workspace name

2. **Deploy the Agent**:

In Microsoft Security Copilot standalone portal:
- Navigate to **Settings** → **Agents**
- Click **Create Agent** → **Upload from YAML**
- Upload the modified `agent-manifest.yaml`
- Configure agent permissions and scope

### Step 4: Enable Built-in Agent Integrations

#### Threat Intelligence Briefing Agent

1. Navigate to Security Copilot → **Agents**
2. Find **Threat Intelligence Briefing Agent**
3. Click **Configure**
4. Set parameters:
   - **Number of vulnerabilities to research**: 50
   - **Lookback period (days)**: 30
   - **Geographic region**: Your operating region
   - **Industry sector**: Your industry
   - **Email recipients**: security-team@yourdomain.com
5. Set schedule: Every 6 hours
6. Click **Enable**

#### Phishing Triage Agent

1. Navigate to Security Copilot → **Agents**
2. Find **Phishing Triage Agent**
3. Click **Enable**
4. Configure integration with Microsoft Defender for Office 365

### Step 5: Deploy Sentinel Workbook

Deploy the compliance dashboard workbook:

#### Method 1: Azure Portal

1. Navigate to Microsoft Sentinel → **Workbooks**
2. Click **+ Add workbook**
3. Click **Edit** → **Advanced Editor**
4. Paste contents of `workbooks/compliance-dashboard-workbook.json`
5. Click **Apply**
6. Click **Save** and provide:
   - **Title**: Security Compliance & Operations Dashboard
   - **Subscription**: Your subscription
   - **Resource Group**: Your resource group
   - **Location**: Your workspace location

#### Method 2: PowerShell

```powershell
$WorkbookJson = Get-Content -Path "./workbooks/compliance-dashboard-workbook.json" -Raw

New-AzResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile "./workbooks/deploy-workbook-template.json" `
    -WorkbookDisplayName "Security Compliance & Operations Dashboard" `
    -WorkbookSourceId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName" `
    -WorkbookContent $WorkbookJson
```

### Step 6: Configure Scheduled Triggers

Set up automation for periodic report execution:

1. **Daily Critical Reports** (8 AM daily):
   - In Security Copilot agent settings
   - Navigate to **Triggers**
   - Add trigger: `DailyCriticalReportsTrigger`
   - Schedule: `0 8 * * *`

2. **Weekly Compliance Reports** (9 AM Mondays):
   - Add trigger: `WeeklyComplianceReportsTrigger`
   - Schedule: `0 9 * * 1`

3. **Threat Intelligence Enrichment** (Every 6 hours):
   - Add trigger: `ThreatIntelEnrichmentTrigger`
   - Schedule: `0 */6 * * *`

### Step 7: Verify Deployment

#### Test Agent Skills

Run test queries to verify agent functionality:

```
# In Security Copilot chat interface
List all compliance controls

# Should return structured list of all controls across frameworks
```

```
Run control AC-2 report

# Should execute identity account management query and return results
```

```
Run daily critical reports

# Should execute all daily critical monitoring queries
```

#### Verify Watchlist Data

Check that data is being written to watchlists:

```kql
// In Sentinel Log Analytics
_GetWatchlist('ComplianceReports_Identity')
| take 10
```

#### Verify Workbook

1. Navigate to Sentinel → **Workbooks**
2. Open "Security Compliance & Operations Dashboard"
3. Verify data is displayed in all sections
4. Check time range and filter controls

## Post-Deployment Configuration

### 1. Customize Report Groups

Edit `config/compliance-framework-mapping.json` to add custom report groups:

```json
"reportGroups": {
  "custom_group_name": {
    "name": "Custom Report Group",
    "frequency": "daily",
    "controls": ["AC-2", "AC-3", "SI-4"],
    "description": "Custom control grouping"
  }
}
```

### 2. Configure Alert Actions

Set up automated responses for critical findings:

1. Navigate to Sentinel → **Analytics Rules**
2. Create new **Scheduled query rule**
3. Query watchlists for critical/high findings:

```kql
_GetWatchlist('ComplianceReports_Threats')
| where Severity == "Critical"
| where RemediationRequired == "Yes"
| where TimeGenerated > ago(1h)
```

4. Configure **Actions**:
   - Send email to security team
   - Create ServiceNow ticket
   - Post to Teams channel

### 3. Configure Data Retention

Set appropriate retention for watchlists:

```powershell
# Set 90-day retention
$watchlists = @(
    "ComplianceReports_Identity",
    "ComplianceReports_Threats",
    "ComplianceReports_Audit"
)

foreach ($watchlist in $watchlists) {
    # Configure retention policy
    # (Retention is managed at the workspace level)
}
```

## Integration with Existing Tools

### ServiceNow Integration

Configure webhook to create tickets for critical findings:

```powershell
# In agent configuration, add webhook skill
- Name: CreateServiceNowTicket
  Type: API
  Method: POST
  Endpoint: https://your-instance.service-now.com/api/now/table/incident
  Headers:
    Content-Type: application/json
    Authorization: Basic <base64-credentials>
```

### Teams Integration

Post daily summaries to Teams channel:

1. Create Teams webhook connector
2. Add GPT skill to agent:

```yaml
- Name: PostDailySummaryToTeams
  DisplayName: Post Daily Summary to Teams
  Settings:
    Template: |-
      Generate a summary of today's compliance findings and post to Teams webhook:
      {{TEAMS_WEBHOOK_URL}}
```

## Troubleshooting

### Issue: No Data in Watchlists

**Symptoms**: Workbook shows empty or no data

**Solutions**:
1. Verify agent is enabled and scheduled triggers are active
2. Check agent execution logs in Security Copilot
3. Verify Sentinel workspace permissions
4. Manually run a test query:
   ```
   Run control AC-2 report
   ```
5. Check KQL query syntax in agent manifest

### Issue: Agent Skills Not Executing

**Symptoms**: Agent commands return errors

**Solutions**:
1. Verify all placeholders in `agent-manifest.yaml` are replaced
2. Check Azure RBAC permissions (need Sentinel Reader minimum)
3. Verify Microsoft Sentinel plugin is enabled in Security Copilot
4. Check tenant/subscription/workspace IDs are correct

### Issue: Threat Intelligence Enrichment Not Working

**Symptoms**: ThreatIntelEnrichment field is null

**Solutions**:
1. Verify Threat Intelligence Briefing Agent is enabled
2. Check agent has access to Microsoft Threat Intelligence plugin
3. Ensure Defender TI license is active
4. Review agent integration logs

### Issue: Workbook Queries Timing Out

**Symptoms**: Workbook panels show timeout errors

**Solutions**:
1. Reduce time range parameter
2. Add indexes to watchlist search keys
3. Optimize KQL queries in workbook
4. Consider data archiving for old findings

## Maintenance

### Daily Tasks
- Review critical findings in dashboard
- Triage high-severity alerts
- Verify agent execution logs

### Weekly Tasks
- Review compliance score trends
- Update control mappings as needed
- Review and close remediated findings

### Monthly Tasks
- Audit agent performance metrics
- Review and optimize KQL queries
- Update threat intelligence sources
- Compliance scorecard review with leadership

## Support and Resources

- **Microsoft Security Copilot Docs**: https://learn.microsoft.com/en-us/copilot/security/
- **Microsoft Sentinel Docs**: https://learn.microsoft.com/en-us/azure/sentinel/
- **NIST CSF 2.0**: https://www.nist.gov/cyberframework
- **CIS Controls v8**: https://www.cisecurity.org/controls/v8

## Next Steps

After successful deployment:
1. Review [Usage Examples](usage-examples.md) for common scenarios
2. Customize control mappings for your organization
3. Set up alerting for critical compliance violations
4. Train team on using the dashboard and agent commands
5. Schedule regular compliance reviews using the workbook
