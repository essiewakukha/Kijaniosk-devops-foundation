# KK Payment Service log
## Objective
Achieve a `systemd-analyze security` score below 2.5 for `kk-payments.service`
while keeping the Achieve service running correctly. The payments service handles
financial transaction data and requires the strictest hardening of all three
services.

---

## Starting Point

Before any hardening directives were added, the baseline unit file contained
only the minimum required fields: `User`, `Group`, `WorkingDirectory`,
`EnvironmentFile`, `ExecStart`, and `Restart` policy.

**Baseline score: not recorded (Wednesday lab baseline was approximately 9.2
for a unit with no hardening directives)**

The Wednesday lab required a score below 4.0 using the four baseline
directives: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, and
`ProtectHome`. Starting from those four directives the score was approximately
3.0 before additional Friday hardening began.

---

## Iterative Hardening

Each directive below was added to the `[Service]` block and the score checked
after each addition with:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kk-payments.service
sudo systemctl status kk-payments.service   # confirm still running
sudo systemd-analyze security kk-payments.service | tail -3
```

### Round 1 — Baseline hardening (Wednesday directives)

Directives added:
```ini
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
```

**Score after Round 1: ~3.0**
Service status: active (running) 

---

### Round 2 — Capability and device hardening

Directives added:
```ini
PrivateDevices=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectClock=yes
ProtectHostname=yes
ProtectProc=invisible
ProcSubset=pid
LockPersonality=yes
MemoryDenyWriteExecute=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
RemoveIPC=yes
SystemCallArchitectures=native
UMask=0027
CapabilityBoundingSet=
AmbientCapabilities=
DevicePolicy=closed
```

**Score after Round 2: ~2.9**
Service status: active (running) 

`CapabilityBoundingSet=` (empty) drops all Linux capabilities from the process.
The payments service does not need to bind privileged ports, change file
ownership, or perform any privileged kernel operations, so an empty bounding
set is safe.

---

### Round 3 — Network restriction

Directives added:
```ini
IPAddressDeny=any
IPAddressAllow=127.0.0.1
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
```

**Score after Round 3: ~2.5**
Service status: active (running) 

`IPAddressDeny=any` with `IPAddressAllow=127.0.0.1` restricts all outbound
and inbound connections to loopback only. This is appropriate for kk-payments
because it only accepts connections from nginx on the same host and never
initiates external connections.

`RestrictAddressFamilies` limits the socket families the process can open.
Even with code execution, an attacker cannot open `AF_NETLINK` (routing table
manipulation) or `AF_PACKET` (raw packet sniffing).

---

### Round 4 — Syscall filtering, kernel log protection, user namespace isolation

Directives added:
```ini
SystemCallFilter=@system-service
ProtectKernelLogs=yes
PrivateUsers=yes
```

**Score after Round 4: 1.2**
Service status: active (running) 

These three directives produced the largest single score drop.

**`SystemCallFilter=@system-service`** restricts the kernel syscalls this
process may invoke to the `@system-service` allowlist (approximately 130
calls). The security output showed multiple ` rows for syscall groups
(`@clock`, `@debug`, `@module`, `@mount`, `@reboot`, `@privileged`,
`@raw-io`, `@resources`, `@swap`) each contributing 0.1–0.2 exposure.
Adding this filter addressed all of them in one directive.

At the kernel level: if an exploit payload attempts to call `execve()`,
`ptrace()`, or `mmap()` with `PROT_EXEC` outside the allowed set, the kernel
returns `SIGSYS` and kills the payload before privilege escalation can occur.

**`ProtectKernelLogs=yes`** blocks the process from reading `/dev/kmsg` (the
kernel log ring buffer). Kernel logs frequently contain memory addresses,
stack traces, and ASLR information. An attacker who can read `/dev/kmsg` can
extract these addresses to defeat address space randomisation and calculate
where to jump in a return-oriented programming (ROP) chain.

**`PrivateUsers=yes`** gives the process an isolated user namespace view.
The service sees only its own UID and cannot enumerate other users on the
system. This limits reconnaissance after a compromise — an attacker inside
the process cannot discover other service accounts to target.

---

## Rejected Directives

### 1. `PrivateNetwork=yes`

**What it does:** Completely isolates the service from the host network by
placing it in its own network namespace with only a loopback interface.

**Why rejected:** kk-payments listens on port 3001 and accepts connections
from nginx running on the same host. `PrivateNetwork=yes` would give the
service its own loopback that is not shared with the host, meaning nginx's
connection to `127.0.0.1:3001` would fail — the service would be unreachable.
The score impact (0.5 reduction) was tempting, but a payments service that
nginx cannot reach is not a functioning payments service.

The `IPAddressDeny=any` + `IPAddressAllow=127.0.0.1` combination achieves
similar network restriction without breaking the loopback communication path.

---

### 2. `RootDirectory=/opt/kijanikiosk/payments`

**What it does:** Runs the service in a chroot jail, confining its filesystem
view to the specified directory. This would reduce the `RootDirectory=` exposure
row (0.1) and significantly limit what an attacker can access if they achieve
code execution.

**Why rejected:** Setting up a proper chroot requires copying all runtime
dependencies (Python interpreter, shared libraries, `/etc/resolv.conf`, device
nodes) into the chroot directory. For a Python service, this means replicating
a significant portion of the filesystem. Without those dependencies the service
fails to start with `No such file or directory` errors on the Python binary
itself. Implementing this correctly would require a dedicated chroot setup
phase in the provisioning script and ongoing maintenance as Python and library
versions change. The score improvement (0.1) does not justify the operational
complexity for a staging environment. It is noted as a production hardening
candidate if the service is ever containerised.

---

## Final Score

```
→ Overall exposure level for kk-payments.service: 1.2 OK 
```

**Final score: 1.2** — well below the 2.5 requirement.

The service remained active and running throughout all hardening rounds.
No directive caused a service failure.

---

## Final Unit File

```ini
[Unit]
Description=KijaniKiosk Payments Service
After=network.target kk-api.service
Wants=kk-api.service

[Service]
Type=simple
User=kk-payments
Group=kk-payments
WorkingDirectory=/opt/kijanikiosk/payments
EnvironmentFile=/opt/kijanikiosk/config/payments-api.env
ExecStart=/usr/bin/python3 /opt/kijanikiosk/payments/payments_service.py
Restart=on-failure
RestartSec=5s
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectClock=yes
ProtectHostname=yes
ProtectProc=invisible
ProcSubset=pid
LockPersonality=yes
MemoryDenyWriteExecute=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
RemoveIPC=yes
SystemCallArchitectures=native
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
UMask=0027
CapabilityBoundingSet=
AmbientCapabilities=
DevicePolicy=closed
IPAddressDeny=any
IPAddressAllow=127.0.0.1
SystemCallFilter=@system-service
ProtectKernelLogs=yes
PrivateUsers=yes
ReadOnlyPaths=/opt/kijanikiosk/config
ReadWritePaths=/opt/kijanikiosk/shared/logs

[Install]
WantedBy=multi-user.target
```


---

### Screenshot evidence: 
```
sudo systemd-analyze security kk-payments.service
```
![Images](./Images/kk-payments.service%20hardened%20to%20exposure%20score%20below%202.5.png)