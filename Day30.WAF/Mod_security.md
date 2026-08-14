# Install ModSecurity for Apache on Ubuntu 24.04

## 1. Update the system

```bash
sudo apt update
sudo apt upgrade -y
```

***

## 2. Install ModSecurity

Ubuntu 24.04 provides the Apache ModSecurity package in the default repository. [\[server-world.info\]](https://www.server-world.info/en/note?os=Ubuntu_24.04&p=httpd&f=14), [\[tecmint.com\]](https://www.tecmint.com/install-modsecurity-with-apache-on-debian-ubuntu/)

```bash
sudo apt install -y libapache2-mod-security2
```

Verify the package is installed:

```bash
dpkg -l | grep mod-security
```

***

## 3. Enable the ModSecurity module

```bash
sudo a2enmod security2
sudo systemctl restart apache2
```

Verify the module is loaded:

```bash
apachectl -M | grep security
```

Expected output:

````text
security2_module (shared)
```

---

## 4. Create the ModSecurity configuration file

By default, Ubuntu installs `modsecurity.conf-recommended`. Copy it to the active configuration file. 

```bash
sudo cp /etc/modsecurity/modsecurity.conf-recommended \
        /etc/modsecurity/modsecurity.conf
````

***

## 5. Enable protection mode

Edit the configuration:

```bash
sudo nano /etc/modsecurity/modsecurity.conf
```

Find:

```apache
SecRuleEngine DetectionOnly
```

Change to:

```apache
SecRuleEngine On
```

This switches ModSecurity from logging-only mode to actively blocking malicious requests. [\[server-world.info\]](https://www.server-world.info/en/note?os=Ubuntu_24.04&p=httpd&f=14), [\[tecmint.com\]](https://www.tecmint.com/install-modsecurity-with-apache-on-debian-ubuntu/)

***

## 6. Install OWASP Core Rule Set (CRS)

Recommended for real protection.

```bash
sudo apt install -y modsecurity-crs
```

Confirm the rule files exist:

```bash
ls -l /usr/share/modsecurity-crs/
```

Ubuntu/Debian packages typically configure CRS automatically. [\[tecmint.com\]](https://www.tecmint.com/install-modsecurity-with-apache-on-debian-ubuntu/)

***

## 7. Reload Apache

```bash
sudo systemctl reload apache2
```

Check configuration:

```bash
sudo apachectl configtest
```

Expected:

```text
Syntax OK
```

***

## 8. Verify ModSecurity is working

Check audit logs:

```bash
sudo tail -f /var/log/apache2/modsec_audit.log
```

 [\[server-world.info\]](https://www.server-world.info/en/note?os=Ubuntu_24.04&p=httpd&f=14)

You can test with a simple request:

```bash
curl "http://YOUR_SERVER/?test=<script>alert(1)</script>"
```

If CRS is active, the request should be logged or blocked depending on your configuration.

***

## Useful files

```text
/etc/modsecurity/modsecurity.conf
/etc/modsecurity/unicode.mapping
/etc/apache2/mods-enabled/security2.conf
/usr/share/modsecurity-crs/
/var/log/apache2/modsec_audit.log
```

For a production server, a common next step is to tune the OWASP CRS paranoia level and whitelist any false positives specific to your applications.
