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

cd "$(dirname "$0")"

./setup-volumes.sh "$context"

# Install CNI.
# First, delete the default EKS VPC CNI
_kubectl -n kube-system delete --ignore-not-found=true daemonset aws-node
# Install Cilium from helm. If this isn't working, check README and make sure
# you added the helm repo.
cilium_helm_args=(
	--kube-context "$context"
	--namespace cni-cilium
	--version 1.8.2
	-f cilium-helm-values.yaml
)
# Don't run helm upgrade if there aren't changes.
if ! helm diff upgrade cilium cilium/cilium \
	--detailed-exitcode \
	"${cilium_helm_args[@]}"
then
	helm upgrade cilium cilium/cilium \
		--install --create-namespace \
		"${cilium_helm_args[@]}
"
else
	echo "Cilium helm deployment unchanged."
fi
