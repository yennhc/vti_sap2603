#!/bin/bash

#1. Install openSSH server
sudo apt install -y openssh-server

#2. Generate key pair
ssh-key-gen -t rsa -b 4096

#Check key pair
ls -l ~/.ssh

#3. Copy public key to server
ssh-copy-id username@server_ip

#Check public key in server
cat ~/.ssh/authorized_keys

#Check SSH service
systemctl status ssh

#4. Don't use password to login
sudo vim /etc/ssh/sshd_config
#Change PasswordAuthentication to no
PasswordAuthentication no
#Restart SSH service
sudo systemctl restart ssh

#Login with key
ssh username@server_ip





