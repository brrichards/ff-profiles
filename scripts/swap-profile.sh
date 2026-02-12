#!/usr/bin/env bash
# swap-profile.sh — List, swap, and save Claude Code profiles.
#
# Usage:
#   swap-profile.sh list   [--repo-root <path>]
#   swap-profile.sh swap <name> [--repo-root <path>] [--target <path>]
#   swap-profile.sh save <name> [--description "..."] [--force] [--repo-root <path>] [--target <path>]
#   swap-profile.sh help
set -euo pipefail

# ── Argument parsing ──

COMMAND=""
PROFILE_NAME=""
REPO_ROOT=""
TARGET=""
DESCRIPTION=""
FORCE=false

while [[ $# -gt 0 ]]; do
	case "$1" in
		list|swap|save|help)
			COMMAND="$1"
			shift
			# If swap or save, next positional arg (if not a flag) is the profile name
			if [[ ("$COMMAND" == "swap" || "$COMMAND" == "save") && $# -gt 0 && "$1" != --* ]]; then
				PROFILE_NAME="$1"
				shift
			fi
			;;
		--repo-root)
			REPO_ROOT="$2"
			shift 2
			;;
		--target)
			TARGET="$2"
			shift 2
			;;
		--description)
			if [[ $# -lt 2 || "$2" == --* ]]; then
				echo "Error: --description requires a value." >&2
				exit 1
			fi
			DESCRIPTION="$2"
			shift 2
			;;
		--force)
			FORCE=true
			shift
			;;
		*)
			shift
			;;
	esac
done

# Resolve repo root: default to the parent of the scripts/ directory
if [[ -z "$REPO_ROOT" ]]; then
	REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

PROFILES_DIR="$REPO_ROOT/claude-profiles"
CUSTOM_PROFILES_DIR="$REPO_ROOT/custom-profiles"
COMMANDS_DIR="$REPO_ROOT/commands"

# ── Helpers ──

json_escape() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# ── Subcommands ──

list_profiles_in_dir() {
	local dir="$1"
	local tag="${2:-}"
	for profile_dir in "$dir"/*/; do
		[[ -d "$profile_dir" ]] || continue
		local name
		name="$(basename "$profile_dir")"
		local description="(no description)"

		if [[ -f "$profile_dir/profile.json" ]]; then
			description="$(grep -o '"description"[[:space:]]*:[[:space:]]*"[^"]*"' "$profile_dir/profile.json" | head -1 | sed 's/.*:[[:space:]]*"\(.*\)"/\1/')" || description="(no description)"
		fi

		if [[ -n "$tag" ]]; then
			printf "  %-20s %s %s\n" "$name" "$tag" "$description"
		else
			printf "  %-20s %s\n" "$name" "$description"
		fi
	done
}

cmd_list() {
	if [[ ! -d "$PROFILES_DIR" ]]; then
		echo "Error: No claude-profiles/ directory found at $PROFILES_DIR" >&2
		exit 1
	fi

	echo "Available profiles:"
	echo ""

	list_profiles_in_dir "$PROFILES_DIR"

	if [[ -d "$CUSTOM_PROFILES_DIR" ]]; then
		list_profiles_in_dir "$CUSTOM_PROFILES_DIR" "[custom]"
	fi

	echo ""
}

cmd_swap() {
	if [[ -z "$PROFILE_NAME" ]]; then
		echo "Error: Profile name required. Usage: swap-profile.sh swap <name>" >&2
		exit 1
	fi

	local profile_dir="$PROFILES_DIR/$PROFILE_NAME"

	# Check custom-profiles/ if not found in claude-profiles/
	if [[ ! -d "$profile_dir" && -d "$CUSTOM_PROFILES_DIR/$PROFILE_NAME" ]]; then
		profile_dir="$CUSTOM_PROFILES_DIR/$PROFILE_NAME"
	fi

	if [[ ! -d "$profile_dir" ]]; then
		echo "Error: Profile \"$PROFILE_NAME\" not found." >&2
		echo "Available profiles:" >&2
		for d in "$PROFILES_DIR"/*/; do
			[[ -d "$d" ]] && echo "  $(basename "$d")" >&2
		done
		if [[ -d "$CUSTOM_PROFILES_DIR" ]]; then
			for d in "$CUSTOM_PROFILES_DIR"/*/; do
				[[ -d "$d" ]] && echo "  $(basename "$d") [custom]" >&2
			done
		fi
		exit 1
	fi

	# Resolve target directory
	if [[ -z "$TARGET" ]]; then
		# Default: parent of the repo root (ff-profiles/ lives inside the project)
		TARGET="$(cd "$REPO_ROOT/.." && pwd)"
	fi

	local target_claude_dir="$TARGET/.claude"

	# Remove existing .claude/ directory
	if [[ -d "$target_claude_dir" ]]; then
		rm -rf "$target_claude_dir"
	fi

	# Copy profile to .claude/
	cp -r "$profile_dir" "$target_claude_dir"

	# Inject /profiles command so it's always available
	mkdir -p "$target_claude_dir/commands"
	if [[ -f "$COMMANDS_DIR/profiles.md" ]]; then
		cp "$COMMANDS_DIR/profiles.md" "$target_claude_dir/commands/profiles.md"
	fi

	echo "Profile \"$PROFILE_NAME\" applied to $TARGET"
}

cmd_save() {
	if [[ -z "$PROFILE_NAME" ]]; then
		echo "Error: Profile name required. Usage: swap-profile.sh save <name>" >&2
		exit 1
	fi

	# Validate profile name: alphanumeric, hyphens, underscores only
	if [[ ! "$PROFILE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
		echo "Error: Profile name must contain only letters, numbers, hyphens, and underscores." >&2
		exit 1
	fi

	# Prevent shadowing built-in profiles
	if [[ -d "$PROFILES_DIR/$PROFILE_NAME" ]]; then
		echo "Error: \"$PROFILE_NAME\" is a built-in profile name. Choose a different name." >&2
		exit 1
	fi

	# Resolve target directory
	if [[ -z "$TARGET" ]]; then
		TARGET="$(cd "$REPO_ROOT/.." && pwd)"
	fi

	local target_claude_dir="$TARGET/.claude"

	if [[ ! -d "$target_claude_dir" ]]; then
		echo "Error: No .claude/ directory found at $target_claude_dir" >&2
		exit 1
	fi

	local save_dir="$CUSTOM_PROFILES_DIR/$PROFILE_NAME"

	# Handle existing profile
	if [[ -d "$save_dir" ]]; then
		if [[ "$FORCE" == true ]]; then
			rm -rf "$save_dir"
		elif [[ -t 0 ]]; then
			read -r -p "Profile \"$PROFILE_NAME\" already exists. Overwrite? [y/N] " response
			case "$response" in
				[yY]|[yY][eE][sS]) rm -rf "$save_dir" ;;
				*) echo "Aborted." ; exit 1 ;;
			esac
		else
			echo "Error: Profile \"$PROFILE_NAME\" already exists. Use --force to overwrite." >&2
			exit 1
		fi
	fi

	# Create custom-profiles directory if needed
	mkdir -p "$CUSTOM_PROFILES_DIR"

	# Copy .claude/ to custom-profiles/<name>
	cp -r "$target_claude_dir" "$save_dir"

	# Strip injected profiles.md (it gets re-injected on swap)
	if [[ -f "$save_dir/commands/profiles.md" ]]; then
		rm "$save_dir/commands/profiles.md"
	fi

	# Generate profile.json
	if [[ -z "$DESCRIPTION" ]]; then
		DESCRIPTION="Custom profile saved on $(date +%Y-%m-%d)"
	fi
	local safe_name safe_desc
	safe_name="$(json_escape "$PROFILE_NAME")"
	safe_desc="$(json_escape "$DESCRIPTION")"
	cat > "$save_dir/profile.json" <<-ENDJSON
	{
	  "name": "$safe_name",
	  "description": "$safe_desc"
	}
	ENDJSON

	echo "Profile \"$PROFILE_NAME\" saved to $save_dir"
}

cmd_help() {
	cat <<'EOF'
Usage: swap-profile.sh <command> [options]

Commands:
  list                List available profiles (built-in and custom)
  swap <name>         Apply a profile to the target directory
  save <name>         Save the current .claude/ directory as a custom profile
  help                Show this help message

Options:
  --repo-root <path>      Path to the ff-profiles repo (default: auto-detected)
  --target <path>         Target project directory (default: parent of repo root)
  --description "text"    Description for saved profile (save only)
  --force                 Overwrite existing profile without prompting (save only)

Examples:
  swap-profile.sh list
  swap-profile.sh swap developer
  swap-profile.sh swap minimal --target /path/to/project
  swap-profile.sh save my-setup
  swap-profile.sh save my-setup --description "My custom config"
  swap-profile.sh save my-setup --force
EOF
}

# ── Dispatch ──

case "${COMMAND:-help}" in
	list) cmd_list ;;
	swap) cmd_swap ;;
	save) cmd_save ;;
	help) cmd_help ;;
	*)
		echo "Error: Unknown command: $COMMAND" >&2
		cmd_help >&2
		exit 1
		;;
esac
