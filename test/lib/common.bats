setup() {
  load ../helpers
  common_setup
  . "$REPO/lib/common.sh"
}

@test "stable_versions drops pre-releases" {
  run stable_versions <<<"$(printf '8.5.7\n8.5.11RC1\n8.4.0alpha\n1.2\n8.4.15\n')"
  [ "$output" = "$(printf '8.5.7\n8.4.15')" ]
}

@test "stable_versions succeeds on no matches" {
  run stable_versions <<<"8.5.0RC1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "version_sort is numeric, not lexical" {
  run version_sort <<<"$(printf '8.5.10\n8.5.7\n8.10.0\n8.9.1\n')"
  [ "$output" = "$(printf '8.5.7\n8.5.10\n8.9.1\n8.10.0')" ]
}

@test "version_matches: exact and component prefix only" {
  version_matches 8.5.7 8.5.7
  version_matches 8.5.7 8.5
  version_matches 8.5.7 8
  run ! version_matches 8.5.7 8.5.1
  run ! version_matches 8.50.1 8.5
}

@test "version_minor and version_major" {
  [ "$(version_minor 8.5.7)" = 8.5 ]
  [ "$(version_major 8.5.7)" = 8 ]
}

@test "rewrite_file replaces content and keeps permissions" {
  f="$BATS_TEST_TMPDIR/f"
  printf 'old\n' >"$f"
  chmod 640 "$f"
  rewrite_file "$f" echo new
  [ "$(cat "$f")" = new ]
  [ "$(find "$f" -perm 640)" = "$f" ]
}

@test "rewrite_file leaves the file alone when the command fails" {
  f="$BATS_TEST_TMPDIR/f"
  printf 'keep\n' >"$f"
  run rewrite_file "$f" sh -c 'echo partial; exit 3'
  [ "$status" -ne 0 ]
  [ "$(cat "$f")" = keep ]
}

@test "detect_os maps uname" {
  STUB_UNAME=Darwin run detect_os
  [ "$output" = macos ]
  STUB_UNAME=Linux run detect_os
  [ "$output" = linux ]
  STUB_UNAME=FreeBSD run detect_os
  [ "$status" -ne 0 ]
}

@test "run_privileged runs the command directly as root" {
  STUB_UID=0 run run_privileged echo hi
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '+ echo hi\nhi')" ] || false
  run ! grep -q sudo "$STUB_LOG"
}

@test "run_privileged goes through sudo when not root" {
  STUB_UID=1000 run run_privileged echo hi
  [ "$status" -eq 0 ]
  [[ "$output" == *hi ]] || false
  assert_log "sudo echo hi"
}

@test "run_privileged without root or sudo says so" {
  STUB_UID=1000 PATH="$(isolated_path id)" run run_privileged echo hi
  [ "$status" -ne 0 ]
  [[ "$output" == *"needs root to run: echo hi (run as root, or install sudo)"* ]]
}

@test "os_release_field strips either quote style" {
  export OS_RELEASE="$FIXTURES/os-release-rocky"
  [ "$(os_release_field ID)" = rocky ]
  [ "$(os_release_field VERSION_ID)" = 9.6 ]
  OS_RELEASE="$FIXTURES/os-release-fedora"
  [ "$(os_release_field NAME)" = "Fedora Linux" ]
  [ "$(os_release_field VERSION_CODENAME)" = "" ]
  [ "$(os_release_field NOPE)" = "" ]
}

@test "os_release_field fails clearly without the file" {
  OS_RELEASE="$BATS_TEST_TMPDIR/missing" run os_release_field ID
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot read $BATS_TEST_TMPDIR/missing"* ]]
}

@test "run_privileged traces to stderr, so redirecting stdout keeps the trace" {
  run --separate-stderr run_privileged echo hi
  [ "$status" -eq 0 ]
  [ "$output" = hi ]
  # shellcheck disable=SC2154 # set by run --separate-stderr
  [ "$stderr" = "+ echo hi" ]
}
