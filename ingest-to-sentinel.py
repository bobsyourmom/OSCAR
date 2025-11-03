#!/usr/bin/env python3
"""
Ingest Security Copilot Compliance Report Results to Sentinel Custom Table
============================================================================
This script queries KQL results from Security Copilot agent and ingests them
into the custom ComplianceReports_CL table in Sentinel.

Prerequisites:
- Azure CLI logged in: az login
- Run setup-custom-table.sh first
- Install required packages: pip install azure-identity azure-monitor-ingestion azure-monitor-query
"""

import json
import os
from datetime import datetime, timezone
from azure.identity import DefaultAzureCredential
from azure.monitor.ingestion import LogsIngestionClient
from azure.monitor.query import LogsQueryClient
from azure.core.exceptions import HttpResponseError

# ============================================================================
# Configuration - Load from environment or set directly
# ============================================================================
DCE_ENDPOINT = os.getenv("DCE_ENDPOINT", "https://DCE-ComplianceReports-XXXX.eastus-1.ingest.monitor.azure.com")
DCR_IMMUTABLE_ID = os.getenv("DCR_IMMUTABLE_ID", "dcr-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
STREAM_NAME = os.getenv("STREAM_NAME", "Custom-ComplianceReports_CL")

# Sentinel/Log Analytics Configuration
WORKSPACE_ID = "YOUR_WORKSPACE_ID"  # Get from: az monitor log-analytics workspace show
SUBSCRIPTION_ID = "dc227dbb-3963-4b6c-be2b-bf29217436d6"
RESOURCE_GROUP = "sentinel"
WORKSPACE_NAME = "sentinel"

# ============================================================================
# Report Definitions - Map to your Security Copilot Agent Skills
# ============================================================================
REPORTS = [
    {
        "name": "FailedAuthenticationReport",
        "report_type": "Identity",
        "query_domain": "identity",
        "control_id": "AC-7|CIS-5.1",
        "framework": "NIST 800-53|CIS Controls v8",
        "query": """
            let timeRange = 24h;
            SigninLogs
            | where TimeGenerated > ago(timeRange)
            | where ResultType != 0
            | summarize
                FailedAttempts = count(),
                FirstAttempt = min(TimeGenerated),
                LastAttempt = max(TimeGenerated),
                Locations = make_set(Location),
                IPAddresses = make_set(IPAddress),
                Applications = make_set(AppDisplayName)
                by UserPrincipalName, UserDisplayName
            | where FailedAttempts >= 5
            | extend
                Severity = case(FailedAttempts >= 20, "Critical", FailedAttempts >= 10, "High", "Medium"),
                FindingType = "Failed Authentication",
                RemediationRequired = iff(FailedAttempts >= 10, "Yes", "Review")
        """
    },
    {
        "name": "MalwareDetectionsReport",
        "report_type": "Threat",
        "query_domain": "threat",
        "control_id": "SI-3|CIS-13.1",
        "framework": "NIST 800-53|CIS Controls v8",
        "query": """
            SecurityAlert
            | where TimeGenerated > ago(24h)
            | where AlertName has_any ("malware", "virus", "trojan", "ransomware", "backdoor")
            | extend ThreatFamily = tostring(ExtendedProperties.["Threat Family"]),
                FilePath = tostring(ExtendedProperties.["File Path"]),
                FileName = tostring(ExtendedProperties.["File Name"])
            | project TimeGenerated, AlertName, AlertSeverity, CompromisedEntity, ThreatFamily,
                FilePath, FileName, RemediationSteps, Status,
                Severity = "Critical",
                FindingType = "Malware Detection",
                RemediationRequired = "Yes"
        """
    },
    {
        "name": "AdminActivityReport",
        "report_type": "Audit",
        "query_domain": "audit",
        "control_id": "AU-6|DE.CM-03|CIS-8.11",
        "framework": "NIST 800-53|NIST CSF 2.0|CIS Controls v8",
        "query": """
            AzureActivity
            | where TimeGenerated > ago(24h)
            | where OperationNameValue has_any ("Microsoft.Authorization", "Microsoft.Compute",
                "Microsoft.Network", "Microsoft.Storage")
            | where ActivityStatusValue == "Success"
            | extend InitiatedBy = tostring(Caller)
            | project TimeGenerated, OperationNameValue, ResourceProviderValue, ResourceGroup,
                SubscriptionId, InitiatedBy, ActivityStatusValue,
                Severity = case(OperationNameValue has_any ("delete", "remove"), "Critical",
                    OperationNameValue has_any ("write", "create"), "High", "Medium"),
                FindingType = "Administrative Activity",
                RemediationRequired = "Review"
        """
    }
]

# ============================================================================
# Main Functions
# ============================================================================

def run_kql_query(credential, report):
    """Execute KQL query against Log Analytics workspace"""
    print(f"Running query: {report['name']}...")

    client = LogsQueryClient(credential)

    try:
        response = client.query_workspace(
            workspace_id=WORKSPACE_ID,
            query=report["query"],
            timespan="PT24H"
        )

        if response.status == "Success":
            # Convert query results to list of dictionaries
            results = []
            for table in response.tables:
                columns = [col.name for col in table.columns]
                for row in table.rows:
                    result = dict(zip(columns, row))
                    results.append(result)

            print(f"  ✓ Query returned {len(results)} results")
            return results
        else:
            print(f"  ✗ Query failed: {response.status}")
            return []

    except HttpResponseError as e:
        print(f"  ✗ Error executing query: {e}")
        return []


def transform_to_table_schema(report, query_results):
    """Transform query results to match custom table schema"""
    transformed_records = []

    for row in query_results:
        # Create base record with report metadata
        record = {
            "TimeGenerated": datetime.now(timezone.utc).isoformat(),
            "ReportType": report["report_type"],
            "ReportName": report["name"],
            "ControlID": report["control_id"],
            "Framework": report["framework"],
            "QueryDomain": report["query_domain"],
            "Severity": row.get("Severity", "Medium"),
            "FindingType": row.get("FindingType", "Unknown"),
            "RemediationRequired": row.get("RemediationRequired", "Review"),
            "Status": row.get("Status", "New")
        }

        # Map common fields from query results
        field_mappings = {
            "UserPrincipalName": "UserPrincipalName",
            "CompromisedEntity": "CompromisedEntity",
            "IPAddress": "SourceIP",
            "AlertName": "AlertName",
            "IncidentNumber": "IncidentNumber",
            "ResourceId": "ResourceId",
            "ResourceGroup": "ResourceGroup",
            "SubscriptionId": "SubscriptionId",
            "Computer": "Hostname",
            "FileName": "FileName",
            "FilePath": "FilePath",
            "ThreatFamily": "ThreatFamily",
            "Tactics": "Tactics",
            "Techniques": "Techniques",
            "OperationNameValue": "Operation",
            "Caller": "InitiatedBy",
            "InitiatedBy": "InitiatedBy",
            "Location": "Location",
            "AppDisplayName": "Application",
            "Description": "Description",
            "RemediationSteps": "RemediationSteps"
        }

        # Map fields that exist in query results
        for source_field, target_field in field_mappings.items():
            if source_field in row and row[source_field] is not None:
                record[target_field] = row[source_field]

        # Handle numeric fields
        if "FailedAttempts" in row:
            record["Count"] = int(row["FailedAttempts"])
        if "FirstAttempt" in row or "FirstSeen" in row:
            record["FirstSeen"] = row.get("FirstAttempt") or row.get("FirstSeen")
        if "LastAttempt" in row or "LastSeen" in row:
            record["LastSeen"] = row.get("LastAttempt") or row.get("LastSeen")

        # Store raw query result for reference
        record["RawData"] = row

        transformed_records.append(record)

    return transformed_records


def ingest_to_sentinel(credential, records):
    """Ingest records to Sentinel custom table via Data Collection API"""
    if not records:
        print("No records to ingest")
        return

    print(f"Ingesting {len(records)} records to Sentinel...")

    client = LogsIngestionClient(
        endpoint=DCE_ENDPOINT,
        credential=credential
    )

    try:
        client.upload(
            rule_id=DCR_IMMUTABLE_ID,
            stream_name=STREAM_NAME,
            logs=records
        )
        print(f"  ✓ Successfully ingested {len(records)} records")

    except HttpResponseError as e:
        print(f"  ✗ Error ingesting data: {e}")
        print(f"  Error details: {e.response.text if hasattr(e, 'response') else 'N/A'}")


def main():
    """Main execution function"""
    print("=" * 60)
    print("Security Copilot Compliance Reports -> Sentinel Ingestion")
    print("=" * 60)
    print(f"DCE Endpoint: {DCE_ENDPOINT}")
    print(f"Stream: {STREAM_NAME}")
    print(f"Workspace ID: {WORKSPACE_ID}")
    print("=" * 60)
    print()

    # Authenticate
    credential = DefaultAzureCredential()

    # Process each report
    all_records = []

    for report in REPORTS:
        print(f"\n📊 Processing: {report['name']}")

        # Run KQL query
        query_results = run_kql_query(credential, report)

        if query_results:
            # Transform to table schema
            transformed = transform_to_table_schema(report, query_results)
            all_records.extend(transformed)
            print(f"  ✓ Transformed {len(transformed)} records")

    # Ingest all records
    if all_records:
        print(f"\n📤 Total records to ingest: {len(all_records)}")
        ingest_to_sentinel(credential, all_records)
    else:
        print("\n⚠️  No records found to ingest")

    print("\n" + "=" * 60)
    print("✅ Processing Complete!")
    print("=" * 60)
    print(f"\nQuery the table in Sentinel:")
    print(f"ComplianceReports_CL | take 10")


if __name__ == "__main__":
    main()
