SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

TARGET_PROXY_URL="${1:-http://localhost:8888}"

cd ../

java -jar EvoMaster/evomaster.jar --header0 "$cookie_line" --bbSwaggerUrl crawler_WUT/$WUT_NAME/_resources/$OPENAPI_FILE --bbTargetUrl $TARGET_PROXY_URL --blackBox true --maxTime 5h |& tee log/evomaster-$WUT_NAME.log
