# Hardening Decisions for Kijanikiosk

## Overview
This document explains the key security hardening decisions applied to the KijaniKiosk services, with a focus on the `kk-payments.service.` The goal was to reduce the system’s attack surface while ensuring that the service continues to function correctly.

Rather than applying every possible restriction, the approach taken was practical hardening — prioritizing high-impact protections while maintaining service reliability. Each decision balances security benefits against operational requirements.

### Hardening strategy
The hardening process followed three main principles:

- Least Privilege – Services should only have access to what they strictly need
- Isolation – Limit interaction with the system, kernel, and other processes
- Controlled Access – Explicitly define what is allowed instead of relying on defaults

The process was iterative. After each change, the service was tested and the security score reviewed using: 
```
systemd-analyze security kk-payments.service
```



### Key Hardening Decisions


| Directive                                          | What It Does                      | Why It Was Added                               | Trade-off                                    |
| -------------------------------------------------- | --------------------------------- | ---------------------------------------------- | -------------------------------------------- |
| `NoNewPrivileges=yes`                              | Prevents privilege escalation     | Stops processes from gaining higher privileges | None — safe default                          |
| `ProtectSystem=strict`                             | Makes filesystem read-only        | Prevents tampering with OS files               | Requires explicit writable paths             |
| `ReadWritePaths=/opt/kijanikiosk/shared/logs`      | Allows writes only to logs        | Ensures controlled write access                | Must maintain correct path                   |
| `ProtectHome=yes`                                  | Blocks access to home directories | Prevents accidental data exposure              | No impact on service                         |
| `PrivateTmp=yes`                                   | Isolates `/tmp` directory         | Prevents temp file attacks                     | Slight debugging complexity                  |
| `PrivateDevices=yes` + `DevicePolicy=closed`       | Removes device access             | Prevents hardware-level interaction            | May break apps needing devices               |
| `MemoryDenyWriteExecute=yes`                       | Blocks executable memory writes   | Mitigates code injection attacks               | Can break JIT-based apps                     |
| `SystemCallFilter=@system-service`                 | Restricts system calls            | Reduces kernel attack surface                  | Needs testing for compatibility              |
| `CapabilityBoundingSet=`                           | Removes all Linux capabilities    | Enforces strict least privilege                | Must ensure app doesn’t require capabilities |
| `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6` | Limits socket types               | Prevents unusual networking behavior           | Must allow required protocols                |
| `IPAddressDeny=any` + `IPAddressAllow=127.0.0.1`   | Restricts network access          | Limits communication to localhost              | Blocks external APIs                         |
| `ProtectKernelModules=yes`                         | Blocks kernel module loading      | Prevents kernel compromise                     | No impact                                    |
| `ProtectProc=invisible`                            | Hides process information         | Prevents process snooping                      | Harder debugging                             |
| `RestrictNamespaces=yes`                           | Blocks namespace creation         | Prevents container escape techniques           | Rare compatibility issues                    |



 ### Key Trade-offs and Decisions
#### 1. Strict Filesystem Control

Using:

ProtectSystem=strict

was a strong decision that significantly reduced risk. However, it required explicitly allowing write access:

ReadWritePaths=/opt/kijanikiosk/shared/logs

This ensures the service can still write logs while everything else remains protected.

#### 2. Network Restriction Strategy

Instead of completely disabling networking, the following approach was used:

IPAddressDeny=any
IPAddressAllow=127.0.0.1

This allows only local communication, which is sufficient for internal service interaction.

This is a safer alternative to leaving the network fully open, while still maintaining functionality.

#### 3. Capability Removal

All Linux capabilities were removed:

CapabilityBoundingSet=
AmbientCapabilities=

This ensures the service cannot:

Modify system settings
Access privileged operations
Interact with sensitive kernel features

This is one of the most impactful security improvements.

#### 4. System Call Filtering

Using:

SystemCallFilter=@system-service

restricts the service to a safe subset of system calls.

This reduces the attack surface significantly, especially against kernel-level exploits.
 Decisions Not Taken
Full Network Isolation (PrivateNetwork=yes)

This was considered but not implemented.

Reason:

The service may need to communicate with other internal services
Future expansion may require external API access

Conclusion:
Too restrictive for current and future needs.

Chroot / Root Directory Isolation (RootDirectory=)
This approach would isolate the service into its own filesystem.
Reason not used:
Complex to configure and maintain
Requires duplicating dependencies
Not necessary for the current risk level
Honest Gaps and Limitations

Despite achieving a strong security score (1.2), some limitations remain:

1.Limited External Network Capability
The current configuration only allows localhost communication:
IPAddressAllow=127.0.0.1
Gap:
The service cannot call external APIs (e.g., payment gateways)
Impact:
May require reconfiguration in a production environment
2.No Root Filesystem Isolation
The service still runs on the host filesystem.
*Risk:* 
If compromised, it may still access allowed paths
Mitigation:
Strong filesystem restrictions already applied

3.System Call Filter Not Fully Customized
Using:
@system-service
is a safe default, but not minimal.
Gap:
Some unnecessary syscalls may still be allowed
Improvement:
Create a custom syscall allowlist for tighter security

4.Debugging Complexity
Restrictions such as:
ProtectProc=invisible
PrivateTmp=yes
can make troubleshooting harder.
Impact:
Developers may need to temporarily relax settings for debugging

5.No Mandatory Access Control (MAC)
This setup does not use tools like:
AppArmor
SELinux
Gap:
No additional policy-based enforcement layer
### Final Outcome

The final hardened configuration:

Reduced exposure from ~9.0 to 1.2
Enforced strict least privilege
Isolated the service from system internals
Restricted filesystem, kernel, and network access

Most importantly, the system remains functional and maintainable, which is critical for real-world deployments.

### Key Takeaway

Effective hardening is about making intentional decisions, not applying every restriction blindly.
Security must always be balanced with:
- Usability
- Maintainability
- Service requirements

This approach ensures the system is not only secure, but also practical to operate.