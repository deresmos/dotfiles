from subprocess import check_output

command = "cat /proc/cpuinfo | grep MHz | awk '{print $4}'"

cpu_freqs = [
    freq for freq in check_output(command, shell=True).decode().split('\n')
    if freq != ''
]

command = 'cat /proc/cpuinfo | grep "model name" | grep -o ":.*"'
res = check_output(command, shell=True).decode().split('\n')
cpu_info = res[0].split(': ')[1]
print('${alignr}${color2}' + cpu_info)

str = ''
if len(cpu_freqs) > 4:
    cpu_str = '${{goto 30}}${{color2}}Core {1}: ${{color}}{0} Mhz '
    cpu_str += '${{color2}}(${{cpu cpu{1}}}%)${{color}}'
    cpu_str += '${{goto 220}}${{color2}}Core {3}: ${{color}}{2} Mhz '
    cpu_str += '${{color2}}(${{cpu cpu{3}}}%)${{color}}\n'

    graph_str = '${{goto 30}}${{cpugraph cpu{} 17,170 303030 467f77}}'
    graph_str += '${{goto 220}}${{cpugraph cpu{} 17,170 303030 467f77}}\n'
    for i in range(len(cpu_freqs) // 2):
        core_index = (i * 2) + 1
        index = i * 2
        str += cpu_str.format(cpu_freqs[index], core_index,
                              cpu_freqs[index + 1], core_index + 1)
        str += graph_str.format(
            core_index, core_index + 1)
else:
    cpu_str = '${{goto 30}}${{color2}}Core {1}: ${{color}}{0} Mhz '
    cpu_str += '${{color2}}(${{cpu cpu{1}}}%)${{color}}\n'
    graph_str = '${{goto 30}}${{cpugraph cpu{} 17,310 303030 467f77}}\n'
    for i, freq in enumerate(cpu_freqs):
        core_index = i + 1
        str += cpu_str.format(freq, core_index)
        str += graph_str.format(
            core_index)

print(str)
