#!/bin/bash
source variables.env

echo "Deploying Workflow: $WORKFLOW_NAME..."
gcloud workflows deploy ${WORKFLOW_NAME} \
  --source=${WORKFLOW_FILE} \
  --location=${REGION} \
  --project=${PROJECT_ID}

echo "Generating JSON Payloads for Cloud Scheduler..."
# GKE_TARGETS is explicitly not wrapped in quotes to pass as a JSON array
cat <<EOF > stop_payload.json
{
  "project_id": "${PROJECT_ID}",
  "region": "${REGION}",
  "action": "stop",
  "vm_label_key": "${VM_LABEL_KEY}",
  "vm_label_value": "${VM_LABEL_VALUE}",
  "gke_targets": ${GKE_TARGETS}
}
EOF

cat <<EOF > start_payload.json
{
  "project_id": "${PROJECT_ID}",
  "region": "${REGION}",
  "action": "start",
  "vm_label_key": "${VM_LABEL_KEY}",
  "vm_label_value": "${VM_LABEL_VALUE}",
  "gke_targets": ${GKE_TARGETS}
}
EOF

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
