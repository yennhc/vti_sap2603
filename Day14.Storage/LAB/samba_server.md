To install an SMB server on Ubuntu, the most common solution is **Samba**, which implements the SMB/CIFS protocol and allows Windows, Linux, and macOS systems to share files. [\[ubuntu.com\]](https://ubuntu.com/server/docs/how-to/samba/file-server/), [\[ubuntu.com\]](https://ubuntu.com/tutorials/install-and-configure-samba)

### 1. Install Samba

```bash
sudo apt update
sudo apt install samba
```

This installs the Samba server packages. [\[ubuntu.com\]](https://ubuntu.com/server/docs/how-to/samba/file-server/), [\[phoenixnap.com\]](https://phoenixnap.com/kb/ubuntu-samba)

### 2. Create a Shared Directory

For example:

```bash
sudo mkdir -p /srv/samba/share
sudo chmod 775 /srv/samba/share
```

Ubuntu's documentation commonly uses `/srv/samba/share` for shared data. [\[ubuntu.com\]](https://ubuntu.com/server/docs/how-to/samba/file-server/)

### 3. Configure Samba

Edit the Samba configuration file:

```bash
sudo nano /etc/samba/smb.conf
```

Add the following at the end:

```ini
[share]
   comment = Ubuntu File Server Share
   path = /srv/samba/share
   browsable = yes
   guest ok = yes
   read only = no
   create mask = 0755
```

This creates a writable share named `share` that can be browsed by clients. [\[ubuntu.com\]](https://ubuntu.com/server/docs/how-to/samba/file-server/)

### 4. Validate the Configuration

```bash
testparm
```

This checks the Samba configuration for syntax errors.

### 5. Restart Samba

```bash
sudo systemctl restart smbd
sudo systemctl enable smbd
```

Verify:

```bash
sudo systemctl status smbd
```

 [\[phoenixnap.com\]](https://phoenixnap.com/kb/ubuntu-samba)

### 6. Allow Samba Through the Firewall (if UFW is enabled)

```bash
sudo ufw allow samba
```

 [\[geeksforgeeks.org\]](https://www.geeksforgeeks.org/linux-unix/how-to-install-and-configure-samba-in-ubuntu/)

### 7. Create a Samba User (Recommended)

If you want authenticated access:

```bash
sudo smbpasswd -a <username>
```

Example:

````bash
sudo smbpasswd -a yen
```

### 8. Access the Share

From Windows Explorer:

```text
\\<ubuntu-ip>\share
````

Example:

```text
\\192.168.1.100\share
```

Find your server IP:

```bash
ip addr
```

### Useful Commands

Check Samba shares:

```bash
sudo smbclient -L localhost -U%
```

Check Samba version:

````bash
samba -V
```

For a Networking Engineer setup with user authentication and Active Directory integration, Samba can also be configured as a domain member or AD-compatible file server.
````
