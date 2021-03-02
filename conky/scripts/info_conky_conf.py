# imports {{{1
import os

from .conky_conf_writer import ConkyConfWriter


class InfoConkyConf(ConkyConfWriter):
    def __init__(self):  # {{{2
        super().__init__('info.conf')

    def getConf(self):  # {{{2
        text = '''
            ${voffset -8}$alignr$color${font Bitstream Vera Sans:size=30}${time %Y}$font
            $color${voffset -30}$color${font Bitstream Vera Sans:size=20}${time %m}$font\
            ${voffset -3} $color${font Bitstream Vera Sans:size=22}${time %d}$font$color2$hr
            $alignc$color${font :size=36}${time %H}:${time %M}
            '''

        text += self.h2('INFORMATION')
        text += '''
            ${goto 40}${color2}HDD FREE:$alignr$color${fs_free} / ${fs_size}
            ${goto 40}${color2}HDD:$color$fs_used_perc% ${fs_bar 6}

            ${voffset 10}${goto 40}${color}Swap${font Bitstream Vera Sans:bold:size=8}$alignr${swap}/ ${swapfree}
            ${voffset 15}$font$alignr${execi 10000 awk -F= '/TION/ {print $2}' /etc/lsb-release |sed 's/"//g'} \
            ${execi 10000 awk -F= '/EASE=/ {printf $2" "} /NAME/ {print $2}' /etc/lsb-release}
            ${voffset 10}${color2}${alignr}${execi 1200 whoami}@${nodename}
            ${alignr}${color2}${font Bitstream Vera Sans:size=8}uptime: ${color}${uptime_short}
            ${voffset 5}${color2}${font Bitstream Vera Sans:size=8}${alignr}kernel: ${color}${kernel}
            '''

        text += self.h2('Calendar')
        text += self.conkyEsc('execpi 1800 python {}'.format(
            os.path.join(self._path, 'print_cal.py')))

        return self._getConf(text)

    def getConfig(self):  # {{{2
        return self._getConfig('')


if __name__ == '__main__':  # {{{1
    text = InfoConkyConf()
    print(text.getConf())
