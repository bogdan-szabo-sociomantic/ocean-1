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

module ocean.io.select.protocol.chain.model.IChainSelectProtocol;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.model.ISelectClient: IAdvancedSelectClient;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.io.select.protocol.generic.ErrnoIOException: IOError, IOWarning;

private import tango.io.model.IConduit: ISelectable;

debug private import tango.util.log.Trace;

/******************************************************************************

    ISelectProtocol abstract class

 ******************************************************************************/

abstract class IChainSelectProtocol : IAdvancedSelectClient
{
    /**************************************************************************

        Return status of io handler chain finalizer delegates.

        0. Unregister =  The io handler chain is finished and should be
            unregistered.

        1. Select = Indicates that the io handler chain has not finished, and
            needs more data (thus select must be called again).

        2. Continue = Indicates that the io handler chain has finished but has
            registered further io handlers which should immediately be given the
            opportunity to process existing data before calling select again.

     **************************************************************************/

    public enum FinalizerStatus
    {
        Unregister = 0,
        Select = 1, 
        Continue = 2 
    }
    
    /**************************************************************************

        Callback delegate alias type definitions

     **************************************************************************/
    
    public alias bool delegate ( void[] data, ref ulong cursor ) IOHandler;
    
    public alias FinalizerStatus delegate ( ) FinalizeDg;
    
    /**************************************************************************

        IOHandlerException class
        
        If an IOHandlerException is thrown by an I/O handler, the I/O handler
        chain is aborted and this instance is unregistered from the Dispatcher.
        Since the IOHandlerException is used only internally, it does not accept
        a message.
        
     **************************************************************************/
    
    static public class IOHandlerException : Exception { this ( ) { super(""); } }
    
    /**************************************************************************

        Default data buffer size
    
     **************************************************************************/

    protected const DefaultBufferSize = 0x400;
    
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

    private   EpollSelectDispatcher dispatcher;

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

        IOWarning exception instance 
    
     **************************************************************************/
    
    protected IOWarning warning_e;
    
    
    /**************************************************************************
    
        IOError exception instance 
    
     **************************************************************************/
    
    protected IOError error_e;
    

    /**************************************************************************

        Constructor
        
        Params:
            conduit     = Conduit to register events for
            dispatcher  = Dispatcher to register conduit for events
            buffer_size = Data buffer size
    
     **************************************************************************/

    protected this ( ISelectable conduit, EpollSelectDispatcher dispatcher, size_t buffer_size )
    {
        super(conduit);
        
        this.warning_e = new IOWarning(this);
        this.error_e   = new IOError(this);
        
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

    protected this ( ISelectable conduit, EpollSelectDispatcher dispatcher )
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
        this.io_handlers.copy(io_handlers);

        this.handler_index = 0;

        this.session_finalizer = session_finalizer;
        
        return this;
    }


    /**************************************************************************

        Sets a single IOHandler and the Session Finalizer
        
        Params:
            io_handler          = IOHandler
            session_finalizer   = Session Finalizer, pass null to provide no
                                  Finalizer
    
        Returns:
            this instance
    
     **************************************************************************/

    public typeof (this) setIOHandlers ( IOHandler io_handler, FinalizeDg session_finalizer = null )
    {
        this.io_handlers.length = 1;
        this.io_handlers[0] = io_handler;

        this.handler_index = 0;

        this.session_finalizer = session_finalizer;

        return this;
    }


    /**************************************************************************

        Registers the chain of io handlers with the select dispatcher. The
        internal data buffer is cleared (if you're just registering a new set of
        io handlers, then any data in the buffer is just old junk).

        Returns:
            this instance

     **************************************************************************/

    public typeof(this) register ( )
    {
        this.data.length = 0;

        this.pos = 0;

        this.cursor = 0;

        this.dispatcher.register(this);

        return this;
    }

    /**************************************************************************

        Unregisters the chain of io handlers with the select dispatcher. The
        internal data buffer is cleared. An exception is thrown (in
        tango.io.selector.EpollSelector) if the chain is not regitsered.

        Returns:
            this instance

        Throws:
            UnregisteredConduitException if the conduit had not been previously
            registered to the selector

     **************************************************************************/

    public typeof(this) unregister ( )
    {
        this.data.length = 0;

        this.dispatcher.unregister(this);

        return this;
    }

    /**************************************************************************

        Unregisters the chain of io handlers with the select dispatcher. The
        internal data buffer is cleared. An exception is not thrown if the chain
        is not registered.

        Returns:
            this instance

     **************************************************************************/

    public typeof(this) safeUnregister ( )
    {
        this.data.length = 0;

        this.dispatcher.safeUnregister(this);

        return this;
    }

    /**************************************************************************

        Returns true if there are IOHandlers pending or false otherwise.
        
        Returns:
            true if there are IOHandlers pending or false otherwise
    
     **************************************************************************/

    final public bool pending ( )
    {
        return this.handler_index < this.io_handlers.length;
    }
    
    /**************************************************************************

        Resets the internal cursors and data buffer. If a fatal error occurs
        during an i/o handler, then this method needs to be called before the
        next i/o handler is activated.

     **************************************************************************/

    public void init ( )
    {
        this.cursor = 0;
        this.pos = 0;
        this.data.length = 0;
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

        Handles events which occurred for conduit. Invokes the abstract
        handle__() method.

        (Implements an abstract super class method.)

        Returns:
            true to indicate to the Dispatcher that the event registration
            should be left unchanged or false to unregister the Conduit. 

     **************************************************************************/

    final bool handle ( Event events )
    in
    {
        assert(events & this.events, typeof (this).stringof ~ ".handle: wrong events");
    }
    body
    {
        FinalizerStatus status;

        do
        {
            bool more = this.handle_(events) || this.pending;

            status = more ? status.Select : this.finishChain();
        }
        while (status == status.Continue);

        return status != status.Unregister;
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
            more = false;
            
            this.io_handlers.length = 0;
        }
            
        return more || this.pending; // TODO: || this.pending is probably unnecessary
    }

   /**************************************************************************

       Handles the current event which just occurred on conduit.
       
       Params:
           events: reported I/O events
           
       Returns:
           true if the method should be called again when the event occurs next
           time or false if finished
    
    **************************************************************************/

    abstract protected bool handle_ ( Event events );
    
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

    private FinalizerStatus finishChain ( )
    {
        bool have_finalizer = !!this.session_finalizer;

        this.handler_index      = 0;
        this.io_handlers.length = 0;

        return have_finalizer? this.session_finalizer() : FinalizerStatus.Unregister;
    }
    
    
    /**************************************************************************

        Returns an identifier string for this instance
        
        Returns:
            identifier string for this instance

     **************************************************************************/
    
    debug (ISelectClient) abstract char[] id ( ) ;
}