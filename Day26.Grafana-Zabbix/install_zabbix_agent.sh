#!/bin/bash
# 1. Install Zabbix repository
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-4%2Bubuntu24.04_all.deb
sudo dpkg -i zabbix-release_7.0-4%2Bubuntu24.04_all.deb
sudo apt update
sudo apt install zabbix-agent2 -y

# 2. Configure Zabbix agent
sudo sed -i 's/Server=127.0.0.1/Server=172.19.78.57/' /etc/zabbix/zabbix_agent2.conf
sudo sed -i 's/ServerActive=127.0.0.1/ServerActive=172.19.78.57/' /etc/zabbix/zabbix_agent2.conf
sudo sed -i 's/Hostname=Zabbix server/Hostname=dev/' /etc/zabbix/zabbix_agent2.conf

# 3. Start Zabbix agent process
sudo systemctl restart zabbix-agent2
sudo systemctl enable zabbix-agent2 
sudo ufw allow 10050/tcp

