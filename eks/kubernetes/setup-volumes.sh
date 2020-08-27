#!/bin/bash
set -euo pipefail

if [[ $# -eq 1 ]]; then
	if [[ $1 == "--help" ]]; then
		echo "usage: $0 [kubecontext]"
		exit 1
	fi

	context="$1"
else
	context="$(kubectl config current-context)"
fi

function _kubectl() {
    kubectl --context "$context" "$@"
}

# Unset sc gp2 as default so we can set our own.
_kubectl patch storageclass gp2 -p '{
  "metadata": {
    "annotations": {
      "storageclass.kubernetes.io/is-default-class": "false"
    }
  }
}'

# Add our new default storageclass.
_kubectl apply -f ebs-storageclass.yaml
