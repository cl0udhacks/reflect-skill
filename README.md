# reflect-skill

**Teach your AI coding assistant to learn from its mistakes.**

Most AI coding agents hit reset every conversation. They don't remember that you corrected them yesterday, that a particular approach worked well last week, or that a deployment pattern burned you last month. Every session starts from zero.

`reflect-skill` fixes this by adding an **experience extraction layer** — a skill that runs at the end of each session to capture what went right, what went wrong, and what was decided, then persists those lessons so future sessions start smarter.

## The Dual-Loop Model

AI coding assistants typically operate with a single loop:

```
User request → Think → Execute → Done
```

This is the **inner loop** — it handles the immediate task. It works, but it has no memory. The agent makes the same mistakes, asks the same clarifying questions, and re-discovers the same constraints session after session.

`reflect-skill` adds an **outer loop**:

```
┌─────────────────────────────────────────────────────┐
│ OUTER LOOP (experience gathering)                   │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │ INNER LOOP (task execution)                   │  │
│  │                                               │  │
│  │  User request → Think → Execute → Done        │  │
│  │                                               │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  Extract lessons → Persist → Decay stale ones       │
│                                                     │
└─────────────────────────────────────────────────────┘
```

The outer loop observes patterns across sessions: corrections the user made, approaches that worked well, architectural decisions that were settled. It extracts these as structured **experience files** that persist between conversations, giving the agent a growing base of project-specific knowledge.

The key insight is **separating task logic from experience gathering**. The inner loop stays fast and focused on the current task. The outer loop runs at natural boundaries (after a commit, after a deploy, at session end) and handles the slower, reflective work of learning.

### Why separation matters

- **No overhead during work** — extraction happens after the task, not during
- **Selective memory** — not everything is worth remembering. The skill filters for durable lessons
- **Natural decay** — experiences that stop being relevant are automatically archived
- **No context bloat** — only active, relevant experiences are loaded into future sessions

## What It Captures

`/reflect` extracts three categories of experience, in priority order:

| Category | Signal | Example |
|----------|--------|---------|
| **Corrections** | User said "no", "don't", redirected approach | "Don't mock the database in integration tests" |
| **Validated approaches** | User confirmed something non-obvious worked | "The bundled PR was the right call for this refactor" |
| **Architectural decisions** | A design choice was discussed and settled | "We use KV for rate limiting, not in-memory counters" |

Each experience is persisted as a structured file:

```yaml
---
schema_version: 1
name: deploy-verification
description: Always verify deploy target matches expected app
type: feedback
frequency: 3
last_triggered: 2026-03-22
decay_eligible: false
---

Always verify branding/title in browser after deploy matches expected app.

Why: Deployed App A's build to App B's hosting project.
How to apply: After any deploy, curl the production URL and verify the response.
```

## How Decay Works

Not every lesson stays relevant forever. `reflect-skill` includes automatic decay:

- **Active** — triggered within the last 60 days. Loaded normally.
- **Stale** (60+ days, still active) — flagged with a warning in the index. Still loaded, but visually marked for review.
- **Archived** (90+ days AND fewer than 3 triggers) — moved to `archived/`. Not loaded into context, but not deleted. Can be un-archived if the topic comes up again.
- **Protected** — experiences marked `decay_eligible: false` never decay. Use this for critical safety rules.

High-frequency experiences survive longer. Something triggered 5 times over 120 days is clearly a recurring pattern — it stays active even though it's "old."

## Installation

### 1. Copy the skill files

Copy the `skills/` directory into your project's skill directory.

**Claude Code:**
```bash
cp -r skills/reflect .claude/skills/reflect
cp -r skills/done .claude/skills/done
```

**Other harnesses:** Place the `SKILL.md` files wherever your AI assistant discovers skills. The skill is plain markdown with YAML frontmatter — it works with any system that loads skill files.

### 2. Create the memory directory structure

Create these directories in your project's persistent memory location:

```bash
# Claude Code example (adjust path for your project)
MEMORY_DIR="$HOME/.claude/projects/<your-project>/memory"

mkdir -p "$MEMORY_DIR/experiences/archived"
mkdir -p "$MEMORY_DIR/state"
```

If you already have memory files, organize them:
- **Feedback/lessons** → `experiences/` (prefix with `exp_`)
- **Project context** → `state/`

### 3. (Optional) Add the auto-trigger hook

This hook nudges your assistant to run `/reflect` after commits and deploys. It's best-effort — `/done` is the guaranteed trigger.

**Claude Code** — add to `~/.claude/settings.json` in the `hooks.PostToolUse` array:

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "INPUT=$(cat); COMMAND=$(echo \"$INPUT\" | jq -r '.tool_input.command // empty'); SUCCEEDED=$(echo \"$INPUT\" | jq -r '.tool_succeeded // false'); if [ \"$SUCCEEDED\" = \"true\" ] && echo \"$COMMAND\" | grep -qE '(git commit|wrangler deploy)'; then echo 'Session marker detected - run /reflect before ending.'; fi",
      "timeout": 5
    }
  ]
}
```

**Other harnesses:** Configure a post-action hook that fires after `git commit` or deploy commands. The hook should print a reminder message that your AI assistant can see.

## Usage

### Manual (anytime)
```
/reflect
```
Scans the current conversation and extracts experiences. Run whenever you want.

### End of session (recommended)
```
/done
```
Runs `/reflect`, prints a session summary, updates `progress.txt`, and flags outstanding work. This is the intended workflow — type `/done` when you're finished working.

### Automatic (via hook)
If you installed the hook in step 3, your assistant will be nudged to run `/reflect` after each commit or deploy. This is best-effort — the assistant may be mid-task and not act on it immediately.

## How It Enhances Your Workflow

**Session 1:** You correct the agent — "don't use `--set-env-vars`, it's destructive."
`/reflect` captures this as an experience.

**Session 2:** The agent reads the experience before suggesting env var commands. It uses `--update-env-vars` without being told.

**Session 5:** The experience has been triggered 4 times. It's now a high-frequency pattern — it will never be auto-archived.

**Session 30:** An old experience about a testing pattern hasn't been relevant in 95 days and was only triggered once. `/reflect` auto-archives it, keeping the active experience set lean and focused.

The result: your AI assistant gets better at working with **your** codebase, **your** preferences, and **your** constraints over time — without you having to repeat yourself.

## Compatibility

`reflect-skill` was developed and tested with [Claude Code](https://docs.anthropic.com/en/docs/claude-code), but the technique is generic. The skill files are plain markdown with YAML frontmatter. Any AI coding harness that supports:

1. **Skill/prompt loading** — reading markdown files as instructions
2. **File persistence** — creating and editing files on disk
3. **Session context** — the ability to scan the current conversation

...can use this skill. The dual-loop pattern works regardless of which LLM or harness you use.

## Examples

See the [`examples/`](examples/) directory for:
- [experience-file.md](examples/experience-file.md) — A complete experience entry with all frontmatter fields
- [memory-structure.md](examples/memory-structure.md) — Recommended directory layout with decay examples

## License

MIT
