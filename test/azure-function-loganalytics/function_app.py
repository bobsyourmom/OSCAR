import azure.functions as func
import logging
import json
import datetime
import hashlib
import hmac
import base64
import requests
import os

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

def build_signature(customer_id, shared_key, date, content_length, method, content_type, resource):
    x_headers = 'x-ms-date:' + date
    string_to_hash = method + "\n" + str(content_length) + "\n" + content_type + "\n" + x_headers + "\n" + resource
    bytes_to_hash = bytes(string_to_hash, encoding="utf-8")
    decoded_key = base64.b64decode(shared_key)
    encoded_hash = base64.b64encode(hmac.new(decoded_key, bytes_to_hash, digestmod=hashlib.sha256).digest()).decode()
    authorization = "SharedKey {}:{}".format(customer_id, encoded_hash)
    return authorization

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
    return response

@app.route(route="SendToLogAnalytics")
def SendToLogAnalytics(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    try:
        req_body = req.get_json()
    except ValueError:
        return func.HttpResponse(
             "Invalid JSON",
             status_code=400
        )

    workspace_id = os.environ.get('WORKSPACE_ID', '5b9c5252-9f87-4414-bdf8-ec380894c24c')
    workspace_key = os.environ.get('WORKSPACE_KEY')

    if not workspace_key:
        return func.HttpResponse(
             "WORKSPACE_KEY environment variable not set",
             status_code=500
        )

    log_type = 'ComplianceReports'
    body = json.dumps(req_body)

    response = post_data(workspace_id, workspace_key, body, log_type)

    if response.status_code >= 200 and response.status_code <= 299:
        return func.HttpResponse(
            json.dumps({"status": "success", "message": "Data sent to Log Analytics"}),
            status_code=200,
            mimetype="application/json"
        )
    else:
        return func.HttpResponse(
            json.dumps({"status": "error", "message": response.text}),
            status_code=response.status_code,
            mimetype="application/json"
        )
