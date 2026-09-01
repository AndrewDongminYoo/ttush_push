#!/usr/bin/env bash

# Fails when a staged Dart file's staged content is unformatted.
#
# `merry run format check` reads the working tree, which is not what a commit
# contains. A partially staged file, or one formatted after it was staged and
# not re-added, makes the tree's verdict describe something other than the
# commit candidate: the hook passes and CI rejects the snapshot, or unrelated
# unstaged drift blocks a commit that is fine. Read each blob out of the index
# instead, which is exactly what the commit will carry.

set -euo pipefail

# R is in the filter because git classifies a staged rename as R, not M, and a
# rename that also carries an edit would otherwise list nothing at all.
#
# The paths arrive NUL-delimited through a file, because both simpler shapes
# lose them. Under git's default core.quotePath a non-ASCII path comes back
# C-quoted, that spelling makes git show fail, and pipefail then reports the
# file as unformatted and blocks the commit for good. Command substitution
# cannot carry the NUL delimiters that avoid it, since it strips NUL bytes.
# Writing to a file also keeps a failing git diff an error rather than an empty
# list that would read as "nothing staged".
staged_list="$(mktemp)"
readonly staged_list
trap 'rm -f "${staged_list}"' EXIT

git diff --cached --name-only -z --diff-filter=ACMR -- '*.dart' >"${staged_list}"

unformatted=''

while IFS= read -r -d '' file; do
	if ! git show ":${file}" |
		dart format --output=none --set-exit-if-changed --stdin-name "${file}" \
			>/dev/null 2>&1; then
		unformatted="${unformatted}  ${file}"$'\n'
	fi
done <"${staged_list}"

if [[ -z ${unformatted} ]]; then
	exit 0
fi

printf 'Staged Dart is not formatted:\n%s' "${unformatted}" >&2
printf 'Run "merry run format", stage the result, then commit again.\n' >&2
exit 1
