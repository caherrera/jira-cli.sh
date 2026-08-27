#!/bin/bash

# Convert Markdown to Atlassian Document Format (ADF)
# Handles headings, code blocks, lists, blockquotes, inline formatting (bold, italic, code, links)

markdown_to_adf() {
  local markdown_text="$1"
  
  if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required for ADF conversion" >&2
    return 1
  fi
  
  local content='[]'
  local line_buffer=""
  local in_code_block=false
  local code_lang=""
  local code_lines=()
  
  local re_code_block='^```([a-zA-Z0-9_-]*)'
  local re_quote='^[[:space:]]*>[[:space:]]*(.+)$'
  local re_heading='^(#{1,6})[[:space:]]+(.+)$'
  local re_task='^[[:space:]]*[\*\-][[:space:]]\[([xX[:space:]])\][[:space:]]+(.+)$'
  local re_bullet='^[[:space:]]*[\*\-][[:space:]]+(.+)$'
  local re_number='^[[:space:]]*[0-9]+\.[[:space:]]+(.+)$'

  while IFS= read -r line || [ -n "$line" ]; do
    
    # Handle code blocks
    if [[ "$line" =~ $re_code_block ]]; then
      if [ -n "$line_buffer" ]; then
        content=$(add_paragraph "$content" "$line_buffer")
        line_buffer=""
      fi
      
      if [ "$in_code_block" = false ]; then
        in_code_block=true
        code_lang="${BASH_REMATCH[1]}"
        code_lines=()
      else
        in_code_block=false
        local code_text
        code_text=$(printf '%s\n' "${code_lines[@]}")
        code_text="${code_text%$'\n'}"
        content=$(add_code_block "$content" "$code_text" "$code_lang")
        code_lang=""
      fi
      continue
    fi
    
    # Collect code block lines
    if [ "$in_code_block" = true ]; then
      code_lines+=("$line")
      continue
    fi
    
    # Handle blockquotes (> quote)
    if [[ "$line" =~ $re_quote ]]; then
      if [ -n "$line_buffer" ]; then
        content=$(add_paragraph "$content" "$line_buffer")
        line_buffer=""
      fi
      local quote_text="${BASH_REMATCH[1]}"
      content=$(add_blockquote "$content" "$quote_text")
      continue
    fi

    # Handle headings (# to ######)
    if [[ "$line" =~ $re_heading ]]; then
      if [ -n "$line_buffer" ]; then
        content=$(add_paragraph "$content" "$line_buffer")
        line_buffer=""
      fi
      
      local level=${#BASH_REMATCH[1]}
      local heading_text="${BASH_REMATCH[2]}"
      content=$(add_heading "$content" "$level" "$heading_text")
      continue
    fi
    
    # Handle task list items (checkboxes)
    if [[ "$line" =~ $re_task ]]; then
      if [ -n "$line_buffer" ]; then
        content=$(add_paragraph "$content" "$line_buffer")
        line_buffer=""
      fi
      
      local checked="${BASH_REMATCH[1]}"
      local task_text="${BASH_REMATCH[2]}"
      local state="TODO"
      [[ "$checked" =~ [xX] ]] && state="DONE"
      
      content=$(add_task_item "$content" "$state" "$task_text")
      continue
    fi
    
    # Handle bullet lists
    if [[ "$line" =~ $re_bullet ]]; then
      if [ -n "$line_buffer" ]; then
        content=$(add_paragraph "$content" "$line_buffer")
        line_buffer=""
      fi
      
      local item_text="${BASH_REMATCH[1]}"
      content=$(add_bullet_item "$content" "$item_text")
      continue
    fi
    
    # Handle numbered lists  
    if [[ "$line" =~ $re_number ]]; then
      if [ -n "$line_buffer" ]; then
        content=$(add_paragraph "$content" "$line_buffer")
        line_buffer=""
      fi
      
      local item_text="${BASH_REMATCH[1]}"
      content=$(add_numbered_item "$content" "$item_text")
      continue
    fi
    
    # Empty line - paragraph separator
    if [ -z "$line" ]; then
      if [ -n "$line_buffer" ]; then
        content=$(add_paragraph "$content" "$line_buffer")
        line_buffer=""
      fi
      continue
    fi
    
    # Regular text - accumulate in buffer
    if [ -n "$line_buffer" ]; then
      line_buffer+=$'\n'
    fi
    line_buffer+="$line"
    
  done <<< "$markdown_text"
  
  # Flush remaining buffer
  if [ -n "$line_buffer" ]; then
    content=$(add_paragraph "$content" "$line_buffer")
  fi
  
  # Build final ADF document
  jq -n --argjson content "$content" '{
    "version": 1,
    "type": "doc",
    "content": $content
  }'
}

# Helper functions for building ADF nodes

add_paragraph() {
  local content="$1"
  local text="$2"
  local inline_content
  inline_content=$(process_inline_formatting "$text")
  
  echo "$content" | jq --argjson inline "$inline_content" \
    '. += [{"type": "paragraph", "content": $inline}]'
}

add_blockquote() {
  local content="$1"
  local text="$2"
  local inline_content
  inline_content=$(process_inline_formatting "$text")
  
  echo "$content" | jq --argjson inline "$inline_content" \
    '. += [{"type": "blockquote", "content": [{"type": "paragraph", "content": $inline}]}]'
}

add_heading() {
  local content="$1"
  local level="$2"
  local text="$3"
  local inline_content
  inline_content=$(process_inline_formatting "$text")
  
  echo "$content" | jq --arg level "$level" --argjson inline "$inline_content" \
    '. += [{"type": "heading", "attrs": {"level": ($level | tonumber)}, "content": $inline}]'
}

add_code_block() {
  local content="$1"
  local code="$2"
  local lang="$3"
  
  if [ -n "$lang" ]; then
    echo "$content" | jq --arg code "$code" --arg lang "$lang" \
      '. += [{"type": "codeBlock", "attrs": {"language": $lang}, "content": [{"type": "text", "text": $code}]}]'
  else
    echo "$content" | jq --arg code "$code" \
      '. += [{"type": "codeBlock", "content": [{"type": "text", "text": $code}]}]'
  fi
}

add_task_item() {
  local content="$1"
  local state="$2"
  local text="$3"
  local inline_content
  inline_content=$(process_inline_formatting "$text")
  
  echo "$content" | jq --arg state "$state" --argjson inline "$inline_content" \
    '. += [{"type": "taskList", "content": [{"type": "taskItem", "attrs": {"state": $state}, "content": [{"type": "paragraph", "content": $inline}]}]}]'
}

add_bullet_item() {
  local content="$1"
  local text="$2"
  local inline_content
  inline_content=$(process_inline_formatting "$text")
  
  echo "$content" | jq --argjson inline "$inline_content" \
    '. += [{"type": "bulletList", "content": [{"type": "listItem", "content": [{"type": "paragraph", "content": $inline}]}]}]'
}

add_numbered_item() {
  local content="$1"
  local text="$2"
  local inline_content
  inline_content=$(process_inline_formatting "$text")
  
  echo "$content" | jq --argjson inline "$inline_content" \
    '. += [{"type": "orderedList", "content": [{"type": "listItem", "content": [{"type": "paragraph", "content": $inline}]}]}]'
}

# Process inline formatting: **bold**, *italic*, `code`, [link](url), ~~strike~~
process_inline_formatting() {
  local text="$1"

  if [[ -z "$text" ]]; then
    echo '[]'
    return 0
  fi

  local nodes='[]'
  local remaining="$text"
  local link_pattern='^([^[]*)\[([^]]+)\]\(([^)]+)\)(.*)$'

  while [[ -n "$remaining" ]]; do
    if [[ "$remaining" =~ $link_pattern ]]; then
      local prefix="${BASH_REMATCH[1]}"
      local label="${BASH_REMATCH[2]}"
      local url="${BASH_REMATCH[3]}"
      remaining="${BASH_REMATCH[4]}"
      if [[ -n "$prefix" ]]; then
        nodes=$(process_inline_styles "$nodes" "$prefix")
      fi
      nodes=$(echo "$nodes" | jq --arg text "$label" --arg href "$url" \
        '. += [{"type": "text", "text": $text, "marks": [{"type": "link", "attrs": {"href": $href}}]}]')
    else
      nodes=$(process_inline_styles "$nodes" "$remaining")
      break
    fi
  done

  echo "$nodes"
}

process_inline_styles() {
  local current_nodes="$1"
  local text="$2"

  if [[ -z "$text" ]]; then
    echo "$current_nodes"
    return 0
  fi

  local chunk="$text"
  local out_nodes="$current_nodes"

  local code_pat='^([^`]*)`([^`]+)`(.*)$'
  local bold_pat='^([^*]*)\*\*([^*]+)\*\*(.*)$'
  local strike_pat='^([^~]*)~~([^~]+)~~(.*)$'
  local em_pat='^([^*]*)\*([^*]+)\*(.*)$'

  # Pattern for inline code `code`
  if [[ "$chunk" =~ $code_pat ]]; then
    local pre="${BASH_REMATCH[1]}"
    local code_val="${BASH_REMATCH[2]}"
    local rest="${BASH_REMATCH[3]}"
    [[ -n "$pre" ]] && out_nodes=$(process_bold_italic "$out_nodes" "$pre")
    out_nodes=$(echo "$out_nodes" | jq --arg text "$code_val" \
      '. += [{"type": "text", "text": $text, "marks": [{"type": "code"}]}]')
    out_nodes=$(process_inline_styles "$out_nodes" "$rest")
    echo "$out_nodes"
    return 0
  fi

  # Pattern for bold **bold**
  if [[ "$chunk" =~ $bold_pat ]]; then
    local pre="${BASH_REMATCH[1]}"
    local bold_val="${BASH_REMATCH[2]}"
    local rest="${BASH_REMATCH[3]}"
    [[ -n "$pre" ]] && out_nodes=$(process_bold_italic "$out_nodes" "$pre")
    out_nodes=$(echo "$out_nodes" | jq --arg text "$bold_val" \
      '. += [{"type": "text", "text": $text, "marks": [{"type": "strong"}]}]')
    out_nodes=$(process_inline_styles "$out_nodes" "$rest")
    echo "$out_nodes"
    return 0
  fi

  # Pattern for strike ~~strike~~
  if [[ "$chunk" =~ $strike_pat ]]; then
    local pre="${BASH_REMATCH[1]}"
    local strike_val="${BASH_REMATCH[2]}"
    local rest="${BASH_REMATCH[3]}"
    [[ -n "$pre" ]] && out_nodes=$(process_bold_italic "$out_nodes" "$pre")
    out_nodes=$(echo "$out_nodes" | jq --arg text "$strike_val" \
      '. += [{"type": "text", "text": $text, "marks": [{"type": "strike"}]}]')
    out_nodes=$(process_inline_styles "$out_nodes" "$rest")
    echo "$out_nodes"
    return 0
  fi

  # Pattern for italic *italic*
  if [[ "$chunk" =~ $em_pat ]]; then
    local pre="${BASH_REMATCH[1]}"
    local em_val="${BASH_REMATCH[2]}"
    local rest="${BASH_REMATCH[3]}"
    [[ -n "$pre" ]] && out_nodes=$(echo "$out_nodes" | jq --arg text "$pre" '. += [{"type": "text", "text": $text}]')
    out_nodes=$(echo "$out_nodes" | jq --arg text "$em_val" \
      '. += [{"type": "text", "text": $text, "marks": [{"type": "em"}]}]')
    out_nodes=$(process_inline_styles "$out_nodes" "$rest")
    echo "$out_nodes"
    return 0
  fi

  # Pure text node
  echo "$out_nodes" | jq --arg text "$chunk" '. += [{"type": "text", "text": $text}]'
}

process_bold_italic() {
  local current_nodes="$1"
  local text="$2"
  [[ -z "$text" ]] && { echo "$current_nodes"; return 0; }
  echo "$current_nodes" | jq --arg text "$text" '. += [{"type": "text", "text": $text}]'
}
