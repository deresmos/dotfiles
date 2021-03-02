import os
from subprocess import Popen


class StartConky:
    def __init__(self, conf_names):
        path = os.path.dirname(os.path.realpath(__file__))
        path = os.path.abspath(os.path.join(path, ".."))
        self.conf_dir = os.path.join(path, "configs")
        self.script_dir = os.path.join(path, "scripts")
        self.save_dir = os.path.join(path, "tmp")

        self.save_paths = [os.path.join(self.save_dir, name) for name in conf_names]
        self.configs = [
            os.path.join(self.conf_dir, name + ".conf") for name in conf_names
        ]

    def execute(self):
        for config in self.save_paths:
            str = "conky -c {}".format(config)
            Popen(["conky", "-c", config])
            print(str)
