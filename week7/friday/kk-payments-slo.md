
# KijaniKiosk Payments Service — SLI and SLO Definitions

**Service:** kk-payments  
**Owner:** Platform Engineering  
**Effective date:** April 26, 2026  
 

## SLI 1 — Availability
**Definition:** Proportion of time the kk-payments health endpoint returns HTTP 200 with "status": "healthy" over a rolling 30-day window.  
**Measurement:** One health check every 10 seconds. Success = HTTP 200 within 2 seconds.  
**SLO target:** 99.9% over any rolling 30-day window (max 43.8 minutes downtime per month).

## SLI 2 — Latency
**Definition:** Proportion of payment requests completing within 800ms at P95 over a rolling 30-day window.  
**Measurement:** nginx $request_time variable in access logs across all /api/payments/* endpoints.  
**SLO target:** 95% of requests must complete within 800ms at P95.

## SLI 3 — Payment Error Rate
**Definition:** Proportion of payment requests returning HTTP 5xx or application-level error over a rolling 30-day window.  
**Measurement:** nginx access log $status field for 5xx responses. Client 4xx errors excluded.  
**SLO target:** Error rate must remain below 0.1% over any rolling 30-day window.

## Rollback Threshold Table

| SLI | 30-day SLO | Rollback Threshold | Window | Justification |
|-----|-----------|-------------------|--------|---------------|
| Availability | 99.9% | 3 consecutive failed health checks | ~30 seconds | 3 failures = sustained outage not a blip. 30s ≈ 417 failed requests = 1.1% of monthly error budget. |
| Latency | P95 ≤ 800ms | P95 > 1,500ms over 5 checks | ~50 seconds | 5 consecutive readings indicates structural problem not a spike. |
| Payment error rate | < 0.1% | > 5% error rate over 2 minutes | 2 minutes | 5% is 50x the SLO threshold. Would consume entire monthly budget in under 4 minutes. |

## What We Do Not Commit To

**1. Upstream payment processor availability**  
We measure the kk-payments service itself. Payment failures caused by third-party processor downtime are excluded from SLO calculations — processor availability is outside our control.

**2. End-to-end transaction completion rate**  
We commit to API availability and server-side error rate only. Transaction completion depends on factors outside our service: card validity, processor routing, fraud detection rules — measured separately by the payments product team.

**3. Performance during traffic spikes beyond 3x baseline**  
Our latency SLO is validated at up to 50,000 requests per hour. Traffic spikes above 150,000 requests per hour without advance notice are not covered by the latency SLO.
