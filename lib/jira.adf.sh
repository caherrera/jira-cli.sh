#!/bin/bash
# ADF (Atlassian Document Format) automatic detector and converter module
# Handles transparent format detection between pre-formatted ADF JSON, Markdown, and plain-text

# shellcheck source=/dev/null
source "${LIB_DIR:-$DIR/../lib}/markdown.sh" 2>/dev/null || true
source "${LIB_DIR:-$DIR/../lib}/markdown_to_adf.sh" 2>/dev/null || true

is_adf_json() {
  local input="$1"
  [[ -z "$input" ]] && return 1
  if [[ "$input" =~ ^[[:space:]]*\{ ]] && [[ "$input" == *"doc"* ]]; then
    if printf '%s' "$input" | jq -e 'if type == "object" and .type == "doc" then true else false end' >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

jira_text_to_adf() {
  local input="$1"

  if [[ -z "$input" ]]; then
    echo '{"type": "doc", "version": 1, "content": []}'
    return 0
  fi

  # 1. If it's already a valid ADF JSON doc, return as-is
  if is_adf_json "$input"; then
    printf '%s' "$input" | jq -c .
    return 0
  fi

  # 2. Convert Markdown / Plain-text to ADF
  local adf_result
  adf_result=$(markdown_to_adf "$input" 2>/dev/null || true)

  if [[ -n "$adf_result" ]] && printf '%s' "$adf_result" | jq -e '.type == "doc"' >/dev/null 2>&1; then
    printf '%s' "$adf_result" | jq -c .
  else
    # Fallback to single paragraph text doc
    jq -n --arg text "$input" '{
      "type": "doc",
      "version": 1,
      "content": [
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": $text
            }
          ]
        }
      ]
    }'
  fi
}

jira_format_field_payload() {
  local field_name="$1"
  local raw_input="$2"

  if [[ "${JIRA_API_VERSION:-3}" == "3" ]]; then
    local adf_doc
    adf_doc=$(jira_text_to_adf "$raw_input")
    jq -n --arg name "$field_name" --argjson adf "$adf_doc" '{($name): $adf}'
  else
    local wiki_text
    wiki_text=$(markdown_to_jira "$raw_input" 2>/dev/null || printf '%s' "$raw_input")
    jq -n --arg name "$field_name" --arg val "$wiki_text" '{($name): $val}'
  fi
}
