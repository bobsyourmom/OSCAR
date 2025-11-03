#!/usr/bin/env python3
import json
import requests
import datetime
import hmac
import hashlib
import base64
import sys

workspace_id = "5b9c5252-9f87-4414-bdf8-ec380894c24c"
shared_key = sys.argv[1]
log_type = "ComplianceReports"

body = json.dumps([
  {
    "TimeGenerated": datetime.datetime.utcnow().isoformat() + "Z",
    "ReportType": "Identity",
    "ReportName": "FailedAuthenticationReport",
    "ControlID": "AC-7|CIS-5.1",
    "Framework": "NIST 800-53|CIS Controls v8",
    "QueryDomain": "identity",
    "Severity": "High",
    "FindingType": "Failed Authentication",
    "RemediationRequired": "Yes",
    "Status": "New",
    "UserPrincipalName": "test.user@example.com",
    "Count": 15,
    "Description": "Test record to verify ingestion"
  }
])

method = 'POST'
content_type = 'application/json'
resource = '/api/logs'
rfc1123date = datetime.datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')
content_length = len(body)
signature = method + "\n" + str(content_length) + "\n" + content_type + "\nx-ms-date:" + rfc1123date + "\n" + resource
bytes_to_hash = bytes(signature, encoding="utf-8")
decoded_key = base64.b64decode(shared_key)
encoded_hash = base64.b64encode(hmac.new(decoded_key, bytes_to_hash, digestmod=hashlib.sha256).digest()).decode()
authorization = "SharedKey {}:{}".format(workspace_id, encoded_hash)

uri = 'https://' + workspace_id + '.ods.opinsights.azure.com' + resource + '?api-version=2016-04-01'

headers = {
    'content-type': content_type,
    'Authorization': authorization,
    'Log-Type': log_type,
    'x-ms-date': rfc1123date
}

response = requests.post(uri, data=body, headers=headers)
print(f"Response: {response.status_code}")
if response.status_code == 200:
    print("✓ Data sent successfully to ComplianceReports_CL table!")
    print("Wait 2-5 minutes, then query in Sentinel:")
    print("ComplianceReports_CL | where TimeGenerated > ago(10m) | take 10")
else:
    print(f"✗ Error: {response.text}")
    sys.exit(1)
