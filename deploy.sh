#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 || "$1" = "--help" ]]; then
	echo "usage: $0 REGISTRY_HOSTNAME [KUBECTL_CONTEXT]"
	exit 1
fi

image_registry="gcr.io/kelda-blimp"
blimp_version="0.13.33"
registry_hostname="$1"
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

templates=()
function template() {
	file="$1"
	shift
	sed "$@" "${file}.tmpl" > "${file}"
	templates+=("$file")
}
function cleanup_templates() {
	for file in "${templates[@]}"; do
		rm "$file"
	done
}
trap cleanup_templates EXIT

cd "$(dirname "$0")"

## Manager
if _kubectl get secret -n manager manager-certs > /dev/null; then
	echo "Using manager certs already present in cluster."
elif [[ -f certs/manager.crt.pem && -f certs/manager.key.pem ]]; then
	# Make sure the namespace exists.
	_kubectl apply -f manager/0_namespace.yaml
	_kubectl create secret -n manager generic manager-certs \
		--from-file=cert.pem=certs/manager.crt.pem,key.pem=certs/manager.key.pem
else
	echo "Manager certs not found. Please generate certs (./gen-certs.sh) and try again."
	exit 1
fi

manager_sed="s|<CLUSTER_MANAGER_IMAGE>|${image_registry}/blimp-cluster-controller:${blimp_version}|;s|<DOCKER_REPO>|${image_registry}|;s|<REGISTRY_HOSTNAME>|${registry_hostname}|;s|<USE_NODE_PORT>|${USE_NODE_PORT:-false}|"
if _kubectl get secret -n manager license > /dev/null; then
	echo "Using installed license."
	template manager/manager-deployment-licensed.yaml "${manager_sed}"
else
	template manager/manager-deployment.yaml "${manager_sed}"
fi
_kubectl apply -f manager/

## Registry
template registry/registry-deployment.yaml "s|<REGISTRY_HOSTNAME>|${registry_hostname}|;s|<DOCKER_AUTH_IMAGE>|${image_registry}/blimp-docker-auth:${blimp_version}|"
_kubectl apply -f registry/
