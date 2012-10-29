/*******************************************************************************

    Linux signal file descriptor event.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        December 2011: Initial release

    authors:        Gavin Norman

    signalfd man page follows:

    signalfd() creates a file descriptor that can be used to accept signals
    targeted at the caller.  This provides an alternative to the use of a signal
    handler or sigwaitinfo(2), and has the advantage that the file descriptor may
    be monitored by select(2), poll(2), and epoll(7).
 
    The mask argument specifies the set of signals that the caller wishes to
    accept via the file descriptor.  This argument is a signal set whose contents
    can be initialized using the macros described in sigsetops(3).  Normally, the
    set of signals to be received via the file descriptor should be blocked using
    sigprocmask(2), to prevent the signals being handled according to their
    default dispositions.  It is not possible to receive SIGKILL or SIGSTOP
    signals via a signalfd file descriptor; these signals are silently ignored if
    specified in mask.
 
    If the fd argument is -1, then the call creates a new file descriptor and
    associates the signal set specified in mask with that descriptor.  If fd is
    not -1, then it must specify a valid existing signalfd file descriptor, and
    mask is used to replace the signal set associated with that descriptor.
 
    Starting with Linux 2.6.27, the following values may be bitwise ORed in flags
    to change the behaviour of signalfd():
 
    SFD_NONBLOCK  Set the O_NONBLOCK file status flag on the new open file
                  description.  Using this flag saves extra calls to fcntl(2) to
                  achieve the same result.
 
    SFD_CLOEXEC   Set the close-on-exec (FD_CLOEXEC) flag on the new file
                  descriptor.  See the description of the O_CLOEXEC flag in
                  open(2) for reasons why this may be useful.
 
    In Linux up to version 2.6.26, the flags argument is unused, and must be
    specified as zero.
 
    signalfd() returns a file descriptor that supports the following operations:
 
    read(2)
           If one or more of the signals specified in mask is pending for the
           process, then the buffer supplied to read(2) is used to return one or
           more signalfd_siginfo structures (see below) that describe the signals.
           The read(2) returns information for as many signals as are pending and
           will fit in the supplied buffer.  The buffer must be at least
           sizeof(struct signalfd_siginfo) bytes.  The return value of the read(2)
           is the total number of bytes read.
 
           As a consequence of the read(2), the signals are consumed, so that they
           are no longer pending for the process (i.e., will not be caught by
           signal handlers, and cannot be accepted using sigwaitinfo(2)).
 
           If none of the signals in mask is pending for the process, then the
           read(2) either blocks until one of the signals in mask is generated for
           the process, or fails with the error EAGAIN if the file descriptor has
           been made nonblocking.
 
    poll(2), select(2) (and similar)
           The file descriptor is readable (the select(2) readfds argument; the
           poll(2) POLLIN flag) if one or more of the signals in mask is pending
           for the process.
 
           The signalfd file descriptor also supports the other file-descriptor
           multiplexing APIs: pselect(2), ppoll(2), and epoll(7).
 
    close(2)
           When the file descriptor is no longer required it should be closed.
           When all file descriptors associated with the same signalfd object have
           been closed, the resources for object are freed by the kernel.

*******************************************************************************/

module ocean.sys.SignalFD;



/*******************************************************************************

    Imports

*******************************************************************************/

version ( Posix )
{
}
else
{
    static assert(false, "module ocean.sys.SignalFD only supported in posix environments");
}

private import ocean.core.ErrnoIOException;

private import ocean.io.select.model.ISelectClient;

private import ocean.sys.SignalMask;

private import tango.io.model.IConduit;

private import tango.stdc.posix.signal;
private import tango.stdc.posix.unistd : read, close;

private import tango.stdc.errno : EAGAIN, EWOULDBLOCK, errno;

private import tango.sys.linux.consts.fcntl : O_NONBLOCK;

debug private import ocean.io.Stdout;


extern ( C )
{
    /***************************************************************************
    
        Definition of external functions required to manage signal events.
    
    ***************************************************************************/
    
    private int signalfd ( int fd, sigset_t* mask, int flags );
    
    
    
    /***************************************************************************
    
        Struct used by signal notification.
    
    ***************************************************************************/
    
    public struct signalfd_siginfo
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
}


/*******************************************************************************

    Signal fd class

*******************************************************************************/

public class SignalFD : ISelectable
{
    /***************************************************************************

        errno exception type for signal events.

    ***************************************************************************/

    private static class SignalErrnoException : ErrnoIOException { }


    /***************************************************************************

        Exception type for signal events.

    ***************************************************************************/

    private static class SignalException : Exception
    {
        /***********************************************************************

            Constructor.

        ***********************************************************************/

        public this ( )
        {
            super("");
        }


        /***********************************************************************

            Sets the exception parameters.

            Params:
                msg    = message
                file   = source code file name
                line   = source code line

            Returns:
                this instance

        ***********************************************************************/

        public typeof (this) opCall ( char[] msg, char[] file = "", long line = 0 )
        {
            super.msg = msg;
            super.file = file;
            super.line = line;
            return this;
        }
    }


    /***************************************************************************

        More convenient alias for signalfd_siginfo.

    ***************************************************************************/

    public alias .signalfd_siginfo SignalInfo;


    /***************************************************************************

        SFD_NONBLOCK flags used by signalfd() function.

    ***************************************************************************/

    private alias O_NONBLOCK SFD_NONBLOCK;


    /***************************************************************************

        Re-usable exception instances.

    ***************************************************************************/

    private const SignalErrnoException errno_exception;

    private const SignalException exception;


    /***************************************************************************

        Integer file descriptor provided by the operating system and used to
        manage the signal event.

    ***************************************************************************/

    private const int fd;


    /***************************************************************************

        List of signals being handled by the fd.

    ***************************************************************************/

    private const int[] signals;


    /***************************************************************************

        Constructor. Creates a signal event file descriptor which will be
        written to when one of the specified signals fires. The normal signal
        handling for the specified signals is optionally masked.

        Params:
            signals = list of signals to handle
            mask = if true, default signal handling of the specified signals
                will be masked

    ***************************************************************************/

    public this ( int[] signals, bool mask = true )
    {
        this.signals = signals;

        SignalSet sigset;
        sigset.clear;
        sigset.add(signals);

        this.fd = .signalfd(-1, &cast(sigset_t)sigset, SFD_NONBLOCK);

        if ( mask )
        {
            this.maskHandledSignals();
        }

        this.exception = new SignalException;
        this.errno_exception = new SignalErrnoException;
    }


    /***************************************************************************

        Destructor. Destroys the signal file descriptor and unmasks all masked
        signals.

    ***************************************************************************/

    ~this ( )
    {
        this.unmaskHandledSignals();
        .close(this.fd);
    }


    /***************************************************************************

        Unmasks all signals handled by this fd, meaning that the default signal
        (interrupt) handler will deal with them from now.

        Warning: this will simply unmask all specified signals. This could be
        problematic if some completely different module has separately requested
        that these signals be masked. If this situation ever arises we'll need
        to come up with a clever solution involving some kind of reference
        counting or something.

    ***************************************************************************/

    public void unmaskHandledSignals ( )
    {
        auto sigset = getSignalMask();
        sigset.remove(this.signals);
        setSignalMask(sigset);
    }


    /***************************************************************************

        Masks all signals handled by this fd, meaning that the default signal
        (interrupt) handler will not deal with them from now.

    ***************************************************************************/

    public void maskHandledSignals ( )
    {
        maskSignals(this.signals);
    }


    /***************************************************************************

        Required by ISelectable interface.

        Returns:
            file descriptor used to manage signal event

    ***************************************************************************/

    public Handle fileHandle ( )
    {
        return cast(Handle)this.fd;
    }


    /***************************************************************************

        Should be called when the signal event has fired. Fills in the provided
        array with structs containing information about which signals fired.

        Params:
            siginfos = output array of structs containing information about
                signals which fired

        Throws:
            if an error occurs while reading from the signalfd

    ***************************************************************************/

    public void handle ( ref SignalInfo[] siginfos )
    {
        siginfos.length = 0;

        SignalInfo siginfo;

        ssize_t bytes;
        do
        {
            bytes = .read(this.fd, &siginfo, siginfo.sizeof);
            if ( bytes == siginfo.sizeof )
            {
                siginfos ~= siginfo;
            }
            else if ( bytes < 0 )
            {
                scope ( exit ) .errno = 0;
                auto errnum = .errno;

                switch ( errnum )
                {
                    case EAGAIN:
                    break;

                    static if ( EAGAIN != EWOULDBLOCK )
                    {
                        case EWOUDLBLOCK:
                        break;
                    }

                    default:
                        throw this.errno_exception(errnum, "reading from signalfd",
                                __FILE__, __LINE__);
                }
            }
            else
            {
                throw this.exception("read invalid bytes from signalfd",
                        __FILE__, __LINE__);
            }
        }
        while ( bytes > 0 );
    }
}

