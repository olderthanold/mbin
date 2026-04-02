# ==== Linux =============================================
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

# ==== PROCESSES ====================================================
top
ps all
ps -f

# ==== Executables =================================================
## make executable, single or recursive whole dir
chmod +x <file>
chmod -R +x /path/to/dir
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

# ==== GIT ========================================================
## ubuntu
## ==== clone repo
git clone -b main https://github.com/olderthanold/mbin.git
## ==== update repo
cd mbin && git pull origin main
## 
git add -A && git commit -m "update" && git push older-m main

# ==== DISKS ========================================================
## ==== Disks list mountable
sudo fdisk -l
df
lsblk
sudo parted -l

# ==== NETWORK ADDRESSES ===========================================
## emp
157.151.234.209
olderemp.duckdns.org
## old
92.5.32.30
olderthanold.duckdns.org
olderthanold.cloudns.cx
## old2
89.168.88.88

# ==== OCI instance =================================================
https://docs.oracle.com/en-us/iaas/Content/Compute/tutorials/first-linux-instance/overview.htm
## tenancy: okderthanold
ocid1.tenancy.oc1..aaaaaaaayd6mxebdj7xpp25xyftvuba2dme5vubiohg3irybx2sitkq2yjna
## user
ocid1.user.oc1..aaaaaaaabdu6itjzjdme5r3i5duc5ww2nf7bubg67lca7aumgsxcmjmptifq
## api key location
/home/ubun2/.config/oldapi.pem
## linux install (AI made setup_oci_cli_ubuntu.sh)
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
oci --version
