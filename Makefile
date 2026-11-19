MAKE = make -s
LINK_CMD = $(MAKE) link SRC=$<
LINK_CONFIG = $(MAKE) link-config SRC=$<
CREATE_DIR = [ -d $$DIR_PATH ] || (mkdir -p $$DIR_PATH && echo "Created directory. ( $$DIR_PATH )")
CREATE_TARGET_DIR = [ -d $@ ] || (mkdir -p $@ && echo "Created directory. ( $@ )")

include ./xdg_config.mk

common: ctags ranger zsh mise wezterm scripts

linux: common polybar rofi mpv feh sxiv i3 urxvt

mac: common cmux ghostty yabai skhd sketchybar claude codex

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

# scripts
.PHONY: scripts
scripts: | $(HOME)/.local/bin
	@chmod a+x $(CURDIR)/scripts/agent-with-worktree.sh
	@$(LINK_CMD) SRC='scripts/agent-with-worktree.sh' DEST='$(HOME)/.local/bin/agent-with-worktree'

# skills
.PHONY: skills
skills:
	@chmod a+x $(CURDIR)/agents/link_skills.sh
	@$(CURDIR)/agents/link_skills.sh

# agents (claude / codex 共通: skills・通知スクリプト・settings)
# settings は agents/settings/*.yaml を ~/.claude/settings.json と ~/.codex/ へ追記する (既存値は変更しない)
.PHONY: agents
agents: skills | $(HOME)/.claude $(HOME)/.codex
	@chmod a+x $(CURDIR)/agents/notify.sh $(CURDIR)/agents/agent_settings.py
	@$(LINK_CMD) SRC='agents/notify.sh' DEST='$(HOME)/.claude/hooks.sh'
	@$(LINK_CMD) SRC='agents/notify.sh' DEST='$(HOME)/.codex/notify.sh'
	@for f in $(HOME)/.claude/settings.json $(HOME)/.codex/config.toml $(HOME)/.codex/hooks.json; do \
		[ -L $$f ] && rm $$f; true; done
	@$(CURDIR)/agents/agent_settings.py -s user -y

.PHONY: agents-diff
agents-diff:
	@$(CURDIR)/agents/agent_settings.py -s user -n
	@echo "== YAML に無い ~/.claude/settings.json の設定 =="
	@$(CURDIR)/agents/agent_settings.py -s user -x

# claude
.PHONY: claude
claude: agents | $(HOME)/.claude/hooks
	@$(LINK_CMD) SRC='agents/claude/statusline.sh' DEST='$(HOME)/.claude/statusline.sh'
	@chmod a+x $(CURDIR)/agents/claude/hooks/sandbox-chain-detector.py
	@$(LINK_CMD) SRC='agents/claude/hooks/sandbox-chain-detector.py' DEST='$(HOME)/.claude/hooks/sandbox-chain-detector.py'

$(HOME)/.claude $(HOME)/.claude/hooks:
	@$(CREATE_TARGET_DIR)

# codex
.PHONY: codex
codex: agents
	@chmod a+x $(CURDIR)/agents/codex/cmux-codex-hook.sh
	@$(LINK_CMD) SRC='agents/codex/cmux-codex-hook.sh' DEST='$(HOME)/.codex/cmux-codex-hook.sh'

$(HOME)/.codex $(HOME)/.local/bin:
	@$(CREATE_TARGET_DIR)

FORCE:
.PHONY: FORCE clean
