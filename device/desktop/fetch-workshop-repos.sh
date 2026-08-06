#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE=${CDMX_WORKSPACE:-/var/lib/cdmx-picoclaw/workspace}

update_repo() {
    local name=$1 url=$2 target=$WORKSPACE/$1

    if [[ -d $target/.git ]]; then
        printf '\n==> Updating %s\n' "$name"
        git -C "$target" remote set-url origin "$url"
        git -C "$target" pull --ff-only
    elif [[ -e $target ]]; then
        printf '\nERROR: %s already exists but is not a Git repository.\n' "$target" >&2
        printf 'It was left untouched. Rename it, then run this launcher again.\n' >&2
        return 1
    else
        printf '\n==> Downloading %s\n' "$name"
        git clone "$url" "$target"
    fi
}

mkdir -p "$WORKSPACE"
update_repo cdmx-bayesopt https://github.com/the-matter-lab/cdmx-bayesopt.git
update_repo cdmx-local-ai https://github.com/the-matter-lab/cdmx-local-ai.git

printf '\nReady. Workshop code is in:\n%s\n' "$WORKSPACE"
