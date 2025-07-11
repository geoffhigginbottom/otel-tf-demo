#! /bin/bash
# Version 2.0

json_file="$1"

# Just cat the file (assuming it is valid JSON in a single line)
# cat "$json_file"

if [ -f "$json_file" ]; then
  cat "$json_file"
else
  echo "{\"error\": \"File not found: $json_file\"}"
  exit 1
fi

# This script reads the HEC tokens from the JSON file created by get_hec_tokens.sh
# and outputs them in a format suitable for Terraform to consume.