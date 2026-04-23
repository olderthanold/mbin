## ==== ssh ======================================================
nano ~/.ssh/config
### put in:
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/old.key
    IdentitiesOnly yes

Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/old.key
    IdentitiesOnly yes
### then
add key to ~/.ssh/old.key

chmod 600 ~/.ssh/old.key
chmod 600 ~/.ssh/config
cd ~
# ==== git ==============================================================
git clone git@github.com:olderthanold/m.git ~/m
git config user.email "olderthanold@gmail.com"
git config user.name "olderthanold"
git remote add github git@github.com:username/m.git
git remote add gitlab git@gitlab.com:username/m.git
git remote set-url --add --push origin git@github.com:olderthanold/m.git
git remote set-url --add --push origin git@gitlab.com:olderthanold/m.git
git remote -v
git add .
git pull
git push

git add .
commit -m "ubuntucommit $(date +"%Y-%m-%d %H:%M:%S")"
git push

## ==== clone repo
git clone -b main https://github.com/olderthanold/mbin.git ~/mm
## ==== update repo
git -C ~/mm pull origin main
## ==== push
git add -A && git commit -m "update" && git push https://github.com/olderthanold/mbin.git main
git add -A && git commit -m "update" && git push https://gitlab.com/olderthanold/mbin.git main

# ==== Executables ======================================================
## make executable, single or recursive whole dir
chmod +x ./*.sh
chmod -R +x /path/to/dir        # enable execute
chmod 777 -R /path/to/dir       # rwx to all

# ==== Linux =========================================================
## Update
sudo apt-get update && sudo apt-get update -y
## install packages
sudo apt install nginx
sudo apt install mc
## ==== .bashrc =  autoexec
env # environment variables
touch # create empty file
which # where in windows

## ==== net cat
nc
# ==== USER =========================================================
## list users
awk -F: '$3>=1000 && $3<65534 {print $1}' /etc/passwd #non system users
getent group sudo       #sudo group members
## groups
groups ubuntu
sudo usermod -aG groupname username
### prepend to path
export PATH="$PATH:$HOME$/mbin"

### root bash pass env interactive / command or script
sudo -E bash
sudo -E bash -c "export PATH=$PATH; ls /root" # if path is not passed

## ====passwords New password
sudo passwd ubun2
### Remove password (disable password login for that user)
sudo passwd -d ubun2
### Better/safer for hardening: lock password-based auth
sudo passwd -l ubun2
### Re-enable later
sudo passwd -u ubun2

## Add this in so that ubun2 does not have to give password for sudo
cd /etc/sudoers.d/90-cloud-init-users
ubun2 ALL=(ALL) NOPASSWD:ALL
## allow ssh by shell
sudo nano /etc/ssh/sshd_config
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes

### then restart shell
sudo systemctl restart ssh

# ==== MEMORY SWAP ====================================================
## create
sudo fallocate -l 5G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
# persist
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

## check
swapon --show
free -h

# ==== DISKS ========================================================
df -h /dev/sda1 # diskfree
## ==== Disks list mountable
sudo fdisk -l
lsblk
sudo parted -l

# ==== NETWORK ADDRESSES ===========================================
## emp
150.136.59.72
## oldb
129.159.30.72
## ocic
89.168.88.88
## lada
92.5.117.49
##
oldneues.duckdns.org
olderbitch.duckdns.org
olderthanold.duckdns.org
olderthanold.cloudns.cx

# ==== add to .bashrc ================================================
echo -e "\033[0;32m =---------- ps -la ----------= \033[0m"
ps -la
echo -e "\033[0;32m =---------- echo -e ----------= \033[0m"
swapon --show
echo -e "\033[0;32m =---------- free -h ----------= \033[0m"
free -h
echo -e "\033[0;32m =---------- df -h /dev/sda1 ----------= \033[0m"
df -h /dev/sda1
echo -e "\033[1;33m =---------- .bashrc done ----------= \033[0m"

# ==== PROCESSES ====================================================
top
ps all
ps -f
## ==== nohup 
### Run in background even if console closes
```bash
nohup sudo -E bash -c "export PATH=$PATH; ociamp.sh" > ociamp.log 2>&1 && touch ociamp_script_completed.txt &
echo $!
```
### Check later:
```bash
ps -fp <PID>
tail -f clone.log
```
### Access process output
/proc
tail -f /proc/<pid>/fd/1

# ==== nohup ================================================

# run build detached from terminal, log output to file
```bash
nohup /opt/mbin/ai/aibuild.sh > build.log 2>&1 &
nohup /opt/mbin/ai/aibuild.sh > build.log 2> error.log &

nohup bash -c 'sudo -E bash -c "export PATH=$PATH; ociamp.sh" && touch ociamp_script_completed.txt' > ociamp02.log 2>&1 &
echo $!
```
# explanation:
# nohup      = ignore terminal disconnect (SIGHUP)
# > build.log = stdout to file
# 2>&1       = stderr to same file / error.log
# &          = run in background

# check if running
pgrep -af aibuild.sh

# monitor output
tail -f build.log

# stop if needed
kill -9 <PID>

# ==== tmux ================================================
# install tmux (only once)
sudo apt install tmux
# start a new tmux session named "build"
tmux new -s build
# inside tmux: run your build script
/opt/mbin/ai/aibuild.sh
# detach from tmux (leave build running)
## press: Ctrl+b then d
# later: list tmux sessions
tmux ls
# reattach to the session
tmux attach -t build
# (optional) kill the session when done
tmux kill-session -t build