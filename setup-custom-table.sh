#!/bin/bash

# ============================================================================
# Setup Custom Sentinel Table for Security Copilot Compliance Reports
# ============================================================================
# This script creates a custom table in Log Analytics/Sentinel that can
# accept results from all Security Copilot compliance and security reports.
#
# Prerequisites:
# - Azure CLI installed and authenticated (az login)
# - Contributor role on the resource group
# ============================================================================

# Configuration Variables
SUBSCRIPTION_ID="dc227dbb-3963-4b6c-be2b-bf29217436d6"
RESOURCE_GROUP="sentinel"
WORKSPACE_NAME="sentinel"
LOCATION="eastus"
TABLE_NAME="ComplianceReports_CL"
DCR_NAME="DCR-ComplianceReports"
DCE_NAME="DCE-ComplianceReports"

echo "=========================================="
echo "Setting up Custom Table for Compliance Reports"
echo "=========================================="
echo "Subscription: $SUBSCRIPTION_ID"
echo "Resource Group: $RESOURCE_GROUP"
echo "Workspace: $WORKSPACE_NAME"
echo "Table Name: $TABLE_NAME"
echo "=========================================="

# Set the active subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Get Workspace Resource ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --query id -o tsv)

echo "Workspace ID: $WORKSPACE_ID"

# ============================================================================
# Step 1: Create Data Collection Endpoint (DCE)
# ============================================================================
echo ""
echo "Step 1: Creating Data Collection Endpoint..."

DCE_ID=$(az monitor data-collection endpoint create \
  --name "$DCE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --public-network-access Enabled \
  --query id -o tsv)

echo "DCE Created: $DCE_ID"

# Get DCE logs ingestion endpoint
DCE_ENDPOINT=$(az monitor data-collection endpoint show \
  --name "$DCE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query logsIngestion.endpoint -o tsv)

echo "DCE Endpoint: $DCE_ENDPOINT"

# ============================================================================
# Step 2: Create Custom Table in Log Analytics
# ============================================================================
echo ""
echo "Step 2: Creating Custom Table Schema..."

# Create the table schema JSON file
cat > /tmp/table-schema.json <<'EOF'
{
  "properties": {
    "schema": {
      "name": "ComplianceReports_CL",
      "columns": [
        {
          "name": "TimeGenerated",
          "type": "datetime",
          "description": "Timestamp when the report was generated"
        },
        {
          "name": "ReportType",
          "type": "string",
          "description": "Type of report (Identity, Threat, Audit, Network, Vulnerability)"
        },
        {
          "name": "ReportName",
          "type": "string",
          "description": "Specific report name (e.g., FailedAuthenticationReport, MalwareDetectionsReport)"
        },
        {
          "name": "ControlID",
          "type": "string",
          "description": "Compliance control ID (e.g., AC-7, SI-3, CIS-5.1)"
        },
        {
          "name": "Framework",
          "type": "string",
          "description": "Compliance framework(s) (e.g., NIST 800-53, CIS Controls v8, NIST CSF 2.0)"
        },
        {
          "name": "Severity",
          "type": "string",
          "description": "Finding severity (Critical, High, Medium, Low, Informational)"
        },
        {
          "name": "FindingType",
          "type": "string",
          "description": "Type of finding (Failed Authentication, Malware Detection, Configuration Change, etc.)"
        },
        {
          "name": "QueryDomain",
          "type": "string",
          "description": "Security domain (identity, threat, audit, network, vulnerability, asset)"
        },
        {
          "name": "RemediationRequired",
          "type": "string",
          "description": "Whether remediation is required (Yes, No, Review)"
        },
        {
          "name": "Status",
          "type": "string",
          "description": "Current status (New, Active, Resolved, False Positive)"
        },
        {
          "name": "UserPrincipalName",
          "type": "string",
          "description": "User principal name (for identity-related findings)"
        },
        {
          "name": "CompromisedEntity",
          "type": "string",
          "description": "Entity that was compromised or affected"
        },
        {
          "name": "SourceIP",
          "type": "string",
          "description": "Source IP address"
        },
        {
          "name": "DestinationIP",
          "type": "string",
          "description": "Destination IP address"
        },
        {
          "name": "AlertName",
          "type": "string",
          "description": "Security alert name"
        },
        {
          "name": "IncidentNumber",
          "type": "string",
          "description": "Incident number or ID"
        },
        {
          "name": "ResourceId",
          "type": "string",
          "description": "Azure Resource ID"
        },
        {
          "name": "ResourceGroup",
          "type": "string",
          "description": "Azure Resource Group"
        },
        {
          "name": "SubscriptionId",
          "type": "string",
          "description": "Azure Subscription ID"
        },
        {
          "name": "TenantId",
          "type": "string",
          "description": "Azure Tenant ID"
        },
        {
          "name": "Hostname",
          "type": "string",
          "description": "Hostname or computer name"
        },
        {
          "name": "FileName",
          "type": "string",
          "description": "File name (for malware detections)"
        },
        {
          "name": "FilePath",
          "type": "string",
          "description": "File path (for malware detections)"
        },
        {
          "name": "ThreatFamily",
          "type": "string",
          "description": "Malware/threat family"
        },
        {
          "name": "Tactics",
          "type": "dynamic",
          "description": "MITRE ATT&CK tactics (array)"
        },
        {
          "name": "Techniques",
          "type": "dynamic",
          "description": "MITRE ATT&CK techniques (array)"
        },
        {
          "name": "Operation",
          "type": "string",
          "description": "Operation performed (for audit logs)"
        },
        {
          "name": "InitiatedBy",
          "type": "string",
          "description": "Who initiated the action"
        },
        {
          "name": "TargetResource",
          "type": "string",
          "description": "Target resource affected"
        },
        {
          "name": "Location",
          "type": "string",
          "description": "Geographic location"
        },
        {
          "name": "Application",
          "type": "string",
          "description": "Application name"
        },
        {
          "name": "Protocol",
          "type": "string",
          "description": "Network protocol"
        },
        {
          "name": "Port",
          "type": "int",
          "description": "Network port"
        },
        {
          "name": "BytesSent",
          "type": "long",
          "description": "Bytes sent (for network traffic)"
        },
        {
          "name": "BytesReceived",
          "type": "long",
          "description": "Bytes received (for network traffic)"
        },
        {
          "name": "CVE",
          "type": "string",
          "description": "CVE identifier (for vulnerabilities)"
        },
        {
          "name": "CVSSScore",
          "type": "real",
          "description": "CVSS score"
        },
        {
          "name": "PatchAvailable",
          "type": "boolean",
          "description": "Whether a patch is available"
        },
        {
          "name": "Count",
          "type": "long",
          "description": "Count of occurrences"
        },
        {
          "name": "FirstSeen",
          "type": "datetime",
          "description": "First occurrence timestamp"
        },
        {
          "name": "LastSeen",
          "type": "datetime",
          "description": "Last occurrence timestamp"
        },
        {
          "name": "Description",
          "type": "string",
          "description": "Detailed description"
        },
        {
          "name": "RemediationSteps",
          "type": "string",
          "description": "Recommended remediation steps"
        },
        {
          "name": "AdditionalData",
          "type": "dynamic",
          "description": "Additional metadata (JSON object)"
        },
        {
          "name": "RawData",
          "type": "dynamic",
          "description": "Original query result (JSON object)"
        }
      ]
    }
  }
}
EOF

echo "Creating custom table: $TABLE_NAME"

az rest --method PUT \
  --url "https://management.azure.com${WORKSPACE_ID}/tables/${TABLE_NAME}?api-version=2022-10-01" \
  --body @/tmp/table-schema.json

echo "Custom table created successfully!"

# ============================================================================
# Step 3: Create Data Collection Rule (DCR)
# ============================================================================
echo ""
echo "Step 3: Creating Data Collection Rule..."

# Create DCR JSON
cat > /tmp/dcr.json <<EOF
{
  "location": "${LOCATION}",
  "properties": {
    "dataCollectionEndpointId": "${DCE_ID}",
    "streamDeclarations": {
      "Custom-${TABLE_NAME}": {
        "columns": [
          {"name": "TimeGenerated", "type": "datetime"},
          {"name": "ReportType", "type": "string"},
          {"name": "ReportName", "type": "string"},
          {"name": "ControlID", "type": "string"},
          {"name": "Framework", "type": "string"},
          {"name": "Severity", "type": "string"},
          {"name": "FindingType", "type": "string"},
          {"name": "QueryDomain", "type": "string"},
          {"name": "RemediationRequired", "type": "string"},
          {"name": "Status", "type": "string"},
          {"name": "UserPrincipalName", "type": "string"},
          {"name": "CompromisedEntity", "type": "string"},
          {"name": "SourceIP", "type": "string"},
          {"name": "DestinationIP", "type": "string"},
          {"name": "AlertName", "type": "string"},
          {"name": "IncidentNumber", "type": "string"},
          {"name": "ResourceId", "type": "string"},
          {"name": "ResourceGroup", "type": "string"},
          {"name": "SubscriptionId", "type": "string"},
          {"name": "TenantId", "type": "string"},
          {"name": "Hostname", "type": "string"},
          {"name": "FileName", "type": "string"},
          {"name": "FilePath", "type": "string"},
          {"name": "ThreatFamily", "type": "string"},
          {"name": "Tactics", "type": "dynamic"},
          {"name": "Techniques", "type": "dynamic"},
          {"name": "Operation", "type": "string"},
          {"name": "InitiatedBy", "type": "string"},
          {"name": "TargetResource", "type": "string"},
          {"name": "Location", "type": "string"},
          {"name": "Application", "type": "string"},
          {"name": "Protocol", "type": "string"},
          {"name": "Port", "type": "int"},
          {"name": "BytesSent", "type": "long"},
          {"name": "BytesReceived", "type": "long"},
          {"name": "CVE", "type": "string"},
          {"name": "CVSSScore", "type": "real"},
          {"name": "PatchAvailable", "type": "boolean"},
          {"name": "Count", "type": "long"},
          {"name": "FirstSeen", "type": "datetime"},
          {"name": "LastSeen", "type": "datetime"},
          {"name": "Description", "type": "string"},
          {"name": "RemediationSteps", "type": "string"},
          {"name": "AdditionalData", "type": "dynamic"},
          {"name": "RawData", "type": "dynamic"}
        ]
      }
    },
    "destinations": {
      "logAnalytics": [
        {
          "workspaceResourceId": "${WORKSPACE_ID}",
          "name": "clv2ws1"
        }
      ]
    },
    "dataFlows": [
      {
        "streams": ["Custom-${TABLE_NAME}"],
        "destinations": ["clv2ws1"],
        "transformKql": "source",
        "outputStream": "Custom-${TABLE_NAME}"
      }
    ]
  }
}
EOF

DCR_ID=$(az rest --method PUT \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Insights/dataCollectionRules/${DCR_NAME}?api-version=2022-06-01" \
  --body @/tmp/dcr.json \
  --query id -o tsv)

echo "DCR Created: $DCR_ID"

# Get the immutable DCR ID
DCR_IMMUTABLE_ID=$(az rest --method GET \
  --url "https://management.azure.com${DCR_ID}?api-version=2022-06-01" \
  --query properties.immutableId -o tsv)

echo "DCR Immutable ID: $DCR_IMMUTABLE_ID"

# ============================================================================
# Step 4: Output Configuration for Ingestion
# ============================================================================
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Custom Table: ${TABLE_NAME}"
echo "DCE Endpoint: ${DCE_ENDPOINT}"
echo "DCR Immutable ID: ${DCR_IMMUTABLE_ID}"
echo "Stream Name: Custom-${TABLE_NAME}"
echo ""
echo "Save these values for data ingestion:"
echo ""
echo "# Environment Variables for Ingestion Script"
echo "export DCE_ENDPOINT=\"${DCE_ENDPOINT}\""
echo "export DCR_IMMUTABLE_ID=\"${DCR_IMMUTABLE_ID}\""
echo "export STREAM_NAME=\"Custom-${TABLE_NAME}\""
echo ""
echo "=========================================="

# Save configuration to file
cat > /tmp/ingestion-config.env <<EOF
# Configuration for ComplianceReports Custom Table Ingestion
DCE_ENDPOINT="${DCE_ENDPOINT}"
DCR_IMMUTABLE_ID="${DCR_IMMUTABLE_ID}"
STREAM_NAME="Custom-${TABLE_NAME}"
TABLE_NAME="${TABLE_NAME}"
WORKSPACE_ID="${WORKSPACE_ID}"
EOF

echo "Configuration saved to: /tmp/ingestion-config.env"
echo ""
echo "Next Steps:"
echo "1. Use the provided Python/PowerShell scripts to ingest data"
echo "2. Query the table in Sentinel: ${TABLE_NAME} | take 10"
echo "3. Create workbooks and analytics rules based on this table"
