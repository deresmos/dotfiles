#! /bin/bash

activate_uvcvideo() {
  error=$(modprobe -n uvcvideo 2>&1)
  if [[ -z $error ]]; then
    # Success dryrun activate
    gksudo -u root 'modprobe uvcvideo'
    exit 0
  else
    # Fail dryrun activate
    zenity --error --width=200 --text="$error"
  fi
}

deactivate_uvcvideo() {
  error=$(modprobe -n -r uvcvideo 2>&1)
  if [[ -z $error ]]; then
    # Success dryrun deactivate
    gksudo -u root 'modprobe -r uvcvideo'
    exit 0
  else
    # Fail dryrun deactivate
    zenity --error --width=200 --text="$error"
  fi
}

activate_toggle() {
  if $(lsmod | grep uvcvideo > /dev/null 2>&1); then
    # If uvcvideo is active
    deactivate_uvcvideo
  else
    # If uvcvideo is inactive
    activate_uvcvideo
  fi
}

show_status_icon() {
  if $(lsmod | grep uvcvideo > /dev/null 2>&1); then
    # If uvcvideo is active
    echo ""
  else
    # If uvcvideo is inactive
    echo "%{F#777}%{F-}"
  fi
}

case "$1" in
    --activate)
        activate_uvcvideo
    ;;
    --deactivate)
        deactivate_uvcvideo
    ;;
    --toggle)
        activate_toggle
    ;;
    *)
      show_status_icon
    ;;
esac
