#!/bin/bash

# Date:    2023-8-10
# Author:  create by Xia Qizhao
# Function:  Install zeek with Goose parser and MMS parser
# Version:   1.0
#
# Script Structure:
# 1. Install Zeek with Goose parser
# 2. Install MMS parser
# 3. Write the path of zeek into the environment variable
#
# Example Usages:
# source ./Step_5_Install_Zeek.bash
#
# IMPORTANT: The make process here may require some memory(There is no specific limit, but if you get stuck, you can check the memory with the free command) and also consume some time.

pwd=$(pwd)

# A non-root user is used here
cd ~/
mkdir workspace4zeek
cd workspace4zeek/

# Step 5: Install zeek with Goose parser and MMS parser

# Step 5_1: Install Zeek with Goose parser
git clone --recursive https://github.com/zeek/zeek
cd zeek
git checkout aff3f4
git submodule update --init --recursive
cd ..
git clone https://github.com/smartgridadsc/Goose-protocol-parser-for-Zeek-IDS.git
cp ./Goose-protocol-parser-for-Zeek-IDS/patch/goose_parser.patch ./zeek
cd zeek/
git apply --reject --whitespace=fix goose_parser.patch
./configure
make
sudo make install
./build/src/bro -v

# Step 5_2: Install MMS parser
cd ~/workspace4zeek/zeek
bro_dist=$(pwd)
cd ..
git clone https://github.com/smartgridadsc/MMS-protocol-parser-for-Zeek-IDS
cd MMS-protocol-parser-for-Zeek-IDS/
./configure --bro-dist=$bro_dist # Here needs to write the absolute path
make
sudo make install

# Step 5_3: Add zeek directory to PATH
echo "export PATH=\$PATH:${bro_dist}/build/src" >>~/.bashrc
source ~/.bashrc
bro -N

# Because the source operation is used here, and the cd command appears in the script, it is necessary to switch back to the original directory at the end.
cd $pwd
