#!/bin/sh
# Regenerates the README screenshots in a new Alacritty window, using your shell and Neovim config.
# Run from the repo root. The terminal running this script needs Screen Recording permission.
cd "$(dirname "$0")/../.." || exit 1
ALACRITTY="$(command -v alacritty || echo /Applications/Alacritty.app/Contents/MacOS/alacritty)"
shoot() {
  "$ALACRITTY" --title NtermDemo --working-directory "$PWD" \
  -o window.dynamic_title=false -o window.dimensions.columns=140 -o window.dimensions.lines=38 \
  -e nvim -c "luafile assets/capture/demo.lua"
}
shoot                         # floating layout
NTERM_POSITION=bottom shoot   # docked layout
