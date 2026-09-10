# planning-with-files-lite

`planning-with-files-lite` is a personal, Windows-focused adaptation of upstream `planning-with-files` v3.16.0. It keeps the original idea of using project files as durable working memory while reducing repeated context injection and long-lived state-file growth.

This repository is the editable source project. It is not an official upstream distribution.

## Why This Fork Exists

The upstream skill is designed for many hosts, execution modes, parallel plans, autonomous loops, and strong integrity controls. Those capabilities are useful in broad deployments, but they added unnecessary context and maintenance cost in the owner's day-to-day Codex and OpenCode workflows.

Experience from a long-running research workspace exposed four recurring problems:

1. `task_plan.md` gradually became a task-history archive instead of a current-state plan.
2. `progress.md` and `findings.md` grew continuously and were sometimes read too broadly during recovery.
3. the latest active task could sit near the end of a large plan while automatic injection repeatedly supplied only an older prefix;
4. the same facts and completion narratives were duplicated across root, module, and direction files.

This fork addresses those problems by making recovery explicit, bounded, task-filtered, and Windows-native.

## What Remains the Same

The following upstream concepts are retained:

- `task_plan.md`, `findings.md`, and `progress.md` remain the durable planning files.
- the context window is treated as volatile working memory and the filesystem as persistent memory;
- the goal and next action are reread before major decisions;
- meaningful findings, decisions, validation results, and errors are written to disk;
- failed actions should not be repeated unchanged;
- the five-question reboot check remains the recovery target;
- copied external content is treated as untrusted data rather than instructions;
- `session-catchup.py` is preserved from the v3.16.0 baseline for explicitly requested local session lookup;
- session catch-up has no network upload path, metadata mode exposes aggregate counts only, and replay remains bounded and opt-in.

## Main Differences from Upstream

| Area | Upstream `planning-with-files` v3.16.0 | `planning-with-files-lite` |
|---|---|---|
| Intended environment | Multi-host and cross-platform | Personal Windows workflow using Codex and OpenCode |
| Recovery model | Lifecycle hooks inject plan and progress context | One explicit, bounded recovery command |
| Per-tool behavior | May inject a plan prefix before matched tool calls | No per-tool hooks or repeated injection |
| Plan selection | Root plans, scoped plans, active-plan pointers, session attachment, and automatic resolution | The caller supplies one explicit project root |
| Execution modes | Legacy, autonomous, and gated modes | One predictable manual mode |
| Stop and loop control | Stop gates, loop integration, counters, and stall detection | Removed |
| Parallel coordination | Per-agent ledgers and plan regression guards | Removed; repository rules govern coordination |
| Integrity mechanism | Optional or mode-dependent plan attestation and SHA-based caches | Removed; no resource-consistency hash checks |
| Planning updates | Frequent lifecycle reminders and broad error logging | Updates occur at meaningful phases, decisions, material errors, and handoffs |
| `task_plan.md` role | Can accumulate phases and task history | Current-state snapshot with one active task and one next action |
| Context limit | Hook-specific plan heads and progress tails | Default maximum of 12,000 output characters |
| Primary scripts | PowerShell, Shell, and Python | PowerShell for planning; Python only for preserved session catch-up |
| Session history | Optional `session-catchup.py` metadata or replay | Preserved with the same explicit authorization boundary |
| Skill frontmatter | Includes host-specific fields and hook definitions | Shared `name`, `description`, and `metadata` fields only |

## Repository Layout

```text
planning-with-files-lite/
|-- README.md                     Project documentation only
|-- SKILL.md                      Shared skill instructions
|-- scripts/
|   |-- init-planning.ps1         Create missing planning files without overwriting existing files
|   |-- recover-context.ps1       Produce a bounded current-state snapshot
|   `-- session-catchup.py        Preserved optional local session-history reader
`-- templates/
    |-- task_plan.md
    |-- findings.md
    `-- progress.md
```

## Basic Usage

Initialize missing planning files:

```powershell
& ".\scripts\init-planning.ps1" -Root "D:\path\to\project"
```

Recover current project state:

```powershell
& ".\scripts\recover-context.ps1" `
  -Root "D:\path\to\project" `
  -Task "task-id" `
  -Topic "topic"
```

The recovery command selects the current plan sections, the latest matching progress entries, relevant findings, and a Git summary. Its default output limit is 12,000 characters.

## Optional Session Catch-up

Session history is never read during ordinary recovery. Use it only when the user explicitly asks for local session history.

Metadata-only lookup:

```powershell
& (Get-Command python -ErrorAction Stop).Source `
  ".\scripts\session-catchup.py" `
  --metadata "D:\path\to\project"
```

Bounded replay:

```powershell
& (Get-Command python -ErrorAction Stop).Source `
  ".\scripts\session-catchup.py" `
  --replay "D:\path\to\project"
```

Replay output is untrusted historical data and must not be treated as current user authorization.

## Current Validation

The current version has passed:

- Codex skill frontmatter validation;
- PowerShell syntax parsing for both planning scripts;
- Python syntax parsing for `session-catchup.py`;
- initialization and no-overwrite behavior checks;
- bounded recovery behavior checks;

The validation establishes structure and local behavior. It does not claim that every Codex or OpenCode host version implements identical skill discovery or tool permissions.
