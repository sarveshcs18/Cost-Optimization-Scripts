#!/bin/bash
source variables.env

echo "Deploying Workflow: $WORKFLOW_NAME..."
gcloud workflows deploy ${WORKFLOW_NAME} \
  --source=${WORKFLOW_FILE} \
  --location=${REGION} \
  --project=${PROJECT_ID}

echo "Generating JSON Payloads for Cloud Scheduler..."

# Function to generate payload
generate_payload() {
  local action=$1
  local component=$2
  jq -n \
    --arg project_id "${PROJECT_ID}" \
    --arg region "${REGION}" \
    --arg action "${action}" \
    --arg target_component "${component}" \
    --arg vm_label_key "${VM_LABEL_KEY}" \
    --arg vm_label_value "${VM_LABEL_VALUE}" \
    --argjson gke_targets "${GKE_TARGETS}" \
    '{argument: ({project_id: $project_id, region: $region, action: $action, target_component: $target_component, vm_label_key: $vm_label_key, vm_label_value: $vm_label_value, gke_targets: $gke_targets} | tojson)}'
}

generate_payload "stop" "gke" > stop_gke.json
generate_payload "stop" "vm" > stop_vm.json
generate_payload "start" "vm" > start_vm.json
generate_payload "start" "gke" > start_gke.json

echo "Deploying Cloud Scheduler Jobs for $APP_NAME..."

# 1. GKE Stop
gcloud scheduler jobs update http schd-${APP_NAME}-gke-stop \
    --location="${REGION}" --project="${PROJECT_ID}" --schedule="${GKE_STOP_CRON}" --time-zone="${TIMEZONE}" \
    --message-body-from-file="stop_gke.json" --uri="https://workflowexecutions.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/workflows/${WORKFLOW_NAME}/executions" \
    --oauth-service-account-email="${SERVICE_ACCOUNT}" --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform" || \
gcloud scheduler jobs create http schd-${APP_NAME}-gke-stop \
    --location="${REGION}" --project="${PROJECT_ID}" --schedule="${GKE_STOP_CRON}" --time-zone="${TIMEZONE}" \
    --message-body-from-file="stop_gke.json" --uri="https://workflowexecutions.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/workflows/${WORKFLOW_NAME}/executions" \
    --oauth-service-account-email="${SERVICE_ACCOUNT}" --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform"

# 2. VM Stop
gcloud scheduler jobs update http schd-${APP_NAME}-vm-stop \
    --location="${REGION}" --project="${PROJECT_ID}" --schedule="${VM_STOP_CRON}" --time-zone="${TIMEZONE}" \
    --message-body-from-file="stop_vm.json" --uri="https://workflowexecutions.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/workflows/${WORKFLOW_NAME}/executions" \
    --oauth-service-account-email="${SERVICE_ACCOUNT}" --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform" || \
gcloud scheduler jobs create http schd-${APP_NAME}-vm-stop \
    --location="${REGION}" --project="${PROJECT_ID}" --schedule="${VM_STOP_CRON}" --time-zone="${TIMEZONE}" \
    --message-body-from-file="stop_vm.json" --uri="https://workflowexecutions.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/workflows/${WORKFLOW_NAME}/executions" \
    --oauth-service-account-email="${SERVICE_ACCOUNT}" --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform"

# 3. VM Start
gcloud scheduler jobs update http schd-${APP_NAME}-vm-start \
    --location="${REGION}" --project="${PROJECT_ID}" --schedule="${VM_START_CRON}" --time-zone="${TIMEZONE}" \
    --message-body-from-file="start_vm.json" --uri="https://workflowexecutions.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/workflows/${WORKFLOW_NAME}/executions" \
    --oauth-service-account-email="${SERVICE_ACCOUNT}" --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform" || \
gcloud scheduler jobs create http schd-${APP_NAME}-vm-start \
    --location="${REGION}" --project="${PROJECT_ID}" --schedule="${VM_START_CRON}" --time-zone="${TIMEZONE}" \
    --message-body-from-file="start_vm.json" --uri="https://workflowexecutions.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/workflows/${WORKFLOW_NAME}/executions" \
    --oauth-service-account-email="${SERVICE_ACCOUNT}" --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform"

# 4. GKE Start
gcloud scheduler jobs update http schd-${APP_NAME}-gke-start \
    --location="${REGION}" --project="${PROJECT_ID}" --schedule="${GKE_START_CRON}" --time-zone="${TIMEZONE}" \
    --message-body-from-file="start_gke.json" --uri="https://workflowexecutions.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/workflows/${WORKFLOW_NAME}/executions" \
    --oauth-service-account-email="${SERVICE_ACCOUNT}" --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform" || \
gcloud scheduler jobs create http schd-${APP_NAME}-gke-start \
    --location="${REGION}" --project="${PROJECT_ID}" --schedule="${GKE_START_CRON}" --time-zone="${TIMEZONE}" \
    --message-body-from-file="start_gke.json" --uri="https://workflowexecutions.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/workflows/${WORKFLOW_NAME}/executions" \
    --oauth-service-account-email="${SERVICE_ACCOUNT}" --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform"

echo "Cleaning up temporary payload files..."
rm stop_gke.json stop_vm.json start_vm.json start_gke.json
echo "Deployment Complete for $APP_NAME!"
