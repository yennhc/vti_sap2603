#!/bin/bash

#Hardware management script
lscpu #CPU information
lshw -short #Hardware information
lsusb #USB devices
lspci #PCI devices
df -h #Disk space usage

#Disk management script
df -h #Check disk space
du -sh /path/to/directory/* | sort -hr #Check disk usage by subdirectories
lsblk #List all disks and their partitions
fdisk -l #List all disks and their partitions (requires sudo)   
mkfs.ext4 /dev/sdX #Format a disk (replace /dev/sdX with the actual disk identifier)

#File management script
ls -l #List files in the current directory
cp source_file destination_file #Copy a file
mv source_file destination_file #Move or rename a file
rm file_name #Delete a file
mkdir directory_name #Create a new directory
rmdir directory_name #Remove an empty directory
find /path/to/search -name "file_pattern" #Find files matching a pattern
chmod 755 file_name #Change file permissions
chown user:group file_name #Change file ownership

#Process management script
ps aux #List all running processes
top #Display real-time system information and processes
htop #Interactive process viewer (requires installation)
kill process_id #Terminate a process (replace process_id with the actual process ID)
pkill process_name #Terminate processes by name (replace process_name with the actual process name)
nice -n 10 command #Run a command with a specific priority (replace command with the actual command)

netstat -tuln #List all listening ports
ss -tuln #List all listening ports (alternative to netstat)
lsof -i :port_number #List processes using a specific port (replace port_number with the actual port number)
nmap -sT localhost #Scan for open ports on the local machine
ufw status #Check firewall status (requires ufw)   

#file editing script
nano file_name #Edit a file using nano editor
vim file_name #Edit a file using vim editor
sed -i 's/old_text/new_text/g' file_name #Replace text in a file using sed
awk '{print $1}' file_name #Print the first column of a file
grep "search_pattern" file_name #Search for a pattern in a file (replace search_pattern with the actual pattern)

cat > file_name #Create a new file and input text until EOF (Ctrl+D)
cat test1.txt test2.txt > combined.txt #Combine two files into one





