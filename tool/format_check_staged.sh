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

# Assigned first rather than piped into the loop, so a failing git diff is an
# error instead of an empty list that would read as "nothing staged".
staged="$(git diff --cached --name-only --diff-filter=ACM -- '*.dart')"
readonly staged

if [[ -z ${staged} ]]; then
	exit 0
fi

unformatted=''

while IFS= read -r file; do
	if ! git show ":${file}" |
		dart format --output=none --set-exit-if-changed --stdin-name "${file}" \
			>/dev/null 2>&1; then
		unformatted="${unformatted}  ${file}"$'\n'
	fi
done <<<"${staged}"

if [[ -z ${unformatted} ]]; then
	exit 0
fi

printf 'Staged Dart is not formatted:\n%s' "${unformatted}" >&2
printf 'Run "merry run format", stage the result, then commit again.\n' >&2
exit 1
