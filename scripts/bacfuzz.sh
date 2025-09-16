timestamp=$(date +%s)
TARGET_PROXY_URL="${1:-http://localhost:8888}"

cd ../crawler
python fuzzer.py --hour 5 --minute 0 --url $TARGET_PROXY_URL --name $WUT_NAME --only-crawling y --without-login y --roles Admin |& tee ../log/BACFUZZ-$(hostname)-${timestamp}.log
