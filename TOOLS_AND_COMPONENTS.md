# Tools and Components Reference

Complete list of all tools, services, and components used in the Security Copilot Compliance Reporting System.

## Microsoft Cloud Services

### 1. Microsoft Security Copilot
**Purpose:** AI-powered security analysis and KQL query execution
**Role:** Executes compliance queries and returns JSON results
**Version:** Latest (2025)
**Cost:** ~1 SCU per execution
**Documentation:** https://learn.microsoft.com/copilot/security/

**Our Usage:**
- Custom agent with 13 KQL queries
- API endpoint: `/process-prompt`
- Returns JSON wrapped in markdown code fences
- Requires OAuth connection authorization

**Connection Name:** `securitycopilot-failedauth`

---

### 2. Azure Logic Apps
**Purpose:** Workflow automation and orchestration
**Role:** Schedules executions, processes data, writes to Log Analytics
**Tier:** Consumption (pay-per-execution)
**Cost:** ~$0.01 per execution
**Documentation:** https://learn.microsoft.com/azure/logic-apps/

**Our Usage:**
- Deployed Name: `ComplianceReports-FailedAuth-Copilot`
- Schedule: Daily at 8:00 AM UTC (Recurrence trigger)
- Actions:
  - ApiConnection (Security Copilot)
  - Compose (JSON manipulation)
  - ParseJson (JSON parsing)
  - ApiConnection (Log Analytics Data Collector)

**Key Actions:**
1. `Run_Copilot_FailedAuth_Report` - Calls Copilot API
2. `Extract_JSON_from_Markdown` - Strips code fences
3. `Parse_JSON_Results` - Parses to array
4. `Send_Data` - Writes to Log Analytics

---

### 3. Azure Sentinel (Microsoft Sentinel)
**Purpose:** Cloud-native SIEM and SOAR
**Role:** Data storage and security analytics platform
**Workspace:** sentinel
**Workspace ID:** YOUR_WORKSPACE_ID
**Documentation:** https://learn.microsoft.com/azure/sentinel/

**Our Usage:**
- Log Analytics workspace backend
- Custom table: `ComplianceReports_CL`
- Data retention: 90 days (default)
- Query language: KQL (Kusto Query Language)

**Table Schema:**
```
ComplianceReports_CL
├── TimeGenerated (datetime)
├── ReportName_s (string)
├── ReportType_s (string)
├── Severity_s (string)
├── ControlID_s (string)
├── Framework_s (string)
├── QueryDomain_s (string)
├── FindingType_s (string)
├── RemediationRequired_s (string)
├── Status_s (string)
├── Technique_s (string, optional)
├── Tactics_s (string, optional)
├── UserPrincipalName_s (string, optional)
└── [query-specific fields]
```

---

### 4. Azure Log Analytics
**Purpose:** Log data collection and analysis
**Role:** Backend for Sentinel, data ingestion endpoint
**API:** HTTP Data Collector API
**Documentation:** https://learn.microsoft.com/azure/azure-monitor/logs/

**Our Usage:**
- Ingestion endpoint: `https://{workspaceId}.ods.opinsights.azure.com/api/logs`
- Authentication: HMAC-SHA256 (handled by connector)
- Custom log type: `ComplianceReports`
- Ingestion latency: 5-10 minutes

---

### 5. Azure Log Analytics Data Collector (Connector)
**Purpose:** Managed connector for writing to Log Analytics
**Role:** Handles authentication and data submission
**Type:** API Connection
**Documentation:** https://learn.microsoft.com/connectors/azureloganalyticsdatacollector/

**Our Usage:**
- Connection Name: `azureloganalyticsdatacollector-copilot`
- Parameters:
  - username: Workspace ID
  - password: Workspace Primary Key
- Handles HMAC signature calculation automatically
- Path: `/api/logs`
- Headers: `Log-Type: ComplianceReports`

**Why This Connector:**
- ✅ Automatic HMAC authentication
- ✅ No manual signature calculation
- ✅ No Integration Account required
- ✅ Simple configuration

**Alternatives Tried (Failed):**
- ❌ Manual `hmac()` function (not supported)
- ❌ JavaScript inline code (requires Integration Account $$$)
- ❌ Azure Monitor Logs connector (wrong API/deprecated)

---

### 6. Azure Sentinel Workbooks (Future)
**Purpose:** Interactive data visualization and dashboards
**Role:** Compliance reporting dashboard (planned)
**Documentation:** https://learn.microsoft.com/azure/sentinel/monitor-your-data

**Planned Dashboards:**
- Executive compliance scorecard
- Control status matrix
- Findings trends and aging
- Framework-specific views
- Remediation tracker

---

## Development Tools

### 7. Azure CLI (az)
**Purpose:** Azure resource management from command line
**Version:** 2.x
**Documentation:** https://learn.microsoft.com/cli/azure/

**Our Usage:**
```bash
# Deploy Logic App
az deployment group create \
  --resource-group sentinel \
  --template-file logicapp-copilot-failedauth.json

# Query Log Analytics
az monitor log-analytics query \
  --workspace {workspace-id} \
  --analytics-query "ComplianceReports_CL | take 10"
```

**Key Commands:**
- `az deployment group create` - ARM template deployment
- `az monitor log-analytics query` - Query workspace
- `az logic workflow show` - View Logic App definition
- `az resource show` - View API connections

---

### 8. Python 3
**Purpose:** Testing and scripting
**Version:** 3.11+
**Documentation:** https://www.python.org/

**Libraries Used:**
- `requests` - HTTP client
- `json` - JSON parsing
- `datetime` - Date/time handling
- `hashlib` - HMAC signature (SHA256)
- `hmac` - HMAC calculation
- `base64` - Encoding/decoding

**Our Scripts:**
- `test/test-webhook-data.py` - Direct Log Analytics API test
- `test/send-test-data.py` - Original test script

---

### 9. JSON / ARM Templates
**Purpose:** Infrastructure as Code
**Format:** Azure Resource Manager (ARM) templates
**Documentation:** https://learn.microsoft.com/azure/azure-resource-manager/

**Our Templates:**
- `prod/logicapp-copilot-failedauth.json` - Production Logic App
- `test/logicapp-test-single.json` - Test Logic App

**Key Sections:**
- `parameters` - Input parameters
- `variables` - Computed values
- `resources` - Azure resources to deploy
- `outputs` - Return values

---

### 10. YAML
**Purpose:** Agent manifest definition
**Format:** YAML (Yet Another Markup Language)
**Documentation:** https://yaml.org/

**Our Manifests:**
- `CONTEXT/agent-manifest-rebuild.yaml` - Production agent (13 queries)
- `CONTEXT/ComplianceSecOpsAutomatedReportingAgent.yaml` - Original template

**Structure:**
```yaml
Descriptor:
  Name: Agent name
  Description: Agent description

SkillGroups:
  - Format: KQL
    Skills:
      - Name: SkillName
        DisplayName: Display Name
        Description: What it does
        Inputs: []
        Settings:
          Target: LogAnalytics
          Template: |
            <KQL query>
```

---

### 11. KQL (Kusto Query Language)
**Purpose:** Query language for Azure data services
**Used In:** Security Copilot queries, Log Analytics queries
**Documentation:** https://learn.microsoft.com/azure/data-explorer/kusto/query/

**Our Queries:**
- 13 compliance queries in agent manifest
- Sentinel data source queries
- Log Analytics result queries

**Example Pattern:**
```kql
let findings = SecurityAlert
| where TimeGenerated > ago(24h)
| where Severity == "High"
| project TimeGenerated, AlertName, Severity;

let hasResults = toscalar(findings | count) > 0;

union findings,
(print placeholder = 1
| where not(hasResults)
| extend FindingType = "No Findings"
| project-away placeholder)
```

---

### 12. Markdown
**Purpose:** Documentation format
**Used In:** README files, Copilot response wrapping
**Documentation:** https://commonmark.org/

**Our Usage:**
- All documentation files (README.md, etc.)
- Security Copilot wraps JSON in markdown code fences
- Need to strip `` `json\n...\n` `` before parsing

---

### 13. Git (Version Control)
**Purpose:** Source control and collaboration
**Repository Structure:**
```
security-reporting-agent/
├── prod/           # Production files
├── test/           # Test files
├── CONTEXT/        # Reference files
└── [docs]          # Documentation
```

---

## Compliance Frameworks

### 14. NIST Cybersecurity Framework 2.0
**Purpose:** Risk-based cybersecurity guidance
**Coverage:** All 6 functions (GOVERN, IDENTIFY, PROTECT, DETECT, RESPOND, RECOVER)
**Documentation:** https://www.nist.gov/cyberframework

**Our Mappings:**
- Control IDs embedded in query results
- Framework field in output data
- Used for compliance reporting

---

### 15. NIST SP 800-53 Rev 5
**Purpose:** Security and privacy controls
**Coverage:** AC, AU, CM, IA, SI families
**Documentation:** https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final

**Control Families Used:**
- AC - Access Control
- AU - Audit and Accountability
- CM - Configuration Management
- IA - Identification and Authentication
- SI - System and Information Integrity
- IR - Incident Response
- CP - Contingency Planning

---

### 16. CIS Controls v8
**Purpose:** Prioritized cybersecurity best practices
**Coverage:** 18 controls
**Documentation:** https://www.cisecurity.org/controls/v8

**Controls Mapped:**
- CIS-1: Asset Inventory
- CIS-2: Software Inventory
- CIS-5: Account Management
- CIS-6: Access Control
- CIS-8: Audit Logs
- CIS-13: Network Monitoring

---

## Azure Resource Types

### 17. Microsoft.Logic/workflows
**Resource Type:** Logic App workflow
**API Version:** 2019-05-01
**Our Resources:**
- ComplianceReports-FailedAuth-Copilot (production)
- ComplianceReports-SingleTest (test)

---

### 18. Microsoft.Web/connections
**Resource Type:** API Connection
**API Version:** 2016-06-01
**Our Resources:**
- securitycopilot-failedauth (Security Copilot connector)
- azureloganalyticsdatacollector-copilot (Log Analytics connector)

---

### 19. Microsoft.OperationalInsights/workspaces
**Resource Type:** Log Analytics workspace
**API Version:** 2020-08-01
**Our Resource:**
- sentinel (workspace name)
- ID: YOUR_WORKSPACE_ID

---

## Testing Tools

### 20. Static Test Data
**Purpose:** Test without consuming SCUs
**Location:** `test/logicapp-test-single.json`
**Contains:** Simulated Security Copilot response with markdown-wrapped JSON

**Benefits:**
- No Security Copilot API calls
- No SCU consumption
- Tests complete flow (markdown stripping, parsing, ingestion)
- Fast iteration during development

---

### 21. Python HTTP Test Script
**Purpose:** Direct API testing bypassing Logic Apps
**Location:** `test/test-webhook-data.py`
**Uses:** Python `requests` library with manual HMAC calculation

**Benefits:**
- Validates Log Analytics API directly
- Confirms HMAC signature algorithm
- Useful for troubleshooting connector issues

---

## Documentation Tools

### 22. Audit Log
**Purpose:** Session work tracking
**Location:** `CONTEXT/claude_audit.log`
**Contains:**
- All decisions made during development
- Technical challenges and solutions
- Deployment commands
- Testing results
- Future roadmap

---

### 23. README Files
**Purpose:** Project documentation
**Locations:**
- `README.md` - Current implementation
- `CONTEXT/README-original.md` - Comprehensive original docs
- `PROJECT_STATUS.md` - Quick reference status

---

### 24. SVG Diagram
**Purpose:** Visual architecture representation
**Location:** `architecture-diagram.svg`
**Shows:** Complete data flow from Copilot → Logic App → Sentinel → Workbook

---

## Summary Statistics

### Total Tools/Services: 24

**Categories:**
- Microsoft Cloud Services: 6
- Development Tools: 9
- Compliance Frameworks: 3
- Azure Resource Types: 3
- Testing Tools: 2
- Documentation: 3

**By Vendor:**
- Microsoft: 18
- Open Source: 6
- Standards Bodies: 3

**By Cost:**
- Paid Services: 4 (Copilot, Logic Apps, Sentinel, Log Analytics)
- Free Tools: 20

---

## Quick Reference

### Essential Commands
```bash
# Deploy Production
cd prod && az deployment group create --resource-group sentinel \
  --template-file logicapp-copilot-failedauth.json --mode Incremental

# Deploy Test
cd test && az deployment group create --resource-group sentinel \
  --template-file logicapp-test-single.json --mode Incremental

# Query Results
az monitor log-analytics query --workspace YOUR_WORKSPACE_ID \
  --analytics-query "ComplianceReports_CL | take 10"

# Test Direct API
cd test && python3 test-webhook-data.py
```

### Essential Files
- Production Logic App: `prod/logicapp-copilot-failedauth.json`
- Production Agent: `CONTEXT/agent-manifest-rebuild.yaml`
- Test Logic App: `test/logicapp-test-single.json`
- Architecture: `architecture-diagram.svg`
- Audit Log: `CONTEXT/claude_audit.log`

---

**Last Updated:** 2025-11-02
**Version:** 1.0
**Status:** Production Ready
