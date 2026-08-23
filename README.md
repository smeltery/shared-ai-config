# shared-ai-config

[![License: PolyForm Shield 1.0.0](https://img.shields.io/badge/License-PolyForm%20Shield%201.0.0-blue.svg)](https://polyformproject.org/licenses/shield/1.0.0/)

Shared agent and skill definitions used by both [OpenCode](https://github.com/smeltery/opencode) and [Claude Code](https://github.com/smeltery/claude) configurations.

## Contents

- `agents/` — Canonical agent body content (no frontmatter)
- `skills/` — Canonical skill body content (no frontmatter)
- `assemble.sh` — Composes final files from shared bodies + tool-specific frontmatter
- `LICENSE` — PolyForm Shield 1.0.0

## How It Works

Each AI tool has its own config repo with tool-specific frontmatter. This repo provides the shared markdown body content. A simple shell script concatenates frontmatter + body into the final files that each tool reads.

```
frontmatter/agents/architect-designer.yml   (tool-specific YAML)
+
shared/agents/architect-designer.md         (shared body content)
=
agents/architect-designer.md                (assembled, committed)
```

## Usage

This repo is consumed as a git submodule in each tool config repo:

```bash
# From the tool repo root:
./shared/assemble.sh opencode    # or: ./shared/assemble.sh claude
./shared/assemble.sh claude --check  # verify files are up-to-date
```

## Updating Shared Content

1. Edit the body file in this repo
2. Commit and push
3. In each tool repo: `git submodule update --remote shared`
4. Run `./shared/assemble.sh <tool>`
5. Commit the updated assembled files

## License

Licensed under [PolyForm Shield 1.0.0](https://polyformproject.org/licenses/shield/1.0.0/) — see [LICENSE](LICENSE) for details.
