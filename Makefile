MAKE = make -s
LINK_CMD = $(MAKE) link SRC=$<
LINK_S_CMD = $(LINK_CMD) DEST=$<
CREATE_DIR = [ -d $$DIR_PATH ] || (mkdir -p $$DIR_PATH && echo 'Created directory')

install:
	@echo '----- START: Create all symbolic link -----'
	@$(MAKE) all
	@echo '-----  END: Created all symbolic link -----'

all: ctags polybar rofi

ctags: .ctags
	@$(LINK_S_CMD)
	@DIR_PATH=$(HOME)/.ctags.d && $(CREATE_DIR)
	@$(LINK_CMD) DEST='.ctags.d/conf.ctags'

polybar: FORCE
	cd polybar && python make-polybar-config.py

polybar-init: FORCE
	curl -L https://github.com/deresmos/polybar-scripts/raw/master/polybar-scripts/pulseaudio-rofi/pulseaudio-rofi.sh -o polybar/pulseaudio-rofi.sh \
		&& chmod a+x polybar/pulseaudio-rofi.sh
	sudo ln -sf $(CURDIR)/polybar/pulseaudio-rofi.sh /usr/local/bin/pulseaudio-rofi
	@$(LINK_CMD) SRC='polybar/uvcvideo.sh' DEST='.config/polybar/uvcvideo.sh'
	@DIR_PATH=$(HOME)/.config/polybar && $(CREATE_DIR)
	sudo ln -sf $(CURDIR)/polybar/polybar-run.sh /usr/local/bin/polybar-run
	cd polybar && python make-polybar-config.py
	@$(LINK_CMD) SRC='polybar/.config' DEST='.config/polybar/config'

rofi: FORCE
	@DIR_PATH=$(HOME)/.config/rofi && $(CREATE_DIR)
	@$(LINK_CMD) SRC='rofi/config' DEST='.config/rofi/config'
	@$(LINK_CMD) SRC='rofi/theme.rasi' DEST='.config/rofi/theme.rasi'

link: FORCE
	@[ -z $(SRC) ] || (SRC_PATH=$(CURDIR)/$(SRC) && \
		DEST_PATH=$(HOME)/$(DEST) && \
		ln -sf $$SRC_PATH $$DEST_PATH && \
		echo 'Created symbolic link:' $$SRC_PATH '==>' $$DEST_PATH)

FORCE:
.PHONY: FORCE
