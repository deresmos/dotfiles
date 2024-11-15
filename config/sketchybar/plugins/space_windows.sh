#!/bin/bash

if [ "$SENDER" = "front_app_switched" ] || [ "$SENDER" = "space_windows_change" ] || [ "$SENDER" = "yabai_window_focused" ]; then
  current_window=$(yabai -m query --windows --window | jq -rc '. |  [.id,  .app]')
  current_space=$(yabai -m query --windows --window | jq '.space')
  window_apps=$(yabai -m query --windows | jq -rc '. | sort_by(."stack-index", .frame.x) | .[] | select(.space=='$current_space') | [.id,  .app]')

  APPS=()
  while read -r line; do APPS+=("$line"); done <<< "$window_apps"
  LENGTH=${#APPS[@]}
  label=""
  for i in "${!APPS[@]}"; do
    app_name=$(echo ${APPS[i]} | sed -r 's/\[[0-9]+,"(.*)"\]/\1/')
    if [[ -z $app_name ]]; then
      continue
    fi
    if [[ "$current_window" == "${APPS[i]}" ]]; then
      label+="✅ $app_name"
    else 
      label+="☑️ $app_name"
    fi

    if [[ $i < $(($LENGTH-1)) ]]; then
       label+=" | "
     fi
  done

  sketchybar --set $NAME label="$label"
fi
