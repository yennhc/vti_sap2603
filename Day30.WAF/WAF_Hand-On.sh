#!/bin/bash

waf_server_ip="172.19.78.82"
web_server_ip="172.19.78.84"
attacker_server_ip="172.19.78.109"

################################ On WEB Server ################################

# This script will install and configure Apache, PHP, and MariaDB on the web server.
sudo apt update && sudo apt upgrade -y
sudo apt install apache2 php php-mysqli php-gd php-xml \
                 mariadb-server git unzip -y
sudo systemctl enable --now apache2 mariadb


## Configure MariaDB and create a database for DVWA
cd /var/www/html
sudo git clone https://github.com/digininja/DVWA.git dvwa
sudo cp dvwa/config/config.inc.php.dist dvwa/config/config.inc.php
sudo chown -R www-data:www-data dvwa
sudo chmod -R 755 dvwa

sudo mysql -u root <<EOF
CREATE DATABASE dvwa CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER 'dvwa'@'localhost' IDENTIFIED BY 'p@ssw0rd';
GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';
FLUSH PRIVILEGES;
EOF

# Edit the DVWA configuration file to set the database user and password
sudo nano /var/www/html/dvwa/config/config.inc.php
# Sửa 2 dòng sau:
$_DVWA['db_user']     = 'dvwa';
$_DVWA['db_password'] = 'p@ssw0rd';


## Check if DVWA is working by accessing it in a web browser or using curl
curl -I http://${web_server_ip}/dvwa/


################################ End On WEB Server ################################




################################ On WAF Server ################################

# This script will enable ModSecurity in Nginx and configure it to use the recommended settings.
sudo mkdir -p /etc/nginx/modsec

sudo curl -fsSL -o /etc/nginx/modsec/modsecurity.conf \
  https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/modsecurity.conf-recommended

sudo curl -fsSL -o /etc/nginx/modsec/unicode.mapping \
  https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/unicode.mapping


sudo sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf


# Enable OWASP ModSecurity Core Rule Set (CRS)
ls -la /usr/share/modsecurity-crs/

# Create a main configuration file for ModSecurity in Nginx
sudo tee /etc/nginx/modsec/main.conf <<'EOF'
Include /etc/nginx/modsec/modsecurity.conf
Include /etc/modsecurity/crs/crs-setup.conf 
Include /usr/share/modsecurity-crs/rules/*.conf
EOF


# Create a new Nginx server block configuration for the WAF
sudo tee /etc/nginx/sites-available/waf.conf <<'EOF'
server {
    listen 80;
    # Bật ModSecurity WAF
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsec/main.conf;
    # Reverse Proxy đến web-server (Private IP .20)
    location / {
        proxy_pass http://${web_server_ip};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 10s;
        proxy_read_timeout 30s;
    }
}
EOF

# Enable the new Nginx server block configuration
sudo ln -s /etc/nginx/sites-available/waf.conf \
           /etc/nginx/sites-enabled/waf.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx


# Test the WAF by sending a request that should be blocked by ModSecurity
echo "Testing the WAF by sending a request that should be blocked by ModSecurity..."
curl -I http://${waf_server_ip}/?id=1' OR '1'='1

################################ End On WAF Server ################################


################################ On Attacker Server ################################

# This script will install curl and Nikto on the attacker server.
sudo apt update
sudo apt install curl nikto -y
nikto -Version

# Không qua WAF (đi thẳng)
curl -v "http://${web_server_ip}/dvwa/login.php?\
username=admin'OR'1'='1&password=x"


# Qua WAF → 403 Forbidden
curl -v "http://${waf_server_ip}/dvwa/login.php?\
username=admin'OR'1'='1&password=x"


# Không qua WAF
curl -v "http://${web_server_ip}/dvwa/\
?search=<script>alert(1)</script>"


# Qua WAF → 403 Forbidden
curl -v "http://${waf_server_ip}/dvwa/\
?search=<script>alert(1)</script>"


# Không qua WAF
curl -v "http://${web_server_ip}/dvwa/\
?page=../../../../etc/passwd"

# Qua WAF → 403 Forbidden
curl -v "http://${waf_server_ip}/dvwa/\
?page=../../../../etc/passwd"



# Từ attacker — quét qua WAF:
nikto -h http://${waf_server_ip} -output ~/nikto_report.txt 2>&1 | tee ~/nikto_screen.txt
cat ~/nikto_screen.txt

# Trên waf-server — đếm số request bị chặn (403):
sudo grep '403' /var/log/nginx/access.log | wc -l


################################ End On Attacker Server ################################


################################ Phân tích log & custom rule ################################

##########Xem ModSecurity Audit Log##################
# Theo dõi log realtime:
sudo tail -f /var/log/modsec_audit.log
# Lọc các request bị block:
sudo grep -B2 -A30 '403' /var/log/modsec_audit.log | head -80
# Nginx access log:
sudo tail -50 /var/log/nginx/access.log
# Đếm 403 theo từng IP:
sudo awk '$9==403 {print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn
##########Xem ModSecurity Audit Log##################


##########Viết Custom Rules##################

###Chặn Nikto Scanner theo User-Agent
sudo tee -a /etc/nginx/modsec/main.conf <<'EOF'
# Custom Rule 1: Block Nikto Scanner by User-Agent
SecRule REQUEST_HEADERS:User-Agent "@contains nikto" \
    "id:9001,phase:1,deny,status:403,\
     msg:'Custom - Scanner Blocked',\
     logdata:'UA: %{REQUEST_HEADERS.User-Agent}'"
EOF


###Chặn SQL keywords trong query string
sudo tee -a /etc/nginx/modsec/main.conf <<'EOF'
# Custom Rule 2: Block SQL keywords
SecRule ARGS "@rx (?i)(union.*select|drop.*table|insert.*into)" \
    "id:9002,phase:2,deny,status:403,\
     msg:'Custom - SQL Keyword Detected'"
EOF

###Reload & kiểm tra custom rule
sudo nginx -t && sudo systemctl reload nginx
# Test Rule 1 (từ attacker) → 403 Forbidden:
curl -A 'Nikto/2.1.6' http://${waf_server_ip}/
# Test Rule 2 (từ attacker) → 403 Forbidden:
curl "http://${waf_server_ip}/?q=UNION+SELECT+1,2,3"
# Xem log custom rule:
sudo grep 'Custom' /var/log/modsec_audit.log | tail -20


##########Viết Custom Rules##################

################################ End Phân tích log & custom rule ################################


