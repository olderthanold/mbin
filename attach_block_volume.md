

## A) Prepare and mount extra volume `/dev/sdb` to `/m`
> ⚠️ `mkfs`/partition steps erase `/dev/sdb`.

```bash
# 1) Inspect disks (confirm /dev/sdb is the extra volume)
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,UUID

# 2) Partition disk (one full partition)
sudo parted -s /dev/sdb mklabel gpt
sudo parted -s /dev/sdb mkpart primary ext4 0% 100%

# 3) Format partition
sudo mkfs.ext4 -L data /dev/sdb1

# 4) Mount now
sudo mkdir -p /m
sudo mount /dev/sdb1 /m

df -h | grep ' /m$'
```

---
## B) Make mount persistent (`/etc/fstab`)

```bash
# 5) Get UUID
sudo blkid /dev/sdb1

# 6) Backup fstab
sudo cp /etc/fstab /etc/fstab.bak

# 7) Add persistent mount line (replace UUID)
echo 'UUID=61676dde-b28f-4515-9fad-52ed72e37226 /m ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

# 8) Validate fstab
sudo mount -a
df -h | grep ' /m$'
```




---
## C) Move `ubuntu` home to `/m/home/ubuntu` (safe method)

### In current `ubuntu` session:
```bash
# 9) Create temporary admin user
sudo adduser tempadmin
sudo usermod -aG sudo tempadmin

# 10) Prepare destination and copy home data
sudo mkdir -p /m/home/ubuntu
sudo rsync -aXS --info=progress2 /home/ubuntu/ /m/home/ubuntu/
sudo chown -R ubuntu:ubuntu /m/home/ubuntu
```

### Open a NEW SSH session as `tempadmin`:
```bash
ssh tempadmin@<server-ip>
```

### In `tempadmin` session:
```bash
# 11) Ensure ubuntu has no active processes
pgrep -u ubuntu -a
# If processes remain:
sudo pkill -u ubuntu
pgrep -u ubuntu -a

# 12) Change ubuntu home path
sudo usermod -d /m/home/ubuntu ubuntu

# 13) Verify
getent passwd ubuntu
# 6th field must be: /m/home/ubuntu
```

### Test login:
```bash
ssh ubuntu@<server-ip>
echo "$HOME"
# expected: /m/home/ubuntu
```

### Optional cleanup later (after full verification):
```bash
sudo mv /home/ubuntu /home/ubuntu.bak
sudo mkdir /home/ubuntu
sudo chown ubuntu:ubuntu /home/ubuntu
```

---
## D) Install nginx and keep site content on `/m`

```bash
# 14) Install nginx
sudo apt update
sudo apt install -y nginx

# 15) Create site content on /m
sudo mkdir -p /m/www/private
echo 'hello from /m volume' | sudo tee /m/www/private/index.html
sudo chown -R www-data:www-data /m/www
sudo chmod -R 755 /m/www
```

```bash
# 16) Nginx site config
cat <<'EOF' | sudo tee /etc/nginx/sites-available/private
server {
    listen 80;
    server_name _;

    root /m/www/private;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

# 17) Enable site
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/private /etc/nginx/sites-enabled/private

# 18) Validate + reload
sudo nginx -t
sudo systemctl reload nginx
```

---
## E) Verify final state

```bash
# Check mount and disk usage split
findmnt /m
df -h | egrep ' /$| /m$'

# Check nginx locally
curl -I http://127.0.0.1
```

If you want, I can give you the **same runbook but non-destructive** (for case where `/dev/sdb1` already exists and you don’t want to reformat).