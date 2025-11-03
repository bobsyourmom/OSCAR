# Security Copilot Compliance Reporting System

Automated compliance reporting using Microsoft Security Copilot + Azure Logic Apps + Azure Sentinel

## Current Implementation (v1.0 - 2025-11-02)

**Status:** ✅ Production Ready

### What's Working
- Single Logic App executing MitreAttackReport daily
- Security Copilot agent with 13 KQL compliance queries
- Automated data ingestion to ComplianceReports_CL table in Sentinel
- All queries return audit trail (even "No Findings")

## Quick Start

### Deploy Production Logic App
```bash
cd prod
az deployment group create \
  --resource-group sentinel \
  --template-file logicapp-copilot-failedauth.json \
  --parameters logicAppName="ComplianceReports-FailedAuth-Copilot" \
  --mode Incremental
```

### Authorize Connections
1. Go to Azure Portal → Resource Groups → sentinel
2. Authorize: **securitycopilot-failedauth** connection
3. Connection **azureloganalyticsdatacollector-copilot** is auto-configured

### Test
Trigger Logic App → Wait 5 mins → Query:
```kql
ComplianceReports_CL
| where TimeGenerated > ago(1h)
| take 10
```

## Architecture

```
Logic App (8 AM Daily)
    ↓
Security Copilot API
    → Execute MitreAttackReport KQL
    → Returns JSON (wrapped in markdown)
    ↓
Logic App Processing
    → Strip markdown fences
    → Parse JSON
    → Send via Azure Log Analytics Data Collector
    ↓
ComplianceReports_CL Table
```

## Project Structure

```
.
├── prod/                           # Production files
│   └── logicapp-copilot-failedauth.json
├── test/                           # Test files (no SCU consumption)
│   ├── logicapp-test-single.json  # Test Logic App with static data
│   ├── test-webhook-data.py       # Python test script
│   └── [old attempts]
├── CONTEXT/                        # Reference/backup files
│   ├── agent-manifest-rebuild.yaml  # Production agent (13 KQL queries)
│   ├── ComplianceSecOpsAutomatedReportingAgent.yaml  # Original template
│   ├── README-original.md          # Original comprehensive README
│   └── claude_audit.log            # Session work log
└── README.md                       # This file
```

## Key Files

### Production
**`prod/logicapp-copilot-failedauth.json`**
- Deployed as: `ComplianceReports-FailedAuth-Copilot`
- Schedule: Daily 8:00 AM UTC
- Executes: MitreAttackReport
- Output: ComplianceReports_CL table

### Agent Manifest
**`CONTEXT/agent-manifest-rebuild.yaml`**
- 13 KQL compliance queries
- Frameworks: NIST CSF 2.0, NIST 800-53, CIS Controls v8
- All queries return audit trail

**Available Reports:**
1. FailedAuthenticationReport
2. MITREAttackReport  
3. AdminActivityReport
4. HighSeverityAlertsReport
5. DataExfiltrationReport
6. PrivilegedAccountUsageReport
7. NetworkAnomalyReport
8. EndpointSecurityComplianceReport
9. MFAStatusReport
10. VulnerabilityManagementReport
11. BackupVerificationReport
12. FirewallRuleChangesReport
13. SuspiciousProcessExecutionReport

## Configuration

### Change Report Type
Edit Logic App prompt in `Run_Copilot_FailedAuth_Report` action:
```json
"PromptContent": "Using the Compliance&SecOpsAutomatedReportingAgent custom agent, execute the [ReportName] KQL skill and return only the raw JSON results"
```

### Change Schedule
Edit `Recurrence` trigger:
- Frequency: Day/Week/Month
- Interval: 1
- Schedule: Hours/Minutes
- Time Zone: UTC

## Testing (No SCU Consumption)

### Test Logic App
```bash
cd test
az deployment group create \
  --resource-group sentinel \
  --template-file logicapp-test-single.json \
  --parameters logicAppName="ComplianceReports-SingleTest" \
  --mode Incremental
```
- Uses static test data
- Tests all processing steps
- Writes to ComplianceReports_CL
- No Security Copilot API calls

### Python Test
```bash
cd test
python3 test-webhook-data.py
```

## Key Learnings

### ✅ What Works
- **Azure Log Analytics Data Collector** connector
  - Accepts workspace ID + key in connection config
  - Handles HMAC authentication automatically
  - Path: `/api/logs`

### ❌ What Doesn't Work
- Manual HMAC signature calculation in Logic Apps
  - `hmac()` function not supported at runtime
  - Requires Integration Account ($$$) for JavaScript code
- **Azure Monitor Logs** connector (deprecated/wrong API)
- Webhook approach (unnecessary complexity)

### 💡 Best Practices
1. Always use Azure Log Analytics Data Collector connector
2. Strip markdown from Copilot responses before parsing
3. Ensure KQL queries return audit trail (even "No Findings")
4. Match skill names exactly in prompts (case-sensitive)
5. Test with static data first (avoid SCU waste)

## Troubleshooting

**No data in table?**
1. Check Logic App run history
2. Verify connections authorized
3. Check "Send_Data" action output (should be 200)
4. Wait 5-10 minutes for ingestion
5. Query: `ComplianceReports_CL | where TimeGenerated > ago(1h)`

**JSON parsing fails?**
- Copilot wraps JSON in ```json fences
- `Extract_JSON_from_Markdown` action handles this

**Wrong skill executes?**
- Skill names are case-sensitive
- Use exact names from agent manifest

## Future Enhancements

- [ ] Create Logic Apps for all 13 reports
- [ ] Build Sentinel workbook for visualization
- [ ] Consolidate into single parameterized Logic App
- [ ] Add alerting for specific findings
- [ ] Historical trending and compliance scoring
- [ ] Multi-tenant support

## Costs

- **Security Copilot:** ~1 SCU per execution
- **Logic App:** Standard consumption pricing
- **Log Analytics:** Data ingestion charges

## Support

- Production Agent: `CONTEXT/agent-manifest-rebuild.yaml`
- Workspace: `sentinel` (ID: YOUR_WORKSPACE_ID)
- Table: `ComplianceReports_CL`
- Resource Group: `sentinel`

## Version History

**v1.0 (2025-11-02)**
- Initial production release
- Single Logic App for MitreAttackReport
- 13 KQL queries in agent manifest
- Azure Log Analytics Data Collector integration
- Daily 8 AM UTC schedule
