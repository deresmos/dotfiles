import os
from abc import abstractmethod


class ConkyConfWriter:
    H1_GOTO = "goto 0"
    H2_GOTO = "goto 20"
    H3_GOTO = "goto 30"

    COLOR = "color"
    COLOR2 = "color2"

    BASE_FONT_SIZE = 9
    H1_FONT_SIZE = "font :size={}".format(int(BASE_FONT_SIZE * 1.6))
    H2_FONT_SIZE = "font :size={}".format(int(BASE_FONT_SIZE * 1.2))
    SMALL_FONT_SIZE = "font :size={}".format(int(BASE_FONT_SIZE * 0.9))

    @abstractmethod
    def getConf(self):
        pass

    def _getConf(self, main_text):
        with open(os.path.join(self.__config_path, "base_setting.conf"), "r") as f:
            conf_str = f.read()

        conf_str += self.getConfig()
        conf_str += main_text + "\n]]\n"

        return conf_str

    @abstractmethod
    def getConfig(self):
        pass

    def _getConfig(self, text):
        return text + "}\n\n" + "conky.text = [[\n\n"

    def __init__(self, conf_filename):
        self.h1_goto = self.conkyEsc(ConkyConfWriter.H1_GOTO)
        self.h2_goto = self.conkyEsc(ConkyConfWriter.H2_GOTO)
        self.h3_goto = self.conkyEsc(ConkyConfWriter.H3_GOTO)

        self.color = self.conkyEsc(ConkyConfWriter.COLOR)
        self.color2 = self.conkyEsc(ConkyConfWriter.COLOR2)

        self.h1_font_size = self.conkyEsc(ConkyConfWriter.H1_FONT_SIZE)
        self.h2_font_size = self.conkyEsc(ConkyConfWriter.H2_FONT_SIZE)
        self.small_font_size = self.conkyEsc(ConkyConfWriter.SMALL_FONT_SIZE)

        path = os.path.dirname(os.path.realpath(__file__))
        self.__config_path = os.path.abspath(os.path.join(path, "../configs"))
        self.__tmp_path = os.path.abspath(os.path.join(path, "../tmp"))
        self._path = path

        self._conf_filename = conf_filename
        self.__save_path = os.path.join(self.__tmp_path, conf_filename)

    def conkyEsc(self, text):
        return "${{{0}}}".format(text)

    def saveConf(self):
        with open(self.__save_path, "w") as f:
            f.write(self.getConf())

    def h1(self, text):
        str = self.h1_goto + self.color + self.h1_font_size
        str += "{}  ".format(text)
        str += self.color2 + self.conkyEsc("hr 4")
        str += self.color + self.conkyEsc("font") + "\n"

        return str

    def h2(self, text):
        str = self.h2_goto + self.color + self.h2_font_size
        str += "{}  ".format(text)
        str += self.color2 + self.conkyEsc("hr 2")
        str += self.color + self.conkyEsc("font") + "\n"

        return str
