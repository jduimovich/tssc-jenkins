#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" 

# acs-image-check
source $SCRIPTDIR/common.sh

# Top level parameters 
export ROX_CENTRAL_ENDPOINT=
export ROX_API_TOKEN=
export ACS_DEPLOY_CHECK_PARAM_VERBOSE=
export PARAM_INSECURE_SKIP_TLS_VERIFY=true

export PARAM_GITOPS_REPO_URL=

function rox-image-check() {
	echo "Running $TASK_NAME:rox-image-check"
	#!/usr/bin/env bash
	set +x

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
	if [ "${PARAM_INSECURE_SKIP_TLS_VERIFY}" = "true" ]; then
	  curl_insecure='--insecure'
	fi
	curl $curl_insecure -s -L -H "Authorization: Bearer $ROX_API_TOKEN" \
	  "https://${ROX_CENTRAL_ENDPOINT}/api/cli/download/roxctl-linux" \
	  --output ./roxctl \
	  > /dev/null
	if [ $? -ne 0 ]; then
	  echo 'Failed to download roxctl'
	  exit 1
	fi
	received_filesize=$(stat -c%s ./roxctl)
	if (( $received_filesize < 10000 )); then
	  # Responce from ACS server is not a binary but error message
	  cat ./roxctl
	  echo 'Failed to download roxctl'
	  exit 2
	fi
	chmod +x ./roxctl  > /dev/null
	
	echo "roxctl image check"
	IMAGE=${PARAM_IMAGE}@${PARAM_IMAGE_DIGEST}
	./roxctl image check \
	  $( [ "${PARAM_INSECURE_SKIP_TLS_VERIFY}" = "true" ] && \
	  echo -n "--insecure-skip-tls-verify") \
	  -e "${ROX_CENTRAL_ENDPOINT}" --image "$IMAGE" --output json --force \
	  > roxctl_image_check_output.json
	cp roxctl_image_check_output.json /steps-shared-folder/acs-image-check.json
	
}

function report() {
	echo "Running $TASK_NAME:report"
	#!/usr/bin/env bash
	cat /steps-shared-folder/acs-image-check.json
	
}

# Task Steps 
rox-image-check
report
