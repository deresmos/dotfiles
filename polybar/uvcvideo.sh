#! /bin/bash

activate_uvcvideo() {
  gksudo -u root 'modprobe uvcvideo'
}

deactivate_uvcvideo() {
  gksudo -u root 'modprobe -r uvcvideo'
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
