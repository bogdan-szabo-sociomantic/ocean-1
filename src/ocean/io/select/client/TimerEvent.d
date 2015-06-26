/*******************************************************************************

    Timer event which can be registered with the EpollSelectDispatcher.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2011: Initial release

    authors:        David Eckardt

*******************************************************************************/

module ocean.io.select.client.TimerEvent;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.select.client.model.ISelectClient: ISelectClient;

import ocean.sys.ErrnoException;
import ocean.core.Array : copy;
import ocean.core.Traits;

import tango.io.model.IConduit: ISelectable;

import tango.stdc.posix.time: time_t, timespec, itimerspec, CLOCK_REALTIME;

import tango.stdc.posix.sys.types: ssize_t;

import tango.stdc.posix.unistd: read, write, close;

import tango.stdc.errno: EAGAIN, EWOULDBLOCK, errno;

import tango.text.convert.Format;

/// <sys/timerfd.h>

const TFD_TIMER_ABSTIME = 1,
      TFD_CLOEXEC       = 0x80000, // octal 02000000
      TFD_NONBLOCK      = 0x800;   // octal 04000

/// <linux/time.h>

const CLOCK_MONOTONIC = 1;

// TODO: move into C bindings after tango/ocean merge

extern (C)
{
    /**************************************************************************

        Creates a new timer object.

        The file descriptor supports the following operations:

        read(2)
               If  the timer has already expired one or more times since its
               settings were last modified using timerfd_settime(), or since the
               last successful read(2), then the buffer given to read(2) returns
               an unsigned 8-byte integer (uint64_t) containing  the  number of
               expirations that have occurred.  (The returned value is in host
               byte order, i.e., the native byte order for integers on the host
               machine.)

               If no timer expirations have occurred at the time of the read(2),
               then the call either blocks until the next timer  expiration, or
               fails with the error EAGAIN if the file descriptor has been made
               non-blocking (via the use of the fcntl(2) F_SETFL operation to
               set the O_NONBLOCK flag).

               A read(2) will fail with the error EINVAL if the size of the
               supplied buffer is less than 8 bytes.

        poll(2), select(2) (and similar)
               The file descriptor is readable (the select(2) readfds argument;
               the poll(2) POLLIN flag) if one or more timer expirations have
               occurred.

               The file descriptor also supports the other file-descriptor
               multiplexing APIs: pselect(2), ppoll(2), and epoll(7).

        close(2)
               When  the  file descriptor is no longer required it should be
               closed.  When all file descriptors associated with the same timer
               object have been closed, the timer is disarmed and its resources
               are freed by the kernel.

        fork(2) semantics
            After a fork(2), the child inherits a copy of the file descriptor
            created by timerfd_create().  The file descriptor refers to the same
            underlying  timer  object  as the corresponding file descriptor in
            the parent, and read(2)s in the child will return information about
            expirations of the timer.

        execve(2) semantics
            A file descriptor created by timerfd_create() is preserved across
            execve(2), and continues to generate timer expirations if the  timer
            was armed.

        Params:
            clockid = Specifies the clock  that is used to mark the progress of
                      the timer, and must be either CLOCK_REALTIME or
                      CLOCK_MONOTONIC.
                      - CLOCK_REALTIME is a settable system-wide clock.
                      - CLOCK_MONOTONIC is a non-settable clock that is not
                          affected by discontinuous changes in the system clock
                          (e.g., manual changes to system time). The current
                          value of each of these clocks can be retrieved using
                          clock_gettime(2).

            flags   = Starting with Linux 2.6.27: 0 or a bitwise OR combination
                      of
                      - TFD_NONBLOCK: Set the O_NONBLOCK file status flag on the
                            new open file description.
                      - TFD_CLOEXEC: Set the close-on-exec (FD_CLOEXEC) flag on
                            the new file descriptor. (See the description of the
                            O_CLOEXEC  flag  in open(2) for reasons why this may
                            be useful.)

                      Up to Linux version 2.6.26: Must be 0.

        Returns:
            a file descriptor that refers to that timer

     **************************************************************************/

    int timerfd_create(int clockid, int flags = 0);

    /**************************************************************************

        Sets next expiration time of interval timer source fd to new_value.

        Params:
            fd        = file descriptor referring to the timer

            flags     = 0 starts a relative timer using new_value.it_interval;
                        TFD_TIMER_ABSTIME starts an absolute timer using
                        new_value.it_value.

            new_value = - it_value: Specifies the initial expiration of the
                            timer. Setting either field to a non-zero value arms
                            the timer. Setting both fields to zero disarms the
                            timer.
                        - it_interval: Setting one or both fields to non-zero
                            values specifies the period for repeated timer
                            expirations after the initial expiration. If both
                            fields are zero, the timer expires just once, at the
                            time specified by it_value.

            old_value = Returns the old expiration time as timerfd_gettime().

        Returns:
            0 on success or -1 on error. Sets errno in case of error.

     **************************************************************************/

    int timerfd_settime(int fd, int flags,
                        itimerspec* new_value,
                        itimerspec* old_value);

    /**************************************************************************

        Returns the next expiration time of fd.

        Params:
            fd         = file descriptor referring to the timer
            curr_value = - it_value:
                             Returns the amount of time until the timer will
                             next expire. If both fields are zero, then the
                             timer is currently disarmed. Contains always a
                             relative value, regardless of whether the
                             TFD_TIMER_ABSTIME flag was specified when setting
                             the timer.
                        - it_interval: Returns the interval of the timer. If
                             both fields are zero, then the timer is set to
                             expire just once, at the time specified by
                             it_value.

        Returns:
            0 on success or -1 on error. Sets errno in case of error.

     **************************************************************************/

    int timerfd_gettime(int fd, itimerspec* curr_value);
}

class TimerEvent : ITimerEvent
{
    /***************************************************************************

        Alias for event handler delegate.

        Returns:
            true to stay registered in epoll or false to unregister.

    ***************************************************************************/

    public alias bool delegate ( ) Handler;

    /***************************************************************************

        Event handler delegate.

    ***************************************************************************/

    private Handler handler;

    /***********************************************************************

        Constructor. Creates a file descriptor to manage the event.

        Constructor. Creates a custom event and hooks it up to the provided
        event handler.

        Params:
            handler = event handler

    ***********************************************************************/

    public this ( Handler handler, bool realtime = false )
    {
        super(realtime);

        this.handler = handler;
    }

    /***************************************************************************

        Called from the select dispatcher when the event fires. Calls the user-
        provided event handler.

        Params:
            event = select event which fired, must be Read

        Returns:
            forwards return value of event handler -- false indicates that the
            event should be unregistered with the selector, true indicates that
            it should remain registered and able to fire again

    ***************************************************************************/

    protected override bool handle_ ( ulong n )
    in
    {
        assert(this.handler);
    }
    body
    {
        return this.handler();
    }

    /***********************************************************************

        Set a new handler

        Params:
            handler = event handler

    ***********************************************************************/

    public void setHandler ( Handler handler )
    {
        this.handler = handler;
    }
}

/*******************************************************************************

    TimerEvent class

*******************************************************************************/

abstract class ITimerEvent : ISelectClient, ISelectable
{
    /***************************************************************************

        Set to true to use an absolute or false for a relative timer. On default
        a relative timer is used.

    ***************************************************************************/

    public bool absolute = false;

    /***************************************************************************

        Integer file descriptor provided by the operating system and used to
        manage the custom event.

    ***************************************************************************/

    private int fd;

    /***************************************************************************

        Reused Exception instance

    ***************************************************************************/

    protected TimerException e;

    /***********************************************************************

        Constructor. Creates a file descriptor to manage the event.

        Params:
            realtime = true:  use a settable system-wide clock.
                       false: use a non-settable clock that is not affected by
                       discontinuous changes in the system clock (e.g., manual
                       changes to system time).

    ***********************************************************************/

    protected this ( bool realtime = false )
    {
        this.fd = .timerfd_create(realtime? CLOCK_REALTIME : CLOCK_MONOTONIC,
                                  TFD_NONBLOCK);
        this.e.enforce(this.fd >= 0, identifier!(.timerfd_create), "");

        this.e = new TimerException;
    }

    /***************************************************************************

        Returns:
            the epoll events to register for.

    ***************************************************************************/

    public override Event events ( )
    {
        return Event.EPOLLIN;
    }

    /***********************************************************************

        Destructor. Destroys the file descriptor used to manage the event.

    ***********************************************************************/

    ~this ( )
    {
        .close(this.fd);
    }


    /***************************************************************************

        Timer expiration event handler.

        Params:
            n =  number of  expirations that have occurred

        Returns:
            true to stay registered in epoll or false to unregister.

    ***************************************************************************/

    abstract protected bool handle_ ( ulong n );

    /***********************************************************************

        Returns the next expiration time.

        Returns:
            itimerspec instance containing the next expiration time.
            - it_value: the amount of time until the timer will next expire. If
                 both fields are zero, then the timer is currently disarmed.
                 Contains always a relative value.
            - it_interval: the interval of the timer. If both fields are zero,
                 then the timer is set to expire just once, at the time
                 specified by it_value.

     ***********************************************************************/

    public itimerspec time ( )
    {
        itimerspec t;

        this.e.enforceRetCode!(.timerfd_gettime)().call(this.fd, &t);

        return t;
    }

    /***************************************************************************

        Sets next expiration time of interval timer.

        Params:
            first =    Specifies the initial expiration of the timer. Setting
                       either field to a non-zero value arms the timer. Setting
                       both fields to zero disarms the timer.

            interval = Setting one or both fields to non-zero values specifies
                       the period for repeated timer expirations after the
                       initial expiration. If both fields are zero, the timer
                       expires just once, at the time specified by it_value.

        Returns:
            the previous expiration time as time().

     **************************************************************************/

    public itimerspec set ( timespec first, timespec interval = timespec.init )
    {
        itimerspec t_new = itimerspec(interval, first),
                   t_old;

        this.e.enforceRetCode!(.timerfd_settime)().call(
            this.fd, this.absolute ? TFD_TIMER_ABSTIME : 0, &t_new, &t_old);

        return t_old;
    }

    /***************************************************************************

        Sets next expiration time of interval timer.

        Setting first_s or first_ms to a non-zero value arms the timer. Setting
        both to zero disarms the timer.
        If both interval_s and interval_,s are zero, the timer expires just
        once, at the time specified by first_s and first_ms.


        Params:
            first_s     = Specifies the number of seconds of the initial
                          expiration of the timer.

            first_ms    = Specifies an amount of milliseconds that will be added
                          to first_s.

            interval_s = Specifies the number of seconds of the period for
                          repeated timer expirations after the initial
                          expiration.

            interval_ms = Specifies an amount of milliseconds that will be added
                          to interval_ms.

        Returns:
            the previous expiration time as time().

     **************************************************************************/

    public itimerspec set ( time_t first_s,        uint first_ms,
                            time_t interval_s = 0, uint interval_ms = 0 )
    {
        return this.set(timespec(first_s,    first_ms    * 1_000_000),
                        timespec(interval_s, interval_ms * 1_000_000));
    }

    /***************************************************************************

        Resets/disarms the timer.

        Returns:
            Returns the previous expiration time as time().

     **************************************************************************/

    public itimerspec reset ( )
    {
        return this.set(timespec.init);
    }

    /***********************************************************************

        Required by ISelectable interface.

        Returns:
            file descriptor used to manage custom event

    ***********************************************************************/

    public override Handle fileHandle ( )
    {
        return cast(Handle)this.fd;
    }

    /***************************************************************************

        Event handler, invoked by the epoll select dispatcher.

        Params:
            event = event(s) reported by epoll

        Returns:
            true to stay registered in epoll or false to unregister.

    ***************************************************************************/

    final override bool handle ( Event event )
    {
        ulong n;

        if (.read(this.fd, &n, n.sizeof) < 0)
        {
            scope (exit) .errno = 0;

            switch (.errno)
            {
                case EAGAIN:
                static if (EAGAIN != EWOULDBLOCK) case EWOULDBLOCK:
                    return true;

                default:
                    throw this.e.useGlobalErrno(identifier!(.read));
            }
        }
        else
        {
            return this.handle_(n);
        }
    }

    /***************************************************************************

        Returns an identifier string for this instance

        Returns:
            identifier string for this instance

    ***************************************************************************/

    debug
    {
        private char[] time_buffer;

        public override char[] id ( )
        {
            this.time_buffer.copy(super.id());
            auto time = this.time();

            Format.format(this.time_buffer, ": {}s {}ns",
                time.it_value.tv_sec, time.it_value.tv_nsec);
            return this.time_buffer;
        }
    }

    /**************************************************************************/

    static class TimerException : ErrnoException { }
}
