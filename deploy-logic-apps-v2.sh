#!/bin/bash

# ============================================================================
# Deploy Logic Apps for Security Copilot Report Ingestion (v2)
# ============================================================================

set -e  # Exit on error

# Configuration
SUBSCRIPTION_ID="dc227dbb-3963-4b6c-be2b-bf29217436d6"
RESOURCE_GROUP="sentinel"
LOCATION="eastus"
WORKSPACE_NAME="sentinel"

echo "=========================================="
echo "Deploying Logic Apps for Report Ingestion"
echo "=========================================="

az account set --subscription "$SUBSCRIPTION_ID"

# Get Workspace Resource ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --query id -o tsv)

echo "Workspace Resource ID: $WORKSPACE_ID"
echo ""

# ============================================================================
# Deploy Logic App 1: Failed Authentication Report
# ============================================================================
echo "1. Deploying FailedAuth-To-CustomTable..."

KQL_QUERY_1='let timeRange = 24h;
SigninLogs
| where TimeGenerated > ago(timeRange)
| where ResultType != 0
| summarize
    FailedAttempts = count(),
    FirstAttempt = min(TimeGenerated),
    LastAttempt = max(TimeGenerated)
    by UserPrincipalName
| where FailedAttempts >= 5
| extend
    Severity = case(FailedAttempts >= 20, "Critical", FailedAttempts >= 10, "High", "Medium"),
    FindingType = "Failed Authentication",
    RemediationRequired = iff(FailedAttempts >= 10, "Yes", "Review")'

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file logicapp-simple-template.json \
  --parameters \
    logicAppName="FailedAuth-To-CustomTable" \
    kqlQuery="$KQL_QUERY_1" \
    reportName="FailedAuthenticationReport" \
    reportType="Identity" \
    controlID="AC-7|CIS-5.1" \
    framework="NIST 800-53|CIS Controls v8" \
    queryDomain="identity" \
    workspaceResourceId="$WORKSPACE_ID" \
    location="$LOCATION" \
  --no-wait

echo "✓ FailedAuth-To-CustomTable deployment started"

# ============================================================================
# Deploy Logic App 2: Malware Detections Report
# ============================================================================
echo "2. Deploying Malware-To-CustomTable..."

KQL_QUERY_2='SecurityAlert
| where TimeGenerated > ago(24h)
| where AlertName has_any ("malware", "virus", "trojan", "ransomware", "backdoor")
| extend
    Severity = "Critical",
    FindingType = "Malware Detection",
    RemediationRequired = "Yes"
| project TimeGenerated, AlertName, AlertSeverity, CompromisedEntity, Severity, FindingType, RemediationRequired'

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file logicapp-simple-template.json \
  --parameters \
    logicAppName="Malware-To-CustomTable" \
    kqlQuery="$KQL_QUERY_2" \
    reportName="MalwareDetectionsReport" \
    reportType="Threat" \
    controlID="SI-3|CIS-13.1" \
    framework="NIST 800-53|CIS Controls v8" \
    queryDomain="threat" \
    workspaceResourceId="$WORKSPACE_ID" \
    location="$LOCATION" \
  --no-wait

echo "✓ Malware-To-CustomTable deployment started"

# ============================================================================
# Deploy Logic App 3: Admin Activity Report
# ============================================================================
echo "3. Deploying AdminActivity-To-CustomTable..."

KQL_QUERY_3='AzureActivity
| where TimeGenerated > ago(24h)
| where OperationNameValue has_any ("Microsoft.Authorization", "Microsoft.Compute")
| where ActivityStatusValue == "Success"
| extend
    Severity = case(OperationNameValue has_any ("delete", "remove"), "Critical", "High"),
    FindingType = "Administrative Activity",
    RemediationRequired = "Review"
| project TimeGenerated, OperationNameValue, Caller, ResourceGroup, Severity, FindingType, RemediationRequired'

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file logicapp-simple-template.json \
  --parameters \
    logicAppName="AdminActivity-To-CustomTable" \
    kqlQuery="$KQL_QUERY_3" \
    reportName="AdminActivityReport" \
    reportType="Audit" \
    controlID="AU-6|DE.CM-03|CIS-8.11" \
    framework="NIST 800-53|NIST CSF 2.0|CIS Controls v8" \
    queryDomain="audit" \
    workspaceResourceId="$WORKSPACE_ID" \
    location="$LOCATION" \
  --no-wait

echo "✓ AdminActivity-To-CustomTable deployment started"

echo ""
echo "Waiting for deployments to complete..."
sleep 30

echo ""
echo "=========================================="
echo "Deployment Status"
echo "=========================================="

# Check deployment status
az deployment group list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?contains(name, 'logicapp-simple-template')].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}" \
  -o table

echo ""
echo "=========================================="
echo "Logic Apps Created"
echo "=========================================="

az logic workflow list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?contains(name, 'CustomTable')].{Name:name, State:state, Location:location}" \
  -o table

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Authorize API connections:"
echo "   az portal --query \"https://portal.azure.com/#resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/overview\""
echo ""
echo "2. For each Logic App:"
echo "   - Open in Portal"
echo "   - Go to 'API connections'"
echo "   - Click the 'azuremonitorlogs-*' connection"
echo "   - Click 'Edit API connection'"
echo "   - Click 'Authorize' and sign in"
echo "   - Click 'Save'"
echo ""
echo "3. Grant Logic Apps permissions to Log Analytics:"
for app in "FailedAuth-To-CustomTable" "Malware-To-CustomTable" "AdminActivity-To-CustomTable"; do
  PRINCIPAL_ID=$(az logic workflow show --resource-group "$RESOURCE_GROUP" --name "$app" --query identity.principalId -o tsv 2>/dev/null || echo "")
  if [ -n "$PRINCIPAL_ID" ]; then
    echo "   Granting $app (Principal: $PRINCIPAL_ID)..."
    az role assignment create \
      --assignee "$PRINCIPAL_ID" \
      --role "Log Analytics Contributor" \
      --scope "$WORKSPACE_ID" \
      --output none 2>/dev/null || echo "   (Role may already exist)"
  fi
done

echo ""
echo "4. Test a Logic App:"
echo "   az logic workflow run create --resource-group $RESOURCE_GROUP --name FailedAuth-To-CustomTable"
echo ""
echo "5. Query results in Sentinel:"
echo "   ComplianceReports_CL | where TimeGenerated > ago(1h) | take 10"
echo ""
