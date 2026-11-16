#!/usr/bin/env bash
# ai-dlc-advisor-detect.sh -- SOURCED LIBRARY, not a hook. Registered in no settings file and
# invoked by no event. `ai-dlc-advisor-gate.sh` and `ai-dlc-recover-gate.sh` (its touchpoint-R
# stage) each `.`-source it as a sibling and prepend `$ADV_DETECT_JQ` to the jq program that
# scans a transcript, so the two gates read the advisor grant, the consult roster, an advisor
# attempt, an advisor result and a consult from ONE definition (BL-1136). A gate that cannot
# source this file warns on stderr and is silent: a guard that cannot read its own detection
# must not deny.
#
# THE DEFINITIONS, each over one transcript line `$l` or one content block:
#   adv_attach($l)   true for an attachment line either fold below reads.
#   adv_fold($l)     folds such a line into `.grant` (the latest `advisor_tool` attachment:
#                    true unless `available: false` or `toolChange: "remove"`) and `.roster`
#                    (the latest `deferred_tools_delta` naming `mcp__advisor__consult`: true in
#                    `addedNames`, false in `removedNames`).
#   adv_blocks($l)   the content blocks a gate may CREDIT on that line: every block of a
#                    `type == "assistant"` line except a `tool_result`, and only the `tool_result`
#                    blocks of a `type == "user"` line. Every other line type yields none: an
#                    `api-request-blob` line re-carries earlier assistant and user blocks, and
#                    crediting them again moves the last attempt or the last gated call later
#                    than it happened (BL-1137).
#   adv_attempt      a block that is a built-in advisor attempt (`server_tool_use` named `advisor`).
#   adv_consult      a block that is a `tool_use` named `mcp__advisor__consult`.
#   adv_res          for an `advisor_tool_result` block: "U" when its `error_code` is
#                    `unavailable`, else "R"; null for any other block.
#   adv_held         over a state carrying `.roster` and `.mcp` (the line of the last consult, 0
#                    when none): the agent HOLDS the consult -- the roster lists it, or no roster
#                    line names it and a consult is on disk.
#
# Compatible with bash 3.2: it only assigns one variable.
ADV_DETECT_JQ='
def adv_attach($l): $l.type == "attachment" and ($l.attachment | type) == "object"
  and ($l.attachment.type == "advisor_tool" or $l.attachment.type == "deferred_tools_delta");
def adv_names($a; $k): ($a[$k] // []) | if type == "array" then any(.[]; . == "mcp__advisor__consult") else false end;
def adv_fold($l):
  if $l.attachment.type == "advisor_tool" then
    .grant = (($l.attachment.available != false) and ($l.attachment.toolChange != "remove"))
  else
    (if adv_names($l.attachment; "removedNames") then .roster = false else . end)
    | (if adv_names($l.attachment; "addedNames") then .roster = true else . end)
  end;
def adv_blocks($l): ($l.message.content? // []) | if type == "array" then .[] else empty end
  | select(type == "object")
  | if $l.type == "assistant" then select(.type != "tool_result")
    elif $l.type == "user" then select(.type == "tool_result")
    else empty end;
def adv_attempt: .type == "server_tool_use" and .name == "advisor";
def adv_consult: .type == "tool_use" and .name == "mcp__advisor__consult";
def adv_res: if .type == "advisor_tool_result" then
    (if ((.content | if type == "object" then .error_code else null end) // "") == "unavailable" then "U" else "R" end)
  else null end;
def adv_held: .roster == true or (.roster == null and .mcp > 0);
'
