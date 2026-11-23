# shellcheck shell=bash
# apk backend (Alpine): nodejs (LTS) or nodejs-current; they conflict, so one
# major at a time, newest release only. npm is separate. --no-cache fetches the index.

backend_available() { command -v apk >/dev/null 2>&1; }
backend_granularity() { echo major; }

# "package major" from lines like nodejs-current-23.11.1-r0.
_apk_nodes() {
  apk --no-cache search -x nodejs nodejs-current |
    awk '{ n = $0; sub(/-[0-9].*/, "", n); v = substr($0, length(n) + 2); split(v, p, "."); print n, p[1] }'
}

backend_versions() { _apk_nodes | cut -d' ' -f2 | sort -u; }

backend_install() {
  local major pkg
  major="$(version_major "$1")"
  need_minor "$major"
  pkg="$(awk -v m="$major" '$2 == m { print $1; exit }' <<<"$(_apk_nodes)")"
  run_privileged apk --no-cache add "$pkg" npm
  # Adding one leaves the other in world and installed, so drop it to switch. World,
  # not `apk info -e`, which counts nodejs-current as nodejs. APK_WORLD is a test seam.
  local other world
  world="$(cat "${APK_WORLD:-/etc/apk/world}" 2>/dev/null || true)"
  for other in nodejs nodejs-current; do
    if [ "$other" != "$pkg" ] && grep -Fxq "$other" <<<"$world"; then run_privileged apk --no-cache del "$other"; fi
  done
}

backend_exec() {
  shift
  exec_bin node "$@"
}
