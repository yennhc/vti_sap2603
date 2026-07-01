# Config MongoDB Replica Set

Create a replica set with 3 members:
- Primary: `mgdb-primary` (172.19.78.2)
- Secondary: `mgdb-secondary1` (172.19.78.3)
- Secondary: `mgdb-secondary2` (172.19.78.4)

## Step 1: Install MongoDB on each member

### On mgdb-primary
```bash
sudo apt-get update
sudo apt install -y gnupg curl
curl -fsSL https://pgp.mongodb.com/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
echo "deb [ arch=arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org 
```

### On mgdb-secondary1
```bash
sudo apt-get update
sudo apt install -y gnupg curl
curl -fsSL https://pgp.mongodb.com/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
echo "deb [ arch=arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org 
```

### On mgdb-secondary2
```bash
sudo apt-get update
sudo apt install -y gnupg curl
curl -fsSL https://pgp.mongodb.com/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
echo "deb [ arch=arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org
```

## Step 2: Configure MongoDB on each member

### On mgdb-primary
```bash
sudo sed -i 's#bindIp: 127.0.0.1#bindIp: 127.0.0.1,172.19.78.2#' /etc/mongod.conf
sudo sed -i 's/#replication:/replication:\n  replSetName: "rs0"/' /etc/mongod.conf
```

### On mgdb-secondary1
```bash
sudo sed -i 's#bindIp: 127.0.0.1#bindIp: 127.0.0.1,172.19.78.3#' /etc/mongod.conf
sudo sed -i 's/#replication:/replication:\n  replSetName: "rs0"/' /etc/mongod.conf  
```

### On mgdb-secondary2
```bash
sudo sed -i 's#bindIp: 127.0.0.1#bindIp: 127.0.0.1,172.19.78.4#' /etc/mongod.conf
sudo sed -i 's/#replication:/replication:\n  replSetName: "rs0"/' /etc/mongod.conf
```


## Step 3: Start MongoDB on each member

### On mgdb-primary
```bash
sudo systemctl restart mongod
sudo systemctl enable mongod
sudo systemctl status mongod
```

### On mgdb-secondary1
```bash
sudo systemctl start mongod
sudo systemctl enable mongod
sudo systemctl status mongod
```

### On mgdb-secondary2
```bash
sudo systemctl restart mongod
sudo systemctl enable mongod
sudo systemctl status mongod
```

## Step 4: Initiate the replica set

### On mgdb-primary
Connect to mongosh:
```bash
mongosh --host 127.0.0.1:27017
```

Run the following commands in the MongoDB shell:
```javascript
rs.initiate(
   {
      _id: "rs0",
      members: [
         { _id: 0, host: "172.19.78.2:27017" },
         { _id: 1, host: "172.19.78.3:27017" },
         { _id: 2, host: "172.19.78.4:27017" }
      ]
   }
)

// Check the status of the replica set
rs.status()

// Set the priority of the members to ensure mgdb-primary is the primary member
cfg = rs.conf()

cfg.members[0].priority = 3
cfg.members[1].priority = 1
cfg.members[2].priority = 1

rs.reconfig(cfg)
```

### Test connection to secondary members
```bash
nc -zv 172.19.78.3 27017
nc -zv 172.19.78.4 27017
```


## Step 5: Verify the replica set is working

### On mgdb-primary
Insert a document into the primary member:
```javascript
use testdb
db.testcollection.insertOne({ name: "MongoDB Replica Set", status: "Working" })
```

### On mgdb-secondary1
Check if the document is replicated to the secondary member:
```javascript
use testdb
db.testcollection.find()
```

### On mgdb-secondary2
Check if the document is replicated to the secondary member:
```javascript
use testdb
db.testcollection.find()    
```
