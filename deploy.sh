#!/bin/bash
source variables.env

echo "Deploying Workflow: $WORKFLOW_NAME..."
gcloud workflows deploy "${WORKFLOW_NAME}" \
  --source="${WORKFLOW_FILE}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}"

echo "Generating JSON Payloads for Cloud Scheduler..."

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

deploy_scheduler_job() {
  local job_name=$1
  local cron_schedule=$2
  local payload_file=$3
  local uri="https://workflowexecutions.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/workflows/${WORKFLOW_NAME}/executions"

  echo "Configuring Scheduler Job: ${job_name}..."

  if gcloud scheduler jobs describe "${job_name}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    gcloud scheduler jobs update http "${job_name}" \
      --location="${REGION}" \
      --project="${PROJECT_ID}" \
      --schedule="${cron_schedule}" \
      --time-zone="${TIMEZONE}" \
      --uri="${uri}" \
      --message-body-from-file="${payload_file}" \
      --oauth-service-account-email="${SERVICE_ACCOUNT}" \
      --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform" \
      --quiet
  else
    gcloud scheduler jobs create http "${job_name}" \
      --location="${REGION}" \
      --project="${PROJECT_ID}" \
      --schedule="${cron_schedule}" \
      --time-zone="${TIMEZONE}" \
      --uri="${uri}" \
      --message-body-from-file="${payload_file}" \
      --oauth-service-account-email="${SERVICE_ACCOUNT}" \
      --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform" \
      --quiet
  fi
}

echo "Deploying Cloud Scheduler Jobs for ${APP_NAME}..."

deploy_scheduler_job "schd-${APP_NAME}-gke-stop" "${GKE_STOP_CRON}" "stop_gke.json"
deploy_scheduler_job "schd-${APP_NAME}-vm-stop" "${VM_STOP_CRON}" "stop_vm.json"
deploy_scheduler_job "schd-${APP_NAME}-vm-start" "${VM_START_CRON}" "start_vm.json"
deploy_scheduler_job "schd-${APP_NAME}-gke-start" "${GKE_START_CRON}" "start_gke.json"

echo "Cleaning up temporary payload files..."
rm stop_gke.json stop_vm.json start_vm.json start_gke.json

echo "Deployment Complete for ${APP_NAME}!"
