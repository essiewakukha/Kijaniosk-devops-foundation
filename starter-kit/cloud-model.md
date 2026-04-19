# Cloud Service Model

## Selected Service Model: Platform as a Service (PaaS)

### Decision Summary

The KijaniKiosk platform is best implemented using a Platform as a Service (PaaS) model to prioritise rapid development, operational efficiency, and scalability.

---

## Justification

PaaS provides a managed environment where the cloud provider handles:

* Infrastructure provisioning (servers, networking, storage)
* Operating system management and patching
* Runtime environment configuration

This allows the engineering team to focus entirely on application logic.

For KijaniKiosk, this is particularly important because:

* The platform is a **payment application**, where development speed and reliability are critical
* The team can **avoid managing infrastructure complexity** in early stages
* Built-in scaling ensures the system can handle **increased transaction load**
* Managed services reduce the risk of **configuration errors and downtime**

---

## Trade-offs

While PaaS offers significant advantages, it introduces some limitations:

* Reduced control over underlying infrastructure compared to IaaS
* Potential vendor lock-in depending on the platform used

However, for an early-stage system, these trade-offs are acceptable because:

* Speed of delivery is more valuable than infrastructure control
* Operational overhead must remain low

---

## Comparison with Other Models

### Infrastructure as a Service (IaaS)

IaaS provides virtual machines, storage, and networking, but requires the team to manage:

* Operating systems
* Security patching
* Runtime environments

Why not chosen:

* Increases operational complexity
* Slows down development
* Requires additional DevOps effort for maintenance

Conclusion:
IaaS offers flexibility but is not efficient for rapid product development at this stage.

---

### Software as a Service (SaaS)

SaaS delivers fully managed applications that users configure but do not build.

Why not chosen:

* KijaniKiosk requires a **custom-built payment platform**
* SaaS does not allow full control over business logic

Conclusion:
SaaS is unsuitable because it does not support building proprietary applications.

---

## Final Decision

PaaS provides the optimal balance between:

* Development speed
* Operational simplicity
* Scalability
* Reliability

It enables the team to focus on delivering business value while the cloud provider manages infrastructure concerns.

This makes it the most appropriate model for KijaniKiosk at its current stage.
