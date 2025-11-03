#!/bin/bash

# ============================================================================
# Redeploy Logic Apps with HTTP Data Collector API (Fixed)
# ============================================================================

set -e

# Configuration
SUBSCRIPTION_ID="dc227dbb-3963-4b6c-be2b-bf29217436d6"
RESOURCE_GROUP="sentinel"
LOCATION="eastus"
WORKSPACE_NAME="sentinel"

echo "=========================================="
echo "Redeploying Logic Apps with Fixed Template"
echo "=========================================="

az account set --subscription "$SUBSCRIPTION_ID"

# Get Workspace details
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --query customerId -o tsv)

WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --query primarySharedKey -o tsv)

WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --query id -o tsv)

echo "Workspace ID: $WORKSPACE_ID"
echo "Workspace Resource ID: $WORKSPACE_RESOURCE_ID"
echo ""

# ============================================================================
# Redeploy Logic App 1: Failed Authentication Report
# ============================================================================
echo "1. Redeploying FailedAuth-To-CustomTable..."

KQL_QUERY_1='let timeRange = 24h;
SigninLogs
| where TimeGenerated > ago(timeRange)
| where ResultType != 0
| summarize
    FailedAttempts = count(),
    FirstAttempt = min(TimeGenerated),
    LastAttempt = max(TimeGenerated),
    IPAddress = make_set(IPAddress)
    by UserPrincipalName
| where FailedAttempts >= 5
| extend
    Severity = case(FailedAttempts >= 20, "Critical", FailedAttempts >= 10, "High", "Medium"),
    FindingType = "Failed Authentication",
    RemediationRequired = iff(FailedAttempts >= 10, "Yes", "Review")'

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file logicapp-http-template.json \
  --parameters \
    logicAppName="FailedAuth-To-CustomTable" \
    kqlQuery="$KQL_QUERY_1" \
    reportName="FailedAuthenticationReport" \
    reportType="Identity" \
    controlID="AC-7|CIS-5.1" \
    framework="NIST 800-53|CIS Controls v8" \
    queryDomain="identity" \
    workspaceId="$WORKSPACE_ID" \
    workspaceKey="$WORKSPACE_KEY" \
    workspaceResourceId="$WORKSPACE_RESOURCE_ID" \
    location="$LOCATION" \
  --mode Complete

echo "✓ FailedAuth-To-CustomTable redeployed"

# ============================================================================
# Redeploy Logic App 2: Malware Detections Report
# ============================================================================
echo "2. Redeploying Malware-To-CustomTable..."

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
  --template-file logicapp-http-template.json \
  --parameters \
    logicAppName="Malware-To-CustomTable" \
    kqlQuery="$KQL_QUERY_2" \
    reportName="MalwareDetectionsReport" \
    reportType="Threat" \
    controlID="SI-3|CIS-13.1" \
    framework="NIST 800-53|CIS Controls v8" \
    queryDomain="threat" \
    workspaceId="$WORKSPACE_ID" \
    workspaceKey="$WORKSPACE_KEY" \
    workspaceResourceId="$WORKSPACE_RESOURCE_ID" \
    location="$LOCATION" \
  --mode Complete

echo "✓ Malware-To-CustomTable redeployed"

echo ""
echo "=========================================="
echo "Redeployment Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Re-authorize API connections in Portal (they may have been recreated)"
echo "2. Test Logic Apps: bash test-logic-apps.sh"
echo ""
