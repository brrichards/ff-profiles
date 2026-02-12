#!/usr/bin/env bash
# Integration tests for swap-profile.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SWAP_SCRIPT="$REPO_ROOT/scripts/swap-profile.sh"

PASS=0
FAIL=0

# Helper: create a temp project directory with ff-profiles/ mimicking the cloned repo
setup_test_env() {
	local tmp
	tmp="$(mktemp -d)"
	# Simulate ff-profiles/ being cloned into the project
	cp -r "$REPO_ROOT/claude-profiles" "$tmp/ff-profiles-claude-profiles"
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

assert_file_not_exists() {
	local desc="$1" path="$2"
	if [ ! -f "$path" ]; then
		echo "  PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $desc"
		echo "    file should not exist: $path"
		FAIL=$((FAIL + 1))
	fi
}

assert_exit_code() {
	local desc="$1" expected="$2" actual="$3"
	if [ "$expected" = "$actual" ]; then
		echo "  PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $desc"
		echo "    expected exit code: $expected"
		echo "    actual exit code:   $actual"
		FAIL=$((FAIL + 1))
	fi
}

# ── Tests ──

echo "=== swap-profile.sh tests ==="

echo ""
echo "--- list subcommand ---"

test_list_shows_profiles() {
	local tmp
	tmp="$(setup_test_env)"
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" list --repo-root "$tmp/ff-profiles" 2>&1)" || true
	assert_contains "list output contains 'developer'" "$output" "developer"
	assert_contains "list output contains 'minimal'" "$output" "minimal"
	cleanup_test_env "$tmp"
}
test_list_shows_profiles

test_list_shows_descriptions() {
	local tmp
	tmp="$(setup_test_env)"
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" list --repo-root "$tmp/ff-profiles" 2>&1)" || true
	assert_contains "list output contains developer description" "$output" "FluidFramework"
	assert_contains "list output contains minimal description" "$output" "Bare-bones"
	cleanup_test_env "$tmp"
}
test_list_shows_descriptions

echo ""
echo "--- swap subcommand ---"

test_swap_developer_copies_profile() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap developer --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "swap developer creates .claude/CLAUDE.md" "$tmp/.claude/CLAUDE.md"
	assert_file_exists "swap developer creates .claude/settings.json" "$tmp/.claude/settings.json"
	cleanup_test_env "$tmp"
}
test_swap_developer_copies_profile

test_swap_minimal_copies_profile() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap minimal --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "swap minimal creates .claude/CLAUDE.md" "$tmp/.claude/CLAUDE.md"
	assert_file_exists "swap minimal creates .claude/settings.json" "$tmp/.claude/settings.json"
	cleanup_test_env "$tmp"
}
test_swap_minimal_copies_profile

test_swap_overwrites_existing() {
	local tmp
	tmp="$(setup_test_env)"
	# First apply developer
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap developer --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	# Developer profile should have agents/ directory
	local had_agents="no"
	[ -d "$tmp/.claude/agents" ] && had_agents="yes"
	# Now swap to minimal
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap minimal --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	# Minimal profile should NOT have agents/ directory
	assert_eq "swap overwrites: developer had agents/" "yes" "$had_agents"
	assert_eq "swap overwrites: minimal does not have agents/" "no" "$([ -d "$tmp/.claude/agents" ] && echo "yes" || echo "no")"
	cleanup_test_env "$tmp"
}
test_swap_overwrites_existing

test_swap_injects_profiles_command() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap developer --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "swap injects profiles.md into .claude/commands/" "$tmp/.claude/commands/profiles.md"
	cleanup_test_env "$tmp"
}
test_swap_injects_profiles_command

test_swap_injects_profiles_command_for_minimal() {
	local tmp
	tmp="$(setup_test_env)"
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap minimal --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "swap injects profiles.md for minimal profile too" "$tmp/.claude/commands/profiles.md"
	cleanup_test_env "$tmp"
}
test_swap_injects_profiles_command_for_minimal

test_swap_invalid_profile_errors() {
	local tmp
	tmp="$(setup_test_env)"
	local exit_code=0
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" swap nonexistent --repo-root "$tmp/ff-profiles" --target "$tmp" 2>&1)" || exit_code=$?
	assert_eq "swap invalid profile exits non-zero" "1" "$exit_code"
	assert_contains "swap invalid profile shows error" "$output" "not found"
	cleanup_test_env "$tmp"
}
test_swap_invalid_profile_errors

test_swap_no_name_errors() {
	local tmp
	tmp="$(setup_test_env)"
	local exit_code=0
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" swap --repo-root "$tmp/ff-profiles" --target "$tmp" 2>&1)" || exit_code=$?
	assert_eq "swap with no name exits non-zero" "1" "$exit_code"
	cleanup_test_env "$tmp"
}
test_swap_no_name_errors

echo ""
echo "--- help subcommand ---"

test_help_prints_usage() {
	local tmp
	tmp="$(setup_test_env)"
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" help --repo-root "$tmp/ff-profiles" 2>&1)" || true
	assert_contains "help output contains usage info" "$output" "Usage"
	cleanup_test_env "$tmp"
}
test_help_prints_usage

echo ""
echo "--- save subcommand ---"

# Helper: set up a .claude/ directory with known files to save
setup_claude_dir() {
	local target="$1"
	mkdir -p "$target/.claude/commands" "$target/.claude/agents"
	echo "# My Custom Instructions" > "$target/.claude/CLAUDE.md"
	echo '{"$schema":"..."}' > "$target/.claude/settings.json"
	echo "agent content" > "$target/.claude/agents/my-agent.md"
	# Simulate the injected profiles.md (should be stripped on save)
	echo "profiles command" > "$target/.claude/commands/profiles.md"
	# A user-created command (should be kept on save)
	echo "my command" > "$target/.claude/commands/my-command.md"
}

test_save_creates_custom_profile() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	"$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "save creates CLAUDE.md in custom profile" "$tmp/ff-profiles/custom-profiles/my-custom/CLAUDE.md"
	assert_file_exists "save creates settings.json in custom profile" "$tmp/ff-profiles/custom-profiles/my-custom/settings.json"
	assert_file_exists "save copies agents" "$tmp/ff-profiles/custom-profiles/my-custom/agents/my-agent.md"
	cleanup_test_env "$tmp"
}
test_save_creates_custom_profile

test_save_creates_profile_json() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	"$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "save creates profile.json" "$tmp/ff-profiles/custom-profiles/my-custom/profile.json"
	local content
	content="$(cat "$tmp/ff-profiles/custom-profiles/my-custom/profile.json" 2>/dev/null || echo "")"
	assert_contains "profile.json contains name" "$content" '"my-custom"'
	assert_contains "profile.json contains description" "$content" '"description"'
	cleanup_test_env "$tmp"
}
test_save_creates_profile_json

test_save_with_description() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	"$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --description "My custom setup" --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	local content
	content="$(cat "$tmp/ff-profiles/custom-profiles/my-custom/profile.json" 2>/dev/null || echo "")"
	assert_contains "profile.json contains custom description" "$content" "My custom setup"
	cleanup_test_env "$tmp"
}
test_save_with_description

test_save_strips_injected_profiles_command() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	"$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_not_exists "save strips injected profiles.md" "$tmp/ff-profiles/custom-profiles/my-custom/commands/profiles.md"
	assert_file_exists "save keeps user commands" "$tmp/ff-profiles/custom-profiles/my-custom/commands/my-command.md"
	cleanup_test_env "$tmp"
}
test_save_strips_injected_profiles_command

test_save_refuses_overwrite_without_force() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	# First save
	"$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	# Second save without --force (non-interactive, stdin is not a terminal)
	local exit_code=0
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --repo-root "$tmp/ff-profiles" --target "$tmp" 2>&1)" || exit_code=$?
	assert_eq "save refuses overwrite without --force" "1" "$exit_code"
	assert_contains "save overwrite error mentions --force" "$output" "\-\-force"
	cleanup_test_env "$tmp"
}
test_save_refuses_overwrite_without_force

test_save_overwrites_with_force() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	# First save
	"$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	# Modify .claude/ to confirm overwrite actually happens
	echo "# Updated Instructions" > "$tmp/.claude/CLAUDE.md"
	# Second save with --force
	local exit_code=0
	"$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --force --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || exit_code=$?
	assert_eq "save with --force exits 0" "0" "$exit_code"
	local content
	content="$(cat "$tmp/ff-profiles/custom-profiles/my-custom/CLAUDE.md" 2>/dev/null || echo "")"
	assert_contains "save with --force overwrites content" "$content" "Updated Instructions"
	cleanup_test_env "$tmp"
}
test_save_overwrites_with_force

test_save_no_name_errors() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	local exit_code=0
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" save --repo-root "$tmp/ff-profiles" --target "$tmp" 2>&1)" || exit_code=$?
	assert_eq "save with no name exits non-zero" "1" "$exit_code"
	cleanup_test_env "$tmp"
}
test_save_no_name_errors

test_save_no_claude_dir_errors() {
	local tmp
	tmp="$(setup_test_env)"
	# Deliberately do NOT set up .claude/
	local exit_code=0
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --repo-root "$tmp/ff-profiles" --target "$tmp" 2>&1)" || exit_code=$?
	assert_eq "save with no .claude/ exits non-zero" "1" "$exit_code"
	assert_contains "save error mentions .claude" "$output" ".claude"
	cleanup_test_env "$tmp"
}
test_save_no_claude_dir_errors

test_save_rejects_invalid_name() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	local exit_code=0
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" save "../escape" --repo-root "$tmp/ff-profiles" --target "$tmp" 2>&1)" || exit_code=$?
	assert_eq "save rejects path traversal name" "1" "$exit_code"
	assert_contains "save invalid name error mentions allowed chars" "$output" "letters"
	# Also test names with slashes
	exit_code=0
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" save "foo/bar" --repo-root "$tmp/ff-profiles" --target "$tmp" 2>&1)" || exit_code=$?
	assert_eq "save rejects name with slash" "1" "$exit_code"
	cleanup_test_env "$tmp"
}
test_save_rejects_invalid_name

test_save_rejects_builtin_name() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	local exit_code=0
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" save developer --repo-root "$tmp/ff-profiles" --target "$tmp" 2>&1)" || exit_code=$?
	assert_eq "save rejects built-in profile name" "1" "$exit_code"
	assert_contains "save builtin name error mentions built-in" "$output" "built-in"
	cleanup_test_env "$tmp"
}
test_save_rejects_builtin_name

test_save_escapes_description_in_json() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	"$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --description 'has "quotes" inside' --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	local content
	content="$(cat "$tmp/ff-profiles/custom-profiles/my-custom/profile.json" 2>/dev/null || echo "")"
	assert_contains "profile.json escapes quotes in description" "$content" 'has \\"quotes\\" inside'
	cleanup_test_env "$tmp"
}
test_save_escapes_description_in_json

test_save_description_flag_requires_value() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	local exit_code=0
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --description --force --repo-root "$tmp/ff-profiles" --target "$tmp" 2>&1)" || exit_code=$?
	assert_eq "save --description without value exits non-zero" "1" "$exit_code"
	assert_contains "save --description error mentions requires value" "$output" "requires a value"
	cleanup_test_env "$tmp"
}
test_save_description_flag_requires_value


test_list_shows_custom_profiles() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	"$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --description "A custom one" --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" list --repo-root "$tmp/ff-profiles" 2>&1)" || true
	assert_contains "list shows custom profile name" "$output" "my-custom"
	assert_contains "list shows custom profile description" "$output" "A custom one"
	assert_contains "list shows [custom] tag" "$output" "\[custom\]"
	cleanup_test_env "$tmp"
}
test_list_shows_custom_profiles

test_swap_loads_custom_profile() {
	local tmp
	tmp="$(setup_test_env)"
	setup_claude_dir "$tmp"
	# Save the custom profile
	"$tmp/ff-profiles/scripts/swap-profile.sh" save my-custom --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	# Swap to minimal (destroys .claude/)
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap minimal --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	# Swap back to custom
	"$tmp/ff-profiles/scripts/swap-profile.sh" swap my-custom --repo-root "$tmp/ff-profiles" --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "swap to custom profile restores CLAUDE.md" "$tmp/.claude/CLAUDE.md"
	local content
	content="$(cat "$tmp/.claude/CLAUDE.md" 2>/dev/null || echo "")"
	assert_contains "swap to custom profile has correct content" "$content" "My Custom Instructions"
	assert_file_exists "swap to custom profile restores agents" "$tmp/.claude/agents/my-agent.md"
	cleanup_test_env "$tmp"
}
test_swap_loads_custom_profile

echo ""
echo "--- help subcommand (save) ---"

test_help_shows_save_command() {
	local tmp
	tmp="$(setup_test_env)"
	local output
	output="$("$tmp/ff-profiles/scripts/swap-profile.sh" help --repo-root "$tmp/ff-profiles" 2>&1)" || true
	assert_contains "help output mentions save command" "$output" "save"
	cleanup_test_env "$tmp"
}
test_help_shows_save_command

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
