#!/usr/bin/env bash
# Creates the Play Store upload keystore and android/key.properties.
# Why a script: the password is typed by the developer and never stored in
# code, chat or git. Both output files are gitignored (mobile/android/.gitignore).
# BACK UP the .jks and the password: losing them means you cannot update the app.
set -euo pipefail

ANDROID_DIR="$(cd "$(dirname "$0")/../android" && pwd)"
JKS="$ANDROID_DIR/app/upload-keystore.jks"
PROPS="$ANDROID_DIR/key.properties"
ALIAS="upload"

if [ -f "$JKS" ]; then
  echo "Keystore already exists at $JKS. Not overwriting." >&2
  exit 1
fi

read -r -s -p "Choose keystore password (min 6 chars): " PW; echo
read -r -s -p "Repeat password: " PW2; echo
if [ "$PW" != "$PW2" ] || [ ${#PW} -lt 6 ]; then
  echo "Passwords do not match or are shorter than 6 characters." >&2
  exit 1
fi

keytool -genkeypair -v \
  -keystore "$JKS" -storetype PKCS12 \
  -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PW" -keypass "$PW" \
  -dname "CN=Prepzo, OU=Mobile, O=Prepzo, L=India, C=IN"

umask 077
cat > "$PROPS" <<EOF
storePassword=$PW
keyPassword=$PW
keyAlias=$ALIAS
storeFile=app/upload-keystore.jks
EOF
chmod 600 "$PROPS" "$JKS"

echo
echo "Created: $JKS"
echo "Created: $PROPS"
echo "Back up both files and the password somewhere safe."
