
# Post-Incident Review
## Week 5 Monday Morning — Pipeline Targeted Wrong Environment

 
**Severity:** P2 — Staging unavailability during investor demonstration  
**Duration:** 48 seconds  


## Section 1: Incident Summary

During Monday morning's investor walkthrough, the automated deployment system sent
the new version of the application to the live demonstration environment instead of
the isolated test environment it was supposed to target. This caused the demonstration
to be unavailable for 48 seconds while the team identified the problem and restored
normal operation. No customer-facing service was affected because the incident was
contained to the staging environment.

## Section 2: Timeline

| Time | Event |
|------|-------|
| 09:00 (estimated) | Nia begins investor walkthrough of the kk-payments deployment pipeline |
| 09:04 (estimated) | Amina triggers the deployment pipeline to demonstrate a blue/green deployment |
| 09:04:15 (estimated) | Pipeline reads TARGET_ENV variable from current shell session |
| 09:04:18 (estimated) | Pipeline targets wrong environment — active blue instead of idle green |
| 09:04:20 (estimated) | Active blue environment begins receiving deployment, disrupting demonstration |
| 09:04:22 (estimated) | Nia observes demonstration is unavailable |
| 09:04:28 (estimated) | Tendo identifies incorrect environment target from pipeline output |
| 09:05:08 | Normal service restored — 48 seconds total unavailability |
| 09:06 (estimated) | Nia resumes investor walkthrough |
| 09:15 (estimated) | Tendo opens incident review thread in engineering channel |

## Section 3: Root Cause

The deployment script read the TARGET_ENV environment variable to determine which
environment to deploy to. This variable was set to the active environment (blue)
in Amina's shell session from a previous manual operation. The pipeline had no
guard that compared TARGET_ENV against /opt/kijanikiosk/.active-env before
proceeding. If such a guard existed, the pipeline would have detected the conflict
and exited with an error before any deployment action was taken.

## Section 4: Contributing Factors

**1. No pre-flight environment validation in the deployment script**  
The script trusted the TARGET_ENV variable without verifying it against the recorded
active environment state, making behaviour dependent on the operator's shell environment.

**2. No separation between demonstration setup and production operations**  
Amina had set TARGET_ENV=blue during morning setup work with no process requiring
a shell environment reset before running a demonstration.

**3. The state file existed but was not used as a validation source**  
The .active-env file records the current active environment but the deployment
script did not read it to cross-check the intended target.

**4. No documented reset checklist before demonstrations**  
The Friday reset procedure did not exist at the time. Environment state before
the investor walkthrough was assumed correct rather than verified.

## Section 5: What Went Well

**Manual recovery was fast:** Tendo identified the wrong environment target from
pipeline output within approximately 8 seconds. Manual recovery restored service
in 48 seconds total — demonstrating the team understood the system well enough
to diagnose and recover without documentation or escalation.

**Incident was contained to staging:** The architectural decision to maintain
completely separate blue and green environments meant no customer-facing payment
service was affected.

## Section 6: Action Items

| # | Action | Owner | Description | Target |
|---|--------|-------|-------------|--------|
| 1 | Add active-environment guard to deployment script | Platform Engineering (Amina) | Modify deploy.sh to read .active-env before proceeding. If TARGET_ENV matches active environment, exit non-zero with clear error message. Makes it structurally impossible to deploy to live environment by accident. | Within 1 week |
| 2 | Add mandatory pre-demonstration reset checklist | Engineering Lead (Tendo) | Create checklist in runbook that must be completed before any demonstration: confirm service states, confirm active environment via state file, confirm proxy version via curl, confirm TARGET_ENV is set to idle environment. | Within 3 days |
| 3 | Replace shell environment variable with config file | Platform Engineering (Amina) | Remove reliance on TARGET_ENV shell variable. Replace with read from fixed path config file written by explicit set-target command. File-based config is auditable and not affected by session contamination. | Within 2 weeks |
| 4 | Implement automated rollback in post-deploy monitor | Platform Engineering (Amina) | Manual 48-second recovery is too slow for kk-payments SLO. Implement post-deploy-monitor.sh with automated rollback trigger. Target: under 90 seconds end-to-end with no human action required. | End of Week 7 |
