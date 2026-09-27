# Update flake inputs to the revision their branch pointed at N days ago,
# not to its tip, so a compromised release has N days to be noticed and
# reverted before it reaches these machines.
#
#   nix-update-lagged                  # 3 days: nixpkgs, home-manager, nix-darwin
#   nix-update-lagged 7                # 7 days
#   nix-update-lagged 3 home-manager   # only the inputs named
#
# Writes flake.lock only. Then `nix-rebuild`, and commit flake.lock: every
# host shares it. Never follow this with `nix flake update` or
# `nh os switch --update`, which jump straight back to the tip.
#
# The revision comes from GitHub's push history for the branch (the
# repository activity API), not from commit dates. For nixpkgs-unstable
# every push is a revision Hydra has built, so it is already cached.
# Commit dates run hours behind the push that published them, so
# filtering on them would lag less than asked.
#
# The default inputs are nixpkgs and the two that track nixpkgs-unstable
# and should move with it. An input already locked to something newer
# than the cutoff (say after a plain `nix flake update`) is left alone
# rather than moved backwards.

# writeShellApplication sets errexit, but bash does not carry it into
# $(...) without this, so a failed API call inside one was ignored and
# its empty result misread as "no push history".
shopt -s inherit_errexit

days="${1:-3}"
if ! [[ $days =~ ^[0-9]+$ ]]; then
  echo "usage: nix-update-lagged [days] [input...]   (default: 3 nixpkgs home-manager nix-darwin)" >&2
  exit 2
fi
shift || true
if (($# > 0)); then
  inputs=("$@")
else
  inputs=(nixpkgs home-manager nix-darwin)
fi

flake="${NH_FLAKE:?NH_FLAKE is not set (apps-nh sets it to the repo)}"
lock="$flake/flake.lock"
cutoff="$(date -u -d "$days days ago" +%FT%TZ)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Without a token GitHub allows 60 API requests an hour per IP address,
# shared by every machine behind the router. A run makes about five, so
# this is only a fallback, but a token (from $GITHUB_TOKEN, or gh when it
# is logged in) raises it to 5000. The header goes through a file in the
# private temp dir so the token never shows in the process list.
token="${GITHUB_TOKEN:-}"
if [[ -z $token ]] && command -v gh >/dev/null 2>&1; then
  token="$(gh auth token 2>/dev/null || true)"
fi
auth=()
if [[ -n $token ]]; then
  printf 'Authorization: Bearer %s\n' "$token" >"$tmp/auth"
  auth=(-H "@$tmp/auth")
fi

api() {
  if ! curl -fsSL -D "$tmp/headers" "${auth[@]}" \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "$1"; then
    echo "GitHub API request failed: $1" >&2
    if ((${#auth[@]} == 0)); then
      echo "(no token: the limit is 60 requests an hour; set GITHUB_TOKEN or run 'gh auth login')" >&2
    fi
    return 1
  fi
}

# Every push to refs/heads/$2 of $1, newest first, paging back (100 a page,
# at most 10 pages) until the history reaches the cutoff. Prints one JSON
# array.
pushes() {
  local url="https://api.github.com/repos/$1/activity?ref=refs/heads/$2&per_page=100"
  local n=0
  : >"$tmp/pushes"
  while [[ -n $url ]] && ((n < 10)); do
    api "$url" >"$tmp/page" || return 1
    jq -c '.[] | select(.activity_type != "branch_deletion")' "$tmp/page" >>"$tmp/pushes"
    n=$((n + 1))
    if jq -e -s --arg c "$cutoff" 'any(.[]; .timestamp <= $c)' "$tmp/pushes" >/dev/null; then
      break
    fi
    url="$(grep -i '^link:' "$tmp/headers" | grep -o '<[^>]*>; rel="next"' | sed 's/^<\(.*\)>.*/\1/' || true)"
  done
  jq -s . "$tmp/pushes"
}

overrides=()
for name in "${inputs[@]}"; do
  node="$(jq -r --arg n "$name" '.nodes.root.inputs[$n] // empty | strings' "$lock")"
  if [[ -z $node ]]; then
    echo "$name: not a direct input in flake.lock" >&2
    exit 1
  fi

  IFS=$'\t' read -r type owner repo ref pinned current < <(
    jq -r --arg k "$node" '.nodes[$k] | [
      .original.type, (.original.owner // "-"), (.original.repo // "-"),
      (.original.ref // "-"), (.original.rev // "-"), (.locked.rev // "-")
    ] | @tsv' "$lock"
  )
  if [[ $type != github ]]; then
    echo "$name: only GitHub inputs are supported (this one is $type)" >&2
    exit 1
  fi
  if [[ $pinned != - ]]; then
    echo "$name: pinned to a revision in flake.nix, skipping"
    continue
  fi
  if [[ $ref == - ]]; then
    ref="$(api "https://api.github.com/repos/$owner/$repo" | jq -r .default_branch)"
  fi

  history="$(pushes "$owner/$repo" "$ref")"
  if [[ $history == "[]" ]]; then
    echo "$name: $ref has no push history, so it is a tag, not a branch; skipping"
    continue
  fi
  when="" rev=""
  read -r when rev < <(
    jq -r --arg c "$cutoff" '[.[] | select(.timestamp <= $c)][0] // empty | "\(.timestamp) \(.after)"' <<<"$history"
  ) || true
  if [[ ! $rev =~ ^[0-9a-f]{40}$ ]]; then
    echo "$name: no push to $owner/$repo $ref found at or before $cutoff" >&2
    exit 1
  fi

  if [[ $current == "$rev" ]]; then
    echo "$name: already at $ref ${rev:0:12} (pushed $when)"
    continue
  fi
  current_when="$(jq -r --arg r "$current" '[.[] | select(.after == $r)][0].timestamp // empty' <<<"$history")"
  if [[ -n $current_when && $current_when > $when ]]; then
    echo "$name: locked ${current:0:12} was pushed $current_when, after the cutoff; not moving it back"
    continue
  fi

  echo "$name: $ref ${current:0:12} -> ${rev:0:12} (pushed $when)"
  overrides+=(--override-input "$name" "github:$owner/$repo/$rev")
done

if ((${#overrides[@]} == 0)); then
  echo "Nothing to update (cutoff $cutoff)."
  exit 0
fi

nix flake lock "$flake" "${overrides[@]}"
echo
echo "flake.lock updated to revisions pushed on or before $cutoff."
echo "Next: nix-rebuild, then commit flake.lock (every host shares it)."
