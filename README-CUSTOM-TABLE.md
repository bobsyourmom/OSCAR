# Custom Sentinel Table for Compliance Reports

## Overview

This solution creates a custom Log Analytics table (`ComplianceReports_CL`) that stores results from all Security Copilot compliance and security reports in a unified schema.

## Table Schema

The `ComplianceReports_CL` table includes 45 fields designed to accommodate various report types:

### Core Metadata Fields
- `TimeGenerated` - Report generation timestamp
- `ReportType` - Category (Identity, Threat, Audit, Network, Vulnerability)
- `ReportName` - Specific report name
- `ControlID` - Compliance control ID(s)
- `Framework` - Compliance framework(s)
- `Severity` - Finding severity
- `FindingType` - Type of finding
- `QueryDomain` - Security domain
- `RemediationRequired` - Remediation status
- `Status` - Finding status

### Identity & Access Fields
- `UserPrincipalName`
- `Location`
- `Application`

### Threat Detection Fields
- `CompromisedEntity`
- `AlertName`
- `IncidentNumber`
- `ThreatFamily`
- `FileName`
- `FilePath`
- `Tactics` (dynamic array)
- `Techniques` (dynamic array)

### Network Security Fields
- `SourceIP`
- `DestinationIP`
- `Protocol`
- `Port`
- `BytesSent`
- `BytesReceived`

### Audit & Resource Fields
- `Operation`
- `InitiatedBy`
- `TargetResource`
- `ResourceId`
- `ResourceGroup`
- `SubscriptionId`
- `TenantId`
- `Hostname`

### Vulnerability Fields
- `CVE`
- `CVSSScore`
- `PatchAvailable`

### Aggregation Fields
- `Count`
- `FirstSeen`
- `LastSeen`

### Additional Fields
- `Description`
- `RemediationSteps`
- `AdditionalData` (dynamic JSON)
- `RawData` (dynamic JSON - original query result)

## Setup Instructions

### Step 1: Run the Setup Script

```bash
cd /home/bob/CODE/Microsoft/securitycopilot/security-reporting-agent
chmod +x setup-custom-table.sh
./setup-custom-table.sh
```

This creates:
- Custom table: `ComplianceReports_CL`
- Data Collection Endpoint (DCE)
- Data Collection Rule (DCR)

Save the output configuration values for ingestion.

### Step 2: Install Python Dependencies

```bash
pip install azure-identity azure-monitor-ingestion azure-monitor-query
```

### Step 3: Configure Ingestion Script

Edit `ingest-to-sentinel.py` and update:

```python
DCE_ENDPOINT = "https://your-dce-endpoint"
DCR_IMMUTABLE_ID = "dcr-xxxxxxxxxxxxxxxxxxxxxxxx"
WORKSPACE_ID = "your-workspace-id"
```

### Step 4: Run Ingestion

```bash
# Ensure Azure CLI is authenticated
az login

# Run ingestion script
python3 ingest-to-sentinel.py
```

## Querying the Table

### Basic Query
```kql
ComplianceReports_CL
| take 10
```

### Filter by Report Type
```kql
ComplianceReports_CL
| where ReportType == "Identity"
| where Severity in ("Critical", "High")
| project TimeGenerated, ReportName, FindingType, UserPrincipalName, Severity, RemediationRequired
```

### Filter by Compliance Framework
```kql
ComplianceReports_CL
| where Framework contains "NIST 800-53"
| where ControlID contains "AC-7"
| summarize FindingCount = count() by ReportName, Severity
```

### Threat Detections with MITRE ATT&CK
```kql
ComplianceReports_CL
| where ReportType == "Threat"
| where isnotempty(Tactics)
| extend TacticsList = tostring(Tactics)
| project TimeGenerated, AlertName, CompromisedEntity, TacticsList, Techniques, Severity
```

### Administrative Activity Summary
```kql
ComplianceReports_CL
| where ReportType == "Audit"
| where Severity in ("Critical", "High")
| summarize ActivityCount = count() by InitiatedBy, Operation, bin(TimeGenerated, 1d)
| order by ActivityCount desc
```

### Compliance Control Coverage
```kql
ComplianceReports_CL
| summarize
    TotalFindings = count(),
    CriticalFindings = countif(Severity == "Critical"),
    HighFindings = countif(Severity == "High"),
    RemediationNeeded = countif(RemediationRequired == "Yes")
    by ControlID, Framework
| order by CriticalFindings desc
```

## Automation Options

### Option 1: Azure Function (Scheduled)

Deploy an Azure Function with timer trigger (daily) that:
1. Runs `ingest-to-sentinel.py`
2. Sends results to the custom table
3. Triggers alerts on critical findings

### Option 2: Logic App (Scheduled)

Create a Logic App with:
- Trigger: Recurrence (daily at 8 AM)
- Action: Azure Function (runs ingestion script)
- Action: Send notification on completion

### Option 3: GitHub Actions (CI/CD)

```yaml
name: Daily Compliance Reports
on:
  schedule:
    - cron: '0 8 * * *'  # Daily at 8 AM UTC
jobs:
  run-reports:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - name: Install dependencies
        run: pip install azure-identity azure-monitor-ingestion azure-monitor-query
      - name: Run ingestion
        run: python3 ingest-to-sentinel.py
```

## Creating Sentinel Workbooks

Use the custom table in Sentinel workbooks:

```kql
// Compliance Dashboard - Top Tile
ComplianceReports_CL
| where TimeGenerated > ago(7d)
| summarize
    TotalFindings = count(),
    Critical = countif(Severity == "Critical"),
    High = countif(Severity == "High"),
    RequiresRemediation = countif(RemediationRequired == "Yes")
| project
    ["Total Findings"] = TotalFindings,
    ["Critical"] = Critical,
    ["High"] = High,
    ["Requires Action"] = RequiresRemediation

// Findings by Framework (Chart)
ComplianceReports_CL
| where TimeGenerated > ago(7d)
| summarize Count = count() by Framework, Severity
| order by Count desc

// Recent Critical Findings (Grid)
ComplianceReports_CL
| where TimeGenerated > ago(24h)
| where Severity == "Critical"
| project
    Time = TimeGenerated,
    Report = ReportName,
    Finding = FindingType,
    Entity = coalesce(UserPrincipalName, CompromisedEntity, Hostname),
    Control = ControlID,
    Remediation = RemediationRequired
| order by Time desc
```

## Analytics Rules

Create analytics rules based on the custom table:

### Rule 1: Critical Findings Detected
```kql
ComplianceReports_CL
| where Severity == "Critical"
| where RemediationRequired == "Yes"
| summarize
    FindingCount = count(),
    Controls = make_set(ControlID)
    by ReportName, FindingType
| where FindingCount > 0
```

### Rule 2: Failed Authentication Spike
```kql
ComplianceReports_CL
| where ReportName == "FailedAuthenticationReport"
| where Count > 20  // More than 20 failed attempts
| project TimeGenerated, UserPrincipalName, Count, Severity
```

## Data Retention

The custom table follows the workspace retention policy (default 90 days). To modify:

```bash
az monitor log-analytics workspace table update \
  --resource-group sentinel \
  --workspace-name sentinel \
  --name ComplianceReports_CL \
  --retention-time 180  # 180 days
```

## Troubleshooting

### Issue: Table not appearing after setup
**Solution**: Wait 5-10 minutes for table provisioning. Then run:
```kql
ComplianceReports_CL | getschema
```

### Issue: Ingestion fails with 403 error
**Solution**: Ensure the identity running the script has these roles:
- `Monitoring Metrics Publisher` on the DCR
- `Log Analytics Contributor` on the workspace

```bash
# Grant permissions
DCR_ID=$(az monitor data-collection rule show -g sentinel -n DCR-ComplianceReports --query id -o tsv)
PRINCIPAL_ID=$(az ad signed-in-user show --query id -o tsv)

az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Monitoring Metrics Publisher" \
  --scope $DCR_ID
```

### Issue: Query returns no results
**Solution**: Check data ingestion logs:
```kql
_LogOperation
| where Category == "Ingestion"
| where TimeGenerated > ago(1h)
| where Detail contains "ComplianceReports_CL"
```

## Cost Considerations

- **Ingestion**: ~$2.50 per GB
- **Storage**: ~$0.12 per GB/month
- **Query**: Included in workspace tier

**Estimated costs** for daily reports:
- ~1000 findings/day = ~500 KB/day
- Monthly ingestion: ~15 MB = ~$0.04
- Monthly storage: ~15 MB = ~$0.002

Total: **~$0.50/month**

## Next Steps

1. ✅ Run `setup-custom-table.sh` to create the table
2. ✅ Configure and run `ingest-to-sentinel.py`
3. ⬜ Create Sentinel workbook for visualization
4. ⬜ Set up analytics rules for critical findings
5. ⬜ Schedule automation (Azure Function/Logic App)
6. ⬜ Integrate with Security Copilot agent triggers
