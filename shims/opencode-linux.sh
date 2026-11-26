#!/bin/sh
# opencode CLI shim (Linux).
#
# `deja resume <session-id> --exec` runs `opencode -s <session-id>`, which this
# shim sends to the OpenCode desktop app: it writes a resume request and, when
# the app is not running, starts it. The deja-resume GUI plugin in
# ~/.config/opencode/plugin/deja-resume reads the request and opens the
# session's tab. Everything else falls back to the normal CLI.

is_ses_id() {
  case "$1" in
    ses_*) return 0 ;;
    *) return 1 ;;
  esac
}

resume_desktop() {
  sid="$1"
  dir="${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
  mkdir -p "$dir" 2>/dev/null
  now=$(( $(date +%s) * 1000 ))
  tmp="$dir/deja-resume.json.tmp"
  printf '{"session":"%s","time":%s}\n' "$sid" "$now" > "$tmp" && mv "$tmp" "$dir/deja-resume.json"

  # If the app is already running, the plugin's main process picks up the
  # request and focuses the window itself. Only start it when it is absent.
  if ! pgrep -f "electron.*opencode-desktop" >/dev/null 2>&1; then
    if command -v opencode-desktop >/dev/null 2>&1; then
      setsid -f opencode-desktop >/dev/null 2>&1
    elif [ -x /usr/bin/opencode-desktop ]; then
      setsid -f /usr/bin/opencode-desktop >/dev/null 2>&1
    else
      rm -f "$dir/deja-resume.json"
      return 1
    fi
  fi
  return 0
}

if [ $# -gt 0 ]; then
  case "$1" in
    -s|--session)
      if [ $# -ge 2 ] && is_ses_id "$2"; then
        resume_desktop "$2" && exit 0
      fi
      ;;
    -s=*|--session=*)
      sid="${1#*=}"
      if is_ses_id "$sid"; then
        resume_desktop "$sid" && exit 0
      fi
      ;;
    ses_*)
      resume_desktop "$1" && exit 0
      ;;
  esac
fi

# Fallback: the normal CLI (mise resolves the user's chosen version).
for c in \
  "$HOME/.local/share/mise/shims/opencode" \
  "/usr/lib/opencode-desktop/opencode-cli"
do
  if [ -x "$c" ]; then
    exec "$c" "$@"
  fi
done

echo "opencode: CLI not found" >&2
exit 127
