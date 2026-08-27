#!/usr/bin/env bash
# Unit tests for Jira ADF automatic detector and converter

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIRA_BIN="${SCRIPT_DIR}/../bin/jira"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Load ADF module
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/markdown.sh"
source "${LIB_DIR}/markdown_to_adf.sh"
source "${LIB_DIR}/jira.adf.sh"

failed=0
total=0

assert_eq() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  total=$((total + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✓ $desc: PASS"
  else
    echo "  ✗ $desc: FAIL (expected '$expected', got '$actual')"
    failed=$((failed + 1))
  fi
}

assert_json_eq() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  total=$((total + 1))
  local norm_expected norm_actual
  norm_expected=$(echo "$expected" | jq -S . 2>/dev/null || echo "$expected")
  norm_actual=$(echo "$actual" | jq -S . 2>/dev/null || echo "$actual")
  if [[ "$norm_expected" == "$norm_actual" ]]; then
    echo "  ✓ $desc: PASS"
  else
    echo "  ✗ $desc: FAIL"
    echo "    Expected: $norm_expected"
    echo "    Actual:   $norm_actual"
    failed=$((failed + 1))
  fi
}

echo "═══════════════════════════════════════════════════"
echo "  Testing ADF Automatic Detection & Conversion"
echo "═══════════════════════════════════════════════════"

# Test 1: is_adf_json detection
pre_adf='{"type": "doc", "version": 1, "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Hello"}]}]}'
assert_eq "Detect valid ADF JSON" "true" "$(is_adf_json "$pre_adf" && echo "true" || echo "false")"
assert_eq "Detect plain text is not ADF" "false" "$(is_adf_json "Just a normal string" && echo "true" || echo "false")"
assert_eq "Detect markdown is not ADF" "false" "$(is_adf_json "# Title" && echo "true" || echo "false")"

# Test 2: Pass-through for pre-formatted ADF
converted_pre=$(jira_text_to_adf "$pre_adf")
assert_json_eq "Pass-through preserves pre-formatted ADF" "$pre_adf" "$converted_pre"

# Test 3: Plain text conversion
plain_text="This is a simple plain text description."
adf_plain=$(jira_text_to_adf "$plain_text")
assert_eq "Plain text converted to doc" "doc" "$(echo "$adf_plain" | jq -r '.type // empty')"
assert_eq "Plain text content extracted" "$plain_text" "$(echo "$adf_plain" | jq -r '.content[0].content[0].text // empty')"

# Test 4: Markdown Headings
md_heading=$'# Main Heading\n## Subheading'
adf_heading=$(jira_text_to_adf "$md_heading")
assert_eq "Heading 1 level" "1" "$(echo "$adf_heading" | jq -r '.content[0].attrs.level // empty')"
assert_eq "Heading 1 text" "Main Heading" "$(echo "$adf_heading" | jq -r '.content[0].content[0].text // empty')"
assert_eq "Heading 2 level" "2" "$(echo "$adf_heading" | jq -r '.content[1].attrs.level // empty')"
assert_eq "Heading 2 text" "Subheading" "$(echo "$adf_heading" | jq -r '.content[1].content[0].text // empty')"

# Test 5: Fenced Code Block with Language
md_code=$'```python\ndef hello():\n    return "world"\n```'
adf_code=$(jira_text_to_adf "$md_code")
assert_eq "Code block type" "codeBlock" "$(echo "$adf_code" | jq -r '.content[0].type // empty')"
assert_eq "Code block language" "python" "$(echo "$adf_code" | jq -r '.content[0].attrs.language // empty')"
assert_eq "Code block text" $'def hello():\n    return "world"' "$(echo "$adf_code" | jq -r '.content[0].content[0].text // empty')"

# Test 6: Blockquote
md_quote=$'> This is a critical quote.'
adf_quote=$(jira_text_to_adf "$md_quote")
assert_eq "Blockquote type" "blockquote" "$(echo "$adf_quote" | jq -r '.content[0].type // empty')"

# Test 7: Inline text marks (Bold, Italic, Code, Links)
md_inline="Here is **bold**, *italic*, \`inline_code\` and [Google](https://google.com)"
adf_inline=$(jira_text_to_adf "$md_inline")
assert_eq "Inline root is doc" "doc" "$(echo "$adf_inline" | jq -r '.type // empty')"

# Test 8: Transparent CLI Integration with pre-formatted ADF in comment
dry_comment_adf=$("$JIRA_BIN" comment add PROJ-100 "$pre_adf" --dry-run 2>/dev/null)
assert_json_eq "CLI accepts pre-formatted ADF without double wrap" "$pre_adf" "$(echo "$dry_comment_adf" | jq -r '.body')"

# Test 9: Transparent CLI Integration with Markdown in comment
dry_comment_md=$("$JIRA_BIN" comment add PROJ-100 "# Big News" --dry-run 2>/dev/null)
assert_eq "CLI converts Markdown comment to heading" "heading" "$(echo "$dry_comment_md" | jq -r '.body.content[0].type // empty')"

# Test 10: Transparent CLI Integration in issue edit
code_payload=$'```json\n{"ok":true}\n```'
dry_edit_md=$("$JIRA_BIN" edit PROJ-100 --description "$code_payload" --dry-run 2>/dev/null)
assert_eq "CLI converts edit description codeBlock" "codeBlock" "$(echo "$dry_edit_md" | jq -r '.fields.description.content[0].type // empty')"

# Test 11: Transparent CLI Integration in worklog
dry_wl_md=$("$JIRA_BIN" worklog add PROJ-100 1h -m "Completed initial setup" --dry-run 2>/dev/null)
assert_eq "CLI converts worklog comment to ADF doc" "doc" "$(echo "$dry_wl_md" | jq -r '.comment.type // empty')"

echo
echo "Results: $((total - failed))/$total passed"
if [ $failed -gt 0 ]; then
  exit 1
fi
exit 0
