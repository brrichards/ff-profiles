#!/usr/bin/env bash
# Integration tests for setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

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

# ── Tests ──

echo "=== setup.sh tests ==="

echo ""
echo "--- setup uses local repo when present ---"

test_setup_copies_developer_profile() {
	local tmp
	tmp="$(mktemp -d)"
	# Simulate: user already has ff-profiles/ in their project (e.g., git submodule or manual clone)
	cp -r "$REPO_ROOT" "$tmp/ff-profiles"
	# Run setup.sh with --local flag (skip clone, use local ff-profiles/)
	bash "$tmp/ff-profiles/setup.sh" --local --skip-install --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "setup creates .claude/CLAUDE.md" "$tmp/.claude/CLAUDE.md"
	assert_file_exists "setup creates .claude/settings.json" "$tmp/.claude/settings.json"
	rm -rf "$tmp"
}
test_setup_copies_developer_profile

test_setup_creates_commands_dir_with_profiles() {
	local tmp
	tmp="$(mktemp -d)"
	cp -r "$REPO_ROOT" "$tmp/ff-profiles"
	bash "$tmp/ff-profiles/setup.sh" --local --skip-install --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "setup injects profiles.md" "$tmp/.claude/commands/profiles.md"
	rm -rf "$tmp"
}
test_setup_creates_commands_dir_with_profiles

test_setup_copies_developer_agents() {
	local tmp
	tmp="$(mktemp -d)"
	cp -r "$REPO_ROOT" "$tmp/ff-profiles"
	bash "$tmp/ff-profiles/setup.sh" --local --skip-install --target "$tmp" > /dev/null 2>&1 || true
	assert_dir_exists "setup copies agents directory" "$tmp/.claude/agents"
	rm -rf "$tmp"
}
test_setup_copies_developer_agents

test_setup_copies_developer_skills() {
	local tmp
	tmp="$(mktemp -d)"
	cp -r "$REPO_ROOT" "$tmp/ff-profiles"
	bash "$tmp/ff-profiles/setup.sh" --local --skip-install --target "$tmp" > /dev/null 2>&1 || true
	assert_dir_exists "setup copies skills directory" "$tmp/.claude/skills"
	rm -rf "$tmp"
}
test_setup_copies_developer_skills

test_setup_prints_summary() {
	local tmp
	tmp="$(mktemp -d)"
	cp -r "$REPO_ROOT" "$tmp/ff-profiles"
	local output
	output="$(bash "$tmp/ff-profiles/setup.sh" --local --skip-install --target "$tmp" 2>&1)" || true
	assert_contains "setup prints profile name" "$output" "developer"
	rm -rf "$tmp"
}
test_setup_prints_summary

echo ""
echo "--- setup handles re-runs ---"

test_setup_overwrites_existing_claude_dir() {
	local tmp
	tmp="$(mktemp -d)"
	cp -r "$REPO_ROOT" "$tmp/ff-profiles"
	# Create a pre-existing .claude/ with a stale file
	mkdir -p "$tmp/.claude"
	echo "stale" > "$tmp/.claude/stale-file.txt"
	bash "$tmp/ff-profiles/setup.sh" --local --skip-install --target "$tmp" > /dev/null 2>&1 || true
	assert_file_exists "setup creates fresh CLAUDE.md" "$tmp/.claude/CLAUDE.md"
	assert_eq "setup removes stale files" "no" "$([ -f "$tmp/.claude/stale-file.txt" ] && echo "yes" || echo "no")"
	rm -rf "$tmp"
}
test_setup_overwrites_existing_claude_dir

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
