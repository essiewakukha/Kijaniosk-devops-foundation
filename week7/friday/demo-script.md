cat > week7/friday/demo-script.md << 'EOF'
# Demo Script — KijaniKiosk Deployment Pipeline
## Board Presentation — Monday Meeting

**Speaker:** Nia (CEO)  
**Operator:** Amina (platform engineering)  
**Audience:** Non-technical board members  

---

### Beat 1 — Introduction

What you are about to see is the system that protects our payments platform
from the moment a new version is released until it is confirmed safe.
Before today, a software failure meant a person had to fix it manually.
Now the system fixes itself.

---

### Beat 2 — Deploy

A new version of our payments software has just been released to a separate
isolated copy of our system — not yet visible to customers. The version our
customers use right now is completely unaffected.

---

### Beat 3 — Switch Traffic

Customers have now been moved to the new version. The previous version
remains on standby, ready to return instantly if anything goes wrong.

---

### Beat 4 — Fault Introduction

Amina has just made the new version fail deliberately — simulating a
critical software flaw. The system is detecting the problem in real time.
No one has been called.

---

### Beat 5 — Automated Rollback

"he system has switched back to the previous version on its own.
Our customers were never exposed to the faulty version.
No human decision was required.

---

### Beat 6 — Summary

From the moment the fault appeared to the moment our customers were
protected: 22 seconds. That number is from the test we just ran.

If our team ever releases a flawed version — at any hour, on any day —
our customers experience at most 22 seconds of disruption before the
system corrects itself. No phone calls. No manual recovery.
That is what we have built.

---

