deprecated module tango.sys.consts.socket;

pragma (msg, "Check tango.sys.consts.socket sources" ~
    " and import of on its modules directly");

public import tango.stdc.posix.sys.socket;
public import core.sys.posix.netinet.in_;
public import core.sys.posix.netinet.tcp;
public import core.sys.posix.netdb;
