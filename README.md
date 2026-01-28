# Backup Config Server to MinIO (Interactive Script)

Script ini digunakan untuk melakukan **backup konfigurasi server Linux** dan meng-upload hasil backup ke **MinIO Object Storage** secara **otomatis & interaktif**.

Backup dilakukan dalam bentuk **1 file `.tar.gz`**, aman untuk restore dan cocok untuk baremetal / VM.

---

## 📦 Yang Dibackup

- `/home/devops`  
  - Bisa **exclude folder tertentu secara interaktif**
  Contoh : builds, .cache, .local, prometheus, backup-config
- `/etc/nginx/nginx.conf`
- `/etc/hosts`

❌ Folder yang di-exclude **tidak akan ikut di-backup**.

---

## 🧰 Prerequisites

Pastikan server sudah memenuhi requirement berikut:

###  OS
- Linux (Ubuntu / Debian / CentOS / RHEL)


## Running script Backup
```bash

curl -O https://raw.githubusercontent.com/andiabdur/backup-config/refs/heads/main/backup.sh

chmod +x backup.sh

./backup.sh

```

## Running script restore 
```bash
curl -O https://raw.githubusercontent.com/andiabdur/backup-config/refs/heads/main/restore.sh

chmod +x restore.sh

./restore.sh
```

