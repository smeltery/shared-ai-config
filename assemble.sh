#!/usr/bin/env bash

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# assemble.sh — Compose final agent/skill files from shared
# bodies and tool-specific frontmatter.
#
# Usage:
#   ./shared/assemble.sh <tool>          # Assemble files
#   ./shared/assemble.sh <tool> --check  # Verify files are up-to-date
#
# Where <tool> is "opencode", "claude", "codex", or "pi".
# Run from the tool repo root (where shared/ is a submodule).
# ─────────────────────────────────────────────────────────────

TOOL="${1:-}"
CHECK="${2:-}"
SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "$TOOL" ]]; then
    echo "Usage: ./shared/assemble.sh <opencode|claude|codex|pi> [--check]"
    exit 1
fi

if [[ "$TOOL" != "opencode" && "$TOOL" != "claude" && "$TOOL" != "codex" && "$TOOL" != "pi" ]]; then
    echo "Error: tool must be 'opencode', 'claude', 'codex', or 'pi', got '$TOOL'"
    exit 1
fi

REPO_ROOT="$(pwd)"
FRONTMATTER_DIR="$REPO_ROOT/frontmatter"
HEADER="<!-- DO NOT EDIT — assembled from shared/ and frontmatter/ by assemble.sh -->"

errors=0

assemble_file() {
    local frontmatter="$1"
    local body="$2"
    local output="$3"

    local assembled
    assembled="---
$(cat "$frontmatter")
---
$HEADER
$(cat "$body")"

    if [[ "$CHECK" == "--check" ]]; then
        if [[ ! -f "$output" ]]; then
            echo "MISSING: $output"
            ((errors++))
            return
        fi
        if ! diff -q <(echo "$assembled") "$output" > /dev/null 2>&1; then
            echo "STALE:   $output"
            ((errors++))
        fi
    else
        mkdir -p "$(dirname "$output")"
        echo "$assembled" > "$output"
        echo "  ✅ $output"
    fi
}

assemble_codex_agent() {
    local frontmatter="$1"
    local body="$2"
    local output="$3"

    local assembled
    assembled="# DO NOT EDIT — assembled from shared/ and frontmatter/ by assemble.sh

$(cat "$frontmatter")
developer_instructions = \"\"\"
$(cat "$body")
\"\"\""

    if [[ "$CHECK" == "--check" ]]; then
        if [[ ! -f "$output" ]]; then
            echo "MISSING: $output"
            ((errors++))
            return
        fi
        if ! diff -q <(echo "$assembled") "$output" > /dev/null 2>&1; then
            echo "STALE:   $output"
            ((errors++))
        fi
    else
        mkdir -p "$(dirname "$output")"
        echo "$assembled" > "$output"
        echo "  ✅ $output"
    fi
}

# ── Agents ──────────────────────────────────────────────────
if [[ "$TOOL" != "pi" ]]; then
    if [[ "$CHECK" != "--check" ]]; then
        echo "🔧 Assembling $TOOL agents..."
    fi

    for frontmatter_file in "$FRONTMATTER_DIR"/agents/*; do
        [[ -f "$frontmatter_file" ]] || continue

        if [[ "$TOOL" == "codex" ]]; then
            name="$(basename "$frontmatter_file" .toml)"
            body_file="$SHARED_DIR/agents/$name.md"

            if [[ ! -f "$body_file" ]]; then
                echo "Warning: No shared body for $name, skipping"
                continue
            fi

            output="$REPO_ROOT/agents/$name.toml"
            assemble_codex_agent "$frontmatter_file" "$body_file" "$output"
        else
            name="$(basename "$frontmatter_file" .yml)"
            body_file="$SHARED_DIR/agents/$name.md"

            if [[ ! -f "$body_file" ]]; then
                echo "Warning: No shared body for $name, skipping"
                continue
            fi

            if [[ "$TOOL" == "opencode" ]]; then
                output="$REPO_ROOT/agent/$name.md"
            else
                output="$REPO_ROOT/agents/$name.md"
            fi

            assemble_file "$frontmatter_file" "$body_file" "$output"
        fi
    done
fi

# ── Ship skill ──────────────────────────────────────────────
if [[ "$CHECK" != "--check" ]]; then
    echo ""
    echo "🔧 Assembling $TOOL ship skill..."
fi

ship_body="$SHARED_DIR/skills/ship.md"
ship_epilogue="$SHARED_DIR/skills/ship-opencode-epilogue.md"

if [[ "$TOOL" == "pi" ]]; then
    # Pi uses plain SKILL.md without YAML frontmatter
    if [[ -f "$ship_body" ]]; then
        ship_output="$REPO_ROOT/agent/skills/ship/SKILL.md"
        assembled="$HEADER
$(cat "$ship_body")"

        if [[ "$CHECK" == "--check" ]]; then
            if [[ ! -f "$ship_output" ]]; then
                echo "MISSING: $ship_output"
                ((errors++))
            elif ! diff -q <(echo "$assembled") "$ship_output" > /dev/null 2>&1; then
                echo "STALE:   $ship_output"
                ((errors++))
            fi
        else
            mkdir -p "$(dirname "$ship_output")"
            echo "$assembled" > "$ship_output"
            echo "  ✅ $ship_output"
        fi
    fi
else
    ship_frontmatter="$FRONTMATTER_DIR/skills/ship.yml"

    if [[ -f "$ship_frontmatter" && -f "$ship_body" ]]; then
        # Build the full body
        if [[ "$TOOL" == "opencode" && -f "$ship_epilogue" ]]; then
            combined_body="$(cat "$ship_body")
$(cat "$ship_epilogue")"
        else
            combined_body="$(cat "$ship_body")"
        fi

        ship_output="$REPO_ROOT/skills/ship/SKILL.md"

        assembled="---
$(cat "$ship_frontmatter")
---
$HEADER
$combined_body"

        if [[ "$CHECK" == "--check" ]]; then
            if [[ ! -f "$ship_output" ]]; then
                echo "MISSING: $ship_output"
                ((errors++))
            elif ! diff -q <(echo "$assembled") "$ship_output" > /dev/null 2>&1; then
                echo "STALE:   $ship_output"
                ((errors++))
            fi
        else
            mkdir -p "$(dirname "$ship_output")"
            echo "$assembled" > "$ship_output"
            echo "  ✅ $ship_output"
        fi
    fi
fi

# ── Third-party skills ──────────────────────────────────────
# Symlinks every SKILL.md found under third-party/ submodules into
# skills/. On a name collision, the submodule listed here wins and
# the others are skipped for that name (e.g. third-party/caveman's
# own "caveman" skill takes precedence over third-party/skills').
if [[ "$TOOL" != "pi" ]]; then
    if [[ "$CHECK" != "--check" ]]; then
        echo ""
        echo "🔧 Linking $TOOL third-party skills..."
    fi

    declare -A SKIP_LINK=( [caveman]="third-party/caveman" )
    skills_dir="$REPO_ROOT/skills"

    while IFS= read -r -d '' skill_md; do
        skill_dir="$(dirname "$skill_md")"
        name="$(basename "$skill_dir")"
        rel="${skill_dir#"$SHARED_DIR"/}"
        winner="${SKIP_LINK[$name]:-}"
        if [[ -n "$winner" && "$rel" != "$winner"/* ]]; then
            continue
        fi

        link="$skills_dir/$name"
        target="../shared/$rel"

        if [[ "$CHECK" == "--check" ]]; then
            if [[ "$(readlink "$link" 2>/dev/null)" != "$target" ]]; then
                echo "STALE:   $link"
                ((errors++))
            fi
        else
            mkdir -p "$skills_dir"
            ln -sfn "$target" "$link"
            echo "  ✅ $link -> $target"
        fi
    done < <(find "$SHARED_DIR"/third-party/*/skills -mindepth 1 -name SKILL.md -print0 2>/dev/null)
fi

# ── Summary ─────────────────────────────────────────────────
echo ""
if [[ "$CHECK" == "--check" ]]; then
    if [[ $errors -gt 0 ]]; then
        echo "❌ $errors file(s) are out of date. Run: ./shared/assemble.sh $TOOL"
        exit 1
    else
        echo "✅ All assembled files are up to date."
    fi
else
    echo "✅ Assembly complete for $TOOL."
fi
