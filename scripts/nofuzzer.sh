#!/bin/bash

echo "Script is doing nothing. Press any key to stop."

# Use `-n1` to read a single character without waiting for Enter
while true; do
    read -n 1 -s -t 1 key
    if [[ $? -eq 0 ]]; then
        echo -e "\nKey pressed: exiting."
        break
    fi
    # Do nothing here (but loop keeps script alive)
done
