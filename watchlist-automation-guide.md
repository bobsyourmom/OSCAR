# Writing Security Copilot Agent Results to Sentinel Watchlists

## Overview
Security Copilot KQL queries cannot directly write to watchlists. You need an automation layer between the agent and watchlists.

## Solution 1: Logic App Playbook with Sentinel Watchlist Connector (Recommended)

### Step 1: Create Watchlists in Sentinel

First, create your watchlists in Sentinel:

1. Navigate to Sentinel → Configuration → Watchlists
2. Create the following watchlists:

**ComplianceReports_Identity**
- Alias: `ComplianceReports_Identity`
- Search Key: `UserPrincipalName`

**ComplianceReports_Threats**
- Alias: `ComplianceReports_Threats`
- Search Key: `AlertName`

**ComplianceReports_Audit**
- Alias: `ComplianceReports_Audit`
- Search Key: `TimeGenerated`

### Step 2: Create Logic App Playbook

Create a Logic App with these steps:

```
Trigger: Recurrence (Daily at 8 AM)
  ↓
Action: Run KQL Query (via Azure Monitor Logs or Sentinel connector)
  - Workspace: sentinel
  - Query: [Your KQL query from the agent]
  ↓
Action: Parse JSON (Parse query results)
  ↓
Action: For Each (Loop through results)
  ↓
  Action: Add Item to Watchlist (Sentinel Watchlist connector)
    - Watchlist Alias: ComplianceReports_Identity
    - Item Data: JSON from current row
```

### Step 3: Logic App JSON Template

```json
{
  "definition": {
    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
    "actions": {
      "Run_query_and_list_results": {
        "type": "ApiConnection",
        "inputs": {
          "host": {
            "connection": {
              "name": "@parameters('$connections')['azuremonitorlogs']['connectionId']"
            }
          },
          "method": "post",
          "body": "SigninLogs\n| where TimeGenerated > ago(24h)\n| where ResultType != 0\n| summarize FailedAttempts = count(), FirstAttempt = min(TimeGenerated), LastAttempt = max(TimeGenerated) by UserPrincipalName\n| where FailedAttempts >= 5",
          "path": "/queryData",
          "queries": {
            "subscriptions": "dc227dbb-3963-4b6c-be2b-bf29217436d6",
            "resourcegroups": "sentinel",
            "resourcetype": "Log Analytics Workspace",
            "resourcename": "sentinel",
            "timerange": "Set in query"
          }
        }
      },
      "For_each_result": {
        "type": "Foreach",
        "foreach": "@body('Run_query_and_list_results')?['value']",
        "actions": {
          "Watchlists_-_Add_a_new_watchlist_item": {
            "type": "ApiConnection",
            "inputs": {
              "host": {
                "connection": {
                  "name": "@parameters('$connections')['azuresentinel']['connectionId']"
                }
              },
              "method": "put",
              "body": {
                "UserPrincipalName": "@items('For_each_result')?['UserPrincipalName']",
                "FailedAttempts": "@items('For_each_result')?['FailedAttempts']",
                "FirstAttempt": "@items('For_each_result')?['FirstAttempt']",
                "LastAttempt": "@items('For_each_result')?['LastAttempt']",
                "Severity": "High",
                "ControlID": "AC-7|CIS-5.1",
                "Framework": "NIST 800-53|CIS Controls v8"
              },
              "path": "/Watchlists/subscriptions/@{encodeURIComponent('dc227dbb-3963-4b6c-be2b-bf29217436d6')}/resourceGroups/@{encodeURIComponent('sentinel')}/workspaces/@{encodeURIComponent('sentinel')}/watchlists/@{encodeURIComponent('ComplianceReports_Identity')}/watchlistItem"
            }
          }
        }
      }
    },
    "triggers": {
      "Recurrence": {
        "type": "Recurrence",
        "recurrence": {
          "frequency": "Day",
          "interval": 1,
          "schedule": {
            "hours": ["8"]
          }
        }
      }
    }
  },
  "parameters": {
    "$connections": {
      "value": {
        "azuremonitorlogs": {
          "connectionId": "/subscriptions/dc227dbb-3963-4b6c-be2b-bf29217436d6/resourceGroups/sentinel/providers/Microsoft.Web/connections/azuremonitorlogs",
          "connectionName": "azuremonitorlogs",
          "id": "/subscriptions/dc227dbb-3963-4b6c-be2b-bf29217436d6/providers/Microsoft.Web/locations/eastus/managedApis/azuremonitorlogs"
        },
        "azuresentinel": {
          "connectionId": "/subscriptions/dc227dbb-3963-4b6c-be2b-bf29217436d6/resourceGroups/sentinel/providers/Microsoft.Web/connections/azuresentinel",
          "connectionName": "azuresentinel",
          "id": "/subscriptions/dc227dbb-3963-4b6c-be2b-bf29217436d6/providers/Microsoft.Web/locations/eastus/managedApis/azuresentinel"
        }
      }
    }
  }
}
```

## Solution 2: Azure Function with Sentinel API

Create an Azure Function (Python) that:
1. Runs the KQL query via Azure Monitor API
2. Processes results
3. Writes to watchlist via Sentinel REST API

### Python Azure Function Example

```python
import azure.functions as func
import requests
import json
from azure.identity import DefaultAzureCredential
from azure.monitor.query import LogsQueryClient

def main(mytimer: func.TimerRequest) -> None:
    # Get credentials
    credential = DefaultAzureCredential()

    # Query Sentinel/Log Analytics
    client = LogsQueryClient(credential)
    workspace_id = "YOUR_WORKSPACE_ID"

    query = """
    SigninLogs
    | where TimeGenerated > ago(24h)
    | where ResultType != 0
    | summarize FailedAttempts = count() by UserPrincipalName
    | where FailedAttempts >= 5
    """

    response = client.query_workspace(workspace_id, query, timespan="PT24H")

    # Prepare watchlist data
    watchlist_items = []
    for row in response.tables[0].rows:
        item = {
            "UserPrincipalName": row[0],
            "FailedAttempts": row[1],
            "Severity": "High",
            "ControlID": "AC-7|CIS-5.1"
        }
        watchlist_items.append(item)

    # Write to Sentinel Watchlist via REST API
    subscription_id = "dc227dbb-3963-4b6c-be2b-bf29217436d6"
    resource_group = "sentinel"
    workspace_name = "sentinel"
    watchlist_alias = "ComplianceReports_Identity"

    token = credential.get_token("https://management.azure.com/.default").token

    for item in watchlist_items:
        url = f"https://management.azure.com/subscriptions/{subscription_id}/resourceGroups/{resource_group}/providers/Microsoft.OperationalInsights/workspaces/{workspace_name}/providers/Microsoft.SecurityInsights/watchlists/{watchlist_alias}/watchlistItems/{item['UserPrincipalName']}?api-version=2023-02-01"

        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }

        body = {
            "properties": {
                "itemsKeyValue": item
            }
        }

        response = requests.put(url, headers=headers, json=body)
```

## Solution 3: Modify Agent to Output to Custom Table

Instead of watchlists, write to a custom Log Analytics table that acts as a "pseudo-watchlist":

### In your KQL queries, add at the end:

```kql
// Your existing query
SigninLogs
| where TimeGenerated > ago(24h)
| where ResultType != 0
| summarize FailedAttempts = count() by UserPrincipalName
| where FailedAttempts >= 5
// This won't write, but you can reference this table in workbooks
```

Then use the **Data Collection API** to write results:
- Create a Data Collection Endpoint (DCE)
- Create a Data Collection Rule (DCR)
- Create a custom table (e.g., `ComplianceReports_CL`)
- Use HTTP Data Collector API to push data

## Solution 4: Use Sentinel Automation Rules

Create Sentinel Automation Rules that:
1. Trigger when your agent-generated alerts fire
2. Run a playbook to add data to watchlist
3. This is best for incident-driven updates

## Recommended Approach

**For your use case (daily compliance reports):**

Use **Solution 1 (Logic Apps)** because:
- Built-in Sentinel Watchlist connector
- No code required
- Visual designer
- Easy to maintain
- Can schedule multiple playbooks for different reports

## Implementation Steps

1. Create watchlists in Sentinel (via UI)
2. Create Logic App for each report type
3. Use the Sentinel connector's "Add item to watchlist" action
4. Schedule the Logic App to run after your Security Copilot agent executes
5. Map query results to watchlist schema

## Alternative: Direct API Integration from Security Copilot

Unfortunately, Security Copilot agents don't currently support direct API calls to external services. You must use an intermediary automation layer (Logic Apps, Functions, or Playbooks).

## Next Steps

Would you like me to:
1. Create a complete Logic App ARM template for one of your reports?
2. Generate Python Azure Function code for watchlist updates?
3. Create a PowerShell script to bulk-load watchlist data?
