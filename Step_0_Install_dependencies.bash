#!/bin/bash

# Date:    2023-8-21
# Author:  create by Xia Qizhao
# Function:  This file installs the dependencies required by this dashboard, except Wazuh-manager and Zeek (IDS tool), which will be installed in the following scripts.
# Version:   1.0
#
# Script Structure:
# 1. apt install
# 2. Install Java
# 3. download ELK, version is 7.14.2
# 4. Disable the firewalld service(Sounds a little unreasonable, but the official Elasticsearch documentation gives this advice)
#
# Example Usages:
# source ./Step_0_Install_dependencies.bash
#
# IMPORTANT: This file needs source ./Step_0_Install_dependencies.bash to run, because it involves PATH modification

# Step 0: install dependencies

# Step 0_0: apt install
sudo apt update
sudo apt install -y curl apt-transport-https unzip wget libcap2-bin software-properties-common lsb-release gnupg cmake make gcc g++ flex libfl-dev bison libpcap-dev libssl-dev python3 python3-dev swig zlib1g-dev net-tools git jq libjson-perl ethtool libyaml-dev
# dependencies for wazuh: curl apt-transport-https unzip wget libcap2-bin software-properties-common lsb-release gnupg
# dependencies for zeek: cmake make gcc g++ flex libfl-dev bison libpcap-dev libssl-dev python3 python3-dev swig zlib1g-dev
# dependencies for this bash file: net-tools git jq
# dependencies for arkime: libjson-perl ethtool libyaml-dev

# Step 0_1: Install Java
# Check if Java is already installed
if command -v java &>/dev/null; then
  echo "Java is already installed. Skipping installation."
  echo "Alert: Java version should be higher than 1.8!"
else
  echo "Java not found. Installing..."

  # Download and extract OpenJDK archive
  cd ~/Downloads
  curl -o openlogic-openjdk-8u262-b10-linux-x64.tar.gz https://builds.openlogic.com/downloadJDK/openlogic-openjdk/8u262-b10/openlogic-openjdk-8u262-b10-linux-x64.tar.gz
  sudo tar -xzf openlogic-openjdk-8u262-b10-linux-x64.tar.gz -C /opt/ # The permission for the /opt/ directory is 755

  # Add Java bin directory to PATH
  echo 'export PATH=$PATH:/opt/openlogic-openjdk-8u262-b10-linux-64/bin' >>~/.bashrc
  source ~/.bashrc
# When we run a script file, the script usually runs in its own subshell or subprocess, which means that variables and functions defined inside the script will be discarded after the script finishes running.
# By executing the source or . command, the commands in the script will be executed directly in the current shell environment, rather than in a separate sub-shell.
fi

# Verify Java version
java -version

# Step 0_2: download ELK, version is 7.14.2
cd ~/Downloads

curl -o elasticsearch-7.14.2-linux-x86_64.tar.gz https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.14.2-linux-x86_64.tar.gz
sudo tar -xzf elasticsearch-7.14.2-linux-x86_64.tar.gz -C /opt/ # The permission for the /opt/ directory is 755

curl -o kibana-7.14.2-linux-x86_64.tar.gz https://artifacts.elastic.co/downloads/kibana/kibana-7.14.2-linux-x86_64.tar.gz
sudo tar -xzf kibana-7.14.2-linux-x86_64.tar.gz -C /opt/ # The permission for the /opt/ directory is 755

curl -o filebeat-7.14.2-linux-x86_64.tar.gz https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.14.2-linux-x86_64.tar.gz
sudo tar -xzf filebeat-7.14.2-linux-x86_64.tar.gz -C /opt/ # The permission for the /opt/ directory is 755

# Disable the firewalld service and check if the firewalld service exists before disabling
if systemctl list-units --full -all | grep -q "firewalld.service"; then
  sudo systemctl disable firewalld
  echo "Firewalld service has been disabled."
else
  echo "Firewalld service is not installed. Skipping..."
fi
