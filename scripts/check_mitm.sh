#!/bin/bash

PROCESS_NAME="mitmdump"

echo "Waiting for mitmdump to finish..."

while pgrep -x "$PROCESS_NAME" > /dev/null; do
    sleep 60
done

echo "mitmdump has finished"
echo "Clean environment"

./clean_docker.sh
