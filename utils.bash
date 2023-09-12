#!/bin/bash

# Function to modify a config file
modify_config() {
    local config_file="$1"
    local config_key="$2"
    local new_value="$3"

    # Use sed to find the line with the config key and update the value
    sudo sed -i "/.*$config_key.*/c\\$new_value" "$config_file"
}
# Usage
# modify_config "$kibana_config_file" "server.host:" "server.host: \"0.0.0.0\""

# Function to check if the server is running
check_port_availability() {
    local target_host="$1"
    local target_port="$2"
    local time_limitation="$3"
    local log_path="$4"
    local counter=0

    while true; do
        if curl -s "$target_host:$target_port"; then
            echo "Port $target_port on $target_host is open. Continuing to the next step."
            break
        else
            echo "Port $target_port on $target_host is not open yet. Waiting for 5 seconds..."
            sleep 5  # wait 5 seconds
            counter=$((counter + 5))
            if [ "$counter" -ge "$time_limitation" ]; then
                echo "Timeout: Port $target_port on $target_host did not open after $time_limitation seconds. Exiting."
                echo "Alert! Maybe there are some errors. Please check $log_path for more information."
                exit 1
            fi
        fi
    done
}
# Usage
# check_port_availability "$target_host" "$target_port" "300" "/opt/elasticsearch-7.14.2/logs/elasticsearch.log"
