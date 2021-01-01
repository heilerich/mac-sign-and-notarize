#!/usr/bin/env sh
KEY_CHAIN=build.keychain
KEY_CHAIN_USER=actions
SIGN_CERT_P12_FILE=certificate.p12

# Recreate the certificate from the secure environment variable
echo $SIGN_CERT_P12 | base64 --decode > $SIGN_CERT_P12_FILE

# Create a keychain
security create-keychain -p $KEY_CHAIN_USER $KEY_CHAIN

# Make the keychain the default so identities are found
security default-keychain -s $KEY_CHAIN

# Unlock the keychain
security unlock-keychain -p $KEY_CHAIN_USER $KEY_CHAIN

security import $SIGN_CERT_P12_FILE -k $KEY_CHAIN -P $SIGN_CERT_PASSWORD -T /usr/bin/codesign;

security set-key-partition-list -S apple-tool:,apple: -s -k $KEY_CHAIN_USER $KEY_CHAIN

# Remove cert created from this script
rm "$SIGN_CERT_P12_FILE"
