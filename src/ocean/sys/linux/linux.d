module ocean.sys.linux.linux;


version (linux) {
    public import ocean.stdc.time;
    public import ocean.stdc.posix.dlfcn;
    public import ocean.stdc.posix.fcntl;
    public import ocean.stdc.posix.poll;
    public import ocean.stdc.posix.pwd;
    public import ocean.stdc.posix.time;
    public import ocean.stdc.posix.unistd;
    public import ocean.stdc.posix.sys.select;
    public import ocean.stdc.posix.sys.stat;
    public import ocean.stdc.posix.sys.types;
    public import ocean.sys.linux.epoll;
}
