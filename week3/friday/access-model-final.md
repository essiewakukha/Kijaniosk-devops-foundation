# KIjaniosk Access Control Model

## Overview

This document defines the finalized access control model for the kijaniosk system under *opt/kijaniosk*. It ensures: 
- least priviledge access for all services
- controlled configurataion access
- shared logging with proper permissions 
- secire health monitoring directory
- compatibility with log rotation process

## Directory Structure and permissions

### 1. /opt/kijanikiosk
```
# file: opt/kijanikiosk
# owner: root
# group: kijanikiosk
user::rwx
group::r-x
other::---
```

##### Purpose
- Root directory for the application

##### Access MOdel
- root: full control
- kijanikiosk group: read and execute
- others: no access

##### Justification
- prevents unathorized modification 
- allows services to traverse the directory

---

### 2. opt/kijanikiosk/config -Environment files

```
# file: opt/kijanikiosk/config
# owner: root
# group: root
user::rwx
user:kk-api:--x
user:kk-payments:--x
user:kk-logs:--x
group::r-x
mask::r-x
other::---
```

##### Purpose
- stores sensitive config files

##### Access Model
Owned by `root:root`, mode `0750`
- Each service account has execute-only (`--x`) on the directory itself,
  meaning they can traverse into it to read their own env file but cannot
  list directory contents
- Individual env files (`api.env`, `payments-api.env`, `logs.env`) are owned
  `root:root`, mode `0640`, with per-file ACL entries granting each service
  account `r--` on its own file only
- **Dirty state corrected:** was `0777` with world-readable secret files
  (`db.env`, `payments-api.env` contained plaintext credentials)

  ##### JUstification
  - service can access files if they know thw path
  - prevents readin sensitive configs
  - enforce least priviledge

---

### 3. /opt/kijanikiosk/shared/logs
```
# file: opt/kijanikiosk/shared/logs
# owner: kk-logs
# group: kijanikiosk
# flags: -s-
user::rwx
user:kk-logs:rwx
user:kk-payments:rwx
user:kk-api:rwx
group::rwx
mask::rwx
other::---
default:user::rwx
default:user:kk-logs:rwx
default:user:kk-payments:rwx
default:user:kk-api:rwx
default:group::rwx
default:mask::rwx
default:other::---
```


##### Purpose
- Centralized logging directory for all services

##### Access Model
- All services have full access(rwx) via named ACL
- Owned by `kk-logs:kijanikiosk`, mode `2770` (SGID set)
- SGID bit ensures new files created in this directory inherit the
  `kijanikiosk` group automatically
- Default ACLs propagate access entries to all new files created inside
  the directory - this is the mechanism that preserves the access model
  after logrotate rotation (see Logrotate Interaction section below)
- World access denied


##### Justification

- enables multi-service logging
- prevents permission conflicts
- ensures consistency for new log files

---

### 4. opt/kijanikiosk/health
```
# file: opt/kijanikiosk/health
# owner: kk-logs
# group: kijanikiosk
user::rwx
group::r-x
other::---
```

##### Purpose
- Stores health check outputs and monitoring data

##### Access Model
- kk-logs: Full access (write health data)
- Group: Read + execute
- Others: No access
- Owned by `kk-logs:kijanikiosk`, mode `0750`

##### Justification
- Centralizes health monitoring
- Prevents unauthorized modification
- Allows controlled visibility

---
# Logrotate Interaction Notes (Requirement 3)

### The problem

When logrotate rotates a log file in `/opt/kijanikiosk/shared/logs/`, it
creates a new empty file to replace the rotated one. The `create` directive
in the logrotate config controls the standard ownership and mode of that new
file. However, standard `create` does not apply ACLs - only the default ACLs
set on the parent directory propagate automatically to new files.

If the default ACLs on `shared/logs/` are missing or incorrect, the new file
created after rotation will not have the named ACL entries for `kk-api`,
`kk-payments`, and `kk-logs`. The result is that services can no longer write
to their log files after rotation  silently, with no error until the next
write attempt.

### The solution

The provisioning script sets both access ACLs and default ACLs on
`/opt/kijanikiosk/shared/logs/`:

```bash
# Access ACLs (apply to the directory itself)
setfacl -m u:kk-api:rwx     /opt/kijanikiosk/shared/logs
setfacl -m u:kk-payments:rwx /opt/kijanikiosk/shared/logs
setfacl -m u:kk-logs:rwx    /opt/kijanikiosk/shared/logs

# Default ACLs (propagate to new files created inside)
setfacl -d -m u:kk-api:rwx     /opt/kijanikiosk/shared/logs
setfacl -d -m u:kk-payments:rwx /opt/kijanikiosk/shared/logs
setfacl -d -m u:kk-logs:rwx    /opt/kijanikiosk/shared/logs
```

The default ACLs (`-d` flag) are the critical piece. When logrotate creates a
new file, the kernel applies the directory's default ACLs to it automatically.
This means no manual ACL repair is needed after each rotation.

### The logrotate config

```
/opt/kijanikiosk/shared/logs/*.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    su root root
    create 0660 kk-logs kijanikiosk
    sharedscripts
    postrotate
        /bin/systemctl restart kk-logs.service >/dev/null 2>&1 || true
    endscript
}
```

- `create 0660 kk-logs kijanikiosk` sets standard ownership on new files
- The default ACLs on the directory then add the named ACL entries on top
- `su root root` runs logrotate as root so it can rename and create files
  regardless of which service owns them
- `postrotate` restarts `kk-logs` so it re-opens its log file handle after
  rotation. `restart` is used instead of `reload` because the log aggregator
  service does not implement `ExecReload`


### Verification

After a forced logrotate, verify the access model survives:

```bash
sudo logrotate -f /etc/logrotate.d/kijanikiosk
sudo -u kk-api touch /opt/kijanikiosk/shared/logs/test-write.tmp \
  && echo "PASS: kk-api can write after logrotate" \
  || echo "FAIL: kk-api cannot write to shared/logs"
```


#### Screenshot 
Screenshot showing: 
```
getfacl /opt/kijanikiosk
getfacl /opt/kijanikiosk/config
getfacl /opt/kijanikiosk/shared/logs
getfacl /opt/kijanikiosk/health
```
![Images](./Images/ACL%20configuration%20for%20KijaniKiosk.png)

### Conclusion
This access model:

- Secures sensitive configuration
- Enables safe multi-service logging
- Supports operational processes like log rotation
- Maintains strict access boundaries