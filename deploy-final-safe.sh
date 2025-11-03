#!/bin/bash

# ============================================================================
# SAFE Logic App Deployment - Uses Incremental Mode Only
# ============================================================================

set -e

SUBSCRIPTION_ID="dc227dbb-3963-4b6c-be2b-bf29217436d6"
RESOURCE_GROUP="sentinel"
LOCATION="eastus"
WORKSPACE_NAME="sentinel"

echo "==========================================="
echo "SAFE Logic App Deployment"
echo "==========================================="
echo "Deployment Mode: INCREMENTAL (safe - won't delete resources)"
echo ""

az account set --subscription "$SUBSCRIPTION_ID"

# Get new workspace details
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

# Deploy FailedAuth Logic App
echo "Deploying FailedAuth-To-CustomTable-v2..."

KQL_QUERY='let timeRange = 24h; SigninLogs | where TimeGenerated > ago(timeRange) | where ResultType != 0 | summarize FailedAttempts = count(), FirstAttempt = min(TimeGenerated), LastAttempt = max(TimeGenerated) by UserPrincipalName | where FailedAttempts >= 5 | extend Severity = case(FailedAttempts >= 20, "Critical", FailedAttempts >= 10, "High", "Medium"), FindingType = "Failed Authentication", RemediationRequired = iff(FailedAttempts >= 10, "Yes", "Review")'

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file logicapp-simple-template.json \
  --parameters \
    logicAppName="FailedAuth-v2" \
    kqlQuery="$KQL_QUERY" \
    reportName="FailedAuthenticationReport" \
    reportType="Identity" \
    controlID="AC-7|CIS-5.1" \
    framework="NIST 800-53|CIS Controls v8" \
    queryDomain="identity" \
    workspaceResourceId="$WORKSPACE_RESOURCE_ID" \
    location="$LOCATION" \
  --mode Incremental \
  --no-wait

echo "✓ FailedAuth-v2 deployment started (Incremental mode - SAFE)"
echo ""
echo "==========================================="
echo "Deployment Complete!"
echo "==========================================="
echo ""
echo "NOTE: New Workspace ID is: $WORKSPACE_ID"
echo ""
echo "Next Steps:"
echo "1. Authorize the API connection in Portal"
echo "2. Test the Logic App"
echo "3. Verify data in ComplianceReports_CL"
