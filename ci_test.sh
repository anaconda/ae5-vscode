#!/bin/bash

set -euo pipefail
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})
cd ${SCRIPT_DIR}

# We need to trim leading zeros from each version component without removing zero itself
expected_version=$(sed -nE 's@.*/code-server-([^-]*)-linux-amd64.tar.gz@\1@p' MANIFEST)
# This is a substring on purpose; the actual string is ~/anaconda/envs/default/bin/python
expected_env=/envs/default/
container_name=ae5-vscode-test

if [ -d /opt/continuum/anaconda/conda-meta ]; then

	# Inside the container: download VSCode and install it
	err_exit() { echo "-- FAILED --"; exit 1; }
	if [ "$SCRIPT_DIR" = "/testing" ]; then
		cp -a /testing /tmp/ae5-vscode
		cd /tmp/ae5-vscode
	fi
	export TOOL_PROJECT_URL=@ TOOL_HOST=@ TOOL_PORT=8086 TOOL_ADDRESS=0.0.0.0
	echo ""
	bash download_vscode.sh 2>&1
	echo ""
	bash install_vscode.sh 2>&1
	echo ""
	mkdir -p /opt/continuum/project
	cp -r test_project/* /opt/continuum/project/
	cd /opt/continuum/project
	source /opt/continuum/anaconda/etc/profile.d/conda.sh
	conda activate base
	export ANACONDA_PROJECT_ENVS_PATH=/opt/continuum/anaconda/envs
	anaconda-project prepare
	echo ""
	touch ~/prepare.log
	bash /tools/vscode/start_vscode.sh 2>&1
	exit 0

fi

# Only one container can run at a time
if [ -n "$(docker ps -aq -f name="^${container_name}$")" ]; then
	echo "Container $container_name is already running" 1>&2
	exit 1
fi

# Query GitHub for the latest production container version
if [ -z "${IMAGE_VER:-}" ]; then
	# This is a bit of a hack 
	IMAGE_VER=$(curl -s -u "_json_key:$AE_GCR_KEY" \
		https://gcr.io/v2/continuum-compute/ae-editor-base/tags/list | \
		jq -r '.tags[]' | tail -1 | sed -E 's@-(arm64|amd64)@@' || :)
	if [ -z "$IMAGE_VER" ]; then
		echo "Could not determine ae-editor-base image version" 1>&2
		exit -1
	fi
fi
image_name=gcr.io/continuum-compute/ae-editor-base:${IMAGE_VER} 
if [ -n "${GITHUB_OUTPUT:-}" ]; then
	echo "image_ver=${IMAGE_VER}" >> "$GITHUB_OUTPUT"
	echo "expected_version=${expected_version}" >> "$GITHUB_OUTPUT"
fi

# Launch the container in detach mode but give it a name we can track
container_cleanup() { 
	docker stop "$container_name" >/dev/null 2>&1 || :
	docker rm "$container_name" >/dev/null 2>&1 || :
}
trap container_cleanup EXIT
cmd=(docker pull "$image_name")
echo "> ${cmd[*]}"
"${cmd[@]}" >/dev/null
cmd=(docker run --detach --name "$container_name" \
	 --publish 8086:8086 --env TOOL_OWNER=$USER --env TOOL_PACKAGE=bash \
	 --tmpfs /tools:exec -v "${SCRIPT_DIR}:/testing:ro" \
	 "$image_name" bash /testing/${SCRIPT_NAME})
echo "> ${cmd[*]}"
"${cmd[@]}" >/dev/null
docker ps --all --no-trunc | grep -E "${container_name}$" || :
echo ""

# Scan the logs of the container until 1) the container dies;
# 2) it emits the "-- FAILED --" error; or 3) it emits a line
# from start_vscode.sh indicating VSCode is running. In that
# last case, capture the timestamp so that we can print the rest
# of the logs after the capture attempt.
timestamp=
while IFS= read -r line; do
	echo "${line#* }"
	case "$line" in
	*"- FAILED -"*) break ;;
	*"- END: AE5 VSCode Launcher -"*) timestamp="${line%% *}"; break ;;
	esac
done < <(docker logs "$container_name" --follow --timestamps)

if [ -z "$timestamp" ]; then
	echo "VSCode failed to stabilize" 1>&2
	exit 1
fi

# Use the playwright script to bring up VSCode, query the VSCode version
# and the Python environment, and compare it against expectation. To keep the Docker logs
# continuous we're capturing the node output in a variable, grabbing the rest of the
# logs, and then we'll print the output of the attempt.
capture_attempt=$(node capture.mjs "$expected_version" "$expected_env" 1>&2 && echo "@@success@@" || :)

docker logs "$container_name" --since="$timestamp" | sed 1d

echo "${capture_attempt%*@@success@@}"
[[ "$capture_attempt" = *"@@success@@" ]] || exit 1
