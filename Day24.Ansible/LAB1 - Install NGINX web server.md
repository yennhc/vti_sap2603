# LAB1 - Install NGINX web server

Dưới đây là **bài lab Ansible cài Nginx Web Server cho 2 máy chủ Ubuntu**.

## 1. Mô hình lab

```
Ansible Control Node
192.168.1.10
        |
        | SSH
        |
+-------------------+      +-------------------+
| Web Server 1      |      | Web Server 2      |
| 192.168.1.21      |      | 192.168.1.22      |
| Ubuntu Server     |      | Ubuntu Server     |
| Nginx             |      | Nginx             |
+-------------------+      +-------------------+
```

## 2. Yêu cầu

Trên máy Ansible Control Node:

```bash
sudo apt update
sudo apt install ansible -y
```

Kiểm tra:

```bash
ansible --version
```

## 3. Tạo SSH key

Trên máy Ansible:

```bash
ssh-keygen
```

Copy key sang 2 web server:

```bash
ssh-copy-id sysadmin@192.168.1.21
ssh-copy-id sysadmin@192.168.1.22
```

Test SSH:

```bash
ssh sysadmin@192.168.1.21
ssh sysadmin@192.168.1.22
```

## 4. Tạo thư mục lab

```bash
mkdir ansible-nginx-lab
cd ansible-nginx-lab
```

## 5. Tạo inventory file

Tạo file:

```bash
nano inventory.ini
```

Nội dung:

```
[webservers]
web1 ansible_host=192.168.1.21
web2 ansible_host=192.168.1.22

[webservers:vars]
ansible_user=sysadmin
ansible_become=yes
```

## 6. Test kết nối Ansible

```bash
ansible -i inventory.ini webservers -m ping
```

```jsx
#Lỗi yêu cầu pass sudo khi chạy ansible có thể được fix bằng cách cho user chạy ansible không cần sudo password 

sudo visudo 

# Thêm vào cuối file config
ynguyen ALL=(ALL) NOPASSWD: ALL
```

Kết quả đúng:

```
web1 | SUCCESS
web2 | SUCCESS
```

## 7. Tạo playbook cài Nginx

Tạo file:

```bash
nano install-nginx.yml
```

Nội dung:

```yaml
---
- name: Install and configure Nginx on two web servers
  hosts: webservers
  become: yes

  tasks:
    - name: Update apt package cache
      apt:
        update_cache: yes

    - name: Install Nginx
      apt:
        name: nginx
        state: present

    - name: Start and enable Nginx service
      service:
        name: nginx
        state: started
        enabled: yes

    - name: Create custom index.html
      copy:
        dest: /var/www/html/index.html
        content: |
          <html>
          <head>
              <title>Ansible Nginx Lab</title>
          </head>
          <body>
              <h1>Hello from {{ inventory_hostname }}</h1>
              <p>This Nginx web server was installed by Ansible.</p>
          </body>
          </html>

    - name: Allow HTTP through UFW
      ufw:
        rule: allow
        port: '80'
        proto: tcp
      ignore_errors: yes
```

## 8. Chạy playbook

```bash
ansible-playbook -i inventory.ini install-nginx.yml
```

## 9. Kiểm tra kết quả

Trên Ansible Control Node:

```bash
curl http://192.168.1.21
curl http://192.168.1.22
```

Hoặc mở trình duyệt:

```
http://192.168.1.21
http://192.168.1.22
```

Kết quả mong muốn:

```
Hello from web1
```

và:

```
Hello from web2
```

##