#!/bin/bash

# Update package list
sudo apt update

# Install Git
sudo apt install -y git

# Verify Git installation
git --version

# Install GitHub CLI
sudo apt install -y gh

# Verify GitHub CLI installation
gh --version

# Authenticate with GitHub (optional, but recommended)
gh auth login


################# Quick setup after installation ########################

# Configure Git globally
git config --global user.name "yennhc"
git config --global user.email "yen.nguyenhoacat@gmail.com"

# Verify configuration
git config --global --list


################## self-hosted Git server (Gitea) ########################

# Create the group first
sudo groupadd --system gitea

# Then create the user with correct syntax
sudo useradd --system -g gitea --home /var/lib/gitea --shell /bin/false gitea

# Create gitea user
#sudo useradd --system -g gitea --home /home/gitea gitea

# Download latest Gitea binary
wget https://github.com/go-gitea/gitea/releases/download/v1.21.5/gitea-1.21.5-linux-amd64 -O gitea
chmod +x gitea

# Move to appropriate directory
sudo mv gitea /usr/local/bin/gitea

# Create necessary directories
sudo mkdir -p /var/lib/gitea/{custom,data,log}
sudo mkdir -p /etc/gitea

# Set permissions
sudo chown -R gitea:gitea /var/lib/gitea
sudo chown -R gitea:gitea /etc/gitea

sudo chmod -R 750 /var/lib/gitea
sudo chmod -R 750 /etc/gitea

sudo chmod +x /usr/local/bin/gitea



# Stop the running process (Ctrl+C in the terminal)

# Update the config file with correct paths
sudo tee /etc/gitea/app.ini > /dev/null << 'EOF'
APP_NAME = Gitea
RUN_USER = gitea
RUN_MODE = prod

[paths]
APP_DATA_PATH = /var/lib/gitea/data
TEMP_PATH = /var/lib/gitea/tmp

[repository]
ROOT = /var/lib/gitea/data/repositories

[database]
DB_TYPE = mysql
HOST = 127.0.0.1:3306
NAME = gitea
USER = ynguyen
PASSWD = your_secure_password

[server]
HTTP_PORT = 3000
ROOT_URL = http://172.19.78.62:3000/

[security]
INSTALL_LOCK = false
EOF



################# Install mysql ########################

# Install MySQL
sudo apt update
sudo apt install -y mysql-server

# Start MySQL service
sudo systemctl start mysql
sudo systemctl enable mysql

# Verify it's running
sudo systemctl status mysql

# Create Gitea database and user
sudo mysql -u root -p << EOF
CREATE DATABASE gitea;
CREATE USER 'ynguyen'@'localhost' IDENTIFIED BY 'your_secure_password';
GRANT ALL PRIVILEGES ON gitea.* TO 'ynguyen'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF



# Run Gitea
#gitea web --config /etc/gitea/app.ini

# Fix file permissions
sudo chmod 644 /etc/gitea/app.ini
sudo chown gitea:gitea /etc/gitea/app.ini

# Start Gitea as the gitea user
sudo su
cd /var/lib/gitea
sudo -u gitea /usr/local/bin/gitea web --config /etc/gitea/app.ini

#####################







