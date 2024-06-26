#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" 

# acs-image-scan
source $SCRIPTDIR/common.sh

# Top level parameters 
export ACS_IMAGE_SCAN_PARAM_ROX_SECRET_NAME=
export ACS_IMAGE_SCAN_PARAM_IMAGE=
export ACS_IMAGE_SCAN_PARAM_IMAGE_DIGEST=
export ACS_IMAGE_SCAN_PARAM_INSECURE_SKIP_TLS_VERIFY=



function rox-image-scan() {
	echo "Running $TASK_NAME:rox-image-scan"
	#!/usr/bin/env bash
	set +x
	
	function set_test_output_result() {
	  local date=$(date +%s)
	  local result=${1:-ERROR}
	  local note=$2
	  local successes=${3:-0}
	  local failures=${4:-0}
	  local warnings=${5:-0}
	  echo "{\"result\":\"${result}\",\"timestamp\":\"${date}\",\"note\":\"${note}\",\"namespace\":\"default\",\"successes\":\"${successes}\",\"failures\":\"${failures}\",\"warnings\":\"${warnings}\"}" \
	    | tee $RESULTS/TEST_OUTPUT
	}
	
	# Check if rox API enpoint is configured
	if [ -z "$ROX_API_TOKEN" ]; then
		echo "ROX_API_TOKEN is not set, demo will exit with success"
		exit 0
	fi
	if [ -z "$ROX_CENTRAL_ENDPOINT" ]; then
		echo "ROX_CENTRAL_ENDPOINT is not set, demo will exit with success"
		exit 0
	fi
	
	echo "Using rox central endpoint ${ROX_CENTRAL_ENDPOINT}"
	
	echo "Download roxctl cli"
	if [ "${PARAM_INSECURE_SKIP_TLS_VERIFY}" = "true" ] ; then
	  curl_insecure='--insecure'
	fi
	curl $curl_insecure -s -L -H "Authorization: Bearer $ROX_API_TOKEN" \
	  "https://${ROX_CENTRAL_ENDPOINT}/api/cli/download/roxctl-linux" \
	  --output ./roxctl  \
	  > /dev/null
	if [ $? -ne 0 ]; then
	  note='Failed to download roxctl'
	  echo $note
	  set_test_output_result ERROR "$note"
	  exit 1
	fi
	chmod +x ./roxctl  > /dev/null
	
	echo "roxctl image scan"
	
	IMAGE=${PARAM_IMAGE}@${PARAM_IMAGE_DIGEST}
	./roxctl image scan \
	  $( [ "${PARAM_INSECURE_SKIP_TLS_VERIFY}" = "true" ] && \
	  echo -n "--insecure-skip-tls-verify") \
	  -e "${ROX_CENTRAL_ENDPOINT}" --image "$IMAGE" --output json --force \
	  > roxctl_image_scan_output.json
	image_scan_err_code=$?
	cp roxctl_image_scan_output.json /steps-shared-folder/acs-image-scan.json
	if [ $image_scan_err_code -ne 0 ]; then
	  cat roxctl_image_scan_output.json
	  note='ACS image scan failed to process the image. See the task logs for more details.'
	  echo $note
	  set_test_output_result ERROR "$note"
	  exit 2
	fi
	
	# Set SCAN_OUTPUT result
	critical=$(cat roxctl_image_scan_output.json | grep -oP '(?<="CRITICAL": )\d+')
	high=$(cat roxctl_image_scan_output.json | grep -oP '(?<="IMPORTANT": )\d+')
	medium=$(cat roxctl_image_scan_output.json | grep -oP '(?<="MODERATE": )\d+')
	low=$(cat roxctl_image_scan_output.json | grep -oP '(?<="LOW": )\d+')
	echo "{\"vulnerabilities\":{\"critical\":${critical},\"high\":${high},\"medium\":${medium},\"low\":${low}}}" | tee $RESULTS/SCAN_OUTPUT
	
	# Set TEST_OUTPUT result
	if [[ -n "$critical" && "$critical" -eq 0 && "$high" -eq 0 && "$medium" -eq 0 && "$low" -eq 0 ]]; then
	  note="Task $(context.task.name) completed. No vulnerabilities found."
	else
	  note="Task $(context.task.name) completed: Refer to Tekton task result SCAN_OUTPUT for found vulnerabilities."
	fi
	set_test_output_result SUCCESS "$note"
	
}

function report() {
	echo "Running $TASK_NAME:report"
	#!/usr/bin/env bash
	cat /steps-shared-folder/acs-image-scan.json
	
}

# Task Steps 
rox-image-scan
report
