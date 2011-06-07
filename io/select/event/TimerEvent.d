module ocean.io.select.event.TimerEvent;

private import ocean.io.select.model.ISelectClient: IAdvancedSelectClient;

private import ocean.io.select.protocol.model.ISelectProtocol;

private import ocean.io.select.protocol.model.ErrnoIOException;

private import tango.io.model.IConduit: ISelectable;

private import tango.stdc.posix.time: time_t, timespec, itimerspec, CLOCK_REALTIME;

private import tango.stdc.posix.sys.types: ssize_t;

private import tango.stdc.posix.unistd: read, write, close;

/// sys/timerfd.h

const TFD_TIMER_ABSTIME = 1;

/// linux/time.h

const CLOCK_MONOTONIC = 1;

extern (C) private
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

/*******************************************************************************

    TimerEvent class

*******************************************************************************/

class TimerEvent : IAdvancedSelectClient, ISelectable
{
    /***************************************************************************
    
        Alias for event handler delegate.
    
    ***************************************************************************/
    
    public alias bool delegate ( ) Handler;
    
    
    public bool absolute = false;
    
    /***************************************************************************
    
        Event handler delegate.
    
    ***************************************************************************/
    
    private Handler handler;
    
    
    /***********************************************************************

        Integer file descriptor provided by the operating system and used to
        manage the custom event.

    ***********************************************************************/

    private int fd;

    private TimerException e;
    
    /***********************************************************************

        Constructor. Creates a file descriptor to manage the event.
        
        Constructor. Creates a custom event and hooks it up to the provided
        event handler.
    
        Params:
            handler = event handler
        
    ***********************************************************************/

    public this ( Handler handler, bool realtime = false )
    {
        this.e = new TimerException;
        
        this.fd = .timerfd_create(realtime? CLOCK_REALTIME : CLOCK_MONOTONIC);
        
        if (fd < 0)
        {
            throw this.e("timerfd_create", __FILE__, __LINE__);
        }
        
        
        this.handler = handler;
        
        super(this);
    }
    
    /***********************************************************************

        Destructor. Destroys the file descriptor used to manage the event.
    
    ***********************************************************************/

    ~this ( )
    {
        .close(this.fd);
    }

    
    /***********************************************************************
    
        Writes to the custom event file descriptor.

        Params:
            data = data to write

     ***********************************************************************/
    
    public itimerspec time ( )
    {
        itimerspec t;
        
        this.e.check(timerfd_gettime(this.fd, &t), "timerfd_gettime", __FILE__, __LINE__);
        
        return t;
    }
    
    /***********************************************************************
    
        Writes to the custom event file descriptor.

        Params:
            data = data to write

    ***********************************************************************/
    
    public itimerspec time ( itimerspec t )
    {
        this.set(t);
        
        return t;
    }
    
    /***********************************************************************
    
        Writes to the custom event file descriptor.

        Params:
            data = data to write

     ***********************************************************************/
    
    public itimerspec set ( itimerspec t )
    {
        itimerspec t_old;
        
        this.e.check(timerfd_settime(this.fd,
                                     this.absolute? TFD_TIMER_ABSTIME : 0,
                                     &t, &t_old),
                                     "timerfd_settime", __FILE__, __LINE__);
        
        return t_old;
    }
    
    public itimerspec set ( time_t first_s,        uint first_ms,
                            time_t interval_s = 0, uint interval_ms = 0 )
    {
        return this.set(itimerspec(timespec(first_s,    first_ms    * 1_000_000),
                                   timespec(interval_s, interval_ms * 1_000_000)));
    }
    
    public itimerspec reset ( )
    {
        return this.set(itimerspec.init);
    }
    
    /***********************************************************************

        Required by ISelectable interface.

        Returns:
            file descriptor used to manage custom event

    ***********************************************************************/

    public Handle fileHandle ( )
    {
        return cast(Handle)this.fd;
    }
    
    /***************************************************************************
    
        Returns:
            select events which this class is registered with
    
    ***************************************************************************/
    
    public Event events ( )
    {
        return Event.Read;
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
    
    public bool handle ( Event event )
    in
    {
        assert(event == Event.Read);
        assert(this.handler);
    }
    body
    {
        ulong n;
        
        .read(this.fd, &n, n.sizeof);
        
        return this.handler();
    }
    
    /***************************************************************************
    
        Returns an identifier string for this instance
    
        (Implements an abstract super class method.)
    
        Returns:
            identifier string for this instance
    
    ***************************************************************************/
    
    debug (ISelectClient) protected char[] id ( )
    {
        return typeof(this).stringof;
    }
    
    static class TimerException : ErrnoIOException
    {
        int check ( int n, char[] msg, char[] file = "", long line = 0 )
        {
            if (n)
            {
                super.set(msg, file, line);
                
                throw this;
            }
            else
            {
                return n;
            }
        }
        
        /**********************************************************************
        
            Queries and resets errno and sets the exception parameters.
            
            Params:
                msg  = message
                file = source code file name
                line = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        public typeof (this) opCall ( char[] msg, char[] file = "", long line = 0 )
        {
            super.set(msg, file, line);
            return this;
        }
    }
}
