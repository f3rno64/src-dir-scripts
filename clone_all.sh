#!/usr/bin/env bash

DEFAULT_JOBS=5
DEFAULT_LIMIT=25
DEFAULT_DIR="$PWD"

DEPTH=0
JOBS=-1
LIMIT=-1
OWNER=""
DIR=""

GH_PATH="$(which gh)"
JQ_PATH="$(which jq)"
SCRIPT_NAME="$(basename "$(realpath "$0")")"

echo_usage() {
	local -r SCRIPT_NAME="$1"

	if [[ -z "$SCRIPT_NAME" ]]; then
		echo "* Script name not provided or empty."
		exit 1
	fi

	echo "* Usage $SCRIPT_NAME [args]"
	echo ""
	echo "For a list of available arguments, and usage instructions, run:"
	echo "./$SCRIPT_NAME --help"
}

echo_description() {
	echo "  This script can be useful for quickly cloning a large number of"
	echo "  repositories from GitHub, especially for organizations with a large"
	echo "  number of repositories."
	echo ""
	echo "  It can also be used for backing up all of a user's or organization's"
	echo "  repositories to a local machine."
	echo ""
	echo "  By utilizing parallel jobs, the cloning process can be significantly"
	echo "  faster compared to cloning each echo repository one by one."
}

echo_flags() {
	echo "  === Flags ==="
	echo ""
	echo "  --help: Show this help text"
	echo ""
	echo "  --depth: The depth at which to clone the remote repository. Defaults"
	echo"            to -1, which is the full history. Any other value will limit"
	echo "           the clone to the specified number of commits."
	echo ""
	echo "  --dir:   Sets the directory where the repositories will be cloned."
	echo ""
	echo "  --owner: Sets the username or organization name to clone all"
	echo "           repositories for."
	echo "           This argument is required and must be followed by the desired"
	echo "           username or organization name."
	echo "           Only repositories owned by the specified user or organization"
	echo "           will be echo tloned."
	echo ""
	echo "  --limit: Sets the maximum number of repositories that will be cloned."
	echo "           This argument is optional and must be followed by a numerical"
	echo "           value. If not specified, all repositories owned by the"
	echo "           specified user or organization will be cloned."
	echo ""
	echo "  --jobs: Sets the number of clone processes to run in parallel."
	echo "          This argument is optional and must be followed by a numerical"
	echo "          value. If not specified, the default value of 1 will be used."
	echo "          Increasing the number of jobs can speed up the cloning process,"
	echo "          but may also put more strain on system resources."
	echo "          It is recommended to use a value that is appropriate for your"
	echo "          system's capabilities."
}

echo_examples() {
	local -r SCRIPT_NAME="$1"

	if [[ -z "$SCRIPT_NAME" ]]; then
		echo "Script name not provided or empty."
		exit 1
	fi

	echo "  === Examples ==="
	echo ""
	echo "  - To clone a maximum of 500 repositories owned by the user 'me'"
	echo "    using 16 parallel jobs into the current directory, run:"
	echo "    \$ ./$SCRIPT_NAME --owner me --jobs 16 --limit 500 --dir ."
	echo ""
	echo "  - To clone all repositories owned by the organization microsoft"
	echo "    using 20 parallel jobs and a max of 500 repositories, into the"
	echo "    directory at ./microsoft, you can run:"
	echo "    \$ ./$SCRIPT_NAME --owner microsoft --jobs 20 --limit 500 --dir ./microsoft"
}

echo_help() {
	local -r SCRIPT_NAME="$1"

	if [[ -z "$SCRIPT_NAME" ]]; then
		echo "Script name not provided or empty."
		exit 1
	fi

	echo_usage "$SCRIPT_NAME"
	echo ""
	echo ""
	echo_description
	echo ""
	echo ""
	echo_flags
	echo ""
	echo ""
	echo_examples "$SCRIPT_NAME"
}

if [[ -z "$GH_PATH" ]]; then
	echo "GitHub CLI (gh) not found."
	echo "Install it and try again."
	echo ""
	echo "For installation instructions, visit: https://cli.github.com"
	exit 1
fi

if [[ -z "$JQ_PATH" ]]; then
	echo "JQ not found."
	echo "Install it and try again."
	echo ""
	echo "For installation instructions, visit: https://stedolan.github.io/jq/download/"
	exit 1
fi

if [[ $# -eq 0 ]]; then
	echo "Error: Missing required argument --owner. See --help"
	exit 1
fi

if [[ "$1" == "--help" ]]; then
	echo_help "$SCRIPT_NAME"
	exit 0
fi

for ((i = 1; i <= $#; i++)); do
	case ${!i} in
	--help)
		echo_help "$SCRIPT_NAME"
		exit 0
		;;
	--jobs)
		next_index=$((i + 1))
		JOBS=${!next_index}
		;;
	--limit)
		next_index=$((i + 1))
		LIMIT=${!next_index}
		;;
	--owner)
		next_index=$((i + 1))
		OWNER=${!next_index}
		;;
	--depth)
		next_index=$((i + 1))
		DEPTH=${!next_index}
		;;
	--dir)
		next_index=$((i + 1))
		DIR=${!next_index}
		;;
	esac
done

if [[ "$JOBS" -eq -1 ]]; then
	JOBS=$DEFAULT_JOBS
	echo "- Job count not specified, using default of $DEFAULT_JOBS"
fi

if [[ "$LIMIT" -eq -1 ]]; then
	LIMIT=$DEFAULT_LIMIT
	echo "- Max repo limit not specified, using default of $DEFAULT_LIMIT"
fi

if [[ -z "$DIR" ]]; then
	DIR=$DEFAULT_DIR
	echo "- Directory not specified, using default of $DEFAULT_DIR"
fi

if [[ -n "$LIMIT" ]] && [[ "$LIMIT" -lt 0 ]]; then
	echo "Error: Limit must be a positive number; received '$LIMIT'"
	exit 1
fi

if [[ -n "$JOBS" ]] && [[ "$JOBS" -lt 0 ]]; then
	echo "Error: Number of jobs must be at least 1; received '$JOBS'"
	exit 1
fi

if [[ -n "$DEBTH" ]] && [[ "$DEBTH" -lt 0 ]]; then
	echo "Error: Clone commit depth must be at least 1 if provided."
	echo "       Received '$DEPTH'."
	exit 1
fi

if [[ -z "$OWNER" ]]; then
	echo "Error: Owner not provided. See --help"
	exit 1
fi

if [[ ! -d "$DIR" ]]; then
	echo "Directory $DIR does not exist, creating it..."
	mkdir "$DIR"
fi

echo "Fetching repo list for $OWNER (at most $LIMIT)..."

GH_REPOS_LIST_JSON=$(gh repo list "$OWNER" --json name --limit "$LIMIT")
mapfile -t GH_REPOS_LIST < <(echo "$GH_REPOS_LIST_JSON" | jq -r '.[].name')
GH_REPOS_LIST_COUNT=${#GH_REPOS_LIST[@]}

echo "Found $GH_REPOS_LIST_COUNT repositories."

NEW_GH_REPOS_LIST=()

for GH_REPO in "${GH_REPOS_LIST[@]}"; do
	if [[ ! -d "$DIR/$GH_REPO" ]]; then
		NEW_GH_REPOS_LIST+=("$GH_REPO")
	fi
done

EXISTING_REPO_COUNT=$((${#GH_REPOS_LIST[@]} - ${#NEW_GH_REPOS_LIST[@]}))
NEW_REPO_COUNT=${#NEW_GH_REPOS_LIST[@]}

if [[ $NEW_REPO_COUNT -eq 0 ]]; then
  echo 'All repos are already present.'
  exit 0
fi

echo "Cloning $NEW_REPO_COUNT new repositories to $DIR."
echo "$EXISTING_REPO_COUNT repos are present and will be skipped."
echo "Will use $JOBS clone operations simultaneously."
echo ""
echo '***'
if [[ $DEPTH -ne 0 ]]; then
	GH_CLONE_ARGS="-- --depth=$DEPTH"
	echo "Cloning to a depth of $DEPTH commits."
else
	GH_CLONE_ARGS=""
	echo "Cloning the full history."
fi
echo '***'

CLONE_COUNT=0

for REPO in "${NEW_GH_REPOS_LIST[@]}"
do
  ((CLONE_COUNT++))

  if [[ $DEPTH -gt 0 ]]; then
    echo "- [$CLONE_COUNT] cloning $OWNER/$REPO (depth $DEPTH)..."
    gh repo clone "$OWNER"/"$REPO" -- --depth="$DEPTH" > /dev/null 2>&1
  else
    echo "- [$CLONE_COUNT] cloning $OWNER/$REPO..."
    gh repo clone "$OWNER"/"$REPO" > /dev/null 2>&1
  fi
done
