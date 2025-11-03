# Logic App Solution for Security Copilot Report Ingestion

## Overview

This solution uses **Azure Logic Apps** to automatically ingest KQL query results from your Security Copilot agent into the custom `ComplianceReports_CL` table in Sentinel.

**No code required** - Logic Apps handle everything through visual workflows.

## Architecture

```
┌─────────────────────┐
│ Security Copilot    │
│ Agent (Scheduled)   │
└──────────┬──────────┘
           │ (runs queries)
           ▼
┌─────────────────────┐       ┌──────────────────┐
│ Logic App           │──────▶│ Sentinel Custom  │
│ (Scheduled Daily)   │       │ Table:           │
│                     │       │ ComplianceReports│
│ 1. Run KQL Query    │       └──────────────────┘
│ 2. Transform Data   │
│ 3. Send via HTTP    │
└─────────────────────┘
```

## Why Logic Apps?

✅ **No Python/Code Required** - Visual designer
✅ **Built-in Sentinel Connector** - Query Log Analytics directly
✅ **HTTP Data Collector API** - Native Log Analytics ingestion
✅ **Scheduled Execution** - Runs automatically
✅ **Managed Identity Support** - Secure authentication
✅ **Cost Effective** - ~$0.001 per execution

## Setup Instructions

### Prerequisites

1. ✅ Run `setup-custom-table.sh` first (creates the custom table)
2. ✅ Ensure Sentinel workspace exists
3. ✅ Azure CLI authenticated with Contributor access

### Step 1: Deploy Logic Apps

```bash
cd /home/bob/CODE/Microsoft/securitycopilot/security-reporting-agent

# Make script executable
chmod +x deploy-logic-app-ingestion.sh

# Deploy Logic Apps
./deploy-logic-app-ingestion.sh
```

This creates 3 Logic Apps:
- **FailedAuth-To-CustomTable** - Failed authentication report
- **Malware-To-CustomTable** - Malware detections report
- **AdminActivity-To-CustomTable** - Admin activity report

### Step 2: Authorize Connections

After deployment, authorize the Logic App connections:

```bash
# Open Azure Portal
az portal --query "https://portal.azure.com/#resource/subscriptions/dc227dbb-3963-4b6c-be2b-bf29217436d6/resourceGroups/sentinel/providers/Microsoft.Logic/workflows/FailedAuth-To-CustomTable"

# In the portal:
# 1. Go to Logic App → API connections
# 2. Click "azuremonitorlogs-*" connection
# 3. Click "Edit API connection"
# 4. Click "Authorize" and sign in
# 5. Click "Save"
```

### Step 3: Test Logic App

```bash
# Manually trigger the Logic App
az logic workflow run create \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable

# Check run history
az logic workflow run list \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable \
  --query "[0].{Status:status, StartTime:startTime, EndTime:endTime}" -o table
```

### Step 4: Verify Data in Sentinel

```kql
// Check if data was ingested
ComplianceReports_CL
| where TimeGenerated > ago(1h)
| where ReportName == "FailedAuthenticationReport"
| take 10
```

## How It Works

### Logic App Flow

Each Logic App follows this pattern:

1. **Trigger**: Recurrence (Daily at 8 AM UTC)

2. **Action: Run KQL Query**
   - Uses Azure Monitor Logs connector
   - Executes the same query as Security Copilot agent
   - Returns results as JSON array

3. **Action: For Each Result**
   - Loops through each row from query

4. **Action: Compose Custom Table Record**
   - Transforms query result to match ComplianceReports_CL schema
   - Adds metadata (ReportType, ControlID, Framework, etc.)

5. **Action: Send to Log Analytics**
   - Uses HTTP Data Collector API
   - Sends to `ComplianceReports_CL` table
   - Authenticates with workspace shared key

## Alternative: Use Log Analytics HTTP Data Collector

Instead of DCR/DCE, the Logic App uses the **simpler HTTP Data Collector API**:

```http
POST https://{workspace-id}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01

Headers:
  Content-Type: application/json
  Log-Type: ComplianceReports  (Creates ComplianceReports_CL table automatically)
  x-ms-date: {RFC1123 date}
  Authorization: SharedKey {workspace-id}:{signature}

Body:
[
  {
    "TimeGenerated": "2025-10-31T10:00:00Z",
    "ReportType": "Identity",
    "ReportName": "FailedAuthenticationReport",
    ...
  }
]
```

The `_CL` suffix is added automatically by Log Analytics!

## Simplified Setup (Alternative)

If you don't want to use `setup-custom-table.sh`, you can let the HTTP Data Collector API create the table automatically:

### Quick Start (No DCR/DCE Required)

1. **Deploy Logic App**
   ```bash
   ./deploy-logic-app-ingestion.sh
   ```

2. **Authorize connection** (via Portal)

3. **Run Logic App**
   ```bash
   az logic workflow run create --resource-group sentinel --name FailedAuth-To-CustomTable
   ```

4. **Table is created automatically!**
   - Table name: `ComplianceReports_CL`
   - Schema inferred from first record

5. **Query the table**
   ```kql
   ComplianceReports_CL | take 10
   ```

That's it! No DCR/DCE setup needed with this approach.

## Adding More Reports

To create Logic Apps for other reports, copy the template and modify:

```bash
# Copy template
cp logicapp-failedauth-template.json logicapp-mfa-template.json

# Edit the JSON:
# 1. Change "body" field (line 87) - Update KQL query
# 2. Change "ReportName" (line 102) - e.g., "MFAComplianceReport"
# 3. Change "ControlID" (line 103) - e.g., "IA-2|CIS-6.1"
# 4. Update field mappings (lines 105-115) as needed

# Deploy
az deployment group create \
  --resource-group sentinel \
  --template-file logicapp-mfa-template.json \
  --parameters logicAppName="MFACompliance-To-CustomTable"
```

## Logic App Schedule Configuration

All Logic Apps run **daily at 8 AM UTC** by default. To change:

### Via Portal:
1. Open Logic App → Logic app designer
2. Click on "Recurrence" trigger
3. Modify frequency, interval, time zone
4. Save

### Via CLI:
```bash
# Change to run every 6 hours
az logic workflow update \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable \
  --definition '{
    "triggers": {
      "Recurrence": {
        "recurrence": {
          "frequency": "Hour",
          "interval": 6
        }
      }
    }
  }'
```

## Monitoring and Troubleshooting

### Check Logic App Runs

```bash
# List recent runs
az logic workflow run list \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable \
  --query "[].{Status:status, Start:startTime, End:endTime, Duration:properties.correlation.clientTrackingId}" \
  -o table

# Get detailed run information
RUN_NAME=$(az logic workflow run list --resource-group sentinel --name FailedAuth-To-CustomTable --query "[0].name" -o tsv)

az logic workflow run show \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable \
  --run-name $RUN_NAME
```

### View Logic App in Portal

```bash
# Open in browser
az logic workflow show \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable \
  --query id -o tsv | xargs -I {} echo "https://portal.azure.com/#resource{}/overview"
```

### Common Issues

#### Issue: "Unauthorized" error on KQL query
**Solution**: Authorize the Azure Monitor Logs API connection in the Portal

#### Issue: HTTP 403 when sending to Log Analytics
**Solution**: Verify workspace ID and key are correct
```bash
az monitor log-analytics workspace show --resource-group sentinel --workspace-name sentinel --query customerId
az monitor log-analytics workspace get-shared-keys --resource-group sentinel --workspace-name sentinel --query primarySharedKey
```

#### Issue: Data not appearing in Sentinel
**Solution**:
1. Check Logic App run history for errors
2. Wait 5-10 minutes for ingestion
3. Query with: `ComplianceReports_CL | where TimeGenerated > ago(1h)`

#### Issue: Schema mismatch
**Solution**: Delete and recreate the table if needed
```bash
# The HTTP Data Collector API creates the table automatically on first use
# Schema is inferred from the first record sent
# If you need to change schema, delete table and send new schema on first run
```

## Cost Estimation

### Logic App Costs
- **Standard tier**: $0.000025 per action execution
- Each Logic App: ~5 actions per row
- Example: 100 rows/day × 5 actions × $0.000025 = **$0.0125/day**
- **Monthly cost**: ~$0.38/month per Logic App

### Data Ingestion
- Ingestion: ~$2.50 per GB
- 100 rows/day × 2 KB/row = 200 KB/day = 6 MB/month
- **Monthly cost**: ~$0.015/month

### Total: ~$1.15/month for 3 Logic Apps

## Integration with Security Copilot Agent

Your Security Copilot agent and Logic Apps can run in parallel:

- **Security Copilot Agent**: Runs reports on-demand or scheduled (24h)
- **Logic Apps**: Run same queries and persist to custom table (daily at 8 AM)

This gives you:
- ✅ On-demand reports via Security Copilot
- ✅ Historical data in Sentinel custom table
- ✅ Workbooks and analytics rules based on custom table
- ✅ Compliance tracking over time

## Next Steps

1. ✅ Deploy Logic Apps with `deploy-logic-app-ingestion.sh`
2. ⬜ Authorize API connections in Portal
3. ⬜ Test one Logic App manually
4. ⬜ Verify data in `ComplianceReports_CL` table
5. ⬜ Create additional Logic Apps for other reports
6. ⬜ Build Sentinel workbooks based on custom table
7. ⬜ Create analytics rules for critical findings

## Advanced: Parallel Logic App Execution

To process all reports at once, create a **parent Logic App** that triggers all child Logic Apps in parallel:

```json
{
  "actions": {
    "Trigger_FailedAuth": {
      "type": "Http",
      "inputs": {
        "method": "POST",
        "uri": "[listCallbackURL(concat(resourceId('Microsoft.Logic/workflows', 'FailedAuth-To-CustomTable'), '/triggers/manual'), '2019-05-01').value]"
      }
    },
    "Trigger_Malware": {
      "type": "Http",
      "inputs": {
        "method": "POST",
        "uri": "[listCallbackURL(concat(resourceId('Microsoft.Logic/workflows', 'Malware-To-CustomTable'), '/triggers/manual'), '2019-05-01').value]"
      }
    }
  }
}
```

This allows all reports to run concurrently, completing in ~1-2 minutes instead of sequentially.
