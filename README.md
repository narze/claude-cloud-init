# claude-cloud-init

Seeds a Claude Cloud container's `~/.claude` with a shared `CLAUDE.md` and a set
of skills, so every new cloud session starts from the same agent setup.

## Quick start

In the Claude Cloud environment editor, paste this into **Setup script**:

```bash
curl -fsSL https://raw.githubusercontent.com/narze/claude-cloud-init/main/install.sh | bash
```

The setup script runs on each new session, before Claude Code launches.

## What it installs

`install.sh` copies these paths from this repo into `~/.claude`:

| Source | Lands at | What it is |
| --- | --- | --- |
| `CLAUDE.template.md` | `~/.claude/CLAUDE.md` | Global agent instructions, applied to every project |
| `.agents/skills/*` | `~/.claude/skills/*` | 29 skills (see [`skills-lock.json`](skills-lock.json) in this repo for upstream sources) |

`~/.claude/skills` is merged, not replaced, so skills already provided by the
harness (`docx`, `pptx`, `pdf`, `xlsx`, ...) survive alongside these.

`~/.claude/CLAUDE.md` **is** overwritten on every run. If you edit it in a live
session, copy the change back into `CLAUDE.template.md` in this repo or the
next session will revert it.

## Configuration

All optional. Positional arguments take precedence over environment variables.

| Variable | Default | Purpose |
| --- | --- | --- |
| `TEMPLATE_REPO` | `narze/claude-cloud-init` | Template to install from. Accepts `owner/repo` or any git URL |
| `TEMPLATE_REF` | default branch | Branch or tag to install |
| `DEST` | `$HOME/.claude` | Where to install |
| `ALLOW_ANY_ENV` | unset | Set to `1` to skip the Claude Cloud check |

```bash
# Use your own fork
curl -fsSL .../install.sh | TEMPLATE_REPO=you/your-template bash

# Same, as a positional argument
curl -fsSL .../install.sh | bash -s -- you/your-template

# A non-GitHub host, installed somewhere else
curl -fsSL .../install.sh | bash -s -- https://gitlab.com/you/tpl.git ~/.claude

# Pin to a tag
curl -fsSL .../install.sh | TEMPLATE_REF=v1.2.0 bash
```

## Using your own template

Any repo works as a template, as long as it has skills under `.agents/skills/`
and, optionally, a `CLAUDE.template.md` at the root. Fork this one or start
from scratch, then point `TEMPLATE_REPO` at it.

## Running outside Claude Cloud

The installer refuses to run on a normal machine, because it would overwrite
your personal `~/.claude/CLAUDE.md`:

```
error: this script only runs inside a Claude Cloud environment.

  CLAUDE_CODE_REMOTE is not set, so this looks like a local machine.
```

The check is on `CLAUDE_CODE_REMOTE`, which Claude Cloud sets from container
bootstrap onward, so it is already present while a setup script runs. (`CLAUDECODE`
looks like the right variable but is not usable: the `claude` process sets it on
itself, so it is absent at setup time and would block every legitimate run.)

To install anyway, on your own machine or into a throwaway directory:

```bash
curl -fsSL .../install.sh | ALLOW_ANY_ENV=1 DEST=/tmp/claude-test bash
```

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Installed |
| `1` | `git` not found |
| `2` | `TEMPLATE_REPO` is not `owner/repo` or a git URL |
| `3` | Not a Claude Cloud environment (see above) |

## Notes

Requires `git`. The installer clones rather than downloading a tarball, because
sandboxed agent proxies commonly permit git traffic while rejecting
`codeload.github.com` with a 403.

`install.sh` copies `CLAUDE.template.md` (as `CLAUDE.md`) and `.agents/skills/*`
explicitly rather than copying the whole clone, so it doesn't depend on
`.claude/skills`, the repo's own local-dev symlinks into `.agents/skills`.

Piping a remote script to `bash` runs whatever that URL currently serves. Read
[`install.sh`](install.sh) before trusting it, and pin `TEMPLATE_REF` if you want
a fixed version.
