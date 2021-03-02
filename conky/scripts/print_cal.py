import calendar
import time
from datetime import date


# set positions
def create_goto(num):
    datas = []
    goto_num = 90
    for _ in range(7):
        datas.append('${{goto {}}}'.format(goto_num))
        goto_num += num

    return datas


def get_calendar():  # {{{1
    localtime = time.localtime(time.time())
    calendar.setfirstweekday(calendar.SUNDAY)
    cal = calendar.month(localtime[0], localtime[1])

    weekday = date(localtime[0], localtime[1], 1).isoweekday()
    weekday %= 7
    lastday = cal.split('\n')[-2].split(' ')[-1]
    weekdays = cal.split('\n')[1].split(' ')

    gotos = create_goto(30)

    str = '${font migu1m:size=16}'
    for i, days in enumerate(weekdays):
        str += '{}{}'.format(gotos[i], days)
    str += '\n'

    # create days
    color = '${color ff00ff}'
    for i in range(1, int(lastday) + 1):
        if i == localtime[2]:
            str += '{}{}{:02}${{color}}'.format(gotos[weekday], color, i)
        else:
            str += '{}{:02}'.format(gotos[weekday], i)

        if weekday == 6:
            str += '\n'

        weekday += 1
        weekday %= 7

    return '${color}' + str


if __name__ == '__main__':  # {{{1

    print(get_calendar())
