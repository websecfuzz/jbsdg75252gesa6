timestamp=$(date +%s)

cd ../
python sqlifuzz/curl_without_proxy.py |& tee log/without-proxy-${WUT_NAME}-$(hostname)-${timestamp}.log
