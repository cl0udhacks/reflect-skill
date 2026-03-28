# Hermes Memory Enhancements

Two enhancements to the Hermes agent memory system that improve cross-session learning and prevent memory bloat.

## Problem

Hermes agents have an 8,000-character memory (MEMORY.md) that persists across sessions and is injected into every turn. The daily session reset at 4 AM ET prompts agents to save "important facts" before context is cleared.

Two problems emerged:

1. **Agents only saved facts, not lessons.** If you corrected an agent's behavior ("don't quote pricing from memory, check the page first"), that correction died with the session. Next day, the agent made the same mistake because the *lesson* was never saved — only factual state.

2. **Memory bloated with session logs.** Agents treated memory as a diary — re-saving pricing data on every session, logging "verified on March 27", "verified on March 28", saving browser tool status repeatedly. One agent hit 95% capacity with mostly duplicate entries.

## Enhancement 1: Reflect Skill

A Hermes-native skill that teaches agents to extract behavioral lessons from conversations and save them in a structured format alongside factual memory.

### What it does

Adds three categories of experience extraction that the default session reset doesn't capture:

| Category | Prefix | Signal | Example |
|----------|--------|--------|---------|
| Corrections | `[CORR]` | User said "no", "don't", rejected approach | "Don't quote pricing from memory" |
| Validated Approaches | `[VALID]` | User confirmed non-obvious choice | "Bullet-point standup format works well" |
| Architectural Decisions | `[ARCH]` | Workflow or process settled | "Social posts go through Angela first" |

Each entry follows a structured format:
```
[CORR] Don't quote pricing from memory — always check the live pricing page first | Why: Quoted outdated Lantern pricing, missed tiers | Apply: Use browser tools before any pricing discussion (×2, 2026-03-28)
```

The `×N` frequency counter and date enable self-managed decay — high-frequency lessons survive, one-off corrections can be dropped when memory is tight.

### How it works

The skill implements four phases:

1. **EXTRACT** — Scan conversation for corrections, validated approaches, and decisions. Filter out anything already in memory or only relevant to the current session.
2. **PERSIST** — Save to memory using `memory_save` with structured prefixes. Deduplicate against existing entries — update frequency rather than creating duplicates.
3. **DECAY** — Review existing experience entries. Remove stale ones (60+ days, low frequency) when memory is tight. Never remove safety-related entries.
4. **REPORT** — Print a one-line summary: `Reflect: N new, M updated, K removed`

### Installation

The skill file goes in each agent's skills directory:

```
/home/<user>/.hermes/skills/reflect/SKILL.md          # michael
/home/<user>/.hermes-angela/skills/reflect/SKILL.md    # angela
/home/<user>/.hermes-jim/skills/reflect/SKILL.md       # jim
/home/<user>/.hermes-robert/skills/reflect/SKILL.md    # robert
/home/<user>/.hermes-dwight/skills/reflect/SKILL.md    # dwight
/home/<user>/.hermes-kelly/skills/reflect/SKILL.md     # kelly
```

Deploy to all agents:
```bash
# From local machine
scp skills/reflect/SKILL.md <server>:/tmp/reflect-skill.md
ssh <server> 'for agent in "" "-angela" "-jim" "-robert" "-dwight" "-kelly"; do
  mkdir -p "/home/<user>/.hermes${agent}/skills/reflect"
  cp /tmp/reflect-skill.md "/home/<user>/.hermes${agent}/skills/reflect/SKILL.md"
done && rm /tmp/reflect-skill.md'
```

Restart agents to load:
```bash
ssh <server> 'for c in hermes-gateway hermes-angela hermes-jim hermes-robert hermes-dwight hermes-kelly; do
  sudo docker exec "$c" python3 -c "import os, signal; os.kill(1, signal.SIGUSR1)" 2>/dev/null || sudo docker restart "$c"
done'
```

Verify registration:
```bash
ssh <server> 'sudo docker exec hermes-gateway /app/venv/bin/hermes skills list 2>&1 | grep reflect'
```

### Usage

- **Manual:** Message an agent `/reflect` at any point during a conversation
- **Session reset:** Agents apply reflect principles during the daily 4 AM automatic session reset when prompted to save memory
- **After corrections:** Agents should proactively save `[CORR]` entries when corrected, even without explicitly invoking the skill

### Design decisions

**Why not use the original reflect-skill as-is?** The [original reflect-skill](https://github.com/cl0udhacks/reflect-skill) is built for Claude Code's file-based memory system (individual `.md` files with YAML frontmatter, indexed by MEMORY.md). Hermes uses a different system — a single flat MEMORY.md file with `§` separators and a built-in `memory_save`/`memory_delete` tool. The adapted version works within Hermes's existing memory architecture with no gateway code changes.

**Why prefixes instead of separate files?** Hermes injects the entire MEMORY.md into every turn. There's no mechanism to selectively load experience files. Prefixed entries in the same file are always available to the agent and don't require changes to the prompt assembly pipeline.

**Why frequency tracking in-line?** Without individual files, there's no YAML frontmatter for metadata. The `(×N, date)` suffix is a compact way to track decay eligibility within the flat-file constraint.

---

## Enhancement 2: Memory Rules (SOUL.md)

A section appended to each agent's SOUL.md (static system prompt) that enforces memory hygiene discipline at the source — preventing bloat before it happens.

### What it does

Defines explicit rules for what belongs in memory and what doesn't, loaded into every session as part of the system prompt. This is the preventive layer — reflect handles extraction, memory rules handle restraint.

### The rules

Appended as a `## Memory Rules` section at the end of each agent's SOUL.md:

```markdown
## Memory Rules

Your memory has an 8,000 character hard limit. Treat it as premium storage — every character must earn its place.

### What belongs in memory
- Durable facts that change rarely (team structure, product names, pricing tiers)
- Behavioral lessons from corrections — these prevent Sean from repeating himself
- Settled decisions and workflows that affect how you operate
- Key blockers or dependencies you need to track across sessions

### What does NOT belong in memory
- Session timestamps or "verified on date X" entries — memory is not a log
- Duplicate entries — if pricing is already saved, do not save it again, update the existing entry
- Status updates that belong in /shared/ docs (project progress, launch checklists)
- Browser tool status, tool debugging notes, or infrastructure state
- Research plans or task lists — those belong in session context or /shared/

### Memory hygiene
- One entry per topic. Merge, do not accumulate.
- Before saving, scan existing memory for overlap. Update > create.
- When memory exceeds 70%, compress verbose entries and drop stale ones.
- Factual entries that are also in /shared/ docs can be removed from memory — you can always read the file.
- Behavioral lessons ([CORR], [VALID], [ARCH]) outrank factual entries when space is tight.
```

### Installation

The rules are appended to each agent's SOUL.md on the server:

```
/home/<user>/.hermes/SOUL.md          # michael
/home/<user>/.hermes-angela/SOUL.md   # angela
/home/<user>/.hermes-jim/SOUL.md      # jim
/home/<user>/.hermes-robert/SOUL.md   # robert
/home/<user>/.hermes-dwight/SOUL.md   # dwight
/home/<user>/.hermes-kelly/SOUL.md    # kelly
```

To add to all agents (idempotent — checks before appending):
```bash
ssh <server> 'MEMORY_RULES=$(cat <<'"'"'RULES'"'"'

## Memory Rules

Your memory has an 8,000 character hard limit. Treat it as premium storage — every character must earn its place.

### What belongs in memory
- Durable facts that change rarely (team structure, product names, pricing tiers)
- Behavioral lessons from corrections — these prevent Sean from repeating himself
- Settled decisions and workflows that affect how you operate
- Key blockers or dependencies you need to track across sessions

### What does NOT belong in memory
- Session timestamps or "verified on date X" entries — memory is not a log
- Duplicate entries — if pricing is already saved, do not save it again, update the existing entry
- Status updates that belong in /shared/ docs (project progress, launch checklists)
- Browser tool status, tool debugging notes, or infrastructure state
- Research plans or task lists — those belong in session context or /shared/

### Memory hygiene
- One entry per topic. Merge, do not accumulate.
- Before saving, scan existing memory for overlap. Update > create.
- When memory exceeds 70%, compress verbose entries and drop stale ones.
- Factual entries that are also in /shared/ docs can be removed from memory — you can always read the file.
- Behavioral lessons ([CORR], [VALID], [ARCH]) outrank factual entries when space is tight.
RULES
)

for agent in "" "-angela" "-jim" "-robert" "-dwight" "-kelly"; do
  file="/home/<user>/.hermes${agent}/SOUL.md"
  if ! grep -q "## Memory Rules" "$file" 2>/dev/null; then
    echo "$MEMORY_RULES" >> "$file"
  fi
done'
```

### Design decisions

**Why SOUL.md and not just the reflect skill?** The reflect skill is invoked explicitly or during session reset. But agents save memory throughout conversations — not just at reset time. SOUL.md rules are always in context, governing every `memory_save` call the agent makes. Reflect handles what to extract; memory rules handle what NOT to save.

**Why not increase the 8K limit?** The limit exists because memory is injected into every API call. Larger memory = more tokens per turn = higher cost and slower responses. The right fix is smarter memory, not more memory.

---

## How They Work Together

```
┌─────────────────────────────────────────────────────────┐
│                    Agent Session                         │
│                                                          │
│  SOUL.md (always loaded)                                │
│  ├── Agent identity, role, projects                     │
│  ├── Communication style                                │
│  └── Memory Rules ← prevents bloat on every save        │
│                                                          │
│  MEMORY.md (injected every turn)                        │
│  ├── Durable facts (team, pricing refs, decisions)      │
│  ├── [CORR] Behavioral corrections                      │
│  ├── [VALID] Validated approaches                       │
│  └── [ARCH] Architectural decisions                     │
│                                                          │
│  During conversation:                                    │
│  ├── Memory Rules govern what gets saved                │
│  ├── Agent can invoke /reflect manually                 │
│  └── Corrections saved proactively as [CORR]            │
│                                                          │
│  At session reset (4 AM):                               │
│  ├── System prompts "save important facts"              │
│  ├── Agent applies reflect extraction principles        │
│  ├── Saves behavioral lessons + factual updates         │
│  └── Runs decay sweep on stale entries                  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Monitoring

Check memory health across all agents:
```bash
ssh <server> 'for agent in "" "-angela" "-jim" "-robert" "-dwight" "-kelly"; do
  file="/home/<user>/.hermes${agent}/memories/MEMORY.md"
  chars=$(wc -c < "$file" 2>/dev/null || echo "0")
  pct=$((chars * 100 / 8000))
  name=$(echo ".hermes${agent}" | sed "s/^\.hermes-//" | sed "s/^\.hermes$/michael/")
  echo "$name: ${chars} chars (${pct}%)"
done'
```

Check for experience entries:
```bash
ssh <server> 'for agent in "" "-angela" "-jim" "-robert" "-dwight" "-kelly"; do
  file="/home/<user>/.hermes${agent}/memories/MEMORY.md"
  name=$(echo ".hermes${agent}" | sed "s/^\.hermes-//" | sed "s/^\.hermes$/michael/")
  corr=$(grep -c "^\[CORR\]" "$file" 2>/dev/null || echo "0")
  valid=$(grep -c "^\[VALID\]" "$file" 2>/dev/null || echo "0")
  arch=$(grep -c "^\[ARCH\]" "$file" 2>/dev/null || echo "0")
  echo "$name: ${corr} corrections, ${valid} validated, ${arch} decisions"
done'
```

## Rollback

**Remove reflect skill:**
```bash
ssh <server> 'for agent in "" "-angela" "-jim" "-robert" "-dwight" "-kelly"; do
  rm -rf "/home/<user>/.hermes${agent}/skills/reflect"
done'
```

**Remove memory rules from SOUL.md:**
```bash
# Manually edit each SOUL.md and remove everything from "## Memory Rules" to end of file
ssh <server> 'for agent in "" "-angela" "-jim" "-robert" "-dwight" "-kelly"; do
  file="/home/<user>/.hermes${agent}/SOUL.md"
  sed -i "/^## Memory Rules$/,\$d" "$file"
done'
```

**Remove experience entries from memory:**
```bash
# Agents can be told to "remove all [CORR], [VALID], [ARCH] entries from memory"
# Or manually edit each MEMORY.md
```

After any rollback, restart agents:
```bash
ssh <server> 'for c in hermes-gateway hermes-angela hermes-jim hermes-robert hermes-dwight hermes-kelly; do
  sudo docker exec "$c" python3 -c "import os, signal; os.kill(1, signal.SIGUSR1)" 2>/dev/null || sudo docker restart "$c"
done'
```

## Credits

Inspired by [reflect-skill](https://github.com/cl0udhacks/reflect-skill) by cl0udhacks, adapted for Hermes Agent's native memory system.
