#!/usr/bin/env bash
# Creates the test fixtures that cannot be committed: an over-size file, an
# unreadable file, and a file whose name starts with "-". Run from the repository root.

set -euo pipefail

mkdir -p test-data/generated

# One byte over the 1 MiB step output limit: a JSON string of 1048576 characters.
{
	printf '"'
	head -c 1048576 /dev/zero | tr '\0' a
	printf '"\n'
} >test-data/generated/over-1mib.json

# Valid JSON that its owner cannot read.
cp test-data/single-line.json test-data/generated/unreadable.json
chmod 000 test-data/generated/unreadable.json

# A path starting with "-" must not be taken for an option.
cp test-data/single-line.json ./-n
