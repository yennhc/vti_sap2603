**pfSense → Syslog (UDP/TCP 514) → Logstash → Elasticsearch → Kibana**

Using **Logstash as the syslog collector**, then parsing pfSense firewall logs before indexing them.

### 1. Architecture

```text
                    ┌─────────────────┐
                    │     pfSense     │
                    │                 │
                    │ Firewall logs   │
                    │ DHCP / VPN /    │
                    │ System logs     │
                    └────────┬────────┘
                             │
                       Syslog UDP/TCP
                          port 514
                             │
                             ▼
                    ┌─────────────────┐
                    │    Logstash     │
                    │                 │
                    │ syslog input    │
                    │ grok/filter     │
                    └────────┬────────┘
                             │
                          HTTP/HTTPS
                             │
                             ▼
                    ┌─────────────────┐
                    │ Elasticsearch   │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │     Kibana      │
                    └─────────────────┘
```

## 2. Configure pfSense

Go to:

**Status → System Logs → Settings**

Find:

**Remote Logging Options**

Enable remote logging and enter your ELK/Logstash server IP.

For example:

```text
Remote log servers:
192.168.10.50:514
```

Select the logs you want to send.

For a SIEM-style setup, I recommend initially selecting:

- Firewall events
- System events
- DHCP
- DNS
- VPN
- Authentication
- General system logs

If your pfSense version offers **Remote Syslog Contents**, enable the categories you need rather than sending everything.

### Protocol

Start with:

```text
UDP 514
```

It's simple and is commonly used for firewall syslog.

For a production environment where log delivery reliability matters, consider TCP/TLS if your pfSense and Logstash configuration support it.

---

# 3. Configure Logstash

On your ELK server, first check whether something is already using port 514.

You previously had an issue where **rsyslog was already occupying UDP/TCP 514**, so this is important.

Run:

```bash
sudo ss -lntup | grep :514
```

or:

```bash
sudo lsof -i :514
```

If you see:

```text
rsyslog
```

then Logstash cannot bind to 514.

You have two choices.

### Option A — Let Logstash own port 514

Stop rsyslog:

```bash
sudo systemctl stop rsyslog
sudo systemctl disable rsyslog
```

Then configure Logstash directly on 514.

### Option B — Keep rsyslog

Use:

```text
pfSense
   ↓
UDP 514
   ↓
rsyslog
   ↓
Logstash
   ↓
Elasticsearch
```

For your existing ELK lab, **Option A is simpler**.

---

# 4. Logstash input

Create:

```bash
sudo nano /etc/logstash/conf.d/pfsense.conf
```

Start with:

```ruby
input {
  udp {
    port => 514
    type => "pfsense"
  }
}
```

Then add Elasticsearch output:

```ruby
output {
  if [type] == "pfsense" {
    elasticsearch {
      hosts => ["https://127.0.0.1:9200"]
      index => "pfsense-%{+YYYY.MM.dd}"

      user => "elastic"
      password => "YOUR_ELASTIC_PASSWORD"

      ssl_certificate_verification => false
    }
  }
}
```

And initially:

```ruby
filter {
}
```

So the complete initial configuration is:

```ruby
input {
  udp {
    port => 514
    type => "pfsense"
  }
}

filter {
}

output {
  if [type] == "pfsense" {
    elasticsearch {
      hosts => ["https://127.0.0.1:9200"]
      index => "pfsense-%{+YYYY.MM.dd}"

      user => "elastic"
      password => "YOUR_ELASTIC_PASSWORD"

      ssl_certificate_verification => false
    }
  }
}
```

---

# 5. Test Logstash configuration

Run:

```bash
sudo /usr/share/logstash/bin/logstash \
  --path.settings /etc/logstash \
  --config.test_and_exit
```

You should get:

```text
Configuration OK
```

Then:

```bash
sudo systemctl restart logstash
```

Check:

```bash
sudo systemctl status logstash
```

And:

```bash
sudo journalctl -u logstash -f
```

---

# 6. Verify pfSense is actually sending logs

On the ELK server:

```bash
sudo tcpdump -ni any port 514
```

Then generate traffic through pfSense.

You should see something similar to:

```text
IP 192.168.10.1.514 > 192.168.10.50.514
```

If you see packets here, the network path is working.

This is an important troubleshooting distinction:

```text
No packets
    ↓
pfSense / network / firewall problem

Packets received
    ↓
Logstash problem

Logstash receives events
    ↓
Elasticsearch/indexing problem
```

---

# 7. Check Elasticsearch

After generating some firewall events:

```bash
curl -k -u elastic:YOUR_PASSWORD \
https://127.0.0.1:9200/_cat/indices?v
```

You should see:

```text
pfsense-2026.08.10
```

Then:

```bash
curl -k -u elastic:YOUR_PASSWORD \
https://127.0.0.1:9200/pfsense-*/_search?pretty
```

You should see pfSense events.

---

# 8. Configure Kibana

Go to:

**Stack Management → Data Views**

Create:

```text
pfsense-*
```

For the timestamp field, select:

```text
@timestamp
```

Then go to:

**Discover**

Select:

```text
pfsense-*
```

You should now see your pfSense events.

---

# 9. Next step: parse pfSense firewall logs

The above configuration gets the raw syslog into Elasticsearch.

But for a **proper ELK/SIEM implementation**, don't stop there.

You want fields such as:

```text
source.ip
source.port
destination.ip
destination.port
network.transport
network.protocol
event.action
event.outcome
observer.name
rule.id
interface
direction
action
```

For example:

```text
192.168.1.100
        │
        │ TCP/443
        ▼
   8.8.8.8:443
        │
        ▼
     pfSense
        │
        ▼
    Logstash
        │
        ├── source.ip = 192.168.1.100
        ├── destination.ip = 8.8.8.8
        ├── destination.port = 443
        ├── network.transport = tcp
        ├── action = pass
        └── interface = LAN
```

That makes Kibana much more useful for searching and dashboards.

## 10. Recommended final architecture

For your ELK environment, I'd build it like this:

```text
                    pfSense
                       │
              Syslog UDP/TCP 514
                       │
                       ▼
                ┌─────────────┐
                │  Logstash   │
                │             │
                │ UDP 514     │
                │             │
                │ GROK        │
                │ KV          │
                │ ECS mapping │
                └──────┬──────┘
                       │
                       ▼
              Elasticsearch
                       │
             pfsense-* index
                       │
                       ▼
                    Kibana
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Firewall       VPN         DNS/DHCP
       Dashboard    Dashboard     Dashboard
```

