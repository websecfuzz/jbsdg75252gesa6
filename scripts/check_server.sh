#!/bin/bash

## ./check_server.sh <<host>> <<port number>> <<target url>>

## Running WUT
PORT=$2               
TIMEOUT=5              
HOST=$1
TARGET_URL=$3 

echo "CHECKING WUT"
while true; do
        if nc -z -w "$TIMEOUT" "$HOST" "$PORT"; then
            if command -v curl &> /dev/null; then
        	response=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL" --max-time "$TIMEOUT")
        	if [ "$response" -eq "200" ]; then
            		echo "Service on $HOST:$PORT is fully ready."
            		break
            	elif  [ "$response" -eq "301" ] || [ "$response" -eq "302" ]; then
            		echo "Service on $HOST:$PORT is fully ready."
            		break
            	fi
            fi
        fi
        echo "server is NOT ready on port $PORT. Retrying in $RETRY_INTERVAL seconds..."
        sleep 5s
done

echo "server is READY on port $PORT"
