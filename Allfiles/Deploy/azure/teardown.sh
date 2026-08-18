#!/usr/bin/env bash
# Tear down the Oracle -> PostgreSQL schema-conversion lab.
#
# Deletes the resource group and purges any soft-deleted Azure OpenAI
# (Cognitive Services) accounts that lived in it, so their names are freed.
#
# Usage:
#   ./teardown.sh                       # deletes 'oracle-bridge-rg' (asks to confirm)
#   ./teardown.sh my-rg                 # deletes a named resource group
#   ./teardown.sh my-rg --yes           # no confirmation prompt
set -euo pipefail

RG=""
ASSUME_YES="no"
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES="yes" ;;
    -*)       echo "Unknown option: $arg" >&2; exit 2 ;;
    *)        [ -z "$RG" ] && RG="$arg" ;;
  esac
done
RG="${RG:-oracle-bridge-rg}"

if ! az group show -n "$RG" >/dev/null 2>&1; then
  echo "Resource group '$RG' does not exist. Nothing to do."
  exit 0
fi

echo "The following resources in '$RG' will be permanently deleted:"
az resource list -g "$RG" --query "[].{name:name, type:type}" -o table || true
echo

if [ "$ASSUME_YES" != "yes" ]; then
  read -r -p "Delete resource group '$RG' and everything in it? Type 'yes' to continue: " reply
  if [ "$reply" != "yes" ]; then
    echo "Aborted."
    exit 1
  fi
fi

# Capture Azure OpenAI accounts (name + location) before deleting the group,
# so we can purge them from the soft-delete state afterwards. Uses a while-read
# loop instead of 'mapfile' so it also works on the older bash on macOS.
OPENAI=()
while IFS= read -r line; do
  [ -n "$line" ] && OPENAI+=("$line")
done < <(az cognitiveservices account list -g "$RG" \
  --query "[].{n:name,l:location}" -o tsv 2>/dev/null || true)

echo "Deleting resource group '$RG'..."
az group delete -n "$RG" --yes

for row in "${OPENAI[@]:-}"; do
  [ -z "$row" ] && continue
  name="$(echo "$row" | cut -f1)"
  loc="$(echo "$row" | cut -f2)"
  echo "Purging soft-deleted Azure OpenAI account '$name' in '$loc'..."
  # The account may take a moment to reach a terminal state after group deletion.
  for _ in 1 2 3 4 5 6; do
    if az cognitiveservices account purge -n "$name" -g "$RG" -l "$loc" >/dev/null 2>&1; then
      break
    fi
    sleep 10
  done
done

echo "Teardown complete."
