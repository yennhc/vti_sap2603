#!/bin/bash

#Mục tiêu: dựng Kafka cluster 3 node chạy KRaft (không dùng ZooKeeper), tạo dữ liệu, sao lưu lạnh (cold backup), phục hồi và kiểm chứng dữ liệu.

#Step 1: Set the environment variables
# ip kafka:
export KAFKA_IP_01=192.168.99.132
export KAFKA_IP_02=192.168.99.133
export KAFKA_IP_03=192.168.99.134

#Step 2: Set hostname for each kafka node
export KAFKA_HOSTNAME_01=kafka-01   
export KAFKA_HOSTNAME_02=kafka-02
export KAFKA_HOSTNAME_03=kafka-03

sudo hostnamectl set-hostname $KAFKA_HOSTNAME_01
sudo hostnamectl set-hostname $KAFKA_HOSTNAME_02
sudo hostnamectl set-hostname $KAFKA_HOSTNAME_03

#Step 3: Set /etc/hosts file for each kafka node
echo "$KAFKA_IP_01 $KAFKA_HOSTNAME_01" | sudo tee -a /etc/hosts
echo "$KAFKA_IP_02 $KAFKA_HOSTNAME_02" | sudo tee -a /etc/hosts
echo "$KAFKA_IP_03 $KAFKA_HOSTNAME_03" | sudo tee -a /etc/hosts

#Step 4: Install Java Development Kit (JDK) on each kafka node
sudo apt update
sudo apt install -y openjdk-17-jre-headless wget tar
java -version

export KAFKA_VERSION='4.3.1'
cd /tmp
wget https://downloads.apache.org/kafka/$KAFKA_VERSION/kafka_2.13-$KAFKA_VERSION.tgz
tar -xzf kafka_2.13-$KAFKA_VERSION.tgz
sudo mv kafka_2.13-$KAFKA_VERSION /opt/kafka
sudo chown -R $USER:$USER /opt/kafka

#Step 5: Create a kafka user and group, and set up directories for Kafka data and configuration
id -u kafka >/dev/null 2>&1 || sudo useradd --system --home /var/lib/kafka --shell /usr/sbin/nologin kafka
sudo install -d -o kafka -g kafka -m 0750 /var/lib/kafka/data /var/lib/kafka/metadata
sudo install -d -o root -g kafka -m 0750 /etc/kafka

#Step 6: Configure Kafka broker properties for each node
# Create a configuration file for each Kafka broker

#kafka-01
sudo tee /etc/kafka/server-1.properties > /dev/null <<EOL

process.roles=broker,controller
node.id=1

# Dùng IP cố định để controller quorum không phụ thuộc DNS / /etc/hosts.
controller.quorum.voters=1@192.168.99.132:9093,2@192.168.99.133:9093,3@192.168.99.134:9093
controller.listener.names=CONTROLLER
listeners=PLAINTEXT://192.168.99.132:9092,CONTROLLER://192.168.99.132:9093
advertised.listeners=PLAINTEXT://192.168.99.132:9092
inter.broker.listener.name=PLAINTEXT
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT

log.dirs=/var/lib/kafka/data
metadata.log.dir=/var/lib/kafka/metadata

num.partitions=3
default.replication.factor=3
min.insync.replicas=2
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
group.initial.rebalance.delay.ms=0
auto.create.topics.enable=false

EOL

#kafka-02
sudo tee /etc/kafka/server-2.properties > /dev/null <<EOL
process.roles=broker,controller
node.id=2
controller.quorum.voters=1@192.168.99.132:9093,2@192.168.99.133:9093,3@192.168.99.134:9093
controller.listener.names=CONTROLLER
listeners=PLAINTEXT://192.168.99.133:9092,CONTROLLER://192.168.99.133:9093
advertised.listeners=PLAINTEXT://192.168.99.133:9092
inter.broker.listener.name=PLAINTEXT
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
log.dirs=/var/lib/kafka/data
metadata.log.dir=/var/lib/kafka/metadata
num.partitions=3
default.replication.factor=3
min.insync.replicas=2
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
group.initial.rebalance.delay.ms=0
auto.create.topics.enable=false
EOL

#kafka-03
sudo tee /etc/kafka/server-3.properties > /dev/null <<EOL
process.roles=broker,controller
node.id=3
controller.quorum.voters=1@192.168.99.132:9093,2@192.168.99.133:9093,3@192.168.99.134:9093
controller.listener.names=CONTROLLER
listeners=PLAINTEXT://192.168.99.134:9092,CONTROLLER://192.168.99.134:9093
advertised.listeners=PLAINTEXT://192.168.99.134:9092
inter.broker.listener.name=PLAINTEXT
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
log.dirs=/var/lib/kafka/data
metadata.log.dir=/var/lib/kafka/metadata
num.partitions=3
default.replication.factor=3
min.insync.replicas=2
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
group.initial.rebalance.delay.ms=0
auto.create.topics.enable=false
EOL

#Assign ownership of the configuration files to the kafka user
#kafka-01
sudo chown root:kafka /etc/kafka/server-1.properties
sudo chmod 0640 /etc/kafka/server-1.properties

#kafka-02
sudo chown root:kafka /etc/kafka/server-2.properties
sudo chmod 0640 /etc/kafka/server-2.properties

#kafka-03
sudo chown root:kafka /etc/kafka/server-3.properties
sudo chmod 0640 /etc/kafka/server-3.properties


#Create cluster ID and format the metadata log directory on each node
#kafka-01
/opt/kafka/bin/kafka-storage.sh random-uuid > /tmp/cluster-id.txt
export KAFKA_CLUSTER_ID=$(cat /tmp/cluster-id.txt)
/opt/kafka/bin/kafka-storage.sh format -t $KAFKA_CLUSTER_ID --config /etc/kafka/server-1.properties

#kafka-02
/opt/kafka/bin/kafka-storage.sh format -t $KAFKA_CLUSTER_ID --config /etc/kafka/server-2.properties

#kafka-03
/opt/kafka/bin/kafka-storage.sh format -t $KAFKA_CLUSTER_ID --config /etc/kafka/server-3.properties

#Step 7: Create systemd service files for each Kafka broker

#Kafka service files will be created for each node to manage the Kafka brokers as systemd services. This allows for easy starting, stopping, and enabling of the Kafka services on boot.
KAFKA_HOME="$(readlink -f /opt/kafka)"
sudo install -d -o kafka -g kafka -m 0750 "$KAFKA_HOME/logs"
sudo chown -R kafka:kafka "$KAFKA_HOME/logs"

#kafka-01
sudo tee /etc/systemd/system/kafka-1.service > /dev/null <<EOL
[Unit]
Description=Apache Kafka Server (kafka-01)
After=network.target
Wants=network.target
[Service]
Type=simple
User=kafka
Group=kafka
ExecStart=/opt/kafka/bin/kafka-server-start.sh /etc/kafka/server-1.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOL

#kafka-02
sudo tee /etc/systemd/system/kafka-2.service > /dev/null <<EOL
[Unit]
Description=Apache Kafka Server (kafka-02)
After=network.target
Wants=network.target
[Service]
Type=simple
User=kafka
Group=kafka
ExecStart=/opt/kafka/bin/kafka-server-start.sh /etc/kafka/server-2.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOL

#kafka-03
sudo tee /etc/systemd/system/kafka-3.service > /dev/null <<EOL
[Unit]
Description=Apache Kafka Server (kafka-03)
After=network.target
Wants=network.target
[Service]
Type=simple
User=kafka
Group=kafka
ExecStart=/opt/kafka/bin/kafka-server-start.sh /etc/kafka/server-3.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOL

#Step 8: Start the Kafka brokers and enable them to start on boot
# Start the Kafka brokers on each node and enable them to start automatically on system boot.
#kafka-01
sudo systemctl daemon-reload
sudo systemctl start kafka-1
sudo systemctl enable kafka-1

#kafka-02
sudo systemctl daemon-reload
sudo systemctl start kafka-2
sudo systemctl enable kafka-2

#kafka-03
sudo systemctl daemon-reload
sudo systemctl start kafka-3
sudo systemctl enable kafka-3

#Health check: Verify that the Kafka brokers are running and the cluster is healthy by checking the status of each service.
#kafka-01
sudo systemctl status kafka-1

sudo ss -lntp | grep -E ':9092|:9093'

for ip in 192.168.99.132 192.168.99.133 192.168.99.134; do
  timeout 2 bash -c "echo >/dev/tcp/$ip/9093" \
    && echo "$ip:9093 OK" \
    || echo "$ip:9093 FAILED"
done

#kafka-02
sudo systemctl status kafka-2
sudo ss -lntp | grep -E ':9092|:9093'
for ip in 192.168.99.132 192.168.99.133 192.168.99.134; do
  timeout 2 bash -c "echo >/dev/tcp/$ip/9093" \
    && echo "$ip:9093 OK" \
    || echo "$ip:9093 FAILED"
done

#kafka-03
sudo systemctl status kafka-3
sudo ss -lntp | grep -E ':9092|:9093'
for ip in 192.168.99.132 192.168.99.133 192.168.99.134; do
  timeout 2 bash -c "echo >/dev/tcp/$ip/9093" \
    && echo "$ip:9093 OK" \
    || echo "$ip:9093 FAILED"
done

#Step 9: Create a topic and produce/consume messages
# Create a topic named "test-topic" with 3 partitions and a replication factor of 3. Then, produce some messages to the topic and consume them to verify that the cluster is working correctly.
$BOOTSTRAP="192.168.99.132:9092,192.168.99.133:9092,192.168.99.134:9092"

/opt/kafka/bin/kafka-topics.sh --create --topic test-topic --partitions 3 --replication-factor 3 --bootstrap-server $BOOTSTRAP
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server $BOOTSTRAP
/opt/kafka/bin/kafka-topics.sh --bootstrap-server $BOOTSTRAP --describe --topic orders

printf "Producing messages to test-topic...\n"
for i in {1..10}; do
  echo "Message $i" | /opt/kafka/bin/kafka-console-producer.sh --topic test-topic --bootstrap-server $BOOTSTRAP
done

printf "Consuming messages from test-topic...\n"
/opt/kafka/bin/kafka-console-consumer.sh --topic test-topic --from-beginning --bootstrap-server $BOOTSTRAP --timeout-ms 10000



