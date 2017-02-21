#!/usr/bin/python2

import sys

FILENAME = sys.argv[1]
REPLACEWITH = "fixup"
MASK = "old"

position = 0

if FILENAME:
    _output = []
    _file = open(FILENAME, "r")
    for _line in _file.readlines():
        if MASK in _line[-(len(MASK)+1):]:
            position += 1
            if position > 1:
                _line = _line.replace("pick", REPLACEWITH)
        _output.append(_line)
    _file.close()
    open(FILENAME, "w").writelines(_output)
    sys.exit(0)
else:
    sys.exit(1)
