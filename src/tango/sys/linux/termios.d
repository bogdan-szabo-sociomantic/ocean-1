module tango.sys.linux.termios;

public import core.sys.linux.termios;
public import core.sys.posix.termios;

import tango.transition;

const B57600    = Octal!("0010001");
