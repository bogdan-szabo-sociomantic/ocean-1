/*******************************************************************************

    Custom event which can be registered with the EpollSelectDispatcher.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        April 2011: Initial release

    authors:        Gavin Norman

    An instance of this class can be registered with an EpollSelectDispatcher,
    and triggered at will, causing it to be selected in the select loop. When it
    is selected, a user-specified callback (given in the class' constructor) is
    invoked.

    Usage example:

    ---

        import ocean.io.select.event.SelectEvent;
        import ocean.io.select.EpollSelectDispatcher;

        // Event handler
        void handler ( )
        {
            // Do something
        }

        auto dispatcher = new EpollSelectDispatcher;
        auto event = new SelectEvent(&handler);

        dispatcher.register(event);

        dispatcher.eventLoop();

        // At this point, any time event.trigger is called, the eventLoop will
        // select the event and invoke its handler callback.

    ---

*******************************************************************************/

module ocean.io.select.event.SelectEvent;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.io.model.IConduit;

private import tango.stdc.posix.sys.types: ssize_t;

private import tango.stdc.posix.unistd: read, write, close;

private import ocean.io.select.model.ISelectClient;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Definitions of external functions required to manage custom events.

*******************************************************************************/

/*******************************************************************************

    Creates an "eventfd object" that can be used as an event wait/notify
    mechanism by userspace applications, and by the kernel to notify userspace
    applications of events. The object contains an unsigned 64-bit integer
    (ulong) counter that is maintained  by the kernel.
    
    The following operations can be performed on the file descriptor:
    
    read(2)
        If the eventfd counter has a nonzero value, then a read(2) returns 8
        bytes containing that value, and the counter's value is reset to zero.
        (The returned value is in host byte order, i.e., the native byte order
        for integers on the host machine.) 
        If the counter is zero at the time of the read(2), then the call either
        blocks until the counter becomes nonzero, or fails with the error EAGAIN
        if the file descriptor has been made non-blocking (via the use of the
        fcntl(2) F_SETFL operation to set the O_NONBLOCK flag).
    
        A read(2) will fail with the error EINVAL if the size of the supplied
        buffer is less than 8 bytes.
        
    write(2)
        A write(2) call adds the 8-byte integer value supplied in its buffer to
        the counter. The maximum value that may be stored in the counter is the
        largest unsigned 64-bit value minus 1 (i.e., 0xfffffffffffffffe). If
        the addition would cause the counter's value to exceed the maximum,
        then the write(2) either blocks until a read(2) is performed on the file
        descriptor, or fails with the error EAGAIN if the file descriptor has
        been made non-blocking. 
        A write(2) will fail with the error EINVAL if the size of the supplied
        buffer is less than 8 bytes, or if an attempt is made to write the value
        0xffffffffffffffff.
         
    poll(2), select(2) (and similar)
        The returned file descriptor supports poll(2) (and analogously epoll(7))
        and select(2), as follows: 
    
        The file descriptor is readable (the select(2) readfds argument; the
        poll(2) POLLIN flag) if the counter has a value greater than 0.
    
        The file descriptor is writable (the select(2) writefds argument; the
        poll(2) POLLOUT flag) if it is possible to write a value of at least
        "1" without blocking.
    
        The file descriptor indicates an exceptional condition (the select(2)
        exceptfds argument; the poll(2) POLLERR flag) if an overflow of the
        counter value was detected. As noted above, write(2) can never overflow
        the counter. However an overflow can occur if 2^64 eventfd "signal
        posts" were performed by the KAIO subsystem (theoretically possible,
        but practically unlikely). If an overflow has occurred, then read(2)
        will return that maximum uint64_t value (i.e., 0xffffffffffffffff). The
        eventfd file descriptor also supports the other file-descriptor
        multiplexing APIs: pselect(2), ppoll(2), and epoll(7).
        
    close(2)
        When the file descriptor is no longer required it should be closed.
        When all file descriptors associated with the same eventfd object have
        been closed, the resources for object are freed by the kernel.
         
    A copy of the file descriptor created by eventfd() is inherited by the child
    produced by fork(2). The duplicate file descriptor is associated with the
    same eventfd object. File descriptors created by eventfd() are preserved
    across execve(2).
    
    Params:
        initval = initial counter value
        flags   = Starting with Linux 2.6.27: 0 or a bitwise OR combination of
                  - EFD_NONBLOCK: Set the O_NONBLOCK file status flag on the
                        new open file description.
                  - EFD_CLOEXEC: Set the close-on-exec (FD_CLOEXEC) flag on
                        the new file descriptor. (See the description of the 
                        O_CLOEXEC  flag  in open(2) for reasons why this may be
                        useful.)
                      
                  Up to Linux version 2.6.26: Must be 0.
                  
    Returns:
        new file descriptor that can be used to refer to the eventfd object
              
*******************************************************************************/

private extern ( C ) int eventfd ( uint initval, int flags );

/*******************************************************************************

    SelectEvent class

    File descriptor event class wrapping C functions. See:

        http://linux.die.net/man/2/eventfd

*******************************************************************************/

class SelectEvent : IAdvancedSelectClient, ISelectable
{
    /***********************************************************************

        Integer file descriptor provided by the operating system and used to
        manage the custom event.

    ***********************************************************************/

    private int fd;


    /***************************************************************************

        Alias for event handler delegate.
    
    ***************************************************************************/

    public alias bool delegate ( ) Handler;


    /***************************************************************************

        Event handler delegate.
    
    ***************************************************************************/

    private Handler handler;


    /***************************************************************************

        Constructor. Creates a custom event and hooks it up to the provided
        event handler.

        Params:
            handler = event handler

    ***************************************************************************/

    public this ( Handler handler )
    {
        this.handler = handler;

        this.fd = .eventfd(0, 0);
        
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
        
        A write() call adds the ulong value supplied in its buffer to the
        counter. The maximum value that may be stored in the counter is
        ulong.max - 1. If the addition would cause the counter's value to
        exceed the maximum, write() either blocks until a read() is
        performed or fails with the error EAGAIN if the file descriptor has
        been made non-blocking. 
        A write() will fail with the error EINVAL if an attempt is made to
        write the value ulong.max.
        
        Params:
            n = value to write
        
        Returns:
            ulong.sizeof on success or -1 on error. For -1 errno is set
            appropriately.
    
    ***********************************************************************/

    public ssize_t write ( ulong n )
    {
        return .write(this.fd, &n, n.sizeof);
    }

    
    /***********************************************************************

        Reads from the custom event file descriptor.
        
        If the eventfd counter has a nonzero value, then a read() returns
        that value, and the counter's value is reset to zero.
        If the counter is zero at the time of the read(), then the call
        either blocks until the counter becomes nonzero, or fails with the
        error EAGAIN if the file descriptor has been made non-blocking.
        
        Params:
            n = value output
            
        Returns:
            ulong.sizeof on success, 0 on end-of-file condition or -1 on
            error. For 0 and -1 errno is set appropriately.
    
    ***********************************************************************/

    public void read ( out ulong n )
    {
        return .read(this.fd, &n, n.sizeof);
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
        this.read(n);

        return this.handler();
    }


    /***************************************************************************

        Triggers the event.

    ***************************************************************************/

    public void trigger ( )
    {
        ulong count_inc = 1;
        this.write(count_inc);
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
}

