#!/usr/bin/env bash
# The ship check. It runs once, as this milestone's check, before the build
# scaffolding leaves the repository, and it goes green only when the repository
# is the one a stranger should find.
#
#   bash .github/scripts/ship-check.sh          the repository this file is in
#   bash .github/scripts/ship-check.sh <dir>    another tree, which is how the
#                                               tests run it on a fixture
#
# Five groups, and every finding names the file, never the line: a check that
# prints the line it caught is a check that copies a key into a log.
#
#   1. the scaffolding paths, by name
#   2. learner-facing words: Checkpoint, Done when, you will
#   3. local paths and private names: /home/, ~/Projects, the host name, GUIDE_DIR, <date>
#   4. secret-shaped strings: access key ids, private key headers, tokens
#   5. TODOs, and a workflow that still calls the milestone runner
#
# It reads every file in the tree and skips what .gitignore keeps out of it. It
# also skips .github/scripts/ and tests/ship-*, because this check's own source
# names every word it refuses, and a check cannot report its own absence: the
# last commit of this milestone removes both.
set -uo pipefail

here=$(cd "$(dirname "$0")/../.." && pwd)
root=${1:-$here}
cd "$root" || { echo "❌ ship-check.sh: $root is not a directory."; exit 2; }

findings=0
finding() { printf '  ❌ %s\n' "$1"; findings=$((findings + 1)); }

# The folders that are not the repository: what the ignore file keeps out, and
# the two the answer key carries beside the repository (the guide folder and the
# build notes), which a clone never has.
SKIP=".git .terraform node_modules dist build scratch secrets"
EXTRA="guide guide-notes"

prune="-path ./.git -prune -o -path ./.terraform -prune -o -path ./node_modules -prune -o -path ./dist -prune -o -path ./build -prune -o -path ./scratch -prune -o -path ./secrets -prune -o -path ./guide -prune -o -path ./guide-notes -prune"
all_files=$(find . $prune -o -type f -print 2>/dev/null | sed 's|^\./||' | sort)

# A path in group 1 is either a file or a folder, and a folder is gone when it
# holds nothing.
gone() {
  [ -e "$1" ] || return 0
  [ -d "$1" ] && [ -z "$(find "$1" -type f -print 2>/dev/null | head -1)" ] && return 0
  return 1
}

scan() { # $1 = extended regex, $2 = what it is, $3 = 1 to read the file list, 0 to skip it
  local pat="$1" label="$2" files="$3" f hits
  [ "$files" = "1" ] || return 0
  for f in $all_files; do
    case "$f" in
      .github/scripts/*|tests/ship-*) continue ;;
    esac
    hits=$(grep -c -I -E -e "$pat" "$f" 2>/dev/null)
    case "${hits:-0}" in
      0|"") ;;
      *) finding "$f: $label" ;;
    esac
  done
}

echo "Ship check: $root"
echo "Skipped, because they are not the repository: $SKIP (ignored), $EXTRA (the guide and its build notes)."
echo

# ---------------------------------------------------------------- group 1 ---
# One path or glob per line. The step files are `tests/sp*`, which leaves this
# milestone's own `tests/ship-*` alone: they are the check that runs this scan,
# and the last commit removes them.
MUST_GO='
docs
milestones.txt
tests/sp*.check
tests/sp*.absent
tests/tooling-briefs.test.ts
tests/tooling-local-check.test.ts
tests/tooling-remote.test.ts
tests/tooling-why.test.ts
tests/tooling-fixtures.ts
.github/workflows/milestone-check.yml
'
echo "1. The build scaffolding"
while IFS= read -r path; do
  case "$path" in "" ) continue ;; esac
  matched=0
  for one in $path; do
    matched=1
    gone "$one" || finding "$one: still here, and it is scaffolding"
  done
  [ "$matched" -eq 0 ] && finding "$path: still here, and it is scaffolding"
done <<EOF
$MUST_GO
EOF

# ---------------------------------------------------------------- group 2 ---
echo
echo "2. Learner-facing words"
scan 'Checkpoint' "the word Checkpoint is written for a learner" 1
scan 'Done when' "the words Done when are written for a learner" 1
scan 'you will' "the words you will address a learner" 1

# ---------------------------------------------------------------- group 3 ---
echo
echo "3. Local paths and private names"
scan '/home/' "an absolute home path" 1
scan '~/Projects' "a path on the machine that built this" 1
scan 'C:\\\\Users' "an absolute home path on Windows" 1
scan 'Kamrui|kamrui' "the name of the machine that built this" 1
scan 'GUIDE_DIR' "a variable that only exists while the guide is being built" 1
scan '<date>' "a decision line without its date" 1
scan 'github\.com/OWNER/|actions/runs/000000000|status\.YOUR-DOMAIN|YOUR-DOMAIN|YOUR_GITHUB_OWNER|REPLACE_WITH_RUN_ID' "a placeholder where a real link belongs" 1

# ---------------------------------------------------------------- group 4 ---
echo
echo "4. Secret-shaped strings"
scan 'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}' "an access key id" 1
scan '-----BEGIN [A-Z ]*PRIVATE KEY' "a private key" 1
scan 'ghp_[A-Za-z0-9]{30,}|xox[baprs]-[A-Za-z0-9-]{10,}' "a token" 1
scan 'aws_secret_access_key' "a secret access key" 1

# ---------------------------------------------------------------- group 5 ---
echo
echo "5. TODOs, and the CI that maps a branch to a milestone"
scan 'TODO|FIXME' "a TODO left in the tree" 1

if [ -f .github/workflows/ci.yml ]; then
  for want in '^on:' 'pull_request' 'tofu fmt -check' 'tofu -chdir=terraform validate' 'tflint --recursive' 'checkov' 'tofu -chdir=terraform test' 'bun test'; do
    grep -q -E -e "$want" .github/workflows/ci.yml 2>/dev/null || finding ".github/workflows/ci.yml: the normal workflow is missing $want"
  done
else
  finding ".github/workflows/ci.yml: the normal workflow is gone, so nothing checks the repository"
fi
for f in $all_files; do
  case "$f" in
    .github/scripts/*|tests/ship-*) continue ;;
  esac
  hits=$(grep -c -I -E -e 'scripts/check\.sh|check-local\.sh|remote-check\.sh|lint-briefs\.sh|milestone-check' "$f" 2>/dev/null)
  case "${hits:-0}" in
    0|"") ;;
    *) finding "$f: still calls the milestone runner" ;;
  esac
done

# ------------------------------------------------------------------ ending ---
echo
if [ "$findings" -eq 0 ]; then
  echo "👍 Ship check passed. Nothing on the list is still in this repository."
  exit 0
fi
echo "👎 Ship check failed: $findings finding(s)."
echo "   Remove what the lines above name, then run this same command again."
exit 1
