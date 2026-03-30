# Integration Notes

This document summarizes the resolutions for the four Integration Challenges encountered during KijaniKiosk DevOps setup.

---

## Challenge 1: Shared Logs Access for Multiple Services

**Conflict:**  
The `kk-api`, `kk-payments`, and `kk-logs` services needed concurrent read/write access to `/opt/kijanikiosk/shared/logs`. By default, only the owner had write permissions, causing log write failures after rotation.

**Options Considered:**  
1. Make the directory world-writable (`chmod 777`) – simple, but insecure.  
2. Use Linux groups and standard permissions – limited, required frequent manual fixes.  
3. Use ACLs with default inheritance – more granular and automatic.

**Chosen Solution:**  
Implemented ACLs and default ACLs (`setfacl -m` and `setfacl -d -m`) to grant rwx access to the three service users.

**Rationale:**  
This approach ensures proper access while maintaining security. Default ACLs also allow logrotate to create new files without manual ACL fixes.

---

## Challenge 2: Logrotate and ACL Propagation

**Conflict:**  
Even with correct ACLs on `/shared/logs`, rotated log files could be created with restrictive default permissions, breaking service logging.

**Options Considered:**  
1. Modify logrotate to run as each service user – complicated and error-prone.  
2. Run logrotate as root and set default ACLs on the directory – simpler, consistent.  
3. Script post-rotation ACL fixes – manual, requires cron monitoring.

**Chosen Solution:**  
Ran logrotate as root (`su root root`) and relied on default ACLs on `/shared/logs`.

**Rationale:**  
This provides a reliable, automated mechanism so services always have write access to rotated logs without extra scripts.

---

## Challenge 3: Service Hardening Conflicts

**Conflict:**  
The `kk-payments` service needed network and filesystem access, but applying strict systemd hardening directives sometimes blocked legitimate functionality (e.g., `PrivateNetwork`, `ProtectHome`).

**Options Considered:**  
1. Relax all hardening directives – lowers security, undesirable.  
2. Tailor directives selectively, keeping critical protections – allows functionality while maintaining a low exposure score.  
3. Disable the service and run manually – impractical for production.

**Chosen Solution:**  
Applied strict protections where possible, allowed only necessary networking (loopback), and carefully configured ReadWritePaths for service-specific directories.

**Rationale:**  
Achieves strong security (systemd-analyze exposure 1.2) while preserving functionality, rather than a blanket relaxation.

---

## Challenge 4: Health Directory Permissions and Monitoring

**Conflict:**  
The new `/opt/kijanikiosk/health` directory needed controlled access for health-check scripts without exposing sensitive configuration data.

**Options Considered:**  
1. Give full rwx to all services – easy, insecure.  
2. Restrict ownership to `kk-logs` only – may block other legitimate monitoring scripts.  
3. Use ACLs for fine-grained access – allows specific users, protects others.

**Chosen Solution:**  
Set ACLs granting rwx to only the service users requiring access (`kk-logs`, etc.), with default ACLs applied for future files if needed.

**Rationale:**  
Provides precise access control without compromising system integrity, following the same pattern as shared logs. Easy to maintain and extend.

---

**Summary:**  
All four integration challenges were resolved using **ACLs for fine-grained filesystem permissions**, **careful systemd hardening**, and **logrotate integration with default ACL propagation**. Each decision balanced **security, reliability, and maintainability**, minimizing manual intervention and operational risk.