#!/usr/bin/env bash
# Run a dbt v2 command against Snowflake.
# The script reads the Snowflake credentials from 1Password and never prints them.
#
# Before the first run, copy op_refs.example to op_refs and enter your 1Password references.
# Usage, from the integration_tests folder:
#   ./ci/snowflake/run.sh debug
#   ./ci/snowflake/run.sh build
set -euo pipefail

cd "$(dirname "$0")/../.."
refs_file="ci/snowflake/op_refs"

if [ ! -f "$refs_file" ]; then
  echo "Missing $refs_file. Copy ci/snowflake/op_refs.example to $refs_file and enter your 1Password references." >&2
  exit 1
fi

while IFS="=" read -r -u 3 name ref; do
  # Skip empty lines and comments.
  [[ -z "$name" || "$name" == \#* ]] && continue
  if ! value="$(op read "$ref")"; then
    echo "Could not read $name from 1Password." >&2
    exit 1
  fi
  if [ -z "$value" ]; then
    echo "$name is empty in 1Password." >&2
    exit 1
  fi
  export "$name=$value"
done 3< "$refs_file"

# The dbt v2 installer puts the binary at ~/.local/bin/dbt. The dbtf alias does not work in scripts.
exec "${DBT_BIN:-$HOME/.local/bin/dbt}" "$@" --profiles-dir ci/snowflake
