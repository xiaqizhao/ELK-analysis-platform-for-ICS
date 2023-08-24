#!/bin/bash

# Date:    2023-8-24
# Author:  create by Xia Qizhao
# Function:  The running functions are messy, and there are specific contents in the Script Structure
# Version:   1.0
#
# Script Structure:
# 1. Install Arkime
# 2. Connect Arkime to ElasticSearch
# 3. Launch Arkime
#
# Example Usages:
# ./Step_6_Inatsll_Arkime.bash
# 
# IMPORTANT: It will reboot after this script finishes, please save other things.

source ./utils.bash

# Step 1: Download Arkime build for Ubuntu 18.06
cd ~/Downloads
curl -o arkime_4.4.0-1_amd64.deb https://s3.amazonaws.com/files.molo.ch/builds/ubuntu-18.04/arkime_4.4.0-1_amd64.deb

# Step 2: Install the downloaded package
sudo dpkg -i arkime_4.4.0-1_amd64.deb

# Step 3: Run the Configure script
interfaces=$(ifconfig | grep -o '^[a-zA-Z0-9]*' | tr '\n' ';')
interfaces=${interfaces%;}
password4arkime="password4arkime"
host_ipv4_address=$(hostname -I | awk '{print $1}')
target_host="http://$host_ipv4_address"
target_port_for_elasticsearch=9200

elastic_password=$(jq -r '.elastic' /opt/password.json)
elasticsearch_URL="http://elastic:$elastic_password@$host_ipv4_address:$target_port_for_elasticsearch"
time_limitation_for_elasticsearch_check=300
log_path_for_elasticsearch="/opt/elasticsearch-7.14.2/logs/elasticsearch.log"

echo -e "$interfaces\n\n$elasticsearch_URL\n$password4arkime\n\n" | sudo /opt/arkime/bin/Configure

# Step 4: connect to OpenSearch/Elasticsearch
check_port_availability "$target_host" "$target_port_for_elasticsearch" "$time_limitation_for_elasticsearch_check" "$log_path_for_elasticsearch"

# Step 5: Initialize/Upgrade OpenSearch/Elasticsearch

/opt/arkime/db/db.pl "$elasticsearch_URL" init
# command example: /opt/arkime/db/db.pl "http://elastic:hxvig3woPtsoHIPwsjSf@192.168.58.131:9200" init
# according to https://arkime.com/settings#elasticsearchBasicAuth

# Step 6: Add admin user
/opt/arkime/bin/arkime_add_user.sh admin "Admin User" "$password4arkime" --admin

# Step 7: Start services
sudo systemctl start arkimecapture.service
sudo systemctl start arkimeviewer.service

# Step 8: Check log files for errors
# sudo tail -f /opt/arkime/logs/viewer.log &
# sudo tail -f /opt/arkime/logs/capture.log &

# Step 9: Access Arkime Web Interface
echo "Visit $target_host:8005 with your browser."
echo "Username: admin"
echo "Password: $password4arkime from step #6"