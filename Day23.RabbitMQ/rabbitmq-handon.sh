#!/bin/bash

#Network 192.168.99.0/24
#Environment RabbitMQ Cluster 3 nodes

haproxy_ip="192.168.99.9"
rabbitmq_01="192.168.99.139"
rabbitmq_02="192.168.99.140"
rabbitmq_03="192.168.99.141"
app01="192.168.99.142" 

######################################################

#### Step 1: Config /etc/hosts on all VMs

sudo tee -a <<'EOF' /etc/hosts
192.168.99.9    haproxy
192.168.99.139  rabbitmq-01
192.168.99.140  rabbitmq-02
192.168.99.141  rabbitmq-03
192.168.99.142  app01
EOF

sudo hostnamectl set-hostname rabbitmq-01
sudo hostnamectl set-hostname rabbitmq-02
sudo hostnamectl set-hostname rabbitmq-03

reboot

######################################################

#Step 2: Install rabbitmq on all 3 nodes    

sudo apt update
sudo apt install rabbitmq-server -y
sudo rabbitmq-plugins enable rabbitmq_management
sudo systemctl enable --now rabbitmq-server

#### Step 3: Sync Erlang cookie

sudo cat /var/lib/rabbitmq/.erlang.cookie

#Copy value of this file to other nodes
#Update erlang cookie and restart rabbitmq service on rabbitmq-02 and rabbitmq-03

sudo systemctl stop rabbitmq-server
sudo vim /var/lib/rabbitmq/.erlang.cookie
sudo chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
sudo chmod 400 /var/lib/rabbitmq/.erlang.cookie
sudo systemctl start rabbitmq-server


#Step4: Join node 2 and node 3 to cluster
#On rabbitmq-02:
sudo rabbitmqctl stop_app
sudo rabbitmqctl reset
sudo rabbitmqctl join_cluster rabbit@rabbitmq-01
sudo rabbitmqctl start_app

#On rabbitmq-03:
sudo rabbitmqctl stop_app
sudo rabbitmqctl reset
sudo rabbitmqctl join_cluster rabbit@rabbitmq-01
sudo rabbitmqctl start_app


### Step 5: Check cluster status
sudo rabbitmqctl cluster_status


### Step 6: Create admin user
sudo rabbitmqctl add_user admin Admin@123
sudo rabbitmqctl set_user_tags admin administrator
sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"
sudo rabbitmqctl delete_user guest


### Step 7: Open firewall
# On 3 RabbitMQ nodes
sudo ufw allow 5672/tcp
sudo ufw allow 15672/tcp
sudo ufw allow 4369/tcp
sudo ufw allow 25672/tcp
sudo ufw enable


### Step 8: Create Quorum Queue
#On rabbitmq-01

sudo rabbitmqctl set_policy ha-all "^school\." \
  '{"ha-mode":"all","ha-sync-mode":"automatic"}' \
  --apply-to queues

#Create exchange
sudo rabbitmqadmin declare exchange \
name=school_events \
type=fanout \
durable=true \
-u admin -p Admin@123

#create queue
sudo rabbitmqadmin declare queue \
    name=school.email \
    durable=true \
    arguments='{"x-queue-type":"quorum"}' \
    -u admin -p Admin@123

sudo rabbitmqadmin declare queue \
    name=school.ad \
    durable=true \
    arguments='{"x-queue-type":"quorum"}' \
    -u admin -p Admin@123

sudo rabbitmqadmin declare queue \
    name=school.email \
    durable=true \
    arguments='{"x-queue-type":"quorum"}' \
    -u admin -p Admin@123   

sudo rabbitmqadmin declare queue \
    name=school.ad \
    durable=true \
    arguments='{"x-queue-type":"quorum"}' \
    -u admin -p Admin@123

sudo rabbitmqadmin declare queue \
    name=school.audit \
    durable=true \
    arguments='{"x-queue-type":"quorum"}' \
    -u admin -p Admin@123

#Bind queue vào exchange
sudo rabbitmqadmin declare binding \
    source=school_events \
    destination=school.email \
    destination_type=queue \
    -u admin -p Admin@123

sudo rabbitmqadmin declare binding \
source=school_events \
destination=school.ad \
destination_type=queue \
-u admin -p Admin@123

sudo rabbitmqadmin declare binding \
source=school_events \
destination=school.audit \
destination_type=queue \
-u admin -p Admin@123


#################### Step9: Install HAProxy ###############################

sudo apt update && sudo apt install haproxy -y

sudo tee -a /etc/haproxy/haproxy.cfg << "EOF"
listen rabbitmq_amqp
    bind *:5672
    mode tcp
    balance roundrobin
    option tcp-check
    server rabbitmq-01 192.168.99.139:5672 check
    server rabbitmq-02 192.168.99.140:5672 check
    server rabbitmq-03 192.168.99.141:5672 check

listen rabbitmq_ui
    bind *:15672
    mode http
    balance roundrobin
    option httpchk GET /
    server rabbitmq-01 192.168.99.139:15672 check
    server rabbitmq-02 192.168.99.140:15672 check
    server rabbitmq-03 192.168.99.141:15672 check
EOF

sudo systemctl restart haproxy
sudo systemctl enable haproxy

#################### Step10: Producer/Consumer HA ###############################

#Create producer.py on app01

tee -a producer.py << "EOF"

import pika
import json
import time

credentials = pika.PlainCredentials("admin", "Admin@123")

connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host="192.168.100.9",
        port=5672,
        credentials=credentials
    )
)

channel = connection.channel()

message = {
    "event": "student.created",
    "student_id": "S1001",
    "name": "Nguyen Van A",
    "grade": "Grade 10"
}

channel.basic_publish(
    exchange="school_events",
    routing_key="",
    body=json.dumps(message),
    properties=pika.BasicProperties(
        delivery_mode=2
    )
)

print("Message sent:", message)

connection.close()

EOF

#Install library
python3 -m venv ~/venv
source ~/venv/bin/activate
pip install pika


#run python producer.py
python3 producer.py

