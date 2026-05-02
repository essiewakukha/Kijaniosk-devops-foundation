# KijaniKiosk Deployment Strategy: Week 7 vs Week 8
## Prepared for Nia — Board Presentation, Monday

---

## What Changed and Why It Matters

Week 7 established that the platform could deploy new software, detect a failure,
and recover automatically in 22 seconds without human involvement. That was a
significant step: it replaced a manual process with a reliable, documented one.
But it left an important question unanswered. The recovery worked because the
previous version of the software was already running on the same machine. Nothing
guaranteed that the software itself would behave consistently when moved to a
different environment, and nothing prevented the machine running it from becoming
a single point of failure.

Week 8 addresses both of those gaps. The payments service is now packaged as a
self-contained unit that carries everything it needs to run: its compiled code,
its exact dependencies, and a declaration of the user account it is permitted to
operate as. This package is stored in a private registry with a unique identifier
tied to the specific code change that produced it. When the platform deploys the
service, it pulls that exact package from the registry and runs it on a cluster
that maintains two independent copies at all times.

The difference in image size tells part of the story. The original unoptimised
container image weighed approximately 190 megabytes. The production image produced
this week is 44 megabytes — a reduction of 77 percent achieved by separating the
build environment from the runtime environment and excluding all development tools
from the final package. This reduction matters because smaller images pull faster, reduce attack surface, and improve deployment consistency.

The cluster's self-healing capability was verified during this week's testing. When
one of the two running copies of the payments service was deleted to simulate a
failure, the cluster detected the missing copy and started a replacement
automatically. The replacement was confirmed running within 70 seconds, without
any human action, and without any interruption to the service — the second copy
continued serving requests throughout the recovery period.

---

## Comparison

| Concern | Week 7 Approach | Week 8 Approach |
|---------|----------------|-----------------|
| **Deployment mechanism** | A shell script switched traffic between two versions of the software running as processes on a single server. The switch was fast but depended entirely on that server remaining available. | A versioned container image tagged with the code version and commit reference is pulled from a registry and run on a cluster. The deployment is described in a manifest that any engineer with registry access can apply to any compatible cluster and get identical results. |
| **Rollback mechanism** | Automated rollback fired in 22 seconds by switching traffic back to the previous process. Recovery was fast but required the previous version to already be running and healthy on the same machine. | The registry retains every tagged image. Rolling back means applying the previous manifest, which instructs the cluster to pull the previous image. No prior state on any machine is required for rollback to succeed. |
| **Failure recovery** | The monitor detected failures and switched traffic. One process was always responsible for recovery logic, and that process itself could fail. | The cluster's control plane continuously reconciles desired state with actual state. When a container failed during this week's verification, the replacement was running within 70 seconds without any script or human action. |
| **Scaling** | Scaling required starting additional processes manually on additional servers, which needed to be provisioned and configured in advance. | Scaling is a single declarative change to the replica count. The cluster handles placement, scheduling, and load distribution. The payments service currently runs two copies at all times, meaning a single container failure causes zero service interruption. |

---

## What Week 8 Does Not Yet Solve

The deployment is more reliable and more reproducible than it was last week, but
it is not yet production-complete. The cluster currently has no automated path
from a code change to a running deployment — an engineer still applies the manifest
manually, which means the version running in the cluster depends on a human action
rather than a verified pipeline. There is also no mechanism to distinguish between
a container that is running and one that is genuinely ready to serve payment
requests, meaning a container that has started but not yet finished initialising
may receive traffic and return errors during that window. Week 9 introduces both
of these controls: a continuous delivery pipeline that moves a verified image from
a code commit to a running deployment without manual steps, and readiness checks
that hold traffic back until the service is confirmed ready to serve.
Overall, Week 8 replaces machine-dependent deployment with a reproducible, self-healing system, significantly improving reliability and operational confidence.
