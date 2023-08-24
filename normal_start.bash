#!/bin/bash

# Date:    2023-8-24
# Author:  create by Xia Qizhao
# Function:  Script to start the service normally after the installation is complete
# Version:   1.0
#
# Script Structure:
# 1. Launch ELK
# 2. Launch Arkime
#
# Example Usages:
# ./normal.start.bash
# 
# IMPORTANT: Nothing.

host_ipv4_address=$(hostname -I | awk '{print $1}')

# Start ELK
/opt/elasticsearch-7.14.2/bin/elasticsearch -d
nohup /opt/kibana-7.14.2-linux-x86_64/bin/kibana > /opt/kb.out 2>&1 &
nohup /opt/filebeat-7.14.2-linux-x86_64/filebeat -e -c /opt/filebeat-7.14.2-linux-x86_64/filebeat.yml > /opt/fb.out 2>&1 &

# Start arkime services
sudo systemctl start arkimecapture.service
sudo systemctl start arkimeviewer.service
# how to import an existing pcap into arkime
# ${install_dir}/bin/capture -c [config_file] -r [PCAP file]

# Check log files for errors
# sudo tail -f /opt/arkime/logs/viewer.log &
# sudo tail -f /opt/arkime/logs/capture.log &

# you can visit http://$host_ipv4_address:5601 and http://$host_ipv4_address:8005 to view the dashboard.
echo "Visit http://$host_ipv4_address:5601 with your browser."
echo "Visit http://$host_ipv4_address:8005 with your browser."