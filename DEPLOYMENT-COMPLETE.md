# Logic Apps Deployment - COMPLETE ✅

## Successfully Deployed Logic Apps

✅ **FailedAuth-To-CustomTable** - Enabled (eastus)
✅ **Malware-To-CustomTable** - Enabled (eastus)

Both Logic Apps are scheduled to run **daily at 8 AM UTC**.

## Next Steps Required

### Step 1: Authorize API Connections (REQUIRED)

The Logic Apps need you to authorize the Azure Monitor Logs connections:

**Option A: Via Azure Portal (Easiest)**

1. Open Azure Portal: https://portal.azure.com
2. Navigate to Resource Group: **sentinel**
3. Find and click on **API Connections**:
   - `azuremonitorlogs-FailedAuth-To-CustomTable`
   - `azuremonitorlogs-Malware-To-CustomTable`
4. For each connection:
   - Click the connection name
   - Click **"Edit API connection"** (left menu)
   - Click **"Authorize"** button
   - Sign in with your Azure credentials
   - Click **"Save"**

**Option B: Via CLI (Opens Portal)**

```bash
# Open the connections in Portal
az resource show \
  --resource-group sentinel \
  --resource-type "Microsoft.Web/connections" \
  --name "azuremonitorlogs-FailedAuth-To-CustomTable" \
  --query id -o tsv | xargs -I {} echo "https://portal.azure.com/#resource{}/overview"
```

### Step 2: Test the Logic Apps

After authorizing the connections, test each Logic App:

```bash
# Test Failed Auth Logic App
az logic workflow run create \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable

# Check run status
az logic workflow run list \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable \
  --top 1 \
  --query "[0].{Status:status, StartTime:startTime, EndTime:endTime}" -o table
```

```bash
# Test Malware Logic App
az logic workflow run create \
  --resource-group sentinel \
  --name Malware-To-CustomTable

# Check run status
az logic workflow run list \
  --resource-group sentinel \
  --name Malware-To-CustomTable \
  --top 1 \
  --query "[0].{Status:status, StartTime:startTime, EndTime:endTime}" -o table
```

### Step 3: Verify Data in Sentinel

Wait 2-5 minutes after running the Logic Apps, then query Sentinel:

```kql
// Check if ComplianceReports_CL table exists and has data
ComplianceReports_CL
| where TimeGenerated > ago(1h)
| take 10
```

```kql
// View Failed Authentication findings
ComplianceReports_CL
| where ReportName == "FailedAuthenticationReport"
| project TimeGenerated, UserPrincipalName, Count, Severity, RemediationRequired
| order by Count desc
```

```kql
// View Malware findings
ComplianceReports_CL
| where ReportName == "MalwareDetectionsReport"
| project TimeGenerated, AlertName, CompromisedEntity, Severity
```

## Logic App Configuration

### Schedule
Both Logic Apps run on this schedule:
- **Frequency**: Daily
- **Time**: 8:00 AM UTC
- **Time Zone**: UTC

To change the schedule:
1. Open Logic App in Portal
2. Click **"Logic app designer"**
3. Click the **"Recurrence"** trigger
4. Modify the schedule settings
5. Click **"Save"**

### What Each Logic App Does

**FailedAuth-To-CustomTable:**
1. Runs KQL query for failed sign-ins (5+ failures in 24h)
2. Transforms results to ComplianceReports_CL schema
3. Sends to Sentinel custom table
4. Tags with: ControlID="AC-7|CIS-5.1", Framework="NIST 800-53"

**Malware-To-CustomTable:**
1. Runs KQL query for malware alerts (24h)
2. Transforms results to ComplianceReports_CL schema
3. Sends to Sentinel custom table
4. Tags with: ControlID="SI-3|CIS-13.1", Framework="NIST 800-53"

## Troubleshooting

### Issue: Logic App runs but no data in Sentinel

**Check 1: View run history in Portal**
```bash
# Get last run details
az logic workflow run list \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable \
  --top 1 \
  --query "[0].{Status:status, Code:code, Error:properties.error}" -o json
```

**Check 2: Verify API connection is authorized**
- Portal → API Connections → Check "Status" column shows "Connected"

**Check 3: Check if query returned results**
- Portal → Logic App → Run history → Click latest run → View each action

### Issue: "Unauthorized" error

**Solution**: Re-authorize the API connection
- Portal → API connections → azuremonitorlogs-* → Edit API connection → Authorize → Save

### Issue: Table not created in Sentinel

The `ComplianceReports_CL` table is created automatically when first data is sent. Wait 5-10 minutes after a successful Logic App run.

To verify table exists:
```kql
search *
| where $table == "ComplianceReports_CL"
| take 1
```

Or check all custom tables:
```kql
search *
| where $table endswith "_CL"
| distinct $table
```

## Monitoring

### View All Runs
```bash
az logic workflow run list \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable \
  --query "[].{Status:status, Start:startTime, End:endTime}" -o table
```

### Check Logic App Status
```bash
az logic workflow show \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable \
  --query "{Name:name, State:state, Endpoint:accessEndpoint}" -o table
```

### Disable/Enable Logic App
```bash
# Disable
az logic workflow update \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable \
  --state Disabled

# Enable
az logic workflow update \
  --resource-group sentinel \
  --name FailedAuth-To-CustomTable \
  --state Enabled
```

## Cost Estimate

### Logic App Execution
- **Price**: $0.000025 per action
- **Actions per run**: ~5-10 actions per result row
- **Example**: 50 rows/day × 7 actions × $0.000025 = **$0.00875/day**
- **Monthly**: ~$0.26/month per Logic App

### Data Ingestion
- **Price**: ~$2.50 per GB
- **Data size**: ~50 rows/day × 2 KB = 100 KB/day = 3 MB/month
- **Monthly**: ~$0.0075/month

**Total**: ~$0.54/month for 2 Logic Apps

## Files Created

- ✅ `agent-manifest.yaml` - Security Copilot agent definition
- ✅ `logicapp-simple-template.json` - Logic App ARM template
- ✅ `deploy-logic-apps-v2.sh` - Deployment script
- ✅ `DEPLOYMENT-COMPLETE.md` - This file

## Integration with Security Copilot Agent

Your Security Copilot agent (`ComplianceSecOpsReporting`) and these Logic Apps work together:

- **Security Copilot**: Runs queries on-demand or via trigger (24h schedule)
- **Logic Apps**: Persist results to Sentinel custom table (daily at 8 AM)

This gives you:
- ✅ On-demand reports via Security Copilot prompts
- ✅ Historical compliance data in Sentinel
- ✅ Workbooks and dashboards based on custom table
- ✅ Analytics rules for automated alerting

## Creating Workbooks

After data is ingested, create a Sentinel workbook:

1. Sentinel → Workbooks → "+ New workbook"
2. Add query visualization:

```kql
ComplianceReports_CL
| where TimeGenerated > ago(7d)
| summarize TotalFindings = count() by ReportType, Severity
| render barchart
```

3. Add compliance dashboard:

```kql
ComplianceReports_CL
| summarize
    Critical = countif(Severity == "Critical"),
    High = countif(Severity == "High"),
    RequiresAction = countif(RemediationRequired == "Yes")
    by ControlID, Framework
| order by Critical desc
```

## Next Steps

1. ✅ **Complete Step 1**: Authorize API connections (REQUIRED)
2. ✅ **Complete Step 2**: Test Logic Apps
3. ✅ **Complete Step 3**: Verify data in Sentinel
4. ⬜ Create Sentinel workbook for visualization
5. ⬜ Create analytics rules for critical findings
6. ⬜ Add more Logic Apps for other reports (MFA, Critical Alerts, etc.)

---

**Deployment Date**: 2025-10-31
**Status**: ✅ Logic Apps Created - Awaiting Authorization
