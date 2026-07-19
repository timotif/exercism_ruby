#!/usr/bin/env bash
# Usage: open_exercise.sh <exercise-slug>
# Opens a new cmux workspace for an Exercism Ruby exercise.
#
# Layout (mirrors the current 4-pane structure):
#   LEFT column:
#     pane A top:    nvim <exercise>.rb
#     pane A bottom: test runner terminal (cd into exercise dir)
#   RIGHT column:
#     pane B top:    glow docs (introduction.md + instructions.md as 2 tabs)
#     pane B bottom: browser (file:// exercise_progression.html) + nvim as 2nd tab
set -euo pipefail

EXERCISE="${1:-}"
if [[ -z "$EXERCISE" ]]; then
  echo "Usage: $0 <exercise-slug>" >&2
  exit 1
fi

REPO_DIR="/Users/tim/VSProjects/exercism_ruby"
CONCEPT_DIR="$REPO_DIR/exercises/concept"
PRACTICE_DIR="$REPO_DIR/exercises/practice"
HTML="$REPO_DIR/exercise_progression.html"

# Locate exercise directory
if [[ -d "$CONCEPT_DIR/$EXERCISE" ]]; then
  EX_DIR="$CONCEPT_DIR/$EXERCISE"
  EX_PARENT="$CONCEPT_DIR"
elif [[ -d "$PRACTICE_DIR/$EXERCISE" ]]; then
  EX_DIR="$PRACTICE_DIR/$EXERCISE"
  EX_PARENT="$PRACTICE_DIR"
else
  echo "Exercise '$EXERCISE' not found in concept or practice directories." >&2
  exit 1
fi

RB_FILE="${EXERCISE//-/_}.rb"
if [[ ! -f "$EX_DIR/$RB_FILE" ]]; then
  echo "Ruby file not found: $EX_DIR/$RB_FILE" >&2
  exit 1
fi

INTRO="$EX_DIR/.docs/introduction.md"
INSTRUCTIONS="$EX_DIR/.docs/instructions.md"

# ---------------------------------------------------------------------------
# Update exercise_progression.html
# ---------------------------------------------------------------------------
python3 - "$HTML" "$EXERCISE" <<'PYEOF'
import sys, re

html_path = sys.argv[1]
new_slug = sys.argv[2]

with open(html_path) as f:
    content = f.read()

# Mark previous "started" as "completed"
updated = re.sub(
    r'(\{\s*slug:\s*"[^"]+",\s*status:\s*)"started"',
    r'\1"completed"',
    content
)

# Mark the new exercise as "started" (only if currently "available")
final = re.sub(
    r'(\{\s*slug:\s*"' + re.escape(new_slug) + r'",\s*status:\s*)"available"',
    r'\1"started"',
    updated
)

if final == updated:
    m = re.search(r'slug:\s*"' + re.escape(new_slug) + r'",\s*status:\s*"(\w+)"', content)
    status = m.group(1) if m else "not found"
    if status in ("started", "completed"):
        print(f"Note: '{new_slug}' is already '{status}' — no change made.")
    else:
        print(f"Warning: '{new_slug}' not found in HTML — add it manually.")
else:
    with open(html_path, "w") as f:
        f.write(final)
    print(f"Updated: '{new_slug}' → started")
PYEOF

# ---------------------------------------------------------------------------
# Build the cmux workspace using --layout JSON
# ---------------------------------------------------------------------------
# Determine glow commands (fall back gracefully if docs missing)
if [[ -f "$INTRO" ]]; then
  CMD_INTRO="glow \"$INTRO\""
else
  CMD_INTRO="echo 'No introduction.md'"
fi
if [[ -f "$INSTRUCTIONS" ]]; then
  CMD_INSTR="glow \"$INSTRUCTIONS\""
else
  CMD_INSTR="echo 'No instructions.md'"
fi

# Layout: horizontal split (left|right), each side split vertically (top|bottom)
LAYOUT=$(python3 -c "
import json, sys

exercise  = sys.argv[1]
ex_dir    = sys.argv[2]
ex_parent = sys.argv[3]
rb_file   = sys.argv[4]
cmd_intro = sys.argv[5]
cmd_instr = sys.argv[6]
html      = sys.argv[7]

layout = {
  'direction': 'horizontal',
  'split': 0.45,
  'children': [
    {
      'direction': 'vertical',
      'split': 0.6,
      'children': [
        {
          'pane': {
            'surfaces': [
              {'type': 'terminal', 'command': f'cd \"{ex_parent}\" && nvim \"{exercise}/{rb_file}\"'}
            ]
          }
        },
        {
          'pane': {
            'surfaces': [
              {'type': 'terminal', 'command': f'cd \"{ex_dir}\"'}
            ]
          }
        }
      ]
    },
    {
      'direction': 'vertical',
      'split': 0.6,
      'children': [
        {
          'pane': {
            'surfaces': [
              {'type': 'terminal', 'command': cmd_intro},
              {'type': 'terminal', 'command': cmd_instr}
            ]
          }
        },
        {
          'pane': {
            'surfaces': [
              {'type': 'terminal', 'command': f'nvim \"{html}\"'}
            ]
          }
        }
      ]
    }
  ]
}
print(json.dumps(layout))
" "$EXERCISE" "$EX_DIR" "$EX_PARENT" "$RB_FILE" "$CMD_INTRO" "$CMD_INSTR" "$HTML")

WS_REF=$(CMUX_QUIET=1 cmux new-workspace \
  --name "$EXERCISE" \
  --layout "$LAYOUT" \
  --focus false 2>/dev/null | awk '{print $2}')

# Find the bottom-right pane (last pane in the workspace) and open a browser
# surface there, then reorder it before the nvim terminal tab.
PANES_JSON=$(CMUX_QUIET=1 cmux list-panes --workspace "$WS_REF" --json 2>/dev/null)
PANE_HTML=$(echo "$PANES_JSON" | python3 -c "import sys,json; panes=json.load(sys.stdin)['panes']; print(panes[-1]['ref'])")
PANE_DOCS=$(echo "$PANES_JSON" | python3 -c "import sys,json; panes=json.load(sys.stdin)['panes']; print(panes[-2]['ref'])")

SURF_NVIM=$(CMUX_QUIET=1 cmux list-pane-surfaces --pane "$PANE_HTML" --workspace "$WS_REF" --json 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['surfaces'][0]['ref'])")

BROWSER_JSON=$(CMUX_QUIET=1 cmux new-surface --type browser --url "file://$HTML" --pane "$PANE_HTML" --workspace "$WS_REF" --focus false --json 2>/dev/null)
SURF_BROWSER=$(echo "$BROWSER_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['surface_ref'])")

# Put browser tab first, nvim tab second
CMUX_QUIET=1 cmux reorder-surface --surface "$SURF_BROWSER" --before "$SURF_NVIM" --workspace "$WS_REF" 2>&1 | grep -v '^OK' || true

# Land on introduction.md (first tab of the docs pane)
SURF_INTRO=$(CMUX_QUIET=1 cmux list-pane-surfaces --pane "$PANE_DOCS" --workspace "$WS_REF" --json 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['surfaces'][0]['ref'])")
CMUX_QUIET=1 cmux move-surface --surface "$SURF_INTRO" --pane "$PANE_DOCS" --workspace "$WS_REF" --focus true 2>&1 | grep -v '^OK' || true
CMUX_QUIET=1 cmux workspace select "$WS_REF" 2>&1 | grep -v '^OK' || true

echo "Workspace '$EXERCISE' ready: $WS_REF"
