# USER PERMISSION - LINUX

## 1. USER MANAGEMENT

### Create user
- adduser (high-level, interactive)
- useradd (low-level)
- passwd (set password)

### Delete user
- deluser
- userdel -r (remove home directory)

### Modify user
- usermod -s (change shell)
- usermod -l (rename user)
- usermod -d (change home directory)

### Lock / Unlock user
- usermod -L (lock)
- usermod -U (unlock)

---

## 2. GROUP MANAGEMENT

### Create group
- groupadd

### Add user to group
- usermod -aG group user

### Remove user from group
- gpasswd -d user group

### Check groups
- groups user

---

## 3. FILE PERMISSIONS

### Permission types
- r (read)
- w (write)
- x (execute)

### Apply to
- user (owner)
- group
- others

Example:
-rw-r--r--

---

## 4. CHMOD

### Symbolic
- chmod u+rwx file
- chmod g-w file
- chmod o+x file

### Numeric
- 7 = rwx
- 5 = r-x

Example:
- chmod 755 file

---

## 5. CHOWN

- chown user file
- chown :group file
- chown user:group file

---

## 6. SUDO

- Grant admin:
  usermod -aG sudo user

---

## PRACTICE LABS

### Lab 1: User lifecycle
- Create user
- Set password
- Lock/unlock
- Delete user

### Lab 2: Group control
- Create group
- Add/remove users
- Verify groups

### Lab 3: Permission control
- Create file
- Apply chmod 777, 755, 644
- Observe differences

### Lab 4: Ownership
- Change owner/group
- Test access behavior
