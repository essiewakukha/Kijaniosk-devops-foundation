# Kijanikiosk Infrastructure Hardening Document
## Introduction


This document outlines the security measures implemented in the KijaniKiosk infrastructure deployed using Terraform and configured with Ansible. The goal of these controls is to protect the system from unauthorized access, ensure system integrity, and maintain reliable service operation.

The infrastructure consists of three EC2 instances (API, Logs, and Payments), each configured with role-based access, controlled networking, and automated service management.

---

## Security Controls Overview

| Control                            | Description                                                                  | Risk Mitigated                   |
| ---------------------------------- | ---------------------------------------------------------------------------- | -------------------------------- |
| Security Groups                    | Restricts inbound and outbound traffic to only necessary ports               | Unauthorized network access      |
| SSH Key Authentication             | Uses key-based authentication instead of passwords                           | Brute force attacks              |
| Least Privilege Users              | Each service runs under its own system user                                  | Privilege escalation             |
| Directory Permissions              | Application files stored in controlled directories with restricted ownership | Unauthorized file access         |
| Systemd Service Management         | Services run under specific users with controlled execution                  | Unauthorized process execution   |
| Idempotent Configuration           | Ensures consistent and predictable system state                              | Configuration drift              |
| Infrastructure as Code (Terraform) | Standardized infrastructure provisioning                                     | Human error and misconfiguration |
| Configuration Management (Ansible) | Automated and repeatable configuration                                       | Inconsistent environments        |

---

## Detailed Security Measures

### 1. Network Security (Security Groups)

Security groups were configured to allow only required traffic:

* SSH (Port 22) is restricted to the administrator’s IP address.
* Other unnecessary ports are closed by default.

This minimizes the attack surface and prevents unauthorized access attempts from the public internet.

---

### 2. Secure Access via SSH Keys

All EC2 instances are accessed using SSH key pairs instead of passwords.

* Private keys are stored securely on the administrator’s machine.
* Password-based authentication is not used.

This prevents brute-force login attempts and ensures only authorized users can access the servers.

---

### 3. Role-Based User Isolation

Each server creates a dedicated system user:

* `kk-api`
* `kk-logs`
* `kk-payments`

Services run under these users instead of root.

This ensures:

* Isolation between services
* Reduced impact if one service is compromised

---

### 4. Controlled Directory Structure

Application files are stored in:

```
/opt/kijanikiosk
```

Permissions:

* Owned by the respective service user
* Not globally writable

This prevents unauthorized modification of application files.

---

### 5. Service Hardening with systemd

Each service is managed using systemd:

* Runs under a non-root user
* Automatically restarts on failure
* Controlled execution environment

This improves reliability and limits the impact of service crashes or malicious behavior.

---

### 6. Configuration Consistency (Idempotency)

Ansible ensures that all configurations are idempotent:

* Running the playbook multiple times does not introduce changes
* The system remains in a known, secure state

This prevents configuration drift and ensures stability over time.

---

### 7. Infrastructure as Code (Terraform)

Terraform is used to provision all infrastructure:

* No manual server creation
* Version-controlled infrastructure definitions
* Repeatable deployments

This reduces human error and ensures consistency across environments.

---

### 8. Automated Configuration Management (Ansible)

Ansible automates server configuration:

* Ensures all servers are configured identically
* Eliminates manual setup errors
* Enforces security policies automatically

---

## Conclusion

The KijaniKiosk infrastructure implements multiple layers of security, including network restrictions, secure authentication, least privilege principles, and automated configuration management. These controls work together to reduce the risk of unauthorized access, system compromise, and operational inconsistencies.

By combining Terraform and Ansible, the system achieves a secure, repeatable, and scalable deployment model aligned with modern DevOps best practices.

---
