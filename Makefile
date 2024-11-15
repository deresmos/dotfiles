MAKE = make -s
LINK_CMD = $(MAKE) link SRC=$<
LINK_CONFIG = $(MAKE) link-config SRC=$<
CREATE_DIR = [ -d $$DIR_PATH ] || (mkdir -p $$DIR_PATH && echo "Created directory. ( $$DIR_PATH )")
CREATE_TARGET_DIR = [ -d $@ ] || (mkdir -p $@ && echo "Created directory. ( $@ )")

include ./xdg_config.mk

common: ctags ranger zsh mise wezterm

linux: common polybar rofi mpv feh sxiv i3 urxvt

mac: common yabai skhd sketchybar

# ctags
.PHONY: ctags
ctags: $(HOME)/.ctags $(HOME)/.ctags.d/conf.ctags

$(HOME)/.ctags:
	@$(LINK_CMD) SRC='ctags/.ctags' DEST='$(HOME)/.ctags'

$(HOME)/.ctags.d/conf.ctags: | $(HOME)/.ctags.d
	@$(LINK_CMD) SRC='ctags/.ctags' DEST='$(HOME)/.ctags.d/conf.ctags'

$(HOME)/.ctags.d:
	@$(CREATE_TARGET_DIR)

# polybar
.PHONY: polybar
polybar: /usr/local/bin/polybar-run $(XDG_CONFIG_HOME)/polybar/config polybar/config
polybar: /usr/local/bin/pulseaudio-rofi $(XDG_CONFIG_HOME)/polybar/uvcvideo.sh

polybar/config:

polybar/pulseaudio-rofi.sh:
	curl -L https://github.com/deresmos/polybar-scripts/raw/master/polybar-scripts/pulseaudio-rofi/pulseaudio-rofi.sh -o polybar/pulseaudio-rofi.sh \
		&& chmod a+x polybar/pulseaudio-rofi.sh

/usr/local/bin/pulseaudio-rofi: polybar/pulseaudio-rofi.sh
	sudo ln -sf $(CURDIR)/polybar/pulseaudio-rofi.sh /usr/local/bin/pulseaudio-rofi

/usr/local/bin/polybar-run:
	sudo ln -sf $(CURDIR)/polybar/polybar-run.sh /usr/local/bin/polybar-run

$(XDG_CONFIG_HOME)/polybar/uvcvideo.sh: | $(XDG_CONFIG_HOME)/polybar
	@$(LINK_CONFIG) SRC='polybar/uvcvideo.sh'

$(XDG_CONFIG_HOME)/polybar/config: polybar/config | $(XDG_CONFIG_HOME)/polybar
	@$(LINK_CONFIG) SRC='polybar/config'

polybar/config: polybar/make-polybar-config.py
	cd polybar && python make-polybar-config.py

$(XDG_CONFIG_HOME)/polybar:
	@$(CREATE_TARGET_DIR)

# feh
.PHONY: feh
feh: $(XDG_CONFIG_HOME)/feh/keys

$(XDG_CONFIG_HOME)/feh/keys: | $(XDG_CONFIG_HOME)/feh
	@$(LINK_CONFIG) SRC='feh/keys'

$(XDG_CONFIG_HOME)/feh:
	@$(CREATE_TARGET_DIR)

# sxiv
.PHONY: sxiv
sxiv: $(XDG_CONFIG_HOME)/sxiv/exec/key-handler $(XDG_CONFIG_HOME)/sxiv/exec/image-info
sxiv: /usr/local/bin/sxiv-target

$(XDG_CONFIG_HOME)/sxiv/exec/key-handler: sxiv/exec/key-handler | $(XDG_CONFIG_HOME)/sxiv/exec
	@$(LINK_CONFIG)

$(XDG_CONFIG_HOME)/sxiv/exec/image-info: sxiv/exec/image-info | $(XDG_CONFIG_HOME)/sxiv/exec
	@$(LINK_CONFIG)

/usr/local/bin/sxiv-target: sxiv/sxiv-target.sh
	sudo ln -sf $(CURDIR)/sxiv/sxiv-target.sh $@

$(XDG_CONFIG_HOME)/sxiv/exec:
	@$(CREATE_TARGET_DIR)

/usr/local/bin/sxiv: | sxiv-code
	cd sxiv-code && make && sudo make install

sxiv-code:
	git clone https://github.com/deresmos/sxiv sxiv-code

clean:
	sudo rm /usr/local/bin/sxiv
	rm -rf sxiv-code

# zsh
.PHONY: zsh
zsh: $(HOME)/.zshrc

$(HOME)/.zshrc:
	@$(LINK_CMD) SRC='zsh/.zshrc' DEST='$(HOME)/.zshrc'

# i3
.PHONY: i3
i3: $(HOME)/.i3/config

$(HOME)/.i3/config: i3/config | $(HOME)/.i3
	@$(LINK_CMD) SRC='i3/config' DEST='$(HOME)/.i3/config'

$(HOME)/.i3:
	@$(CREATE_TARGET_DIR)

# urxvt
.PHONY: urxvt
urxvt: $(HOME)/.Xresources

$(HOME)/.Xresources: urxvt/.Xresources
	@$(LINK_CMD) SRC='urxvt/.Xresources' DEST='$(HOME)/.Xresources'

# utils
link: FORCE
	@[ -z $(SRC) ] || (SRC_PATH=$(CURDIR)/$(SRC) && \
		DEST_PATH=$(DEST) && \
		ln -sf $$SRC_PATH $$DEST_PATH && \
		echo 'Created symbolic link:' $$SRC_PATH '==>' $$DEST_PATH)

link-config: FORCE
	make -s link SRC=$(SRC) DEST=$(XDG_CONFIG_HOME)/$(SRC)

# wezterm
.PHONY: wezterm
wezterm:
	@$(LINK_CMD) SRC='wezterm/.wezterm.lua' DEST='$(HOME)/.wezterm.lua'

FORCE:
.PHONY: FORCE clean
