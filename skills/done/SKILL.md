---
name: done
description: "End-of-session wrapper. Runs /reflect for experience extraction, prints a session summary, updates progress tracking, and flags outstanding work. Use when finishing a session."
---

# Done — Session End Skill

Wraps up the current session with experience extraction, progress tracking, and status reporting.

## Step 1: Run /reflect

Invoke the `/reflect` skill. This extracts experiences from the conversation, persists them to memory, and runs the decay sweep.

Wait for `/reflect` to complete before proceeding.

## Step 2: Session Summary

Print a summary of what happened this session:

```
Session Summary
───────────────
Built:
- <list of features/changes completed>

In Progress:
- <list of unfinished work>

Blocked:
- <list of blockers, if any>

Next:
- <suggested next steps>
```

Derive this from:
- Tasks completed during the session
- Files created or modified (check git status/diff if available)
- Any outstanding tasks still pending
- Any blockers or questions raised but not resolved

## Step 3: Update Progress File

Write the session summary to a `progress.txt` file in the project root, replacing any existing content.

Format:
```
Last session: <YYYY-MM-DD>

Built:
- <items>

In Progress:
- <items>

Blocked:
- <items>

Next:
- <items>
```

## Step 4: Flag Outstanding Work

If any task tracking files have unchecked items, remind the user:
> "There are N unchecked items in the task list. Review before next session?"

## Rules
- This skill is the GUARANTEED trigger for `/reflect`. Any hooks are best-effort.
- Keep the summary terse — this is end-of-session, not a report.
- Do not prompt for confirmation — just run. The user typed `/done`, they want to wrap up.
