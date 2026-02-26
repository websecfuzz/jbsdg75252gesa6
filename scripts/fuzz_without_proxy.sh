timestamp=$(date +%s)

cd ../

USE_PROGRESS=${USE_PROGRESS:-0}

if [ "$USE_PROGRESS" = "1" ]; then
	SCRIPT_PATH="sqlifuzz/fuzz_without_proxy_with_progress.py"
	MODE="with-progress"
else
	SCRIPT_PATH="sqlifuzz/fuzz_without_proxy.py"
	MODE="without-progress"
fi

python "$SCRIPT_PATH" |& tee "log/${MODE}-${WUT_NAME}-$(hostname)-${timestamp}.log"
