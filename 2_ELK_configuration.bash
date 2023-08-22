#!/bin/bash

# To do:
# 1. test 300s

sudo apt update
sudo apt install -y jq

# sudo chmod -R 755 /opt/elasticsearch-7.14.2
# sudo chmod -R 777 /opt/elasticsearch-7.14.2/logs
# sudo chmod -R 777 /opt/elasticsearch-7.14.2/config
# There's actually still a risk here, 755 isn't a reasonable permission setting, but for the sake of normal operation, it's being deployed using 755 for the time being.
sudo chown -R $(whoami):$(id -gn) /opt/elasticsearch-7.14.2

/opt/elasticsearch-7.14.2/bin/elasticsearch -d

host_ipv4_address=$(hostname -I | awk '{print $1}')
target_host="http://$host_ipv4_address"
target_port=9200

# while true; do
#     if curl -s "$target_host:$target_port"; then
#         echo "Port $target_port on $target_host is open. Continuing to the next step."
#         break  
#     else
#         echo "Port $target_port on $target_host is not open yet. Waiting for 5 seconds..."
#         sleep 5  # wait 5 seconds
#     fi
# done

counter=0
while true; do
    if curl -s "$target_host:$target_port"; then
        echo "Port $target_port on $target_host is open. Continuing to the next step."
        break  
    else
        echo "Port $target_port on $target_host is not open yet. Waiting for 5 seconds..."
        sleep 5  # wait 5 seconds
        counter=$((counter + 5))
        if [ "$counter" -ge 300 ]; then
            echo "Timeout: Port $target_port on $target_host did not open after 300 seconds. Exiting."
            echo "Alert! Maybe there are some errors. please check /opt/elasticsearch-7.14.2/logs/elasticsearch.log"
            exit 1
        fi
    fi
done

echo "y" | /opt/elasticsearch-7.14.2/bin/elasticsearch-setup-passwords auto > password_temp_1.txt
grep "PASSWORD" password_temp_1.txt | sed 's/^.*PASSWORD //' > password_temp_2.txt
awk '{print "\"" $1 "\": \"" $3 "\","}' password_temp_2.txt | sed '$ s/.$//' | awk 'BEGIN {print "{"} {print} END {print "}"}' > password.json

rm password_temp_1.txt password_temp_2.txt
sudo mv password.json /opt/

elastic_password=$(jq -r '.elastic' /opt/password.json)

if curl -u "elastic:$elastic_password" "$target_host:$target_port" | grep -q "You Know, for Search"; then
    echo "ElasticSearch deployed successfully!"
else
    echo "Alert! Maybe there are some errors. please check /opt/elasticsearch-7.14.2/logs/elasticsearch.log"
fi

# config the kibana
