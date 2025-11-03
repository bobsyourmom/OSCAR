# Security Copilot - Automated Compliance & SecOps Reporting Agent

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-production--ready-brightgreen)

## 🎯 Overview

This Microsoft Security Copilot agent provides **comprehensive, automated security compliance reporting** for Security Operations teams. It maps security findings to multiple compliance frameworks (NIST CSF 2.0, NIST 800-53, CIS Controls v8), enriches data with threat intelligence from Security Copilot agents, and visualizes everything in beautiful Sentinel workbooks.

### Key Features

- ✅ **Multi-Framework Compliance Mapping** - NIST CSF 2.0, NIST 800-53, CIS Controls v8
- 🔍 **40+ Pre-Built KQL Queries** - Covering all major security domains
- 🤖 **Microsoft Agent Integration** - Threat Intel Briefing, Phishing Triage, Vulnerability Remediation
- 📊 **Visual Dashboards** - Executive summary, threat landscape, control matrix, remediation tracking
- 🔄 **Automated Scheduling** - Daily, weekly, and on-demand report execution
- 💾 **Watchlist Storage** - Persistent storage in Sentinel for historical analysis
- 🎨 **Customizable Report Groups** - Pre-defined and custom control groupings

## 📁 Repository Structure

```
security-reporting-agent/
├── agent-manifest.yaml                      # Main Security Copilot agent definition
├── config/
│   └── compliance-framework-mapping.json    # Framework and control mappings
├── queries/
│   ├── identity-access-queries.kql          # IAM compliance queries
│   ├── threat-detection-queries.kql         # Threat detection queries
│   └── audit-logging-queries.kql            # Audit and logging queries
├── watchlist-schemas/
│   └── deploy-watchlists.ps1                # Watchlist deployment script
├── workbooks/
│   └── compliance-dashboard-workbook.json   # Sentinel workbook definition
├── docs/
│   ├── deployment-guide.md                  # Complete deployment instructions
│   └── usage-examples.md                    # Usage scenarios and examples
└── README.md                                # This file
```

## 🚀 Quick Start

### Prerequisites

- Microsoft Security Copilot license
- Microsoft Sentinel workspace
- Azure PowerShell modules (`Az.SecurityInsights`, `Az.OperationalInsights`)
- Appropriate Azure RBAC permissions

### 5-Minute Deployment

1. **Clone and Configure**
   ```bash
   cd security-reporting-agent
   # Edit agent-manifest.yaml with your Azure details
   ```

2. **Deploy Watchlists**
   ```powershell
   ./watchlist-schemas/deploy-watchlists.ps1 `
       -SubscriptionId "<YOUR_SUB_ID>" `
       -ResourceGroupName "<YOUR_RG>" `
       -WorkspaceName "<YOUR_WORKSPACE>"
   ```

3. **Upload Agent to Security Copilot**
   - Open Security Copilot standalone portal
   - Navigate to Settings → Agents → Create Agent
   - Upload `agent-manifest.yaml`

4. **Deploy Workbook**
   - Open Microsoft Sentinel → Workbooks → Add Workbook
   - Advanced Editor → Paste `workbooks/compliance-dashboard-workbook.json`
   - Save as "Security Compliance & Operations Dashboard"

5. **Test**
   ```
   # In Security Copilot chat
   List all compliance controls
   Run daily critical reports
   ```

**📖 For detailed instructions, see [Deployment Guide](docs/deployment-guide.md)**

## 💡 Usage Examples

### List Available Controls

```plaintext
List all compliance controls
```

**Output**: Comprehensive list of all controls across NIST CSF 2.0, NIST 800-53, and CIS Controls v8

### List Controls by Framework

```plaintext
List NIST CSF controls
List CIS controls
List NIST 800-53 controls
```

### Show Report Groups

```plaintext
Show control groups
```

**Available Groups**:
- `daily_critical` - Daily Critical Security Monitoring (8 controls)
- `weekly_compliance` - Weekly Compliance Review (7 controls)
- `identity_governance` - Identity & Access Governance (10 controls)
- `threat_detection` - Threat Detection & Response (7 controls)
- `audit_logging` - Audit & Logging Review (7 controls)
- `vulnerability_management` - Vulnerability & Patch Management (3 controls)

### Run Individual Control Report

```plaintext
Run control AC-2 report
Run control SI-4 report
Run MFA compliance report
```

### Run Report Group

```plaintext
Run identity controls group
Run threat detection controls group
Run all daily reports
Run all weekly reports
```

## 📊 Compliance Framework Coverage

### NIST Cybersecurity Framework 2.0

All 6 functions covered:
- **GOVERN** (GV) - Organizational cybersecurity governance
- **IDENTIFY** (ID) - Asset management, risk assessment
- **PROTECT** (PR) - Identity management, data protection
- **DETECT** (DE) - Threat detection, monitoring
- **RESPOND** (RS) - Incident response, analysis
- **RECOVER** (RC) - Recovery planning, communications

### NIST SP 800-53 Rev 5

Major control families:
- **AC** - Access Control (7 controls)
- **AU** - Audit and Accountability (5 controls)
- **CM** - Configuration Management (2 controls)
- **IA** - Identification and Authentication (4 controls)
- **SI** - System and Information Integrity (4 controls)

### CIS Controls v8

18 critical security controls:
- **CIS-1** - Inventory and Control of Enterprise Assets
- **CIS-2** - Inventory and Control of Software Assets
- **CIS-5** - Account Management
- **CIS-6** - Access Control Management
- **CIS-8** - Audit Log Management
- **CIS-13** - Network Monitoring and Defense
- And more...

## 🔍 Security Domains Covered

| Domain | # of Queries | Primary Tables | Watchlist |
|--------|--------------|----------------|-----------|
| Identity & Access Management | 10 | SigninLogs, AuditLogs, IdentityInfo | ComplianceReports_Identity |
| Threat Detection & Response | 12 | SecurityAlert, SecurityIncident, ThreatIntelligenceIndicator | ComplianceReports_Threats |
| Audit & Logging | 10 | AuditLogs, AzureActivity | ComplianceReports_Audit |
| Network Security | 8 | AzureNetworkAnalytics_CL, CommonSecurityLog | ComplianceReports_Network |
| Vulnerability Management | 6 | SecurityRecommendation, Update | ComplianceReports_Vulnerabilities |
| Data Protection | 5 | AzureDiagnostics, StorageBlobLogs | ComplianceReports_DataProtection |
| Asset Inventory | 4 | Heartbeat, ConfigurationData | ComplianceReports_Assets |
| Incident Response | 5 | SecurityIncident | ComplianceReports_Incidents |

## 🤖 Microsoft Agent Integrations

### Threat Intelligence Briefing Agent

**Purpose**: Enrich threat findings with contextual intelligence

**Integration Points**:
- High/critical security alerts
- Data exfiltration indicators
- MITRE ATT&CK technique analysis
- APT indicator detection

**Usage**: Findings marked with `ThreatIntelEnrichment: Eligible` are automatically enriched

### Phishing Triage Agent

**Purpose**: Automatically triage phishing alerts

**Integration Points**:
- Phishing attempts detection
- Malicious email activity
- Suspicious link analysis

**Usage**: Findings marked with `PhishingTriageEligible: Yes` are auto-triaged

### Vulnerability Remediation Agent (Optional)

**Purpose**: Provide step-by-step remediation guidance

**Integration Points**:
- Critical vulnerability findings
- Patch compliance status
- Configuration drift detection

### Conditional Access Optimization Agent (Optional)

**Purpose**: Identify identity security gaps

**Integration Points**:
- Conditional access policy violations
- Policy coverage gaps
- MFA compliance issues

## 📈 Dashboard Views

### Executive Summary
- Overall compliance score
- Critical findings count
- Risk score trends
- Framework coverage heatmap

### Threat Intelligence Dashboard
- Active alerts by severity
- MITRE ATT&CK tactics observed
- Phishing/malware detections
- Data exfiltration indicators

### Identity & Access Management
- Failed authentication attempts
- MFA compliance status
- Privileged account activity
- Inactive accounts

### Audit & Configuration Management
- Administrative activities
- Security configuration changes
- Resource deletions
- Policy modifications

### Control Status Matrix
- Control-by-control assessment status
- Pass/Fail/Partial indicators
- Last assessed timestamps
- Risk score by control

### Remediation Tracker
- Open findings by severity
- Aging analysis
- MTTR metrics
- Assignment status

## 🔧 Customization

### Add Custom Control

Edit `config/compliance-framework-mapping.json`:

```json
{
  "id": "CUSTOM-001",
  "title": "Custom Security Control",
  "description": "Your control description",
  "queryDomain": "identity",
  "severity": "high"
}
```

### Add Custom Query

Create new KQL file in `queries/` directory:

```kql
// Custom query
YourTable
| where TimeGenerated > ago(24h)
| project TimeGenerated, FindingDetails,
    Severity = "High",
    ControlID = "CUSTOM-001",
    Framework = "Custom Framework",
    QueryDomain = "custom",
    FindingType = "Custom Finding",
    RemediationRequired = "Yes"
```

### Add Custom Report Group

Update `compliance-framework-mapping.json`:

```json
"reportGroups": {
  "custom_daily": {
    "name": "Custom Daily Reports",
    "frequency": "daily",
    "controls": ["CUSTOM-001", "AC-2", "SI-4"],
    "description": "Custom control grouping for daily review"
  }
}
```

## 🔐 Security Considerations

- **Least Privilege**: Agent requires minimum Sentinel Reader role
- **Data Residency**: All data stored in your Sentinel workspace region
- **Audit Trail**: All agent executions logged in Security Copilot audit logs
- **Watchlist Security**: Watchlists inherit Sentinel RBAC permissions
- **Credential Management**: No credentials stored in agent manifest
- **Threat Intel**: Enrichment uses Microsoft's threat intelligence only

## 📊 Metrics & KPIs

The solution tracks these key security metrics:

- **Compliance Score**: Calculated based on finding severity
- **Risk Score**: Weighted score (Critical=10, High=5, Medium=2)
- **Control Coverage**: Percentage of controls assessed
- **Mean Time to Remediate (MTTR)**: Average remediation time
- **Finding Aging**: Days since finding was first detected
- **SLA Breach Rate**: Percentage of findings exceeding SLA

## 🛠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| No data in watchlists | Verify agent triggers are enabled; manually run test query |
| Agent skills not executing | Check tenant/subscription/workspace IDs in manifest |
| Workbook timeout errors | Reduce time range; optimize queries |
| Threat intel not enriching | Verify Threat Intelligence Briefing Agent is enabled |
| Missing permissions | Ensure Sentinel Contributor + Security Reader roles |

**📖 See [Deployment Guide - Troubleshooting](docs/deployment-guide.md#troubleshooting) for detailed solutions**

## 📅 Maintenance Schedule

### Daily
- Review critical findings dashboard
- Triage high-severity alerts
- Verify agent execution status

### Weekly
- Review compliance score trends
- Update control mappings
- Close remediated findings

### Monthly
- Compliance scorecard review
- Agent performance optimization
- Query tuning and optimization

## 🤝 Contributing

Contributions welcome! Areas for enhancement:

- Additional compliance frameworks (ISO 27001, SOC 2, PCI-DSS, HIPAA)
- More KQL query templates
- Custom workbook panels
- Integration with additional Microsoft agents
- SOAR playbook templates

## 📄 License

MIT License - See LICENSE file for details

## 📞 Support

- **Documentation**: [docs/](docs/)
- **Issues**: File in GitHub Issues
- **Microsoft Docs**:
  - [Security Copilot](https://learn.microsoft.com/en-us/copilot/security/)
  - [Microsoft Sentinel](https://learn.microsoft.com/en-us/azure/sentinel/)

## 🎓 Resources

- [NIST Cybersecurity Framework 2.0](https://www.nist.gov/cyberframework)
- [NIST SP 800-53 Rev 5](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [CIS Controls v8](https://www.cisecurity.org/controls/v8)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [Microsoft Security Best Practices](https://docs.microsoft.com/en-us/security/compass/compass)

## 🌟 Acknowledgments

Built with:
- Microsoft Security Copilot
- Microsoft Sentinel
- Azure Monitor
- KQL (Kusto Query Language)

---

**Made with ❤️ for Security Operations Teams**

*Automate compliance, detect threats, protect your organization*
