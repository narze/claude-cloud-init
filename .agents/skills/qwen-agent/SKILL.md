---
name: qwen-agent
description: Delegate menial, well-scoped coding tasks to a cheap Qwen-backed subagent via the `claude-9arm` command instead of burning Claude tokens/quota. Use when the work is mechanical and low-risk — bulk renames, formatting, boilerplate, find-replace, grep-style search & summarization, reading/condensing logs or files, test/docstring/comment scaffolding, or running builds/linters/tests and reporting pass-fail. Also use when the user says "use qwen", "delegate this", "send it to 9arm/qwen", or "do this cheaply". Do NOT use for architecture, design, debugging judgment, security-sensitive edits, or anything needing this conversation's context.
---

# qwen-agent

Offload **menial, self-contained** tasks to a Qwen model running inside a headless Claude Code instance (`claude-9arm`). Keeps expensive Claude reasoning for work that needs it.

## The command

`claude-9arm` is a shell alias → `claude --model qwen3.6-35b-a3b` routed through the 9arm gateway. Run it headless with `-p`:

```bash
claude-9arm -p "<self-contained task prompt>" --allowedTools Bash Read Edit Write Glob Grep
```

- **This is the default invocation.** The flag list scopes which tools the subagent may use without a prompt, so it can finish a menial job unattended. Without it the subagent stalls waiting for approval on the first edit or command.
- The alias bakes in `--allowedTools '*'`, which Claude Code **silently ignores** with a warning (`Wildcard tool name "*" is not supported`). That warning is expected and harmless — the `--allowedTools` you append is what takes effect.
- For edit-only, lower-risk tasks you may instead use `--permission-mode acceptEdits` (auto-accepts file edits, but Bash still prompts — don't use it for verification/build/test runs).

## Writing the task prompt (most important step)

The qwen subagent has **zero** context from this conversation. A vague prompt is the #1 failure mode. Every prompt must be standalone:

- **Absolute paths** for every input and output file (`/Users/tpatinya/proj/src/foo.ts`, not `foo.ts`).
- **Explicit inputs, outputs, and acceptance criteria** — what to change, what "done" looks like.
- **No references** to "the file we discussed", "above", or prior turns.
- Treat qwen as a capable-but-literal junior: spell out the steps, keep scope tight.

Bad: `clean up the imports`
Good: `In /Users/tpatinya/proj/src/api.ts, remove unused imports and sort the remaining import statements alphabetically. Do not change any other code. Confirm the file still parses.`

## Mind the context window (128k)

Qwen runs with a **128k-token context window** — much smaller than Claude's. The whole job (your prompt + every file it reads + its own reasoning and edits) has to fit inside it. Size each delegated task to the model, not just to "is it menial":

- **Estimate the footprint** before delegating: roughly the bytes of files it must read + open + write, ÷ 4 ≈ tokens. If a single task would pull in large files or many files at once, it won't fit.
- **Break large jobs into independent chunks** that each touch a bounded slice — e.g. one file (or a few small ones) per run, one directory per run, one log segment per run. Run the chunks as separate `claude-9arm` invocations (foreground, or background-parallel per the Return contract section).
- **Don't make it read what it doesn't need.** Point it at the exact files/paths required; never tell it to "scan the repo" or read a whole large tree.
- **Watch for context-exhaustion symptoms** when verifying: truncated edits, ignored later instructions, or a summary that omits files it was told to touch usually mean the task overflowed — split it smaller and retry.

When a job is inherently too big to slice cleanly (it needs whole-codebase context to do correctly), that's a sign it isn't a qwen task — keep it yourself.

## Working directory

The Bash tool's `cd` resets between calls and `cd &&` can trip permission prompts. Don't rely on cwd:

- Put **absolute paths in the prompt**, or
- Pass `--add-dir /abs/path` to grant the subagent access to a directory.

## Return contract

- **Default (text):** qwen's final message prints to stdout — read it directly.
- **Need to parse the result:** add `--output-format json` and extract the `result` field.
- **Background / parallel (run several at once):** redirect to a log and run with the Bash tool's `run_in_background: true`, then read the log when it finishes:

  ```bash
  claude-9arm -p "<task>" --allowedTools Bash Read Edit Write Glob Grep > /tmp/qwen-<label>.log 2>&1
  ```

  Launch independent tasks as separate background runs; collect each log on completion. Use this when delegating 2+ unrelated menial jobs.

## Workflow checklist

1. Confirm the task is menial and low-risk (see description). If it needs design judgment or this chat's context, **do it yourself** — don't delegate.
2. Check it fits qwen's **128k context window** — estimate the file footprint and split large jobs into bounded per-file/per-dir chunks (see "Mind the context window").
3. Write a fully self-contained prompt with absolute paths and acceptance criteria.
4. Run `claude-9arm -p "..." --allowedTools Bash Read Edit Write Glob Grep` (foreground), or background-redirect for parallel jobs.
5. **Verify the output yourself** — qwen is cheaper and less reliable. Check the file/result actually meets the acceptance criteria before reporting success.

## One-time setup (optional, removes repeated prompts)

To stop per-call permission prompts on delegated runs, add a Bash allow rule for the command (via the `update-config` skill, or by editing settings):

```json
{ "permissions": { "allow": ["Bash(claude-9arm:*)"] } }
```

## When NOT to delegate

Architecture/design, debugging that needs reasoning, security-sensitive changes, anything requiring this conversation's context, or tasks where a wrong cheap-model edit is costly to catch. When in doubt, keep it.
