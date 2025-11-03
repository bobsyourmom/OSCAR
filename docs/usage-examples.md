# Usage Examples - Security Copilot Compliance Reporting Agent

## Table of Contents

- [Basic Usage](#basic-usage)
- [Daily Operations](#daily-operations)
- [Weekly Compliance Reviews](#weekly-compliance-reviews)
- [Incident Investigation](#incident-investigation)
- [Executive Reporting](#executive-reporting)
- [Custom Scenarios](#custom-scenarios)

---

## Basic Usage

### Discover Available Controls

**Scenario**: You want to see all available compliance controls across all frameworks.

**Command**:
```
List all compliance controls
```

**Expected Output**:
```
Available Compliance Controls:

NIST Cybersecurity Framework 2.0:
- GV.OC-01: Organization's cybersecurity governance is established (Severity: High, Domain: audit)
- ID.AM-01: Physical devices and systems are inventoried (Severity: Medium, Domain: asset)
- PR.AA-01: Identities and credentials are managed (Severity: Critical, Domain: identity)
...

NIST 800-53 Rev 5:
- AC-2: Account Management (Severity: Critical, Domain: identity)
- AC-7: Unsuccessful Logon Attempts (Severity: High, Domain: identity)
- SI-4: System Monitoring (Severity: Critical, Domain: threat)
...

CIS Controls v8:
- CIS-5.1: Establish and Maintain an Inventory of Accounts (Severity: Critical, Domain: identity)
- CIS-13.1: Centralize Security Event Alerting (Severity: Critical, Domain: threat)
...
```

### List Controls by Framework

**Scenario**: You need to focus on NIST CSF controls specifically.

**Command**:
```
List NIST CSF controls
```

**Expected Output**: Filtered list showing only NIST Cybersecurity Framework 2.0 controls.

### Show Report Groups

**Scenario**: You want to understand pre-defined control groupings.

**Command**:
```
Show control groups
```

**Expected Output**:
```
Available Report Groups:

1. daily_critical (Frequency: Daily)
   - Description: Daily Critical Security Monitoring
   - Controls: PR.AA-01, DE.AE-02, RS.AN-01, AC-2, AC-7, SI-3, SI-4, CIS-5.1, CIS-13.1
   - Purpose: Critical security events requiring daily review

2. weekly_compliance (Frequency: Weekly)
   - Description: Weekly Compliance Review
   - Controls: ID.AM-01, ID.AM-02, CIS-1.1, CIS-2.1, CIS-5.3, CM-8, AU-6, CIS-8.11
   - Purpose: Compliance and configuration management reviews

3. identity_governance (Frequency: On-Demand)
   - Description: Identity and Access Governance
   - Controls: PR.AA-01, AC-2, AC-3, IA-2, IA-5, CIS-5.1, CIS-5.2, CIS-5.3, CIS-6.1, CIS-6.2
   - Purpose: Comprehensive identity and access management review

...
```

---

## Daily Operations

### Morning Security Review

**Scenario**: Every morning at 8 AM, your SOC needs to review overnight security events.

#### Step 1: Run Daily Critical Reports

**Command**:
```
Run all daily reports
```

**What Happens**:
- Executes all queries in the `daily_critical` report group
- Results written to appropriate watchlists
- Dashboard automatically updates

#### Step 2: Review Dashboard

Navigate to Sentinel Workbook: "Security Compliance & Operations Dashboard"

**Key Sections to Review**:
1. **Executive Summary** - Overall compliance score, critical findings
2. **Threat Intelligence Dashboard** - New alerts, MITRE tactics
3. **Identity & Access** - Failed auth attempts, suspicious sign-ins

#### Step 3: Investigate Critical Findings

**Command**:
```
Show me critical threats from the last 24 hours
```

**Follow-up Commands**:
```
Run critical alerts report
Run data exfiltration report
Run malware detections report
```

### Failed Authentication Investigation

**Scenario**: Multiple failed authentication attempts detected.

#### Step 1: Get Failed Auth Report

**Command**:
```
Run failed authentication report
```

**Output**: List of users with 5+ failed attempts in last 24 hours

#### Step 2: Check Specific User

In workbook, filter by UserPrincipalName or query watchlist:

```kql
_GetWatchlist('ComplianceReports_Identity')
| where FindingType == 'Failed Authentication'
| where UserPrincipalName == 'suspicious.user@domain.com'
| project TimeGenerated, FailedAttempts, IPAddresses, Locations, Severity
```

#### Step 3: Take Action

If malicious:
1. Disable account
2. Reset credentials
3. Create incident
4. Document in watchlist with remediation notes

### Phishing Alert Triage

**Scenario**: Multiple phishing alerts received.

#### Step 1: Run Phishing Report

**Command**:
```
Run phishing alerts report
```

**What Happens**:
- Query executes against SecurityAlert table
- Findings marked with `PhishingTriageEligible: Yes`
- Phishing Triage Agent automatically processes eligible alerts

#### Step 2: Review Triage Results

**Command**:
```
Show me phishing triage results from today
```

**Output**: Auto-triaged phishing alerts with:
- Verdict (True Positive, False Positive, Benign)
- Confidence score
- Explanation
- Recommended actions

#### Step 3: Handle Confirmed Threats

For true positives:
1. Block sender domain
2. Remove emails from all mailboxes
3. Notify affected users
4. Update anti-phishing policies

---

## Weekly Compliance Reviews

### Monday Morning Compliance Review

**Scenario**: Every Monday at 9 AM, review weekly compliance status.

#### Step 1: Run Weekly Reports

**Command**:
```
Run all weekly reports
```

**Executes**:
- Asset inventory compliance
- Inactive account detection
- Audit log review
- Configuration baseline checks

#### Step 2: Review Compliance Dashboard

Navigate to workbook → **Compliance Score by Framework**

**Review**:
- NIST CSF compliance score (target: >85%)
- NIST 800-53 compliance score (target: >90%)
- CIS Controls compliance score (target: >80%)

#### Step 3: Address Failing Controls

**Command**:
```
Show me failing controls
```

**Workbook Query**:
```kql
union
    (_GetWatchlist('ComplianceReports_Identity')),
    (_GetWatchlist('ComplianceReports_Threats')),
    (_GetWatchlist('ComplianceReports_Audit'))
| summarize
    CriticalFindings = countif(Severity == 'Critical')
    by ControlID
| where CriticalFindings > 0
| order by CriticalFindings desc
```

### Inactive Account Cleanup

**Scenario**: Weekly review of inactive accounts (CIS-5.3, AC-2).

#### Step 1: Run Inactive Accounts Report

**Command**:
```
Run inactive accounts report
```

**Output**: Users with no sign-in activity for 90+ days

#### Step 2: Review List

Check watchlist:
```kql
_GetWatchlist('ComplianceReports_Identity')
| where FindingType == 'Inactive Account'
| where AccountEnabled == true
| project UserPrincipalName, LastSignIn, DaysSinceLastSignIn, RemediationRequired
| order by DaysSinceLastSignIn desc
```

#### Step 3: Disable Accounts

For accounts >90 days inactive:
1. Verify with manager (no longer needed)
2. Disable account
3. Document in watchlist:
   ```
   Status: Remediated
   RemediationDate: 2025-10-30
   RemediatedBy: admin@domain.com
   ```

---

## Incident Investigation

### Suspicious Activity Investigation

**Scenario**: Alert triggered for potential data exfiltration.

#### Step 1: Check Recent Threats

**Command**:
```
Run data exfiltration report
```

**Output**: Potential data exfiltration indicators

#### Step 2: Enrich with Threat Intelligence

**Command**:
```
Enrich these findings with threat intelligence
```

**What Happens**:
- Threat Intelligence Briefing Agent analyzes findings
- Checks against known threat actor TTPs
- Identifies related indicators of compromise
- Provides context on similar attacks

#### Step 3: Check Lateral Movement

**Command**:
```
Show me lateral movement activity for entity: SERVER01
```

**Workbook Query**:
```kql
_GetWatchlist('ComplianceReports_Threats')
| where FindingType == 'Lateral Movement'
| where CompromisedEntity has 'SERVER01'
| project TimeGenerated, SourceDevice, DestinationDevice, Techniques, Severity
```

#### Step 4: Run MITRE ATT&CK Analysis

**Command**:
```
Run MITRE ATT&CK report
```

**Output**: Observed techniques mapped to MITRE framework

**Analysis**:
- Techniques: T1048 (Exfiltration Over Alternative Protocol), T1041 (Exfiltration Over C2 Channel)
- Tactics: Exfiltration, Command and Control
- Kill Chain Stage: Actions on Objectives

#### Step 5: Create Incident

Based on findings:
1. Create Security Incident in Sentinel
2. Assign to IR team
3. Set severity: High
4. Link all related alerts
5. Begin containment procedures

---

## Executive Reporting

### Monthly Executive Briefing

**Scenario**: Prepare monthly security posture briefing for leadership.

#### Step 1: Generate Compliance Scorecard

Navigate to workbook → **Executive Summary**

**Metrics to Extract**:
- Overall compliance score: 87%
- Critical findings: 12
- High findings: 45
- Risk score: 345
- Trend: +3% improvement from last month

#### Step 2: Framework-Specific Scores

From **Compliance Score by Framework** table:

| Framework | Score | Status |
|-----------|-------|--------|
| NIST CSF 2.0 | 89% | ✅ Pass |
| NIST 800-53 | 91% | ✅ Pass |
| CIS Controls v8 | 84% | ⚠️ Partial |

#### Step 3: Top Threats Summary

From **Threat Intelligence Dashboard**:

**This Month**:
- Total alerts: 1,247
- Critical alerts: 23
- Phishing attempts blocked: 156
- Malware detections: 8
- Data exfiltration attempts: 2 (both blocked)

**MITRE ATT&CK Top Techniques**:
1. T1078 - Valid Accounts (45 occurrences)
2. T1566 - Phishing (38 occurrences)
3. T1059 - Command and Scripting Interpreter (22 occurrences)

#### Step 4: Remediation Status

From **Remediation Tracker**:

- Open critical findings: 12
- Open high findings: 45
- Average MTTR: 4.2 days (target: <5 days)
- SLA breached items: 3

#### Step 5: Generate Executive Summary

**Command**:
```
Generate executive summary for the last 30 days
```

**Output** (formatted for presentation):
```
SECURITY POSTURE SUMMARY - October 2025

Overall Compliance Score: 87% (+3% MoM)
Risk Score: 345 (-15 from last month)

Framework Compliance:
✅ NIST CSF 2.0: 89%
✅ NIST 800-53: 91%
⚠️ CIS Controls v8: 84%

Threat Landscape:
- 1,247 alerts processed
- 23 critical threats contained
- 156 phishing attempts blocked
- 2 data exfiltration attempts stopped

Top Security Concerns:
1. CIS-5.3: 47 inactive accounts require review
2. AC-7: Multiple failed authentication attempts (brute force indicators)
3. SI-2: 12 critical vulnerabilities pending patch

Remediation Performance:
- MTTR: 4.2 days (Target: <5 days) ✅
- Open critical findings: 12
- SLA compliance: 97%

Recommendations:
1. Accelerate inactive account cleanup (CIS-5.3)
2. Implement adaptive authentication for high-risk users
3. Fast-track critical vulnerability patching
```

---

## Custom Scenarios

### Custom Report Group Creation

**Scenario**: Create custom report group for PCI-DSS compliance.

#### Step 1: Define Control Mapping

Edit `config/compliance-framework-mapping.json`:

```json
"reportGroups": {
  "pci_dss_quarterly": {
    "name": "PCI-DSS Quarterly Review",
    "frequency": "quarterly",
    "controls": [
      "AC-2",  // Requirement 8: Identify and authenticate access
      "AC-7",  // Requirement 8: Account lockout
      "AU-2",  // Requirement 10: Track and monitor access
      "AU-6",  // Requirement 10: Review logs
      "SI-4",  // Requirement 11: Monitor systems
      "AC-17"  // Requirement 8: Remote access control
    ],
    "description": "PCI-DSS compliance quarterly review requirements"
  }
}
```

#### Step 2: Run Custom Report Group

**Command**:
```
Run PCI-DSS quarterly reports
```

### Threat Hunting Scenario

**Scenario**: Proactive threat hunting for APT indicators.

#### Step 1: Run APT Indicator Query

**Command**:
```
Run APT indicator report
```

**What It Checks**:
- Multiple ATT&CK techniques from single entity
- Persistence + Defense Evasion + C2 tactics
- Activity spanning multiple days
- Multiple affected systems

#### Step 2: Correlate with Threat Intel

**Command**:
```
Correlate findings with known APT groups
```

**Threat Intelligence Briefing Agent**:
- Analyzes tactics/techniques
- Maps to known threat actor profiles
- Identifies campaign indicators
- Provides context on similar incidents

#### Step 3: Deep Dive Investigation

Custom KQL queries:
```kql
// Timeline of suspicious activity
_GetWatchlist('ComplianceReports_Threats')
| where CompromisedEntity == 'SUSPECTED_HOST'
| project TimeGenerated, FindingType, Tactics, Techniques
| order by TimeGenerated asc

// Check for related IOCs
ThreatIntelligenceIndicator
| where Active == true
| where NetworkIP in (<IPs_from_investigation>)
```

### Compliance Audit Preparation

**Scenario**: Preparing for external compliance audit.

#### Step 1: Run All Control Groups

```
Run identity governance controls group
Run threat detection controls group
Run audit logging controls group
Run vulnerability management controls group
```

#### Step 2: Export Evidence

For each control:
```kql
// Example: AC-2 evidence
_GetWatchlist('ComplianceReports_Identity')
| where ControlID has 'AC-2'
| where TimeGenerated > ago(90d)
| summarize
    AssessmentCount = count(),
    LastAssessment = max(TimeGenerated),
    FindingCount = count(),
    CriticalCount = countif(Severity == 'Critical')
| extend Status = iff(CriticalCount == 0, "Pass", "Fail")
```

#### Step 3: Generate Audit Package

Create report package:
1. Compliance scorecard (last 90 days)
2. Control evidence documents
3. Remediation documentation
4. Audit log exports
5. Executive summary

---

## Tips and Best Practices

### Performance Optimization

1. **Use Time Filters**: Always specify time range to limit query scope
2. **Leverage Watchlists**: Query watchlists instead of raw tables for historical data
3. **Batch Operations**: Run report groups instead of individual queries
4. **Schedule Wisely**: Stagger scheduled triggers to avoid resource contention

### Data Management

1. **Archive Old Findings**: Move findings >90 days to cold storage
2. **Clean Up Remediated Items**: Update status of fixed findings
3. **Maintain Watchlist Hygiene**: Regularly purge obsolete entries
4. **Document Exceptions**: Add notes for accepted risks

### Agent Integration

1. **Monitor Agent Execution**: Check logs daily for errors
2. **Tune Enrichment**: Configure threat intel agent parameters
3. **Review Auto-Triage**: Validate phishing triage accuracy weekly
4. **Update Skills**: Add new queries as threats evolve

### Dashboard Usage

1. **Bookmark Key Views**: Save frequently used filter combinations
2. **Export Snapshots**: Download charts for presentations
3. **Set Up Alerts**: Configure alerts for critical threshold breaches
4. **Share Workbooks**: Distribute read-only copies to stakeholders

---

## Additional Resources

- [Deployment Guide](deployment-guide.md) - Complete deployment instructions
- [README](../README.md) - Project overview and quick start
- [Microsoft Security Copilot Docs](https://learn.microsoft.com/en-us/copilot/security/)
- [KQL Reference](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)
