# NFS Server Installation

```bash
#!/bin/bash

#Install nfs server
sudo apt update && sudo apt install -y nfs-kernel-server

#Create share folder 
sudo mkdir -p /mnt/nfs_share
sudo chown nobody:nogroup /mnt/nfs_share
sudo chmod 777 /mnt/nfs_share

#Create NFS exports
# /mnt/nfs_share <ip_address>(rw,sync,no_subtree_check,insecure)
echo "/mnt/nfs_share 192.168.100.0/24(rw,sync,no_subtree_check,insecure)" | sudo tee -a /etc/exports

#Restart NFS server
sudo systemctl restart nfs-kernel-server

#Enable NFS server at boot
sudo systemctl enable nfs-server

#Check NFS server status
sudo systemctl status nfs-server


#Firewall configuration (Ubuntu/Debian)
sudo ufw allow from [IP_ADDRESS] to any port nfs
sudo ufw reload

#On NFS Client 
sudo apt update && sudo apt install -y nfs-common
sudo mkdir -p /mnt/nfs_share
sudo mount [IP_ADDRESS]:/mnt/nfs_share /mnt/nfs_share
sudo df -h
```
