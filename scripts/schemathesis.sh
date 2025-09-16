SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ../

TARGET_PROXY_URL="${1:-http://localhost:8888}"

schemathesis run --header "$cookie_line" --url $TARGET_PROXY_URL crawler_WUT/$WUT_NAME/_resources/$OPENAPI_FILE |& tee log/schemathesis-$WUT_NAME.log
