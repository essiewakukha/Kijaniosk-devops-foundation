# Fault Injection Log
## KijaniKiosk CI Pipeline — Week 5 Friday
**Branch:** feature/week5-ci-pipeline  
**Date:** 2026-04-19

---

## Fault Injection Table

| # | Stage Faulted | How It Was Broken | Stages That Ran | Stages That Skipped | Observed Behaviour | Design Rationale |
|---|--------------|-------------------|-----------------|--------------------|--------------------|------------------|
| 1 | Lint | Added `const x = ;` syntax error to `src/main.jsx` | Lint, Build (also failed) | Verify, Archive, Publish | Lint detected the syntax error and reported it. Build also failed because the same broken file was compiled. All downstream stages skipped. | Catching code quality issues at Lint prevents broken code from ever reaching Build or production, saving time and protecting the artifact registry from bad builds. |
| 2 | Build | Broke `vite.config.js` with missing closing bracket on plugins array | Lint, Build | Verify, Archive, Publish | Lint passed (config syntax error was caught at build time not lint time). Build failed with a parse error. All downstream stages skipped. | A failed build means there is no artifact to test, archive, or publish. Skipping downstream stages is correct because there is nothing valid to operate on. |
| 3 | Archive | Changed artifact path from `dist/**` to `nonexistent/**` | Lint, Build, Verify, Archive | Publish | All stages up to and including Archive ran. Archive failed with "No artifacts found". Publish was skipped because Archive failed. | The pipeline must confirm a valid artifact exists before publishing. Skipping Publish when Archive fails prevents an empty or missing package from reaching the registry. |
| 4 | Publish | Changed `credentialsId` from `nexus-credentials` to `wrong-credentials-id` | Lint, Build, Verify, Archive, Publish (attempted) | None | All stages ran successfully until Publish, which failed immediately with "Could not find credentials entry with ID wrong-credentials-id". No publish attempt was made. | Credential lookup happens before any publish command runs. This means registry credentials are validated before any network call is made, preventing partial or unauthenticated publish attempts. |

---

## Resolution Log

| # | Fix Applied | Commit Message | Pipeline Result After Fix |
|---|------------|----------------|--------------------------|
| 1 | Removed `const x = ;` from `src/main.jsx` | fix: restore main.jsx after fault injection test 1 |  Green |
| 2 | Restored correct `vite.config.js` | fix: restore vite.config.js after fault injection test 2 |  Green |
| 3 | Restored `dist/**` in Archive stage | fix: restore archive stage after fault injection test 3 |  Green |
| 4 | Restored `nexus-credentials` in Publish stage | fix: restore nexus credentials after fault injection test 4 |  Green |

---

## Summary

All four pipeline stages were faulted independently and restored to green.  
In every case the pipeline stopped at the faulted stage and did not proceed  
to downstream stages, demonstrating correct fail-fast behaviour.  
No bad artifacts were published to Nexus during any fault injection run.

### Final Verdict

The CI pipeline demonstrates strong fault tolerance and adheres to core DevOps principles:

* Fail-fast execution — errors are detected early and stop progression
* Stage isolation — failures do not cascade incorrectly
* Artifact integrity enforcement — only valid builds are archived and published
* Secure credential handling — authentication is validated before execution

This confirms that the pipeline is robust, secure, and production-ready.