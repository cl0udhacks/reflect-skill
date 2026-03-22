# Example Memory Directory Structure

After setting up `/reflect`, your memory directory will look like this:

```
memory/
├── MEMORY.md                     # Index file (loaded into context)
├── experiences/                  # Durable lessons (outer loop)
│   ├── archived/                 # Auto-archived stale experiences
│   ├── exp_deploy-safety.md      # frequency: 5, decay_eligible: false
│   ├── exp_api-pagination.md     # frequency: 2, last_triggered: 2026-03-15
│   └── exp_test-isolation.md     # frequency: 1, last_triggered: 2026-01-10
└── state/                        # Project-specific context (inner loop)
    ├── scaling-analysis.md
    ├── mobile-plans.md
    └── session-notes.md
```

## What goes where?

**`experiences/`** — Lessons that apply across sessions and projects:
- Corrections ("don't mock the database in integration tests")
- Validated approaches ("the bundled PR was the right call")
- Safety rules ("never use --set-env-vars, always --update-env-vars")

**`state/`** — Context specific to ongoing work:
- Project plans and roadmaps
- Session summaries
- Architecture decisions for a specific feature

**`experiences/archived/`** — Experiences that haven't been relevant in 90+ days with fewer than 3 triggers. They're not deleted — just moved out of active context. If they become relevant again, `/reflect` can un-archive them.

## Decay Example

```
exp_test-isolation.md
  frequency: 1
  last_triggered: 2026-01-10
  decay_eligible: true

Today: 2026-04-15 (95 days since last trigger)
→ frequency (1) < 3 AND days (95) > 90
→ ARCHIVED to experiences/archived/

exp_deploy-safety.md
  frequency: 5
  last_triggered: 2026-01-05
  decay_eligible: false

Today: 2026-04-15 (100 days since last trigger)
→ decay_eligible: false
→ SKIPPED (critical safety rule, never expires)
```

## MEMORY.md Index Format

Your memory index should have an `## Experiences` section at the top:

```markdown
# Memory

## Experiences

- [exp_deploy-safety.md](experiences/exp_deploy-safety.md) — Always verify deploy target matches expected app
- [exp_api-pagination.md](experiences/exp_api-pagination.md) — Use cursor-based pagination, not offset
- STALE [exp_test-isolation.md](experiences/exp_test-isolation.md) — Isolate test databases per suite

## State

- [scaling-analysis.md](state/scaling-analysis.md) — Current scaling ceiling analysis
- [mobile-plans.md](state/mobile-plans.md) — Mobile app implementation roadmap
```
