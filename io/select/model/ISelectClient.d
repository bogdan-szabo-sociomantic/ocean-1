/******************************************************************************

    Base class for registrable client objects for the SelectDispatcher

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
    
    Contains the three things that the SelectDispatcher needs:
        1. the I/O device instance
        2. the I/O events to register the device for
        3. the event handler to invocate when an event occured for the device
        
    In addition a subclass may override finalize(). When handle() returns false
    or throws an Exception, the ISelectClient instance is unregistered from the
    SelectDispatcher and finalize() is invoked. 
    
 ******************************************************************************/

module ocean.io.select.model.ISelectClient;

/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.io.selector.model.ISelector: Event;
private import tango.io.model.IConduit:           ISelectable;

/******************************************************************************

    ISelectClient abstract class

 ******************************************************************************/

abstract class ISelectClient
{
    alias .Event       Event;
    alias .ISelectable ISelectable;
    
    /**************************************************************************

        I/O device instance
        
        Note: Conforming to the name convention used in tango.io.selector, the
        ISelectable instance is named "conduit" although ISelectable and
        IConduit are distinct from each other. However, in most application
        cases the provided instance will originally implement both ISelectable
        and IConduit (as, for example, tango.io.device.Device and
        tango.net.device.Socket). 

     **************************************************************************/
    
    private ISelectable conduit_;
    
    /**************************************************************************

        Constructor
        
        Params:
            conduit_     = I/O device instance
    
     **************************************************************************/

    protected this ( ISelectable conduit_ )
    {
        this.conduit_     = conduit_;
    }
    
    /**************************************************************************

        Returns the I/O device instance
        
        Returns:
             the I/O device instance
    
     **************************************************************************/
    
    final ISelectable conduit ( )
    in
    {
        debug (ISelectClient) assert (this.conduit_, this.id ~ ": no conduit");
        else  assert (this.conduit_, typeof (this).stringof ~ ": no conduit");
    }
    body
    {
        return this.conduit_;
    }
    
    /**************************************************************************

        Sets the I/O device instance
        
        Params:
             conduit_ = I/O device instance
    
     **************************************************************************/

    final void conduit ( ISelectable conduit_ )
    {
        this.conduit_ = conduit_;
    }
    
    /**************************************************************************

        Returns the I/O events to register the device for
        
        Returns:
             the I/O events to register the device for
    
     **************************************************************************/

    abstract Event events ( );
    
    /**************************************************************************

        I/O event handler
        
        Params:
             conduit = I/O device instance (as taken from Selection Key by the
                       SelectDispatcher)
             event   = identifier of I/O event that just occured on the device
             
        Returns:
            true if the handler should be called again on next event occurrence
            or false if this instance should be unregistered from the
            SelectDispatcher.
    
     **************************************************************************/

    abstract bool handle ( ISelectable conduit, Event event );
    
    /**************************************************************************

        Finalize method, called after this instance has been unregistered from
        the Dispatcher. Intended to be overloaded by a subclass if required.
        
     **************************************************************************/

    void finalize ( ) { }
    
    /**************************************************************************

        Error reporting method, called when an Exception is caught from
        handle(). Intended to be overloaded by a subclass if required.
        
        Params:
            exception: Exception thrown by handle()
            event:     Seletor event while exception was caught
        
     **************************************************************************/

    void error ( Exception exception, Event event ) { }
    
    /**************************************************************************

        Returns an identifier string of this instance
        
        Returns:
             identifier string of this instance
    
     **************************************************************************/

    debug (ISelectClient) abstract char[] id ( );
}

/******************************************************************************

    ISelectClientWithFinalizer abstract class
    
    Provides setting an IFinalizer instance that implements the finalize()
    method at run-time as well as an IErrorReporter implementing error().

 ******************************************************************************/

abstract class IAdvancedSelectClient : ISelectClient
{
    /**************************************************************************

        EventInfo struct
        
        Contains a Selector event and methods to test for event flags set
        
        Example:
                                                                             ---
            auto info = EventInfo(EventInfo.Event.Read | EventInfo.Event.Hangup);
            
            bool x = info.read;         // x is true
            bool y = info.write;        // y is false
            bool z = info.hangup;       // z is true
                                                                             ---
        
     **************************************************************************/

    struct EventInfo
    {
        Event code = Event.None;
        
        /**********************************************************************
         
            Returns:
                true if the current code is clear or false if it contains an event
        
         **********************************************************************/

        bool none ( )
        {
            return !this.code;
        }
        
        /**********************************************************************
            
            AND-Compares flags with the current code.
            
            Params:
                flags = flags to compare
                
            Returns:
                true if all bits of flags are set in the current code or false
                otherwise
        
         **********************************************************************/
        
        bool eventFlagsSet ( Event flags )
        {
            return !!(this.code & flags);
        }
        
        /**********************************************************************
        
            Returns:
                true if all bits of flags are set in the current code or false
                otherwise
        
         **********************************************************************/

        bool eventFlagsSetT ( Event flags ) ( )
        {
            return this.eventFlagsSet(flags);
        }
        
        alias eventFlagsSetT!(Event.Read)          read;
        alias eventFlagsSetT!(Event.UrgentRead)    urgent_read;
        alias eventFlagsSetT!(Event.Write)         write;
        alias eventFlagsSetT!(Event.Error)         error;
        alias eventFlagsSetT!(Event.Hangup)        hangup;
        alias eventFlagsSetT!(Event.InvalidHandle) invalid_handle;
    }
    
    /**************************************************************************/

    interface IFinalizer
    {
        void finalize ( );
    }
    
    /**************************************************************************/

    interface IErrorReporter
    {
        void error ( Exception exception, EventInfo event );
    }
    
    /**************************************************************************

        IFinalizer and IErrorReporter instance
    
     **************************************************************************/

    private IFinalizer     finalizer_ = null;
    private IErrorReporter error_reporter_ = null;
    
    /**************************************************************************

        Constructor
        
        Params:
            conduit     = I/O device instance
    
     **************************************************************************/

    protected this ( ISelectable conduit )
    {
        super (conduit);
    }
    
    /**************************************************************************

        Sets the Finalizer. May be set to null to disable finalizing.
        
        Params:
            finalizer_ = IFinalizer instance
    
     **************************************************************************/
    
    final void finalizer ( IFinalizer finalizer_ )
    {
        this.finalizer_ = finalizer_;
    }
    
    /**************************************************************************

        Sets the Error REporter. May be set to null to disable error reporting.
        
        Params:
            finalizer = IFinalizer instance
    
     **************************************************************************/

    final void error_reporter ( IErrorReporter error_reporter_ )
    {
        this.error_reporter_ = error_reporter_;
    }
    
    /**************************************************************************

        Finalize method, called after this instance has been unregistered from
        the Dispatcher.
    
     **************************************************************************/
    
    final override void finalize ( )
    {
        if (this.finalizer_)
        {
            this.finalizer_.finalize();
        }
    }
    
    /**************************************************************************

        Error reporting method, called when an Exception is caught from
        super.handle().
        
        Params:
            exception: Exception thrown by handle()
            event:     Seletor event while exception was caught
        
     **************************************************************************/

    final override void error ( Exception exception, Event event )
    {
        if (this.error_reporter_)
        {
            this.error_reporter_.error(exception, EventInfo(event));
        }
    }
    
    /**************************************************************************

        Destructor
        
     **************************************************************************/

    ~this ( )
    {
        this.finalizer_      = null;
        this.error_reporter_ = null;
    }
}
