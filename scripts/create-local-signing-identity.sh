#!/bin/zsh
set -euo pipefail

IDENTITY_NAME="YuJi Local Code Signing"
KEYCHAIN=$(security default-keychain -d user | sed -E 's/^[[:space:]]*"//; s/"[[:space:]]*$//')
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/yuji-signing.XXXXXX")
PASSWORD=$(openssl rand -hex 24)

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if security find-certificate -c "$IDENTITY_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "签名证书已存在：$IDENTITY_NAME"
  security find-identity -v -p codesigning "$KEYCHAIN"
  exit 0
fi

cat > "$TEMP_DIR/openssl.cnf" <<'EOF'
[req]
distinguished_name = subject
x509_extensions = extensions
prompt = no

[subject]
CN = YuJi Local Code Signing
O = YuJi Local Development

[extensions]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
EOF

openssl req -x509 -newkey rsa:3072 -nodes -days 3650 \
  -config "$TEMP_DIR/openssl.cnf" \
  -keyout "$TEMP_DIR/private-key.pem" \
  -out "$TEMP_DIR/certificate.pem" >/dev/null 2>&1

openssl pkcs12 -export \
  -inkey "$TEMP_DIR/private-key.pem" \
  -in "$TEMP_DIR/certificate.pem" \
  -name "$IDENTITY_NAME" \
  -passout "pass:$PASSWORD" \
  -out "$TEMP_DIR/identity.p12"

security import "$TEMP_DIR/identity.p12" \
  -k "$KEYCHAIN" \
  -P "$PASSWORD" \
  -T /usr/bin/codesign >/dev/null

security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TEMP_DIR/certificate.pem"

echo "已创建本机稳定签名身份：$IDENTITY_NAME"
security find-identity -v -p codesigning "$KEYCHAIN"
