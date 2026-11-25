setup() {
  load ../helpers
  common_setup
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
  git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
  git init -q "$PROJECT_DIR"
  cd "$PROJECT_DIR" || return
  git remote add origin "$BATS_TEST_TMPDIR/origin.git"
  commit
}

commit() { git commit -q --allow-empty -m "change $RANDOM"; }

# tag NAME [MESSAGE]: tags HEAD (annotated when MESSAGE is given) and pushes it.
tag() {
  if [ -n "${2:-}" ]; then git tag -a "$1" -m "$2"; else git tag "$1"; fi
  git push -q origin "$1"
}

on_main() { GITHUB_REF=refs/heads/main GITHUB_SHA="$(git rev-parse HEAD)" run "$REPO/scripts/release.sh"; }
on_tag() { GITHUB_REF="refs/tags/$1" run "$REPO/scripts/release.sh"; }

# created TAG ARGS...: `gh release create` got exactly ARGS for TAG.
created() {
  local tag="$1"
  shift
  [ "$(cat "$STUB_ROOT/releases/$tag")" = "$(printf '%s\n' release create "$tag" "$@")" ] ||
    { echo "gh release create got:"; cat "$STUB_ROOT/releases/$tag"; return 1; }
}

nothing_created() { [ -z "$(ls "$STUB_ROOT/releases" 2>/dev/null)" ]; }

@test "main: no release tag yet publishes nothing" {
  on_main
  [ "$status" -eq 0 ]
  [[ "$output" == *"no vX.Y.Z tag yet; push v0.1.0 to start releasing"* ]] || false
  nothing_created
}

@test "main: publishes the next patch after the highest release tag" {
  tag v0.1.9
  commit
  tag v0.1.10
  tag v0.2.0-rc.1
  tag v0.1.011
  commit
  on_main
  [ "$status" -eq 0 ]
  created v0.1.11 --target "$(git rev-parse HEAD)" --title v0.1.11 --generate-notes --notes-start-tag v0.1.10
}

@test "main: a commit that already has a release tag is skipped" {
  tag v0.1.0
  commit
  tag v0.2.0
  on_main
  [ "$status" -eq 0 ]
  [[ "$output" == *"is already released; nothing to do"* ]] || false
  nothing_created
}

@test "main: a commit older than the latest release is skipped" {
  tag v0.1.0
  commit
  old="$(git rev-parse HEAD)"
  commit
  tag v0.1.1
  GITHUB_REF=refs/heads/main GITHUB_SHA="$old" run "$REPO/scripts/release.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"v0.1.1 is not an ancestor of $old; nothing published"* ]] || false
  nothing_created
}

# labels LABEL...: the PR behind HEAD carries LABELs.
labels() {
  mkdir -p "$STUB_ROOT/labels"
  printf '%s\n' "$@" >"$STUB_ROOT/labels/$(git rev-parse HEAD)"
}

@test "main: a PR labeled breaking gets no patch" {
  tag v0.1.0
  commit
  labels enhancement breaking
  on_main
  [ "$status" -eq 0 ]
  [[ "$output" == *"since v0.1.0 is from a PR labeled breaking; tag a minor or major instead of a patch"* ]] || false
  nothing_created
}

@test "main: a later unlabeled merge still holds back after a breaking one" {
  tag v0.1.0
  commit
  labels breaking
  breaking="$(git rev-parse HEAD)"
  commit
  labels bug
  on_main
  [ "$status" -eq 0 ]
  [[ "$output" == *"$breaking since v0.1.0 is from a PR labeled breaking"* ]] || false
  nothing_created
}

@test "main: other labels still publish a patch" {
  tag v0.1.0
  commit
  labels enhancement
  on_main
  [ "$status" -eq 0 ]
  created v0.1.1 --target "$(git rev-parse HEAD)" --title v0.1.1 --generate-notes --notes-start-tag v0.1.0
}

@test "tag: a new minor leads with the tag message and lists everything since the last minor" {
  tag v0.1.0
  commit
  tag v0.1.1
  commit
  tag v0.1.2
  tag v0.2.0 "$(printf 'Node module, LTS-aware latest\n\nBreaking: FLOOR_LTS is now LTS.')"
  on_tag v0.2.0
  [ "$status" -eq 0 ]
  created v0.2.0 --verify-tag --title v0.2.0 --generate-notes --notes-start-tag v0.1.0 \
    --notes "$(printf 'Node module, LTS-aware latest\n\nBreaking: FLOOR_LTS is now LTS.')"
}

@test "tag: the message survives a checkout that left the tag lightweight" {
  tag v0.1.0 "First release"
  git tag -f v0.1.0 'v0.1.0^{}' >/dev/null
  on_tag v0.1.0
  [ "$status" -eq 0 ]
  created v0.1.0 --verify-tag --title v0.1.0 --generate-notes --notes "First release"
}

@test "tag: a new major starts from the previous minor" {
  tag v0.3.0
  commit
  tag v0.3.4
  tag v1.0.0
  on_tag v1.0.0
  [ "$status" -eq 0 ]
  created v1.0.0 --verify-tag --title v1.0.0 --generate-notes --notes-start-tag v0.3.0
}

@test "tag: the first release and a hand-pushed patch use GitHub's defaults" {
  tag v0.1.0
  on_tag v0.1.0
  [ "$status" -eq 0 ]
  created v0.1.0 --verify-tag --title v0.1.0 --generate-notes
  commit
  tag v0.1.1
  on_tag v0.1.1
  [ "$status" -eq 0 ]
  created v0.1.1 --verify-tag --title v0.1.1 --generate-notes
}

@test "tag: an already published release is left alone" {
  tag v0.1.0
  on_tag v0.1.0
  on_tag v0.1.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"v0.1.0 is already released; nothing to do"* ]] || false
  [ "$(grep -c 'release create' "$STUB_LOG")" -eq 1 ]
}

@test "tag: a tag that isn't vX.Y.Z is refused" {
  tag v0.2.0-rc.1
  on_tag v0.2.0-rc.1
  [ "$status" -ne 0 ]
  [[ "$output" == *"v0.2.0-rc.1 is not a vX.Y.Z tag"* ]] || false
  nothing_created
}
