# LAB Ansible + HAProxy

Created by: Yen Nguyen Hoa Cat
Created time: June 13, 2026 5:09 PM

# LAB: Ansible + HAProxy Load Balancer

Lab này mô phỏng kiến trúc production cơ bản:

- 1 HAProxy Load Balancer
- 2 Nginx Web Servers
- Deploy toàn bộ bằng Ansible

Bạn sẽ học được:

- Multi-tier inventory
- HAProxy template
- Dynamic backend generation bằng Jinja2
- Ansible facts
- Handlers
- Rolling update cơ bản
- Health check
- Reverse proxy architecture

HAProxy là một trong những load balancer phổ biến nhất cho production environments. 

---

# Architecture

```
                    CLIENT
                       |
                       |
                +-------------+
                |  HAProxy    |
                |  lb01       |
                +-------------+
                 /           \
                /             \
       +-------------+   +-------------+
       |    web1     |   |    web2     |
       |   Nginx     |   |   Nginx     |
       +-------------+   +-------------+
```

---

# Environment

| Hostname | Role | IP |
| --- | --- | --- |
| lb01 | HAProxy | 192.168.100.205 |
| web1 | Nginx | 192.168.100.206 |
| web2 | Nginx | 192.168.100.207 |

Ubuntu 22.04+

---

# Project Structure

```bash
ansible-haproxy-lab/
├── inventory.ini
├── site.yml
├── group_vars/
│   ├── webservers.yml
│   └── loadbalancers.yml
├── roles/
│   ├── nginx/
│   │   ├── tasks/
│   │   ├── handlers/
│   │   ├── templates/
│   │   └── defaults/
│   └── haproxy/
│       ├── tasks/
│       ├── handlers/
│       ├── templates/
│       └── defaults/
```

---

# STEP 1 — Create Project

```bash
mkdir -p ansible-haproxy-lab
cd ansible-haproxy-lab
```

---

# STEP 2 — Create Inventory

## inventory.ini

```
[loadbalancers]
lb01 ansible_host=192.168.100.205

[webservers]
web1 ansible_host=192.168.100.206
web2 ansible_host=192.168.100.207

[all:vars]
ansible_user=ubuntu
ansible_python_interpreter=/usr/bin/python3
```

---

# STEP 3 — Create Main Playbook

## site.yml

```yaml
---
- name: Configure Web Servers
  hosts: webservers
  become: yes

  roles:
    - nginx

- name: Configure Load Balancer
  hosts: loadbalancers
  become: yes

  roles:
    - haproxy
```

---

# STEP 4 — Create Roles

```bash
ansible-galaxy init roles/nginx
ansible-galaxy init roles/haproxy
```

---

# STEP 5 — Configure Nginx Role

## roles/nginx/tasks/main.yml

```yaml
---
- name: Install nginx
  apt:
    name: nginx
    state: present
    update_cache: yes

- name: Deploy index page
  template:
    src: index.html.j2
    dest: /var/www/html/index.html
  notify:
    - restart nginx

- name: Ensure nginx running
  service:
    name: nginx
    state: started
    enabled: yes
```

---

# STEP 6 — Nginx Template

## roles/nginx/templates/index.html.j2

```html
<!DOCTYPE html>
<html>
<head>
    <title>Ansible HAProxy Lab</title>
</head>
<body>

<h1>Hello from {{ inventory_hostname }}</h1>

<p>Managed by Ansible</p>

<p>Server IP: {{ ansible_host }}</p>

</body>
</html>
```

---

# STEP 7 — Nginx Handler

## roles/nginx/handlers/main.yml

```yaml
---
- name: restart nginx
  service:
    name: nginx
    state: restarted
```

---

# STEP 8 — Configure HAProxy Role

## roles/haproxy/tasks/main.yml

```yaml
---
- name: Install haproxy
  apt:
    name: haproxy
    state: present
    update_cache: yes

- name: Deploy HAProxy config
  template:
    src: haproxy.cfg.j2
    dest: /etc/haproxy/haproxy.cfg
  notify:
    - restart haproxy

- name: Ensure haproxy running
  service:
    name: haproxy
    state: started
    enabled: yes
```

---

# STEP 9 — HAProxy Template

## roles/haproxy/templates/haproxy.cfg.j2

```
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon

defaults
    mode http
    timeout connect 5s
    timeout client  50s
    timeout server  50s

frontend http_front
    bind *:80
    default_backend web_back

backend web_back
    balance roundrobin

{% for host in groups['webservers'] %}
    server {{ host }} {{ hostvars[host]['ansible_host'] }}:80 check
{% endfor %}
```

Đây là phần quan trọng nhất của lab:

```
{% for host in groups['webservers'] %}
```

HAProxy backend sẽ tự động generate theo inventory.

---

# STEP 10 — HAProxy Handler

## roles/haproxy/handlers/main.yml

```yaml
---
- name: restart haproxy
  service:
    name: haproxy
    state: restarted
```

---

# STEP 11 — Test SSH Connectivity

```bash
ansible all -i inventory.ini -m ping
```

Expected:

```
web1 | SUCCESS
web2 | SUCCESS
lb01 | SUCCESS
```

---

# STEP 12 — Run Playbook

```bash
ansible-playbook -i inventory.ini site.yml
```

---

# STEP 13 — Verify

Open browser:

```
http://192.168.1.100
```

Refresh nhiều lần.

Bạn sẽ thấy response thay đổi:

```
Hello from web1
```

và

```
Hello from web2
```

Đây là HAProxy round-robin load balancing.

---

# STEP 14 — Verify HAProxy Config

SSH vào lb01:

```bash
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
```

Expected:

```
Configuration file is valid
```

---

# STEP 15 — Verify Backend Health

```bash
systemctl status haproxy
```

Test health check:

```bash
curl http://192.168.1.101
curl http://192.168.1.102
```

---

# STEP 16 — Simulate Failure

Stop nginx trên web2:

```bash
sudo systemctl stop nginx
```

Refresh browser trên:

```
http://192.168.1.100
```

Traffic sẽ chỉ đi qua web1.

HAProxy health check sẽ tự remove unhealthy backend.

HAProxy health checking là một feature cực kỳ quan trọng trong production systems. ([arXiv](https://arxiv.org/abs/2212.14198?utm_source=chatgpt.com))

---

# STEP 17 — Add Variables

## group_vars/loadbalancers.yml

```yaml
haproxy_frontend_port: 80
haproxy_backend_port: 80
```

Update template:

```
bind *:{{ haproxy_frontend_port }}
```

và:

```
server {{ host }} {{ hostvars[host]['ansible_host'] }}:{{ haproxy_backend_port }} check
```

---

# STEP 18 — Add Stats Page (Intermediate+)

## Update haproxy.cfg.j2

```
listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
```

Run playbook again.

Open:

```
http://192.168.1.100:8404/stats
```

Bạn sẽ thấy:

- backend status
- health checks
- session count
- traffic metrics

---

# STEP 19 — Add Rolling Deployment

## Update site.yml

```yaml
- name: Configure Web Servers
  hosts: webservers
  serial: 1
  become: yes

  roles:
    - nginx
```

`serial: 1` giúp update từng server một.

Đây là nền tảng của zero-downtime deployment.

---

# Kỹ năng bạn học được

| Skill | Level |
| --- | --- |
| Reverse Proxy | Intermediate |
| Load Balancing | Intermediate |
| HAProxy | Intermediate |
| Dynamic Templates | Intermediate |
| Jinja2 loops | Intermediate |
| Health Checks | Intermediate |
| Rolling Deployment | Intermediate |
| Multi-host automation | Intermediate |
| Inventory grouping | Intermediate |

---

# Production Concepts bạn vừa thực hành

| Concept | Meaning |
| --- | --- |
| Reverse Proxy | Frontend nhận request |
| Load Balancing | Chia traffic |
| Health Check | Detect failed backend |
| High Availability | Tăng uptime |
| Rolling Update | Update không downtime |
| Infrastructure as Code | Automation bằng Ansible |
