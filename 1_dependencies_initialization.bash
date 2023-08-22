#!/bin/bash

sudo apt update
sudo apt install -y curl apt-transport-https unzip wget libcap2-bin software-properties-common lsb-release gnupg cmake make gcc g++ flex libfl-dev bison libpcap-dev libssl-dev python3 python3-dev swig zlib1g-dev net-tools git
# dependencies for wazuh: curl apt-transport-https unzip wget libcap2-bin software-properties-common lsb-release gnupg
# dependencies for zeek: cmake make gcc g++ flex libfl-dev bison libpcap-dev libssl-dev python3 python3-dev swig zlib1g-dev
# dependencies for this bash file: net-tools git

# Check if Java is already installed
if command -v java &>/dev/null; then
  echo "Java is already installed. Skipping installation."
  echo "Alert: Java version should be higher than 1.8!"
else
  echo "Java not found. Installing..."
  
  # Download and extract OpenJDK archive
  cd ~/Downloads
  curl -o openlogic-openjdk-8u262-b10-linux-x64.tar.gz https://builds.openlogic.com/downloadJDK/openlogic-openjdk/8u262-b10/openlogic-openjdk-8u262-b10-linux-x64.tar.gz
  sudo tar -xzf openlogic-openjdk-8u262-b10-linux-x64.tar.gz -C /opt/   # The permission for the /opt/ directory is 755 
  
  # Add Java bin directory to PATH
  echo 'export PATH=$PATH:/opt/openlogic-openjdk-8u262-b10-linux-64/bin' >> ~/.bashrc
  source ~/.bashrc
# When you run a script file, the script usually runs in its own subshell or subprocess, which means that variables and functions defined inside the script will be discarded after the script finishes running.
# By executing the source or . command, the commands in the script will be executed directly in the current shell environment, rather than in a separate sub-shell.
fi

# Verify Java version
java -version

# download ELK, version is 7.14.2
cd ~/Downloads

curl -o elasticsearch-7.14.2-linux-x86_64.tar.gz https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.14.2-linux-x86_64.tar.gz
sudo tar -xzf elasticsearch-7.14.2-linux-x86_64.tar.gz -C /opt/   # The permission for the /opt/ directory is 755 

curl -o kibana-7.14.2-linux-x86_64.tar.gz https://artifacts.elastic.co/downloads/kibana/kibana-7.14.2-linux-x86_64.tar.gz
sudo tar -xzf kibana-7.14.2-linux-x86_64.tar.gz -C /opt/   # The permission for the /opt/ directory is 755 

curl -o filebeat-7.14.2-linux-x86_64.tar.gz https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.14.2-linux-x86_64.tar.gz
sudo tar -xzf filebeat-7.14.2-linux-x86_64.tar.gz -C /opt/   # The permission for the /opt/ directory is 755 

# Disable the firewalld service and check if the firewalld service exists before disabling
if systemctl list-units --full -all | grep -q "firewalld.service"; then
    sudo systemctl disable firewalld
    echo "Firewalld service has been disabled."
else
    echo "Firewalld service is not installed. Skipping..."
fi


# config the ElasticSearch

# Function to modify a config file
modify_config() {
    local config_file="$1"
    local config_key="$2"
    local new_value="$3"

    # Use sed to find the line with the config key and update the value
    sudo sed -i "/.*$config_key.*/c\\$new_value" "$config_file"
}

# Get the IPv4 address using hostname -I command
host_ipv4_address=$(hostname -I | awk '{print $1}')

# Specify the Elasticsearch configuration file path
elasticsearch_config_file="/opt/elasticsearch-7.14.2/config/elasticsearch.yml"

# Backup the original configuration file
sudo cp "$elasticsearch_config_file" "$elasticsearch_config_file.backup"

# modify configuration options in the Elasticsearch config file
modify_config "$elasticsearch_config_file" "network.host:" "network.host: 0.0.0.0"
modify_config "$elasticsearch_config_file" "discovery.seed_hosts:" "discovery.seed_hosts: ["$host_ipv4_address"]"
modify_config "$elasticsearch_config_file" "cluster.initial_master_nodes:" "cluster.initial_master_nodes: ["$host_ipv4_address"]"

# Add configuration options in the Elasticsearch config file
sudo bash -c "cat >> $elasticsearch_config_file" << EOF
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
EOF

echo "Configuration options added to $elasticsearch_config_file"


# Fix error: max virtual memory error
sudo bash -c "cat >> /etc/sysctl.conf" << EOF
vm.max_map_count = 262144
EOF

sysctl -p
echo "max virtual memory error fixed"

# Fix error: max file descriptor error 
sudo bash -c "cat >> /etc/sysctl.conf" << EOF
fs.file-max = 2000000
EOF

sudo bash -c "cat >> /etc/security/limits.conf" << EOF
*	soft	nofile	204800
*	hard	nofile	204800
EOF

sudo bash -c "cat >> /etc/pam.d/common-session" << EOF
session required        pam_limits.so
EOF

# Define the new value for DefaultLimitNOFILE
new_limit_nofile="DefaultLimitNOFILE=204800"

# Modify /etc/systemd/system.conf
modify_config "/etc/systemd/system.conf" "DefaultLimitNOFILE" "$new_limit_nofile"

# Modify /etc/systemd/user.conf
modify_config "/etc/systemd/user.conf" "DefaultLimitNOFILE" "$new_limit_nofile"

echo "max file descriptor error fixed"

echo "Finish configuration for ElasticSearch. Ready to reboot!"
reboot