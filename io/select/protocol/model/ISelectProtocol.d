/******************************************************************************

    Manages a chain of read or write callback delegates to be invoked on a
    Select Read or Write event for a non-blocking I/O device.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
    
    The ISelectProtocol is an abstract class to manage a chain of read or write
    callback delegates for a non-blocking I/O device.
    
    An instance of a ISelectProtocol subclass is instantiated with the
    non-blocking I/O device, the "Conduit", and a SelectDispatcher instance,
    the "Dispatcher".
    
    The I/O delegates, the "IOHandlers", are set using setIOHandlers().
    When setting the Handlers, the ISelectProtocol instance automatically
    registeres itself in the Dispatcher using the Conduit and the events()
    method. events() is implemented by the subclass and reflects the events to
    be registered for, usually either "Event.Read" or "Event.Write" ("Event"
    enumerator from tango.io.selector.model.ISelect).
    
    If the registered event occurs, the handle() method, which is implemented by
    the subclass, is invoked with the Conduit on which the event occured and the
    current IOHandler as parameters. handle() must return either false to
    indicate that it finished or true if it did not finish and wants to wait for
    the event to occur again. (Waiting for the event to occur again is usually
    required when the IOHandler and/or Conduit did not consume all data to be
    sent or produced as much data as requested.) Each time handle() returns
    false, the next IOHandler in the chain is picked and handle() is invoked
    with the Conduit and that IOHandler again until handle() has returned false
    for all Handlers.
    
    After handle() has returned false for all Handlers, the ISelectProtocol
    instance either indicates to the Dispatcher to unregister the Conduit or
    Session Finalizer another callback delegate, the "Session Finalizer".
    The Session Finalizer may optionally be provided as an additional parameter
    of setIOHandlers().
    
       - If the Session Finalizer is not provided, the ISelectProtocol instance
         indicates to the Dispatcher to unregister the Conduit after handle
         has returned false for the last IOHandler.
       - If the Session Finalizer is provided, it is invoked after handle() has
         returned false for the last IOHandler. The Session Finalizer indicates
         by returning false that the Conduit should be unregistered from the
         Dispatcher or by returning true that the registration should remain
         unchanged. The Session Finalizer is responsible to change the Conduit
         event registration in the Dispatcher where appropriate.
    
 ******************************************************************************/

module ocean.io.select.protocol.model.ISelectProtocol;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.model.ISelectClient;

private import ocean.io.select.SelectDispatcher;

private import ISelect = tango.io.selector.model.ISelector: Event;

private import tango.io.model.IConduit: ISelectable, IConduit;

debug private import tango.util.log.Trace;

/******************************************************************************

    ISelectProtocol abstract class

 ******************************************************************************/

abstract class ISelectProtocol : IAdvancedSelectClient
{
    /**************************************************************************

        Callback delegate alias type definitions

     **************************************************************************/
    
    alias bool delegate ( void[] data, ref ulong cursor ) IOHandler;
    
    alias bool delegate ( ) FinalizeDg;
    
    /**************************************************************************

        IOHandlerException class
        
        If an IOHandlerException is thrown by an I/O handler, the I/O handler
        chain is aborted and this instance is unregistered from the Dispatcher.
        Since the IOHandlerException is used only internally, it does not accept
        a message.
        
     **************************************************************************/
    
    static class IOHandlerException : Exception { this ( ) { super(""); } }
    
    /**************************************************************************

        Default data buffer size
    
     **************************************************************************/

    const DefaultBufferSize = 0x400;
    
    /**************************************************************************

        Data buffer size
    
     **************************************************************************/

    protected size_t buffer_size;
    
    /**************************************************************************

        Current read/write position (index) in the data buffer
    
     **************************************************************************/

    protected ulong pos    = 0;
    
    /**************************************************************************

        Cursor position for current IOHandler
    
     **************************************************************************/

    private ulong cursor = 0;
    
    /**************************************************************************

        Data buffer
    
     **************************************************************************/
    
    protected void[] data;
    
    /**************************************************************************

        Dispatcher
    
     **************************************************************************/

    private   SelectDispatcher dispatcher;
    
    /**************************************************************************

        IOHandler chain
    
     **************************************************************************/

    private   IOHandler[] io_handlers;
    
    /**************************************************************************

        Index of current IOHandler in chain
    
     **************************************************************************/
    
    protected   size_t handler_index = 0;
    
    /**************************************************************************

        FinalizeDg
    
     **************************************************************************/

    private   FinalizeDg session_finalizer = null;
    
    /**************************************************************************

        Constructor
        
        Params:
            conduit     = Conduit to register events for
            dispatcher  = Dispatcher to register conduit for events
            buffer_size = Data buffer size
    
     **************************************************************************/

    protected this ( ISelectable conduit, SelectDispatcher dispatcher, size_t buffer_size )
    {
        super(conduit);
        
        this.data = new void[buffer_size];
        this.data.length = 0;
        
        this.buffer_size = buffer_size;
        
        this.dispatcher = dispatcher;
    }
    
    /**************************************************************************

        Constructor; uses the default data buffer size
        
        Params:
            conduit     = Conduit to register events for
            dispatcher  = Dispatcher to register conduit for events
    
     **************************************************************************/

    protected this ( ISelectable conduit, SelectDispatcher dispatcher )
    {
        this(conduit, dispatcher, this.DefaultBufferSize);
    }
    
    /**************************************************************************

        Sets the chain of IOHandlers and the Session Finalizer
        
        Params:
            io_handlers         = chain of IOHandlers
            session_finalizer   = Session Finalizer, pass null to provide no
                                  Finalizer
    
        Returns:
            this instance
    
     **************************************************************************/
    
    public typeof (this) setIOHandlers ( IOHandler[] io_handlers, FinalizeDg session_finalizer = null )
    {
        this.io_handlers = io_handlers.dup;

        this.data.length = 0;
        
        this.handler_index = 0;
        
        this.session_finalizer = session_finalizer;
        
        this.dispatcher.register(this);
        
        return this;
    }
    
    /**************************************************************************

        Returns true if there are IOHandlers pending or false otherwise.
        
        Returns:
            true if there are IOHandlers pending or false otherwise
    
     **************************************************************************/

    final bool pending ( )
    {
        return this.handler_index < this.io_handlers.length;
    }
    
    /**************************************************************************

        Returns true if the current data buffer position is at the end of the
        data buffer or false otherwise.
        
        Returns:
            true if the current data buffer position is at the end of the
        data buffer or false otherwise
    
     **************************************************************************/

    protected bool endOfData ( )
    {
        return this.pos >= this.data.length;
    }
    
    /**************************************************************************

        Handles events events_in which occurred for conduit. Invokes the
        abstract handle() method with conduit and the current IOHandler, picking
        the next IOHandler or invoking the Session Finalizer where appropriate.
        
        (Implements an abstract super class method.)
        
        Returns:
            true to indicate to the Dispatcher that the event registration
            should be left unchanged or false to unregister the Conduit. 
    
     **************************************************************************/

    final bool handle ( ISelectable conduit, Event events_in )
    in
    {
        assert (events_in & this.events(), typeof (this).stringof ~ ".handle: wrong events");
    }
    body
    {
        bool unfinished = this.handle(conduit);
        
        unfinished |= this.pending;
        
        if (!unfinished)
        {
            unfinished |= this.finalize();
        }
        
        return unfinished;
    }
    
    /**************************************************************************

        Invokes the IOHandlers, starting from the current IOHandler, one after
        another until a IOHandler returns true or all IOHandlers have been
        invoked.
        
        Returns:
            true if this method should be invoked again or false if it is
            finished.
     
     **************************************************************************/
    
    protected bool invokeHandlers ( )
    {
        bool more;
        
        try do
        {
            more = this.invokeHandler();
            
            if (!more)
            {
                this.handler_index++;
            }
        }
        while (!more && this.pending)
        catch (IOHandlerException)
        {
            // FIXME: Is the error callback invoked?
            
            more = false;
            
            this.io_handlers.length = 0;
        }
            
        return more || this.pending;
    }

   /**************************************************************************

       Handles the current event which just occurred on conduit.
       
       Params:
           conduit: Conduit for which the event occurred
           
       Returns:
           true if the method should be called again when the event occurs next
           time or false if finished
    
    **************************************************************************/

    abstract protected bool handle ( ISelectable conduit );
    
    /**************************************************************************

        Returns the identifiers of the event(s) to register for. This is usually 
        either Event.Read or Event.Write.
        
        (Defers an abstract super class method.)
        
        Returns:
            the identifiers of the event(s) to register for
     
     **************************************************************************/

    abstract Event events ( );
    
    
    /**************************************************************************

        Invokes the current IOHandler.
        A slice of this.data, starting from this.pos, is passed to the
        IOHandler and the cursor counter. After the IOHandler has finished,
        this.pos is increased by the same amount as the IOHandler increased the
        cursor. 
        
        Returns:
            Passes through the return value of the invoked IOHandler, that is,
            true if the IOHandler should be invoked again or false if it is
            finished.
     
     **************************************************************************/

    private bool invokeHandler ( )
    in
    {
        assert (this.pending, typeof (this).stringof ~ ".handle: no I/O Handler left");
    }
    body
    {
        ulong c  = this.cursor;
        
        bool more = this.io_handlers[this.handler_index](this.data[this.pos .. $], c);
        
        assert (c >= this.cursor, "I/O Handler moved cursor backwards");
        
        ulong len = c - this.cursor;
        
        assert (len <= this.data.length, "I/O Handler processed too much data");
        
        this.cursor = more? c : 0;
        
        this.pos += len;
        
        return more;
    }
    
    /**************************************************************************

        Clears the IOHandlers and invokes the Session Finalizer if provided.
        
        Returns:
            Passes through the return value of the FinalizeDg.
    
     **************************************************************************/

    private bool finalize ( )
    {
        bool have_finalizer = !!this.session_finalizer;
        
        this.handler_index      = 0;
        this.io_handlers.length = 0;

        return have_finalizer? this.session_finalizer() : false;
    }
    
    
    /**************************************************************************

        Returns an identifier string for this instance
        
        Returns:
            identifier string for this instance

     **************************************************************************/
    
    debug (DhtClient) abstract char[] id ( ) ;
    
    /**************************************************************************

        Destructor
        
     **************************************************************************/

    ~this ( )
    {
        delete this.data;
        delete this.io_handlers;
    }
}