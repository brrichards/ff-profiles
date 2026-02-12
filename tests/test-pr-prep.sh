#!/usr/bin/env bash
# Integration tests for the pr-prep profile
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SWAP_SCRIPT="$REPO_ROOT/scripts/swap-profile.sh"

PASS=0
FAIL=0

# ── Helpers ──

setup_test_env() {
	local tmp
	tmp="$(mktemp -d)"
	mkdir -p "$tmp/ff-profiles"
	cp -r "$REPO_ROOT/claude-profiles" "$tmp/ff-profiles/claude-profiles"
	cp -r "$REPO_ROOT/commands" "$tmp/ff-profiles/commands"
	cp -r "$REPO_ROOT/scripts" "$tmp/ff-profiles/scripts"
	chmod +x "$tmp/ff-profiles/scripts/swap-profile.sh"
	echo "$tmp"
}

cleanup_test_env() {
	rm -rf "$1"
}

assert_eq() {
	local desc="$1" expected="$2" actual="$3"
	if [ "$expected" = "$actual" ]; then
		echo "  PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $desc"
		echo "    expected: $expected"
		echo "    actual:   $actual"
		FAIL=$((FAIL + 1))
	fi
}

assert_contains() {
	local desc="$1" haystack="$2" needle="$3"
	if echo "$haystack" | grep -q "$needle"; then
		echo "  PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $desc"
		echo "    expected to contain: $needle"
		echo "    actual: $haystack"
		FAIL=$((FAIL + 1))
	fi
}

assert_file_exists() {
	local desc="$1" path="$2"
	if [ -f "$path" ]; then
		echo "  PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $desc"
		echo "    file not found: $path"
		FAIL=$((FAIL + 1))
	fi
}

assert_dir_exists() {
	local desc="$1" path="$2"
	if [ -d "$path" ]; then
		echo "  PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $desc"
		echo "    directory not found: $path"
		FAIL=$((FAIL + 1))
	fi
}

assert_valid_json() {
	local desc="$1" path="$2"
	if python3 -c "import json; json.load(open('$path'))" 2>/dev/null; then
		echo "  PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $desc"
		echo "    invalid JSON: $path"
		FAIL=$((FAIL + 1))
	fi
}

assert_file_executable() {
	local desc="$1" path="$2"
	if [ -x "$path" ]; then
		echo "  PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $desc"
		echo "    not executable: $path"
		FAIL=$((FAIL + 1))
	fi
}

assert_json_has_key() {
	local desc="$1" path="$2" key="$3"
	if python3 -c "
import json, sys
data = json.load(open('$path'))
keys = '$key'.split('.')
obj = data
for k in keys:
    obj = obj[k]
" 2>/dev/null; then
		echo "  PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $desc"
		echo "    key '$key' not found in $path"
		FAIL=$((FAIL + 1))
	fi
}

# ── Tests ──

echo "=== pr-prep profile tests ==="

echo ""
echo "--- profile discovery ---"

test_list_includes_pr_prep() {
	local tmp
	tmp="$(setup_test_env)"
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" list --repo-root "$tmp/ff-profiles" 2>&1)" || true
	assert_contains "list output contains 'pr-prep'" "$output" "pr-prep"
	cleanup_test_env "$tmp"
}
test_list_includes_pr_prep

test_list_shows_pr_prep_description() {
	local tmp
	tmp="$(setup_test_env)"
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" list --repo-root "$tmp/ff-profiles" 2>&1)" || true
	assert_contains "list shows pr-prep description" "$output" "PR"
	cleanup_test_env "$tmp"
}
test_list_shows_pr_prep_description

echo ""
echo "--- profile swap ---"

test_swap_pr_prep_creates_claude_md() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "swap pr-prep creates .claude/CLAUDE.md" "$tmp/.claude/CLAUDE.md"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_creates_claude_md

test_swap_pr_prep_creates_settings() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "swap pr-prep creates .claude/settings.json" "$tmp/.claude/settings.json"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_creates_settings

test_swap_pr_prep_creates_profile_json() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "swap pr-prep creates .claude/profile.json" "$tmp/.claude/profile.json"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_creates_profile_json

test_swap_pr_prep_creates_hooks_json() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "swap pr-prep creates .claude/hooks.json" "$tmp/.claude/hooks.json"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_creates_hooks_json

test_swap_pr_prep_creates_mcp_json() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "swap pr-prep creates .claude/.mcp.json" "$tmp/.claude/.mcp.json"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_creates_mcp_json

test_swap_pr_prep_injects_profiles_command() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "swap pr-prep injects profiles.md" "$tmp/.claude/commands/profiles.md"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_injects_profiles_command

echo ""
echo "--- directory structure ---"

test_swap_pr_prep_has_agents_dir() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_dir_exists "swap pr-prep creates agents/" "$tmp/.claude/agents"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_has_agents_dir

test_swap_pr_prep_has_skills_dir() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_dir_exists "swap pr-prep creates skills/" "$tmp/.claude/skills"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_has_skills_dir

test_swap_pr_prep_has_commands_dir() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_dir_exists "swap pr-prep creates commands/" "$tmp/.claude/commands"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_has_commands_dir

test_swap_pr_prep_has_hooks_dir() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_dir_exists "swap pr-prep creates hooks/" "$tmp/.claude/hooks"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_has_hooks_dir

echo ""
echo "--- agent files ---"

test_swap_pr_prep_has_reviewer_agent() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "pr-reviewer agent exists" "$tmp/.claude/agents/pr-reviewer.md"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_has_reviewer_agent

test_swap_pr_prep_has_simplifier_agent() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "simplifier agent exists" "$tmp/.claude/agents/simplifier.md"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_has_simplifier_agent

test_swap_pr_prep_has_validator_agent() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "validator agent exists" "$tmp/.claude/agents/validator.md"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_has_validator_agent

echo ""
echo "--- skill files ---"

test_swap_pr_prep_has_checklist_skill() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "pr-checklist skill exists" "$tmp/.claude/skills/pr-checklist/SKILL.md"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_has_checklist_skill

echo ""
echo "--- command files ---"

test_swap_pr_prep_has_prep_pr_command() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "prep-pr command exists" "$tmp/.claude/commands/prep-pr.md"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_has_prep_pr_command

echo ""
echo "--- hook scripts ---"

test_swap_pr_prep_has_lint_hook_script() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "lint-on-save hook script exists" "$tmp/.claude/hooks/lint-on-save.sh"
	assert_file_executable "lint-on-save hook script is executable" "$tmp/.claude/hooks/lint-on-save.sh"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_has_lint_hook_script

test_swap_pr_prep_has_completion_gate_script() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "completion-gate hook script exists" "$tmp/.claude/hooks/completion-gate.sh"
	assert_file_executable "completion-gate hook script is executable" "$tmp/.claude/hooks/completion-gate.sh"
	cleanup_test_env "$tmp"
}
test_swap_pr_prep_has_completion_gate_script

echo ""
echo "--- JSON validity ---"

test_profile_json_is_valid() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_valid_json "profile.json is valid JSON" "$tmp/.claude/profile.json"
	cleanup_test_env "$tmp"
}
test_profile_json_is_valid

test_settings_json_is_valid() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_valid_json "settings.json is valid JSON" "$tmp/.claude/settings.json"
	cleanup_test_env "$tmp"
}
test_settings_json_is_valid

test_hooks_json_is_valid() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_valid_json "hooks.json is valid JSON" "$tmp/.claude/hooks.json"
	cleanup_test_env "$tmp"
}
test_hooks_json_is_valid

test_mcp_json_is_valid() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_valid_json ".mcp.json is valid JSON" "$tmp/.claude/.mcp.json"
	cleanup_test_env "$tmp"
}
test_mcp_json_is_valid

echo ""
echo "--- JSON structure ---"

test_settings_has_permissions() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_json_has_key "settings.json has permissions.allow" "$tmp/.claude/settings.json" "permissions.allow"
	assert_json_has_key "settings.json has permissions.deny" "$tmp/.claude/settings.json" "permissions.deny"
	assert_json_has_key "settings.json has permissions.ask" "$tmp/.claude/settings.json" "permissions.ask"
	cleanup_test_env "$tmp"
}
test_settings_has_permissions

test_hooks_json_has_post_tool_use() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_json_has_key "hooks.json has hooks.PostToolUse" "$tmp/.claude/hooks.json" "hooks.PostToolUse"
	cleanup_test_env "$tmp"
}
test_hooks_json_has_post_tool_use

test_hooks_json_has_stop() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_json_has_key "hooks.json has hooks.Stop" "$tmp/.claude/hooks.json" "hooks.Stop"
	cleanup_test_env "$tmp"
}
test_hooks_json_has_stop

test_mcp_has_github_server() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_json_has_key ".mcp.json has mcpServers.github" "$tmp/.claude/.mcp.json" "mcpServers.github"
	cleanup_test_env "$tmp"
}
test_mcp_has_github_server

test_profile_json_has_name() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	local name
	name="$(python3 -c "import json; print(json.load(open('$tmp/.claude/profile.json'))['name'])" 2>/dev/null)" || name=""
	assert_eq "profile.json name is pr-prep" "pr-prep" "$name"
	cleanup_test_env "$tmp"
}
test_profile_json_has_name

echo ""
echo "--- swap isolation (pr-prep does not leak into other profiles) ---"

test_swap_from_pr_prep_to_minimal_removes_agents() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap pr-prep --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	local had_agents="no"
	[ -d "$tmp/.claude/agents" ] && had_agents="yes"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap minimal --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_eq "pr-prep had agents/" "yes" "$had_agents"
	assert_eq "minimal does not have agents/" "no" "$([ -d "$tmp/.claude/agents" ] && echo "yes" || echo "no")"
	cleanup_test_env "$tmp"
}
test_swap_from_pr_prep_to_minimal_removes_agents

echo ""
echo "--- existing tests still pass ---"

test_existing_profiles_still_listed() {
	local tmp
	tmp="$(setup_test_env)"
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" list --repo-root "$tmp/ff-profiles" 2>&1)" || true
	assert_contains "list still shows developer" "$output" "developer"
	assert_contains "list still shows minimal" "$output" "minimal"
	assert_contains "list also shows pr-prep" "$output" "pr-prep"
	cleanup_test_env "$tmp"
}
test_existing_profiles_still_listed

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
