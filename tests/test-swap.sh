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
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
