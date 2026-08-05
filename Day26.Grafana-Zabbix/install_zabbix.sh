#!/bin/bash

# 1.Install Zabbix repository
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-4%2Bubuntu24.04_all.deb
sudo dpkg -i zabbix-release_7.0-4%2Bubuntu24                                .04_all.deb
sudo apt update

# 2. Install Zabbix server, frontend, and agent
sudo apt install zabbix-server-mysql zabbix-frontend-php \
  zabbix-apache-conf zabbix-sql-scripts zabbix-agent2 -y


# 3. Install MySQL server
sudo apt install mysql-server -y
sudo systemctl enable --now mysql
sudo mysql -u root -p

#In Mysql shell, run the following commands to create a database and user for Zabbix:
create database zabbix character set utf8mb4 collate utf8mb4_bin;
create user zabbix@localhost identified by 'MatKhau_Lab_2024!';
grant all privileges on zabbix.* to zabbix@localhost;
set global log_bin_trust_function_creators = 1;
quit;

# 4. Import initial schema and data
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | \
  mysql --default-character-set=utf8mb4 -uzabbix -p zabbix

# Enable flag to allow the creation of functions and triggers in MySQL
sudo mysql -uroot -p -e "set global log_bin_trust_function_creators = 0;"

# 5. Configure the database for Zabbix server
sudo vim /etc/zabbix/zabbix_server.conf
#DBPassword=MatKhau_Lab_2024!

# 6. Start Zabbix server and agent processes
sudo systemctl restart zabbix-server zabbix-agent apache2

