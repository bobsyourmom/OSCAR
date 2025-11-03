#!/usr/bin/env python3
import json
import requests
import datetime
import hashlib
import hmac
import base64

# Build the API signature
def build_signature(customer_id, shared_key, date, content_length, method, content_type, resource):
    x_headers = 'x-ms-date:' + date
    string_to_hash = method + "\n" + str(content_length) + "\n" + content_type + "\n" + x_headers + "\n" + resource
    bytes_to_hash = bytes(string_to_hash, encoding="utf-8")
    decoded_key = base64.b64decode(shared_key)
    encoded_hash = base64.b64encode(hmac.new(decoded_key, bytes_to_hash, digestmod=hashlib.sha256).digest()).decode()
    authorization = "SharedKey {}:{}".format(customer_id, encoded_hash)
    return authorization

# Build and send a request to the POST API
def post_data(customer_id, shared_key, body, log_type):
    method = 'POST'
    content_type = 'application/json'
    resource = '/api/logs'
    rfc1123date = datetime.datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')
    content_length = len(body)
    signature = build_signature(customer_id, shared_key, rfc1123date, content_length, method, content_type, resource)
    uri = 'https://' + customer_id + '.ods.opinsights.azure.com' + resource + '?api-version=2016-04-01'

    headers = {
        'content-type': content_type,
        'Authorization': signature,
        'Log-Type': log_type,
        'x-ms-date': rfc1123date
    }

    response = requests.post(uri, data=body, headers=headers)
    if (response.status_code >= 200 and response.status_code <= 299):
        print('Accepted - Status Code: {}'.format(response.status_code))
    else:
        print("Response code: {}".format(response.status_code))
        print("Response: {}".format(response.text))

# Test data matching what Security Copilot returns (single object, not array)
test_data = {
    "Technique": "N/A",
    "Tactics": "N/A",
    "AlertCount": 0,
    "FirstSeen": "2025-11-02T16:23:51.6581837Z",
    "LastSeen": "2025-11-02T16:23:51.6581837Z",
    "Severities": "[]",
    "AffectedEntities": "[]",
    "Severity": "Informational",
    "ControlID": "RS.AN-01|SI-4",
    "Framework": "NIST CSF 2.0|NIST 800-53",
    "QueryDomain": "threat",
    "ReportType": "Threat",
    "ReportName": "MITREAttackReport-Test",
    "FindingType": "No Findings",
    "RemediationRequired": "No",
    "Status": "Completed"
}

# Get workspace key
import subprocess
workspace_key = subprocess.check_output([
    'az', 'monitor', 'log-analytics', 'workspace', 'get-shared-keys',
    '--resource-group', 'sentinel',
    '--workspace-name', 'sentinel',
    '--query', 'primarySharedKey',
    '-o', 'tsv'
]).decode().strip()

customer_id = '5b9c5252-9f87-4414-bdf8-ec380894c24c'
log_type = 'ComplianceReports'

body = json.dumps(test_data)
print(f"Sending test data to Log Analytics...")
print(f"Data: {body}")
post_data(customer_id, workspace_key, body, log_type)
