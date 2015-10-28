
module tango.sys.linux.signalfd;

import tango.stdc.posix.signal: sigset_t;

extern (C):

/* Flags for signalfd.  */
enum: uint
{
    SFD_CLOEXEC = 0x8_0000, // octal 02000000
    SFD_NONBLOCK = 0x800, // octal 04000
}

struct signalfd_siginfo
{
    uint ssi_signo;    /* Signal number */
    int  ssi_errno;    /* Error number (unused) */
    int  ssi_code;     /* Signal code */
    uint ssi_pid;      /* PID of sender */
    uint ssi_uid;      /* Real UID of sender */
    int  ssi_fd;       /* File descriptor (SIGIO) */
    uint ssi_tid;      /* Kernel timer ID (POSIX timers) */
    uint ssi_band;     /* Band event (SIGIO) */
    uint ssi_overrun;  /* POSIX timer overrun count */
    uint ssi_trapno;   /* Trap number that caused signal */
    int  ssi_status;   /* Exit status or signal (SIGCHLD) */
    int  ssi_int;      /* Integer sent by sigqueue(2) */
    ulong ssi_ptr;     /* Pointer sent by sigqueue(2) */
    ulong ssi_utime;   /* User CPU time consumed (SIGCHLD) */
    ulong ssi_stime;   /* System CPU time consumed (SIGCHLD) */
    ulong ssi_addr;    /* Address that generated signal
                          (for hardware-generated signals) */
    ubyte[48] pad;     /* Pad size to 128 bytes (allow for
                          additional fields in the future) */

    static assert(signalfd_siginfo.sizeof == 128);
}

int signalfd ( int fd, sigset_t* mask, int flags );

