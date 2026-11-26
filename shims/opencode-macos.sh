#!/bin/sh
# opencode CLI shim.
#
# `deja resume <session-id> --exec` runs `opencode -s <session-id>`, which this
# shim sends to the OpenCode desktop app: it writes a resume request and opens
# (or focuses) the app. The deja-resume GUI plugin in
# ~/.config/opencode/plugin/deja-resume reads the request and opens the
# session's tab. Everything else falls back to the bundled TUI CLI.

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
  if /usr/bin/open -b ai.opencode.desktop >/dev/null 2>&1; then
    return 0
  fi
  rm -f "$dir/deja-resume.json"
  return 1
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

# Fallback: the TUI CLI bundled with the desktop app.
for c in \
  "/Applications/OpenCode.app/Contents/Resources/opencode-cli" \
  "$HOME/Library/Application Support/ai.opencode.desktop/cli/"*/opencode-cli
do
  if [ -x "$c" ]; then
    exec "$c" "$@"
  fi
done

echo "opencode: CLI not found (is the OpenCode desktop app installed?)" >&2
exit 127
