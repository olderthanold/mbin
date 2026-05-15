# a. **- Oracle OCI always free setup -**
## 1 *OCI console account info* ----------------------
   ### Basic info
Create account, credit card needed, will charge and immediately return about 1$. Creating instance will create passkey or you can use yours. Add region, tenant and username to get your login link that save clicking/writing:
```
https://cloud.oracle.com/?region=<region>&tenant=<tenant>&provider=Default&username=<username>
```
- 2 Micro instances (+ Ampere 4 CPU + 24 RAM)
- 200 GB block storage
- VCN, DBs, Apex, monitoring, notifications and many other useless things
[Always free resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)

## 2 *Account preparations* ----------------------

### Enable alternative login methods and recovery in the Identity domain:
+ In top right corner click: `Profile > Identity Domain > Authentication tab`
+ Enable or Disable factors
+ Turn on mail, mobile app (set 4 digits), security Qs
+ Edit email settings: 4 60 10 72
+ Save changes

### Set up alternative login methods for yourslef
+ In top right corner click: Profile > *yourmail*
+ Security tab
+ 2-step verification
   - Email
   - Mobile App
   - Security questions
### Set up budget - alert for 1% of 1$ forecasted spending
If you upgrade to get ampere you should set alert.

## 3 *Virtual Cloud Network (VCN)* ----------------------

### Create a VCN, a network that connects all your virtual OCI stuff
Go to Networking > Virtual Cloud Networks
Create VCN
Name it *yournet*
CIDR 10.0.0.0/16
Click Create VCN
in Virtual Cloud Networks click *yournet*

### b. Gateway - a virtual device in VCN for your VM to reach internets
Click Gateways tab
Create Internet Gateway
Name it *yourgate*
Click Create Internet Gateway

### c. Routing - route outgoing traffic in VCN to your gateway
Click Routing tab
Click Default Route Table for *yournet*
Route Rules
Add Route Rule
Internet Gateway
0.0.0.0/0
*yourgate*
Click Add Route Rules

### d. Subnet - it is good for dividing your VCN, we need only 1
click Subnets tabs
Create Subnet
10.0.0.0/16 (same as above)
click Create Subnet

## 4 *Compute - Virtual Machine (VM) Instance* ----------------------

Go to Compote > Instances
Click Create Instance button
### Basic information
Change name to *instname*
Click Change image buton
Select Ubuntu
Pick Image name: Canonical Ubuntu 24.04
Click Select image button
Click Select shape button
Pick Specialty and previous generation
Pick VM.Standard.E2.1.Micro
Click Select shape button
Next
### Security: leave defaults
### Networking
Change name to *VNICname*
It should be all prefilled/defaults:
select existing VCN, your VCN, select existing subnet
Automatically assign private IPv4 address
Automatically assign public IPv4 address yes
Generate a key pair for me 
### IMPORTANT: Download private key & Download public key # === DO NOT MISS THIS!!!!
Next
### Boot volume: leave defaults
Next
### Review, check
Click Create
Will take a bit of time, In progress

# B. **- UBUNTU VM SETUP for Windows -**
## 1 *Windows*
### Get IP
Get public IP from OCI console instance: 129.80.226.856
### make keys yours
- `icacls "c:\apps\keys\my.key" /inheritance:r`
- `icacls "c:\apps\keys\my.key" /grant:r "user:F"`
### 1. Connect to the instance
`ssh -i c:\apps\keys\my.key ubuntu@92.5.32.303`
### 2. Pull scripts from github
`sudo git clone -b main https://github.com/olderthanold/mbin.git /m/mbin`
### 3. Run scripts and create user ubun2, default ubuntu will be a backup
`sudo /m/mbin/0ini.sh ubun2    #takes some time`

If fails run with Make scripts executable: `sudo chmod -R +x /m/mbin/*.sh`
### 4. create passwords
`sudo passwd ubuntu`   # create password for defaul ubuntu account
`sudo passwd ubun2`    # create password for new ubun2 account
### 5. reboot
`sudo reboot`

# C **- website -**
### set up free subdomain (map your subdomain to IP)
- [duckdns](https://www.duckdns.org/domains)
- [clouDNS](https://www.cloudns.net)
### once IP is mapped to domain
- `sudo 0web.sh yourname.duckdns.org`
- creates auto renewable certificate for https (cert that domain is on ip)
- creates ngnix site (map domain addres to a dir)
- webiste root is /m/webs/yourname
- u can change web root dir, run `0web.sh` for syntax

# d **- Block Storage -**
no good for aways free
### OCI console
- a. create block volume 
- b. attach to VM

### UBUNTU
- Attach block voluem, on can be shared others read only
- if all write it needs paid stuff