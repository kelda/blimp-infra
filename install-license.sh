#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 || "$1" = "--help" ]]; then
	echo "usage: $0 LICENSE_PATH [KUBECTL_CONTEXT]"
	exit 1
fi

license_path="$1"
kubectl_context=""
if [[ $# -eq 2 ]]; then
	kubectl_context="$2"
fi

function _kubectl() {
	if [[ -n "$kubectl_context" ]]; then
		kubectl --context "$kubectl_context" "$@"
	else
		kubectl "$@"
	fi
}

# Make sure namespace exists before creating secret.
_kubectl apply -f manager/0_namespace.yaml

# Use kubectl apply so that if a license already exists in the cluster, this
# will replace it will the new one cleanly.
_kubectl create secret -n manager generic license \
		 --from-file=license="${license_path}" \
		 --dry-run=client -o yaml | kubectl apply -f -
