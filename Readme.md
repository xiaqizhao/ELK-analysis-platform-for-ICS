# ELK-analysis-platform-for-ICS

This repo provides an ELK installation script, using components such as Elasticsearch, Kibana, FIlebeat, and Arkime. The IDS used are Wazuh (HIDS) and Zeek (NIDS). It can provide three interfaces of traffic statistics, alarm events, and visualized connection statistics.

By the way, in fact, the functions here are very powerful. In theory, many kinds of log files (including Linux logs, windows logs, Linux audit logs, apache logs, etc.) can be included through the configuration of filebeat, and with the help of wazuh's kibana Plug-in, all logs can be combined and displayed in a dashboard, but here we only focus on the network traffic of ICS, and the HIDS function is only for demo display)

> There is a lack of an architecture diagram that has not been drawn yet

## Installation

You can directly run the above bash files one by one. It has been tested on the ubuntu18.06.04 (x86) system. The detailed version is as follows:

| Software      | Version  |
| ------------- | -------- |
| Ubuntu        | 18.06.04 |
| ElasticSearch | 7.14.2   |
| Kibana        | 7.14.2   |
| Filebeat      | 7.14.2   |
| Arkime        | 4.4.0    |
| Zeek          | 2.6      |
| Wazuh Manager | 4.2.7-1  |

Note: I forgot to set the permissions when submitting for the first time commit. The bash files may not have x permissions and need to be added manually

Note: Here are some bash files that involve rebooting, see the comments in bash for details, remember to save your previous work before running.

```shell
source ./Step_0_Install_dependencies.bash
./Step_1_Install_ElasticSearch.bash	# there is a reboot command
./Step_2_Config_ElasticSearch_and_Install_Kibana.bash	# there is a reboot command
./Step_3&4_Config_Wazuh_Kibana_plugin_and_Install_Filebeat.bash	# there is a reboot command
source ./Step_5_Install_Zeek.bash
./Step_6_Inatsll_Arkime.bash

# After all the above bash operations are completed, you can visit http://hostip:5601 and http://hostip:8005 to view the dashboard.

# The username and password of http://hostip:5601 needs to be viewed in /opt/password.json
# The username and password for http://hostip:8005 are admin:password4arkime
```

It is still very convenient here. Although it is published to a private IP, all hosts in the intranet that can access this hostIP can view these dashboards.

## Some theoretical basis

According to the first chapter of the book [The Practice of Network Security Monitoring](https://nostarch.com/nsm), the data sources of Network Security Monitoring (NSM) can be roughly divided into four categories (originally 7 categories , Session data, Statistical data, and Metadata are generally not as important as the following four categories):

1. *full content*——can be used to record traffic, generated by tcpdump, etc.
2. *transaction data*——can be used to summarize traffic (various `.log` data generated in zeek, the session data is ignored here, session data can be considered as `conn.log generated by zeek `data)
3. *extracted content* - can be used to extract traffic (more precisely, to extract content into file formats, people will want to extract such files to provide data for their malware sandbox or analysis tools)
4. *alert data*——can be used to judge traffic (that is, normal alert information generated by snort, etc., will alert some warning information such as SSH scanning)

From the perspective of Zeek, as an NSM platform, Zeek can collect the latter three data forms, namely **transaction data, extracted content, and alert data**. At the same time, the most classic is the transaction data collected by zeek (various `.log`)

From the perspective of this Dashboard, we show alert data, transcation data, and some Statistical data. The following describes what each interface does.

## Filebeat

![fe1332415f751c097f3fd1380b29750](https://xiaqizhao-oss.oss-cn-beijing.aliyuncs.com/fe1332415f751c097f3fd1380b29750.png)

This dashboard is from FileBeat, where the content of the panels and the number of panels are editable, here is four panels with four tuple(src.ip, src.port, dst.ip and dst.port) and MMS events, and in the lower right corner is some metadata detection provided by zeek (this image is detecting if the host is a container or not)

## Events page

> I forget to take a screenshot.

## Arkime connection page

![48ae3914777d140e50898db24a4a6af](https://xiaqizhao-oss.oss-cn-beijing.aliyuncs.com/48ae3914777d140e50898db24a4a6af.png)

This page is generated by arkime, which is an indexed packet capture and search tool rather than IDS. It dedicates to provide more visibility. Through this page, we can see which connections are the most active, and we can also see which nodes should not have connections.

