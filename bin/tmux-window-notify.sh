#!/bin/bash

# Check if running in tmux and get window name
if [ -n "$TMUX" ]; then
  CONTEXT=$(tmux display-message -p -t "$TMUX_PANE" '#W')
  LABEL="TMUX Window"
else
  CONTEXT="$CLAUDE_PROJECT_DIR"
  LABEL="Dir"
fi

terminal-notifier -title "$1" -message "$2"$'\n\n'"$LABEL: $CONTEXT"
