#!/usr/bin/env bash
# Importa certificado .p12 y perfil de aprovisionamiento desde variables de entorno.
# Uso en CI: secrets IOS_CERTIFICATE_P12_BASE64 + IOS_CERTIFICATE_PASSWORD + IOS_PROVISIONING_PROFILE_BASE64
set -euo pipefail

: "${IOS_CERTIFICATE_P12_BASE64:?Falta IOS_CERTIFICATE_P12_BASE64}"
: "${IOS_CERTIFICATE_PASSWORD:?Falta IOS_CERTIFICATE_PASSWORD}"
: "${IOS_PROVISIONING_PROFILE_BASE64:?Falta IOS_PROVISIONING_PROFILE_BASE64}"

KEYCHAIN="$RUNNER_TEMP/build.keychain"
CERT_PATH="$RUNNER_TEMP/cert.p12"
PROFILE_PATH="$RUNNER_TEMP/profile.mobileprovision"
PROFILE_PLIST="$RUNNER_TEMP/profile.plist"

echo "Creando keychain temporal…"
security create-keychain -p "" "$KEYCHAIN"
security default-keychain -s "$KEYCHAIN"
security unlock-keychain -p "" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"

echo "Importando certificado .p12…"
echo -n "$IOS_CERTIFICATE_P12_BASE64" | base64 -D -o "$CERT_PATH"
security import "$CERT_PATH" -P "$IOS_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN"

echo "Instalando perfil de aprovisionamiento…"
echo -n "$IOS_PROVISIONING_PROFILE_BASE64" | base64 -D -o "$PROFILE_PATH"
security cms -D -i "$PROFILE_PATH" > "$PROFILE_PLIST"

PROFILE_UUID=$(/usr/libexec/PlistBuddy -c 'Print UUID' "$PROFILE_PLIST")
PROFILE_NAME=$(/usr/libexec/PlistBuddy -c 'Print Name' "$PROFILE_PLIST")
TEAM_ID=$(/usr/libexec/PlistBuddy -c 'Print TeamIdentifier:0' "$PROFILE_PLIST")
APP_ID=$(/usr/libexec/PlistBuddy -c 'Print Entitlements:application-identifier' "$PROFILE_PLIST" | sed 's/.*\.//')

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$PROFILE_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/${PROFILE_UUID}.mobileprovision"

SIGN_IDENTITY=$(security find-identity -v -p codesigning "$KEYCHAIN" | grep -E 'Apple (Development|Distribution)' | head -n 1 | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+([^"]+).*/\1/')

if [ -z "$SIGN_IDENTITY" ]; then
  echo "ERROR: no se encontró identidad de firma en el keychain"
  security find-identity -v -p codesigning "$KEYCHAIN"
  exit 1
fi

echo "sign_identity=$SIGN_IDENTITY" >> "$GITHUB_OUTPUT"
echo "team_id=$TEAM_ID" >> "$GITHUB_OUTPUT"
echo "profile_uuid=$PROFILE_UUID" >> "$GITHUB_OUTPUT"
echo "profile_name=$PROFILE_NAME" >> "$GITHUB_OUTPUT"
echo "bundle_id=$APP_ID" >> "$GITHUB_OUTPUT"

echo "Firma lista: $SIGN_IDENTITY | Team $TEAM_ID | Perfil $PROFILE_NAME"
