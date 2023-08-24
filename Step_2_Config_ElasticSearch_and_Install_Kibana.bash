#!/bin/bash

# Date:    2023-8-22
# Author:  create by Xia Qizhao
# Function:  The running functions are messy, and there are specific contents in the Script Structure
# Version:   1.0
#
# Script Structure:
# 1. Configure a password for elasticsearch and store it in a local json file
# 2. Install kibana
# 3. Launch and test the kibana
# 4. Install wazuh-manager and wazuh_kibana plugin
# 5. Reboot
#
# Example Usages:
# ./Step_2_Config_ElasticSearch_and_Install_Kibana.bash
#
# IMPORTANT: It will reboot after this script finishes, please save other things.

source ./utils.bash

# Step 1_3: test the ElasticSearch without password

# The default owner here is root, which will cause some permission problems. We directly modify the owner to keep the minimum permission.
sudo chown -R $(whoami):$(id -gn) /opt/elasticsearch-7.14.2

# run the elasticsearch and test
/opt/elasticsearch-7.14.2/bin/elasticsearch -d

host_ipv4_address=$(hostname -I | awk '{print $1}')
target_host="http://$host_ipv4_address"
target_port_for_elasticsearch=9200

time_limitation_for_elasticsearch_check=300
log_path_for_elasticsearch="/opt/elasticsearch-7.14.2/logs/elasticsearch.log"
check_port_availability "$target_host" "$target_port_for_elasticsearch" "$time_limitation_for_elasticsearch_check" "$log_path_for_elasticsearch"

# Step 1_4: Configure the password of elasticsearch and store it in json
echo "y" | /opt/elasticsearch-7.14.2/bin/elasticsearch-setup-passwords auto >password_temp_1.txt
grep "PASSWORD" password_temp_1.txt | sed 's/^.*PASSWORD //' >password_temp_2.txt
awk '{print "\"" $1 "\": \"" $3 "\","}' password_temp_2.txt | sed '$ s/.$//' | awk 'BEGIN {print "{"} {print} END {print "}"}' >password.json

rm password_temp_1.txt password_temp_2.txt
sudo mv password.json /opt/

# Step 1_5: test the ElasticSearch with password
elastic_password=$(jq -r '.elastic' /opt/password.json)

if curl -u "elastic:$elastic_password" "$target_host:$target_port_for_elasticsearch" | grep -q "You Know, for Search"; then
    echo "ElasticSearch deployed successfully!"
else
    echo "Alert! Maybe there are some errors. please check /opt/elasticsearch-7.14.2/logs/elasticsearch.log"
fi

# Step 2: install the kibana

# Step 2_1: config the kibana

# The default owner here is root, which will cause some permission problems. We directly modify the owner to keep the minimum permission.
sudo chown -R $(whoami):$(id -gn) /opt/kibana-7.14.2-linux-x86_64

kibana_config_file="/opt/kibana-7.14.2-linux-x86_64/config/kibana.yml"
modify_config "$kibana_config_file" "server.host:" "server.host: \"0.0.0.0\""
modify_config "$kibana_config_file" "server.publicBaseUrl:" "server.publicBaseUrl: \"http://$host_ipv4_address:5601\""

kibana_system_password=$(jq -r '.kibana_system' /opt/password.json)
modify_config "$kibana_config_file" "elasticsearch.username:" "elasticsearch.username: \"kibana_system\""
modify_config "$kibana_config_file" "elasticsearch.password:" "elasticsearch.password: \"$kibana_system_password\""

# Step 2_2: launch the kibana
sudo touch /opt/kb.out
sudo chown $(whoami):$(id -gn) /opt/kb.out
nohup /opt/kibana-7.14.2-linux-x86_64/bin/kibana >/opt/kb.out 2>&1 &

# Step 2_3: test the kibana
target_port_for_kibana=5601
time_limitation_for_kibana_check=450
log_path_for_kibana="/opt/kb.out"
check_port_availability "$target_host" "$target_port_for_kibana" "$time_limitation_for_kibana_check" "$log_path_for_kibana"

# Step 3: install wazuh-manager and wazuh_kibana plugin

# Step 3_1: install wazuh-manager itself
sudo su <<EOF
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
echo "deb https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list
apt update
apt install wazuh-manager=4.2.7-1
systemctl daemon-reload
systemctl enable wazuh-manager
systemctl start wazuh-manager
EOF

# Step 3_2: install wazuh_kibana plugin
/opt/kibana-7.14.2-linux-x86_64/bin/kibana-plugin install https://packages.wazuh.com/4.x/ui/kibana/wazuh_kibana-4.2.7_7.14.2-1.zip

reboot
