# KijaniKiosk Infrastructure Hardening Decisions
### Prepared for Board Review | Week 4 | April 2026

---

## Introduction

This document describes the security decisions made when building
the KijaniKiosk staging infrastructure. It is written for a
non-technical audience. Its purpose is to explain what protections
are in place, why each one was chosen, and what risks each one
addresses.

The staging environment consists of three servers: one handling
the application programming interface, one handling payment
processing, and one handling system logs. Each server was
provisioned automatically using infrastructure code and configured
automatically using a configuration management tool. No server was
set up by hand.

The decisions documented here were made deliberately. Each one
represents a trade-off between convenience and security. Where
a more convenient option was available but carried higher risk,
the more secure option was chosen.

---

## Security Controls

| Control | What It Does | Risk Mitigated |
|---------|-------------|----------------|
| Restricted network access | Only the ports required for each server's role are open. All other traffic is blocked at the network boundary before it reaches the server. | Reduces the number of ways an attacker can attempt to reach the system from the internet. |
| Key-based server access | Servers accept connections only from holders of a specific cryptographic key file. Username and password login is disabled entirely. | Eliminates the possibility of an attacker gaining access by guessing or stealing a password. |
| Dedicated service accounts | Each service runs under its own isolated system identity with no ability to perform administrative actions. | Limits the damage an attacker can cause if one service is compromised — they cannot use it to reach other services or administrative functions. |
| Read-only system protection | The core operating system files are mounted as read-only for each service process. The service can read what it needs but cannot write to system directories. | Prevents a compromised service from modifying the operating system or installing persistent malicious software. |
| New privilege prevention | Service processes are blocked from acquiring permissions beyond those they started with, even if an attacker finds a way to request them. | Closes a common escalation path where an attacker uses a running service to gain administrative control of the server. |
| Remote infrastructure state | The record of what infrastructure exists is stored remotely with locking enabled, meaning only one change can be made at a time and all changes are recorded. | Prevents two engineers from making conflicting changes simultaneously and ensures a complete audit trail of every infrastructure change. |
| Automated AMI sourcing | The base server image is selected automatically based on defined criteria rather than a fixed identifier that can become outdated. | Ensures servers are always built from a current, supported image rather than one that may no longer receive security updates. |
| Automated log persistence | System logs are written to permanent storage and rotated on a defined schedule so that older logs are archived rather than deleted. | Ensures that evidence of unusual activity is retained and available for review, which is a requirement for financial services compliance. |
| Private key isolation | The cryptographic key used to access servers is never stored in the infrastructure code, the configuration code, or any shared repository. It exists only on the administrator's machine. | Prevents accidental exposure of access credentials through version control systems, which is one of the most common causes of infrastructure breaches. |

---

## Why Automation Is Itself a Security Control

Every server in the KijaniKiosk staging environment was built
from the same specification. The same specification runs the same
way every time it is applied. This means the security controls
described above are not applied once by one engineer and then
trusted to persist — they are reapplied and verified every time
the configuration management tool runs.

This matters because systems drift. An engineer making a manual
change to fix an urgent problem, a software update that adjusts
a file permission, a new package that opens a port — these are
the ordinary events that cause a system to gradually diverge from
its intended state. Automated configuration management detects
and corrects that drift automatically. The second run of the
configuration tool against all three servers produced no changes,
confirming that the system was in exactly the state the
specification described.

For a financial services platform, this is not a convenience — it
is an accountability requirement. When an auditor asks whether the
payments server is configured to the documented standard, the
answer is not "we believe so." The answer is "we ran the
verification tool against it this morning and it showed no
deviations."

---

## The Payment Service Security Score

The payment processing service was evaluated using a built-in
operating system security assessment tool. It achieved a score
of 2.1, below the 2.5 threshold set as the project requirement.
This score reflects the combination of read-only system
protection, privilege prevention, and service account isolation
described in the table above. The service starts correctly and
operates normally under these restrictions.

---

## What the Current Posture Does Not Protect Against

The controls described in this document protect the infrastructure
layer — the servers, the network boundaries, and the service
processes. They do not protect against vulnerabilities in the
application code itself. If the payment processing application
contains a flaw that allows an attacker to manipulate transactions,
the infrastructure hardening described here will not prevent that.
The current posture also does not include intrusion detection,
meaning that a sophisticated attacker who gains access through an
application vulnerability may not be detected until damage has
already occurred. Encryption of data at rest on the server volumes
is not yet enabled. These are the next priorities for the security
roadmap and will be addressed before the environment is promoted
to production.