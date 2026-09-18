#!/bin/bash
source variables.env

echo "Deploying Workflow: $WORKFLOW_NAME..."
gcloud workflows deploy ${WORKFLOW_NAME} \
  --source=${WORKFLOW_FILE} \
  --location=${REGION} \
  --project=${PROJECT_ID}

echo "Generating JSON Payloads for Cloud Scheduler..."

# Use jq to construct the JSON, stringify it, and wrap it in the 'argument' field
jq -n \
  --arg project_id "${PROJECT_ID}" \
  --arg region "${REGION}" \
  --arg action "stop" \
  --arg vm_label_key "${VM_LABEL_KEY}" \
  --arg vm_label_value "${VM_LABEL_VALUE}" \
  --argjson gke_targets "${GKE_TARGETS}" \
  '{argument: ({project_id: $project_id, region: $region, action: $action, vm_label_key: $vm_label_key, vm_label_value: $vm_label_value, gke_targets: $gke_targets} | tojson)}' > stop_payload.json

jq -n \
  --arg project_id "${PROJECT_ID}" \
  --arg region "${REGION}" \
  --arg action "start" \
  --arg vm_label_key "${VM_LABEL_KEY}" \
  --arg vm_label_value "${VM_LABEL_VALUE}" \
  --argjson gke_targets "${GKE_TARGETS}" \
  '{argument: ({project_id: $project_id, region: $region, action: $action, vm_label_key: $vm_label_key, vm_label_value: $vm_label_value, gke_targets: $gke_targets} | tojson)}' > start_payload.json

echo "Updating STOP Scheduler Job..."
gcloud scheduler jobs update http infra-cost-optimizer-stop \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --message-body-from-file="stop_payload.json" \
    --oauth-service-account-email="${SERVICE_ACCOUNT}" \
    --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform"

echo "Updating START Scheduler Job..."
gcloud scheduler jobs update http infra-cost-optimizer-start \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --message-body-from-file="start_payload.json" \
    --oauth-service-account-email="${SERVICE_ACCOUNT}" \
    --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform"

echo "Cleaning up temporary payload files..."
rm stop_payload.json start_payload.json

echo "Deployment Complete!"
