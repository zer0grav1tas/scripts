#!/bin/bash

TENANT_ID="your-tenant-id"
CLIENT_ID="your-client-id"
CLIENT_SECRET="your-client-secret"
GRAPH_ENDPOINT="query-uri"

TOKEN=$(curl -X POST https://login.microsoftonline.com/0$TENANT_ID/oauth2/v2.0/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=https://graph.microsoft.com/.default" \
  -d "grant_type=client_credentials")

ACCESS_TOKEN=$(echo $TOKEN | jq -r '.access_token')

curl -X GET $GRAPH_ENDPOINT \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json"

# e.g. Query to get Entra ID App Registrations

# TENANT_ID="1234-1234-1234-1234"
# CLIENT_ID="1234-1234-1234-1234"
# CLIENT_SECRET="abcdefghijklmnop"
# GRAPH_ENDPOINT="https://graph.microsoft.com/v1.0/applications?$select=id,displayName,passwordCredentials,keyCredentials"