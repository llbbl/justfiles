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
