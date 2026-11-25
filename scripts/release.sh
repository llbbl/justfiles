#!/usr/bin/env bash
# Publishes a GitHub release from CI: the next patch after a push to main, or
# the vX.Y.Z tag a maintainer pushed. Run from the checkout; needs gh and GH_TOKEN.
set -euo pipefail

# No leading zeros: bash arithmetic would read 08 as octal.
SEMVER_RE='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

die() {
  echo "release: $*" >&2
  exit 1
}

# Release tags (strict vX.Y.Z, optionally only those matching GLOB), oldest first.
release_tags() {
  local tags
  tags="$(git tag -l "${1:-v*}" --sort=v:refname)"
  grep -E "$SEMVER_RE" <<<"$tags" || true
}

publish_patch() {
  local sha="$1" latest here rc labels c major minor patch next
  latest="$(release_tags | tail -n 1)"
  if [ -z "$latest" ]; then
    echo "::notice::no vX.Y.Z tag yet; push v0.1.0 to start releasing"
    return 0
  fi
  here="$(git tag --points-at "$sha")"
  if [ -n "$(grep -E "$SEMVER_RE" <<<"$here" || true)" ]; then
    echo "$sha is already released; nothing to do"
    return 0
  fi
  # A re-run of an older run must not put a newer version on older code.
  rc=0
  git merge-base --is-ancestor "$latest" "$sha" || rc=$?
  if [ "$rc" -eq 1 ]; then
    echo "::warning::$latest is not an ancestor of $sha; nothing published"
    return 0
  fi
  [ "$rc" -eq 0 ] || die "git merge-base failed for $latest and $sha"
  # Any breaking merge since the last release holds patches back until a minor
  # or major is tagged, not just one on this commit.
  for c in $(git rev-list --first-parent "$latest..$sha"); do
    labels="$(gh api "repos/{owner}/{repo}/commits/$c/pulls" --jq '.[].labels[].name')"
    if grep -Fxq breaking <<<"$labels"; then
      echo "::notice::$c since $latest is from a PR labeled breaking; tag a minor or major instead of a patch"
      return 0
    fi
  done
  IFS=. read -r major minor patch <<<"${latest#v}"
  next="v$major.$minor.$((patch + 1))"
  gh release create "$next" --target "$sha" --title "$next" --generate-notes --notes-start-tag "$latest"
}

publish_tag() {
  local tag="$1" prev="" msg args=()
  [[ $tag =~ $SEMVER_RE ]] || die "$tag is not a vX.Y.Z tag"
  if gh release view "$tag" >/dev/null 2>&1; then
    echo "$tag is already released; nothing to do"
    return 0
  fi
  # actions/checkout can leave an annotated tag lightweight, dropping its message.
  git fetch --force origin "refs/tags/$tag:refs/tags/$tag"
  # Every merge already got a patch release, so a new minor or major lists
  # everything since the previous X.Y.0 instead of since the last patch.
  if [[ $tag =~ \.0$ ]]; then
    prev="$(release_tags 'v*.0' | awk -v t="$tag" '$0 == t { found = p } { p = $0 } END { print found }')"
  fi
  [ -z "$prev" ] || args+=(--notes-start-tag "$prev")
  if [ "$(git cat-file -t "$tag")" = tag ]; then
    msg="$(git tag -l --format='%(contents:subject)%0a%0a%(contents:body)' "$tag")"
    [ -z "$msg" ] || args+=(--notes "$msg")
  fi
  gh release create "$tag" --verify-tag --title "$tag" --generate-notes ${args[@]+"${args[@]}"}
}

case "${GITHUB_REF:?}" in
  refs/tags/*) publish_tag "${GITHUB_REF#refs/tags/}" ;;
  refs/heads/*) publish_patch "${GITHUB_SHA:?}" ;;
  *) die "unexpected ref $GITHUB_REF" ;;
esac
