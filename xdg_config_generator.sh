#! /bin/bash

makefile="xdg_config.mk"

echo -n > $makefile

find config/** -type d -maxdepth 1 | while read -r dir; do
  config_name=$(echo "$dir" | sed -r 's/^config\/(.*)$/\1/')
  config_files=$(find "$dir" -type f | sed -r "s/config\/(.*)/	@\$(LINK_CMD) SRC='config\/\1' DEST='\$(XDG_CONFIG_HOME)\/\1'/g")
  cat <<EOF >> $makefile
# $config_name
.PHONY: $config_name
$config_name: | \$(XDG_CONFIG_HOME)/$config_name
$config_files

\$(XDG_CONFIG_HOME)/$config_name:
	@\$(CREATE_TARGET_DIR)

EOF
done
