PRE_ECHO = echo '==> $@'
MAKE = make -s
LINK_CMD = $(MAKE) link SRC=$<
LINK_CONFIG = $(MAKE) link-config SRC=$<
CREATE_DIR = [ -d $$DIR_PATH ] || (mkdir -p $$DIR_PATH && echo "Created directory. ( $$DIR_PATH )")

FORCE:
.PHONY: FORCE ctags

install:
	@echo '----- START: Create all symbolic link -----'
	@$(MAKE) common
	@echo '-----  END: Created all symbolic link -----'

common: ctags

linux: common polybar rofi mpv

# ctags
ctags: ctags/.ctags
	@$(PRE_ECHO)
	@$(LINK_CMD) DEST='$(HOME)/.ctags'
	@DIR_PATH=$(HOME)/.ctags.d && $(CREATE_DIR)
	@$(LINK_CMD) DEST='$(HOME)/.ctags.d/conf.ctags'

# polybar
polybar: polybar/pulseaudio-rofi.sh FORCE
	@$(PRE_ECHO)
	@$(LINK_CONFIG) SRC='polybar/uvcvideo.sh'
	@DIR_PATH=$(XDG_CONFIG_HOME)/polybar && $(CREATE_DIR)
	sudo ln -sf $(CURDIR)/polybar/polybar-run.sh /usr/local/bin/polybar-run
	cd polybar && python make-polybar-config.py
	@$(LINK_CONFIG) SRC='polybar/config'

polybar/pulseaudio-rofi.sh:
	curl -L https://github.com/deresmos/polybar-scripts/raw/master/polybar-scripts/pulseaudio-rofi/pulseaudio-rofi.sh -o polybar/pulseaudio-rofi.sh \
		&& chmod a+x polybar/pulseaudio-rofi.sh
	sudo ln -sf $(CURDIR)/polybar/pulseaudio-rofi.sh /usr/local/bin/pulseaudio-rofi

# rofi
rofi: FORCE
	@$(PRE_ECHO)
	@DIR_PATH=$(XDG_CONFIG_HOME)/rofi && $(CREATE_DIR)
	@$(LINK_CONFIG) SRC='rofi/config'
	@$(LINK_CONFIG) SRC='rofi/theme.rasi'

# mpv
mpv: FORCE
	@$(PRE_ECHO)
	@DIR_PATH=$(XDG_CONFIG_HOME)/mpv && $(CREATE_DIR)
	@$(LINK_CONFIG) SRC='mpv/mpv.conf'
	@$(LINK_CONFIG) SRC='mpv/input.conf'

# utils
link: FORCE
	@[ -z $(SRC) ] || (SRC_PATH=$(CURDIR)/$(SRC) && \
		DEST_PATH=$(DEST) && \
		ln -sf $$SRC_PATH $$DEST_PATH && \
		echo 'Created symbolic link:' $$SRC_PATH '==>' $$DEST_PATH)

link-config: FORCE
	make -s link SRC=$(SRC) DEST=$(XDG_CONFIG_HOME)/$(SRC)
