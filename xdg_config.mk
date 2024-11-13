# mise
.PHONY: mise
mise: | $(XDG_CONFIG_HOME)/mise
	@$(LINK_CMD) SRC='config/mise/config.toml' DEST='$(XDG_CONFIG_HOME)/mise/config.toml'

$(XDG_CONFIG_HOME)/mise:
	@$(CREATE_TARGET_DIR)

# mpv
.PHONY: mpv
mpv: | $(XDG_CONFIG_HOME)/mpv
	@$(LINK_CMD) SRC='config/mpv/mpv.conf' DEST='$(XDG_CONFIG_HOME)/mpv/mpv.conf'
	@$(LINK_CMD) SRC='config/mpv/input.conf' DEST='$(XDG_CONFIG_HOME)/mpv/input.conf'

$(XDG_CONFIG_HOME)/mpv:
	@$(CREATE_TARGET_DIR)

# ranger
.PHONY: ranger
ranger: | $(XDG_CONFIG_HOME)/ranger
	@$(LINK_CMD) SRC='config/ranger/scope.sh' DEST='$(XDG_CONFIG_HOME)/ranger/scope.sh'
	@$(LINK_CMD) SRC='config/ranger/rc.conf' DEST='$(XDG_CONFIG_HOME)/ranger/rc.conf'
	@$(LINK_CMD) SRC='config/ranger/commands.py' DEST='$(XDG_CONFIG_HOME)/ranger/commands.py'
	@$(LINK_CMD) SRC='config/ranger/rifle.conf' DEST='$(XDG_CONFIG_HOME)/ranger/rifle.conf'

$(XDG_CONFIG_HOME)/ranger:
	@$(CREATE_TARGET_DIR)

# rofi
.PHONY: rofi
rofi: | $(XDG_CONFIG_HOME)/rofi
	@$(LINK_CMD) SRC='config/rofi/config' DEST='$(XDG_CONFIG_HOME)/rofi/config'
	@$(LINK_CMD) SRC='config/rofi/theme.rasi' DEST='$(XDG_CONFIG_HOME)/rofi/theme.rasi'

$(XDG_CONFIG_HOME)/rofi:
	@$(CREATE_TARGET_DIR)

# skhd
.PHONY: skhd
skhd: | $(XDG_CONFIG_HOME)/skhd
	@$(LINK_CMD) SRC='config/skhd/skhdrc' DEST='$(XDG_CONFIG_HOME)/skhd/skhdrc'

$(XDG_CONFIG_HOME)/skhd:
	@$(CREATE_TARGET_DIR)

# yabai
.PHONY: yabai
yabai: | $(XDG_CONFIG_HOME)/yabai
	@$(LINK_CMD) SRC='config/yabai/yabairc' DEST='$(XDG_CONFIG_HOME)/yabai/yabairc'

$(XDG_CONFIG_HOME)/yabai:
	@$(CREATE_TARGET_DIR)

