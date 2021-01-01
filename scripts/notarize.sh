#!/usr/bin/env sh

# Needed inputs
# APP_PATH
# API_KEY_ID
# API_ISSUER

APP_PATH=`python -c "import os; print(os.path.realpath('${APP_PATH}'))"`
BUNDLE_ID=`/usr/bin/mdls -name kMDItemCFBundleIdentifier -r "${APP_PATH}"`
ZIP_PATH="`mktemp -d`/${BUNDLE_ID}.zip"

echo "Preparing ${BUNDLE_ID} at ${APP_PATH} for upload"

# Create a ZIP archive suitable for altool.
/usr/bin/ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

UPLOAD_RESPONSE_PATH=`mktemp`
/usr/bin/xcrun altool --notarize-app \
                      --primary-bundle-id "${BUNDLE_ID}" \
                      --apiKey "${API_KEY_ID}" \
                      --apiIssuer "${API_ISSUER}" \
                      --file "${ZIP_PATH}" \
                      --output-format json \
                      2>/dev/null | sed -n '/^{.*$/,$p' > "${UPLOAD_RESPONSE_PATH}"

REQUEST_UUID=`cat "${UPLOAD_RESPONSE_PATH}" | /usr/local/bin/jq -r ".[\"notarization-upload\"].RequestUUID"`
if [[ $? -ne 0 ]]; then
  echo "submission for notarization returned an error"
  cat "${UPLOAD_RESPONSE_PATH}"
  exit 1
fi

while true; do
    sleep 5
    echo "checking for notarization status (job ${REQUEST_UUID}) ..."
    CHECK_RESPONSE_PATH=`mktemp`

    /usr/bin/xcrun altool --notarization-info "${REQUEST_UUID}" \
                          --apiKey "${API_KEY_ID}" \
                          --apiIssuer "${API_ISSUER}" \
                          --output-format json \
                          2>/dev/null | sed -n '/^{.*$/,$p' > "${CHECK_RESPONSE_PATH}"

    CHECK_STATUS=`cat "${CHECK_RESPONSE_PATH}" | /usr/local/bin/jq -r ".[\"notarization-info\"][\"Status\"]"` 
    if [[ "${CHECK_STATUS}" == "success" ]]; then
        echo "notarization done!"
        xcrun stapler staple "${APP_PATH}"
        echo "stapling done!"
        break
    fi
    if [[ "${CHECK_STATUS}" != "in progress" ]]; then
        echo "checking notarization status returned status: ${CHECK_STATUS}"
        cat "${CHECK_RESPONSE_PATH}"
        exit 1
    fi
    echo "not finished yet (status: ${CHECK_STATUS}, sleep 30s then checking again..."
    sleep 30
done

echo "Gatekeeper result:"

/usr/sbin/spctl -a -v "${APP_PATH}"
