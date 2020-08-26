import sys
from configparser import ConfigParser
from pathlib import Path


def net_interface_state_gen():
    for path in Path('/sys/class/net').iterdir():
        path = path / 'operstate'
        with open(path, 'r', encoding='utf-8') as f:
            yield path.parent.name, f.read().strip()


def net_interface_uevent_gen():
    for path in Path('/sys/class/net').iterdir():
        path = path / 'uevent'
        with open(path, 'r', encoding='utf-8') as f:
            if path.parent.name == 'lo':
                continue
            yield path.parent.name, f.read()


def get_up_interface():
    for interface, state in net_interface_state_gen():
        if 'up' == state:
            return interface


def get_wlan_interface():
    for interface, uevent in net_interface_uevent_gen():
        if 'DEVTYPE=wlan' in uevent:
            return interface

    return ''


def get_eth_interface():
    for interface, uevent in net_interface_uevent_gen():
        if 'DEVTYPE=wlan' not in uevent:
            return interface

    return ''


if __name__ == '__main__':
    if not Path('/sys/class/net').exists():
        sys.exit(1)

    config = ConfigParser()
    path = './config'
    config.read_file(open(path, 'r', encoding='utf-8'))
    config['var']['eth-interface'] = get_eth_interface()
    config['var']['wlan-interface'] = get_wlan_interface()
    config['var']['net-interface'] = get_up_interface()

    with open('.config', 'w', encoding='utf-8') as f:
        config.write(f)
