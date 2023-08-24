#!/bin/bash

# Date:    2023-8-21
# Author:  create by Xia Qizhao
# Function:  This script modifies some Elasticsearch configuration files, and modifies some parameters that will cause elasticsearch errors in ubuntu 18.06.04. After the script finishes running, it needs to be rebooted.
# Version:   1.0
#
# Script Structure:
# 1. Configure /opt/elasticsearch-7.14.2/config/elasticsearch.yml
# 2. Fix error: max virtual memory error
# 3. Fix error: max file descriptor error
# 4. Reboot
#
# Example Usages:
# ./Step_1_Install_ElasticSearch.bash
#
# IMPORTANT: It will reboot after this script finishes, please save other things.

source ./utils.bash

# Step 1 Install ElasticSearch

# Step 1_1: config the ElasticSearch
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
sudo bash -c "cat >> $elasticsearch_config_file" <<EOF
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
EOF

echo "Configuration options added to $elasticsearch_config_file"

# Step 1_2 fix some error caused by OS environment
# Fix error: max virtual memory error
sudo bash -c "cat >> /etc/sysctl.conf" <<EOF
vm.max_map_count = 262144
EOF

sysctl -p
echo "max virtual memory error fixed"

# Fix error: max file descriptor error
sudo bash -c "cat >> /etc/sysctl.conf" <<EOF
fs.file-max = 2000000
EOF

sudo bash -c "cat >> /etc/security/limits.conf" <<EOF
*	soft	nofile	204800
*	hard	nofile	204800
EOF

sudo bash -c "cat >> /etc/pam.d/common-session" <<EOF
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
