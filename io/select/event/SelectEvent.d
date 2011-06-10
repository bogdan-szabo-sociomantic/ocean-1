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

    TODO: either here, or in a new module, add timed event support, perhaps
    using timerfd_create.

*******************************************************************************/

module ocean.io.select.event.SelectEvent;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.io.model.IConduit;

private import tango.stdc.posix.sys.types: ssize_t;

private import ocean.io.select.model.ISelectClient;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Definitions of C functions required to manage custom events.

*******************************************************************************/

private extern ( C )
{
    int eventfd ( uint initval, int flags );
    ssize_t write ( int fd, void* buf, size_t count );
    ssize_t read ( int fd, void* buf, size_t count );
    int close ( int fd );
}


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

        Parmas:
            data = data to write

    ***********************************************************************/

    private void write ( void[] data )
    {
        .write(this.fd, data.ptr, data.length);
    }

    
    /***********************************************************************

        Reads from the custom event file descriptor.

        Parmas:
            data = data buffer to read into

    ***********************************************************************/
   
    private void read ( void[] data )
    {
        .read(this.fd, data.ptr, data.length);
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
        ubyte[ulong.sizeof] receive;
        this.read(receive);

        return this.handler();
    }


    /***************************************************************************

        Triggers the event.

    ***************************************************************************/

    public void trigger ( )
    {
        ulong count_inc = 1;
        this.write((cast(void*)&count_inc)[0..ulong.sizeof]);
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

