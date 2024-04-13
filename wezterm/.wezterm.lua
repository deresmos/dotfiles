local wezterm = require 'wezterm'

return {
  font = wezterm.font_with_fallback {
    'Fira Code',
    'Teminess Nerd Font',
  },
  font_size = 12,
  automatically_reload_config = true,
  warn_about_missing_glyphs = false,
}
