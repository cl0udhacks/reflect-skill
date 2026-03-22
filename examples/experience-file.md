---
schema_version: 1
name: deploy-verification
description: Always verify branding/title after deploy matches expected app
type: feedback
frequency: 3
last_triggered: 2026-03-22
decay_eligible: false
---

Always verify branding/title in browser after deploy matches expected app.

**Why:** Deployed App A's build to App B's hosting project when the deploy command didn't include a `cd` to the correct directory.
**How to apply:** After any deploy, curl the production URL and check the response matches the expected app. Use `cd /path && pwd && deploy` pattern as a visual sanity check.
