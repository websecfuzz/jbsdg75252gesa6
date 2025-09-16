SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

## HOW TO USE: ./sh <WUT_NAME> <PORT> <HOME_URL> <OPENAPIFILENAME> <FUZZER_NAME>>
## EXAMPLE: ./sh wordpress3 8081 / openapi.json

export WUT_NAME=$1
export WUT_PORT=$2
export WUT_URL="http://localhost:$2"
TARGET_URL=$WUT_URL$3
export OPENAPI_FILE=$4
export FUZZER_NAME=$5

## DELETE SHARED-DATA
mv ../shared-data/mysql_proxy_$WUT_NAME.log ../shared-data/mysql_proxy_$WUT_NAME.log.old

## RUNNING WUT
cd ../
cd WUT/$WUT_NAME
docker compose up --detach --force-recreate

## CHECK WUT AVAILABLE OR NOT
cd $SCRIPT_DIR
./check_server.sh localhost $2 $TARGET_URL

## CALL LOGIN MODULE
source ../venv/bin/activate
cd ../crawler
python login.py

## LOAD COOKIE DATA FROM LOGIN
COOKIE_FILE="../login_state/$WUT_NAME/Admin.txt"

# Check if the file exists
if [[ ! -f "$COOKIE_FILE" ]]; then
    echo "Error: File '$COOKIE_FILE' not found."
    exit 1
fi

# Load the cookie string from the file
export cookie_line=$(<"$COOKIE_FILE")
# Optionally extract just the cookie value (removes "Cookie": part)
cookie_value=$(echo "$cookie_line" | sed 's/^"Cookie": "//;s/"$//')

## CHECK IF THERE IS A SPECIAL HEADER FILE
HEADER_FILE="../WUT/$WUT_NAME/_resources/header"
if [[ -f "$HEADER_FILE" ]]; then
    echo "Found File '$HEADER_FILE'. Use it."
    export cookie_line=$(<"$HEADER_FILE")
fi

## Running Reverse Proxy
cd $SCRIPT_DIR
cd ../
mitmdump --mode reverse:$WUT_URL --flow-detail 0 --set flow_storage=memory-limited --quiet --listen-port 8888 -s crawler/mitmproxy_addon.py &
WEB_PROXY_PID=$!

cd $SCRIPT_DIR
./${FUZZER_NAME}.sh $6

# Optionally: wait for some time (e.g., to capture traffic for 1 minutes)
sleep 60
echo "KILL WEB_PROXY_PID $WEB_PROXY_PID"
kill $WEB_PROXY_PID

cd $SCRIPT_DIR
cd ../
cd crawler_WUT/$WUT_NAME
docker compose down
