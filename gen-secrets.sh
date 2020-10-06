#!/bin/bash
set -euo pipefail

function make_cert () {
	# Note: we just issue all certs to localhost, since we want to be flexible
	# about DNS.
	description="$1"
	cert_path="$2"
	key_path="$3"

	config="$(mktemp)"

	cat > "${config}" <<-EOF
[req]
prompt = no
distinguished_name = dn

[dn]
C=US
ST=California
L=Berkeley
O=Kelda Inc
OU=Kelda Blimp ${description}
CN=localhost

[ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
EOF

	openssl req \
			-x509 \
			-newkey rsa:4096 \
			-keyout "${key_path}" \
			-out "${cert_path}" \
			-days 365 \
			-nodes \
			-extensions ext \
			-config "${config}"

	rm "${config}"
}

function gen_token () {
	length="$1"

	# Restrict the token the alphanumerical characters to avoid any encoding
	# issues.
	cat /dev/urandom | tr -dc a-zA-Z0-9 | head -c "${length}"
}

cd "$(dirname "$0")"

mkdir -p secrets

make_cert "Manager" secrets/manager.crt.pem secrets/manager.key.pem

gen_token 32 > secrets/cluster-auth-token
