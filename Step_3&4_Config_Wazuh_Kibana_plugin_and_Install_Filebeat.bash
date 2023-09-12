#!/bin/bash

# Date:    2023-8-23
# Author:  create by Xia Qizhao
# Function:  The running functions are messy, and there are specific contents in the Script Structure
# Version:   1.0
#
# Script Structure:
# 1. Start the Elasticsearch and kibana service after reboot
# 2. Configure wazuh plugin in kibana
# 3. Configure filebeat.yml
# 4. Configure zeek module in kibana
# 5. Reboot
#
# Example Usages:
# ./Step_3&4_Config_Wazuh_Kibana_plugin_and_Install_Filebeat.bash
#
# IMPORTANT: It will reboot after this script finishes, please save other things.

source ./utils.bash

# Start the Elasticsearch and kibana service after reboot
/opt/elasticsearch-7.14.2/bin/elasticsearch -d
nohup /opt/kibana-7.14.2-linux-x86_64/bin/kibana > /opt/kb.out 2>&1 &

# some constant definitions
host_ipv4_address=$(hostname -I | awk '{print $1}')
target_host="http://$host_ipv4_address"
target_port_for_kibana=5601
target_port_for_elasticsearch=9200
time_limitation_for_kibana_check=450
log_path_for_kibana="/opt/kb.out"

# Check if the service is started
check_port_availability "$target_host" "$target_port_for_kibana" "$time_limitation_for_kibana_check" "$log_path_for_kibana"

elastic_password=$(jq -r '.elastic' /opt/password.json)

# Step 3_3: configure wazuh plugin in kibana
# Generate the file of wazuh plugin in kibana
curl -s -o /dev/null -u "elastic:$elastic_password" "$target_host:$target_port_for_kibana/app/wazuh#/health-check"

# Modify the file generated above
kibana_plugin_config_file="/opt/kibana-7.14.2-linux-x86_64/data/wazuh/config/wazuh.yml"
modify_config "$kibana_plugin_config_file" "url: https:\/\/localhost" "     url: https://$host_ipv4_address"

# Here is a simple lock to ensure that the files needed for subsequent operations are correctly generated

counter=0
time_limitation=$time_limitation_for_kibana_check
while true; do
    modify_config "$kibana_plugin_config_file" "url: https:\/\/localhost" "     url: https://$host_ipv4_address"
    if [ $? -ne 0 ]; then
        echo "Generating configuration file failed. Running curl command to generate again..."
        curl -s -u "elastic:$elastic_password" "$target_host:$target_port_for_kibana/app/wazuh#/health-check"

        sleep 5  # wait 5 seconds
        counter=$((counter + 5))
        if [ "$counter" -ge "$time_limitation" ]; then
            echo "Timeout: $target_host:$target_port_for_kibana/app/wazuh#/health-check generates kibana data of wazuh failed, please access this url in browser manually."
            exit 1
        fi
    else
        echo "kibana data of wazuh generate successfully."
        break
    fi
done

# Step 4 install filebeat
# Step 4_1 configure wazuh in filebeat
sudo chmod -R 755 /opt/filebeat-7.14.2-linux-x86_64/

# Download some filebeat files about wazuh
cd ~/Downloads
curl -o wazuh-filebeat-0.1.tar.gz https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.1.tar.gz
tar -xvf wazuh-filebeat-0.1.tar.gz
sudo mv wazuh /opt/filebeat-7.14.2-linux-x86_64/module

template_json_name_for_wazuh="wazuh-template.json"
template_json_path_for_wazuh="/opt/filebeat-7.14.2-linux-x86_64/module/wazuh/"
curl -o wazuh-template.json https://raw.githubusercontent.com/wazuh/wazuh/4.2/extensions/elasticsearch/7.x/wazuh-template.json
sudo mv wazuh-template.json /opt/filebeat-7.14.2-linux-x86_64/module/wazuh

# Step 4_2 configure filebeat.yml

# add yaml to filebeat.yml
# If you use vscode to open this file, an error may be reported here, but it doesn't matter, it is a false positive, and it can run normally.
filebeat_config_file="/opt/filebeat-7.14.2-linux-x86_64/filebeat.yml"
sudo bash -c "cat >> $filebeat_config_file" << EOF
filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
    archives:
      enabled: false

setup.template.json.enabled: true
setup.template.json.path: $template_json_path_for_wazuh$template_json_name_for_wazuh
setup.template.json.name: wazuh
setup.template.overwrite: true
setup.ilm.enabled: false

output.elasticsearch.host: ["$host_ipv4_address:$target_port_for_elasticsearch"]
output.elasticsearch.username: elastic
output.elasticsearch.password: $elastic_password
EOF


sudo touch /opt/fb.out
sudo chown $(whoami):$(id -gn) /opt/fb.out
# test filebeat
sudo su <<EOF
cd /opt/filebeat-7.14.2-linux-x86_64
./filebeat test output
# ./filebeat -e
# nohup /opt/filebeat-7.14.2-linux-x86_64/filebeat -e -c /opt/filebeat-7.14.2-linux-x86_64/filebeat.yml > /opt/fb.out 2>&1 &	
EOF

kibana_system_password=$(jq -r '.kibana_system' /opt/password.json)
sudo bash -c "cat >> $filebeat_config_file" << EOF
setup.kibana:
  host: "$host_ipv4_address:$target_port_for_kibana"
  protocol: "http"
  #username: "kibana_system"
  #password: "$kibana_system_password"
setup.dashboards.enabled: true
EOF


# step 4_3 configure zeek in filebeat
# Please note: You must use a relative path here, which is a bit inconvenient
cd /opt/filebeat-7.14.2-linux-x86_64/
sudo ./filebeat modules enable zeek

filebeat_zeek_module_config_file="./modules.d/zeek.yml"
zeek_log_path="/usr/local/bro/logs"
sudo bash -c "cat > $filebeat_zeek_module_config_file" << EOF
# Module: zeek
# Docs: /guide/en/beats/filebeat/7.6/filebeat-module-zeek.html

- module: zeek
  capture_loss:
    enabled: true
    var.paths: ["$zeek_log_path/capture_loss.log"]
  connection:
    enabled: true
    var.paths: ["$zeek_log_path/conn.log"]
  dce_rpc:
    enabled: true
    var.paths: ["$zeek_log_path/dce_rpc.log"]
  dhcp:
    enabled: true
    var.paths: ["$zeek_log_path/dhcp.log"]
  dnp3:
    enabled: true
    var.paths: ["$zeek_log_path/dnp3.log"]
  dns:
    enabled: true
    var.paths: ["$zeek_log_path/dns.log"]
  dpd:
    enabled: true
    var.paths: ["$zeek_log_path/dpd.log"]
  files:
    enabled: true
    var.paths: ["$zeek_log_path/files.log"]
  ftp:
    enabled: true
    var.paths: ["$zeek_log_path/ftp.log"]
  http:
    enabled: true
    var.paths: ["$zeek_log_path/http.log"]
  intel:
    enabled: true
    var.paths: ["$zeek_log_path/intel.log"]
  irc:
    enabled: true
    var.paths: ["$zeek_log_path/irc.log"]
  kerberos:
    enabled: true
    var.paths: ["$zeek_log_path/kerberos.log"]
  modbus:
    enabled: true
    var.paths: ["$zeek_log_path/modbus.log"]
  mysql:
    enabled: true
    var.paths: ["$zeek_log_path/mysql.log"]
  notice:
    enabled: true
    var.paths: ["$zeek_log_path/notice.log"]
  ntlm:
    enabled: true
    var.paths: ["$zeek_log_path/ntlm.log"]
  ocsp:
    enabled: true
    var.paths: ["$zeek_log_path/ocsp.log"]
  pe:
    enabled: true
    var.paths: ["$zeek_log_path/pe.log"]
  radius:
    enabled: true
    var.paths: ["$zeek_log_path/radius.log"]
  rdp:
    enabled: true
    var.paths: ["$zeek_log_path/rdp.log"]
  rfb:
    enabled: true
    var.paths: ["$zeek_log_path/rfb.log"]
  sip:
    enabled: true
    var.paths: ["$zeek_log_path/sip.log"]
  smb_cmd:
    enabled: true
    var.paths: ["$zeek_log_path/smb_cmd.log"]
  smb_files:
    enabled: true
    var.paths: ["$zeek_log_path/smb_files.log"]
  smb_mapping:
    enabled: true
    var.paths: ["$zeek_log_path/smb_mapping.log"]
  smtp:
    enabled: true
    var.paths: ["$zeek_log_path/smtp.log"]
  snmp:
    enabled: true
    var.paths: ["$zeek_log_path/snmp.log"]
  socks:
    enabled: true
    var.paths: ["$zeek_log_path/socks.log"]
  ssh:
    enabled: true
    var.paths: ["$zeek_log_path/ssh.log"]
  ssl:
    enabled: true
    var.paths: ["$zeek_log_path/ssl.log"]
  stats:
    enabled: true
    var.paths: ["$zeek_log_path/stats.log"]
  syslog:
    enabled: true
    var.paths: ["$zeek_log_path/syslog.log"]
  traceroute:
    enabled: true
    var.paths: ["$zeek_log_path/traceroute.log"]
  tunnel:
    enabled: true
    var.paths: ["$zeek_log_path/tunnel.log"]
  weird:
    enabled: true
    var.paths: ["$zeek_log_path/weird.log"]
  x509:
    enabled: true
    var.paths: ["$zeek_log_path/x509.log"]
EOF

sudo chmod -R 755 /opt/filebeat-7.14.2-linux-x86_64
sudo chown -R root:root /opt/filebeat-7.14.2-linux-x86_64/module

reboot