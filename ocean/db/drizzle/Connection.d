/*******************************************************************************

    Connection class for LibDrizzleEpoll. Used only internally. 

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Mathias Baumann

    Link with:
        -L-ldrizzle
        
*******************************************************************************/

module ocean.db.drizzle.Connection;

/*******************************************************************************

    C-Binding Imports

*******************************************************************************/

private import ocean.db.drizzle.c.drizzle_client;

private import ocean.db.drizzle.c.drizzle;

private import ocean.db.drizzle.c.conn;

private import ocean.db.drizzle.c.query;

private import ocean.db.drizzle.c.constants;

private import ocean.db.drizzle.c.result;

/*******************************************************************************

    General Private Imports

*******************************************************************************/

private import ocean.io.select.model.ISelectClient;

private import tango.io.model.IConduit: ISelectable;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.util.container.queue.NotifyingQueue;

private import ocean.core.Array : copy;

private import ocean.util.log.Trace;

/*******************************************************************************

    Public Imports

*******************************************************************************/

public import ocean.core.ContextUnion;

public import ocean.db.drizzle.Result;

public import ocean.db.drizzle.LibDrizzleEpoll;

public import ocean.db.drizzle.Exception;

/*******************************************************************************

    Tango Imports

*******************************************************************************/

private import tango.stdc.stringz;

private import tango.core.Thread;

/*******************************************************************************

    Alias for the callback for the query function

    Params:
        context   = An arbitrary context object set by the user
        result    = Result Object providing functions and iterators to 
                    access the result. Will be null in case of an error.
        exception = null on success, else the exception that was thrown.                     
                    DrizzleException contains the failed query along with 
                    a message of what went wrong. 
                    (Though, drizzle provides rather rudimentary 
                     error descriptions)

*******************************************************************************/

public alias void delegate ( ContextUnion context, Result result, 
                             DrizzleException exception ) QueryCallback;

/*******************************************************************************

    Connection class

*******************************************************************************/

package class Connection : ISelectClient
{
    /***************************************************************************

        Local Exception Object, to not allocate a new one each time.

    ***************************************************************************/

    private DrizzleException exception;

    /***************************************************************************

        Whether it should register again after handle was called

    ***************************************************************************/

    private bool register_again = false;

    /***************************************************************************

        Result object instance

    ***************************************************************************/

    private Result resultObj; 

    /***************************************************************************

        LibDrizzleEpoll reference

    ***************************************************************************/

    private LibDrizzleEpoll drizzle;

    /***************************************************************************

        Whether the timezone for this connection was initialized

    ***************************************************************************/

    package bool timezone_initialized;

    /***************************************************************************

        file handle for this connection

    ***************************************************************************/

    package Handle fd;

    /***************************************************************************

        Event bitmask

    ***************************************************************************/

    private Event _events;

    /***************************************************************************

        the currently executing sql query. 
        .length is zero if no query is active

    ***************************************************************************/

    private char[] queryString;

    /***************************************************************************

        user-set query callback

    ***************************************************************************/

    private QueryCallback callback;

    /***************************************************************************

        User-set request context

    ***************************************************************************/

    private ContextUnion requestContext;

    /***************************************************************************

        Drizzle connection instance. Will be reused each time

    ***************************************************************************/

    private drizzle_con_st connection = void;

    /***************************************************************************

        Set when an exception in the drizzle cb happened

    ***************************************************************************/

    private Exception drizzle_callback_error = null;
    
    /***************************************************************************

        Whether we got disconnected and shouldn't try to to reconnect

    ***************************************************************************/
    
    private bool disconnected = false;
        
    /***************************************************************************

        Fiber instance.
    
    ***************************************************************************/

    protected Fiber fiber;
    
    /***************************************************************************

        Buffer for the struct deserialisation
    
    ***************************************************************************/
        
    protected ubyte[] buffer;
    
    /***************************************************************************

        Reference to the request queue to pop more requests
    
    ***************************************************************************/
    
    protected NotifyingQueue!(LibDrizzleEpoll.DrizzleRequest) request_queue;
    
    /***************************************************************************

        Constructor

        Params:
            drizzle = the main LibDrizzleEpoll instance

    ***************************************************************************/

    package this ( LibDrizzleEpoll drizzle )
    {
        this.buffer = new ubyte[1024];
        
        this.fiber  = new Fiber (&this.internalHandler, 16*1024);
        
        this.request_queue = drizzle.connections;

        this.drizzle = drizzle;

        timezone_initialized = false;

        if (null == drizzle_con_add_tcp(&drizzle.drizzle, 
                                        &this.connection,
                                        drizzle.host, drizzle.port,
                                        drizzle.username, drizzle.password,
                                        drizzle.database,
                                        drizzle_con_options_t.DRIZZLE_CON_MYSQL))
        {
            throw new Exception("Could not create connection");
        }
        
        drizzle_con_set_context(&this.connection, cast(void*) this);

        this.resultObj = new Result(&this.connection);
        this.exception = new DrizzleException();
    }
   
    /***************************************************************************

        Returns the socket file handle of this connection object

    ***************************************************************************/

    override public Handle fileHandle ( )
    {
        return this.fd;
    }
    
    /***************************************************************************

        Helper function for retrying a function within the fiber 

    ***************************************************************************/

    private static bool retry ( drizzle_return_t code )
    {
        if (code == drizzle_return_t.DRIZZLE_RETURN_IO_WAIT)
        {
            debug ( Drizzle ) Trace.formatln("Waiting for data .. ");
            Fiber.yield();
            return true;
        }

        return false;
    }

    /***************************************************************************

        Internal query function. Should only be called within this.fiber.

    ***************************************************************************/

    private void queryInternal ()
    in
    {
        assert (this.fiber.state == Fiber.State.EXEC);
    }
    body
    {
        drizzle_return_t returnCode;
        this.disconnected = false; // Disconnected is set to false because
                                   // drizzle_query actually retries the connection
        
        do
        {
            resultObj.query = queryString;
            auto result = drizzle_query(&this.connection, &resultObj.result, 
                                        this.queryString.ptr, 
                                        this.queryString.length, &returnCode);
            
            if (null is result)
            {
                throw exception.reset(queryString, returnCode, 
                                      "Failed to allocate result", null);
            }
        }
        while ( retry(returnCode) && !disconnected )
        
        scope (exit) this.resultObj.reset();
        
        if (returnCode == drizzle_return_t.DRIZZLE_RETURN_OK)
        {
            if (this.callback !is null)
            {
                this.callback(this.requestContext, resultObj, null);
                this.reset();                
            }
        }
        else if (this.callback !is null)            
        {
            if (this.drizzle_callback_error !is null)
            {
                 exception.reset(this.queryString, returnCode, 
                                 this.drizzle_callback_error.msg, 
                                 this.drizzle_callback_error);
            }
            else
            {
                char[] msg;
                
                if ( disconnected )
                {
                    returnCode = drizzle_return_t.DRIZZLE_RETURN_COULD_NOT_CONNECT;
                    msg = "Couldn't connect to server";
                    timezone_initialized = false;
                }
                else
                {
                    msg = fromStringz(drizzle_error(
                                   drizzle_con_drizzle(&this.connection)));
                }

                exception.reset(queryString, returnCode, msg, null);
            }
            
            this.callback (this.requestContext, null, this.exception);
            
            this.reset();
            debug ( Drizzle ) Trace.formatln("called reset");
        }
    }
    
        
    /***************************************************************************

        Fiber function
    
    ***************************************************************************/

    private void internalHandler ( )
    in
    {
        assert (this.fiber.state == Fiber.State.EXEC);
    }
    body
    {
        while (true)
        {
            auto request = this.request_queue.pop(this.buffer);

            debug ( Drizzle ) Trace.formatln("Request, fiber: {}, discon: {}", cast(void*)this.fiber, this.disconnected);
            
            if (request !is null)
            {
                if ( !timezone_initialized )
                {
                    debug ( Drizzle ) Trace.formatln("Init. timezone");
                    this.queryString    = drizzle.timezone_query;
                    this.callback       = &timezoneCallback;

                    this.queryInternal();
                }

                this.request(*request);
                debug ( Drizzle ) Trace.formatln("After request()");
            }
            else if ( this.request_queue.ready(&this.notify) )
            {
                register_again = false;
                this.fiber.cede();
            }
        }
    }

    /***************************************************************************

        Callback for timezone query
    
    ***************************************************************************/

    private void timezoneCallback ( ContextUnion context, Result result,
                                    DrizzleException exception )
    {
        if ( exception is null ) timezone_initialized = true;
        else
        {
           timezone_initialized = false;
        }

        debug ( Drizzle ) Trace.formatln("Timezone: {}", timezone_initialized);
    }

    /***************************************************************************

        Called by RequestQueue when this Handler is waiting for new
        Requests. 
        
        The handler then starts popping items (from the queue) 
        as if there is no tomorrow.
        
        When there are no more items to pop, it registers back in the 
        request queue and yields/cedes.
    
    ***************************************************************************/

    public void notify()
    {
        if ( this.fiber.state == Fiber.State.HOLD )
        {
            fiber.call();
        }
    }


    /***************************************************************************

        Sends a query using this connection and will call the provided
        callback when the data arrived

        Params:
            query = query to send
            cb    = callback to call
            rc    = request context. Will be passed to the callback

    ***************************************************************************/
    
    protected void request ( ref LibDrizzleEpoll.DrizzleRequest request )
    in
    {
        assert (this.fiber.state == Fiber.State.EXEC, "Fiber not in state EXEC!");
    }
    body
    {
        assert (this.queryString.length == 0, "Connection already in use");

        this.queryString    = request.query;
        this.callback       = *(cast(QueryCallback*) request.callback.ptr);
        this.requestContext = *(cast(ContextUnion*) request.context.ptr);

        // internalHandler should have initialized the timezone
        if ( !timezone_initialized )
        {
            if ( callback !is null )
                // if that failed, the last exception should contain the error
                this.callback (this.requestContext, null, this.exception);
        }
        else
            this.queryInternal();
        debug ( Drizzle ) Trace.formatln("After queryInternal");
    }
    
    
    /***************************************************************************

        Error function that will be called by the Dispatcher in case 
        an Exception happened

        Calls the user-provided error callback

        Params:
            e  = exception that happened
            ev = at which event it happened

    ***************************************************************************/

    override protected void error_ ( Exception e, Event ev )
    {
        auto internal_error = drizzle_return_t.DRIZZLE_RETURN_INTERNAL_ERROR;

        drizzle_con_set_revents(&this.connection, ev);

        this.disconnected = (Event.EPOLLHUP & ev) != 0;

        debug ( Drizzle ) Trace.formatln("Error called: Disconnected: {}", disconnected);
        
        Exception exc = e;
        
        if ( this.fiber.state != Fiber.State.TERM )
        {
            try this.fiber.call();
            catch (Exception ex) if (exc !is null) 
            {
                exc.next = ex; 
                exc      = ex;
            }
            else
            {
                exc = ex;
            }
        }

        if ( this.fiber.state == Fiber.State.TERM )
        {
            if (this.callback !is null)
            {
                this.callback (this.requestContext, null, 
                               exception.reset(this.queryString, internal_error, 
                                               e.msg, e)); 
            }
            
            this.fiber.reset();
            this.reset();
            this.notify();
        }
    }

    /***************************************************************************

        Will be called when the connection timed out

        Calls the user-provided error callback

    ***************************************************************************/

    override public void timeout ( )
    {
        auto lost_connection = drizzle_return_t.DRIZZLE_RETURN_LOST_CONNECTION;

        timezone_initialized = false;

        if (this.callback !is null)
        {
            this.callback (this.requestContext, null, 
                                exception.reset(queryString,
                                    lost_connection, "Connection timed out", 
                                    null)); 
        }
    }

    /***************************************************************************

        Returns the currently registered events

        Returns:
            currently registered events

    ***************************************************************************/

    override public Event events ( )
    {
        return _events;
    }

    /***************************************************************************

        Sets the active events

    ***************************************************************************/

    package void setEvents ( Event events )
    {
        _events = events;

        register_again = true;
    }

    /***************************************************************************

        I/O event handle. Called by the EpollSelectDispatcher to inform
        the class instance about new events

        Params:
            event   = identifier of I/O event that just occured on the device
             
        Returns:
            false if the fiber is in state TERM

    ***************************************************************************/

    override public bool handle ( Event event )
    in
    {
        assert (this.fiber.state == Fiber.State.HOLD);
    }
    body
    {
        debug ( Drizzle ) Trace.formatln("Handle: New data..");
        register_again = false;
        
        drizzle_con_set_revents(&this.connection, event);
    
        try this.fiber.call();
        catch ( DrizzleException e )
        {
            debug ( Drizzle ) Trace.formatln(" Exception in handle");
            if (this.callback !is null)            
            {
                this.callback (this.requestContext, null, e); 
            }
            
            this.fiber.reset();
            this.reset();
            this.notify();            
        }
        catch ( Exception e )
        {
            Trace.formatln("{} FailSafe Exception Catcher triggered: {} ({}:{})",
                       cast(void*) this, e.msg, e.file, e.line);
        }

        debug ( Drizzle ) Trace.formatln("Register again: {}", register_again);
        return register_again;
    }

    public void finalize ( )
    {
        if ( !timezone_initialized && disconnected && register_again )
        {
            drizzle.epoll.register(this);
        }
    }

    /***************************************************************************

        When a connection broke, drizzle gets the next requests and retries it.
        As all of this happens in the error callback called by epoll and as 
        it only returns control back to epoll after the fiber yields,
        which is after drizzle re-registered itself for a new event,
        epoll continues with the normal way of things, which is, unregistering
        the select-client (this class). After that finalize() is called.
    
        In finalize we have to re-register, else this connection will never be
        called again, always waiting for a response which it never checks for.        

    ***************************************************************************/
    
    override public void finalize ( FinalizeStatus status )
    {
        debug ( Drizzle ) Trace.formatln("Finalize called on {}, {} && {} && {}", this.id(), !timezone_initialized, disconnected, register_again);
        if ( !timezone_initialized && register_again )
        {
            drizzle.epoll.register(this);
        }
    }

    /***************************************************************************

        Set by LibDrizzleEpoll.drizzleCallback in case an exception was
        thrown.
        
        Params:
            e = exception that was thrown
            
        See_Also:
            LibDrizzleEpoll.drizzleCallback

    ***************************************************************************/

    package void callbackError ( Exception e )
    {
        this.drizzle_callback_error = e;
    }
    
    /***************************************************************************

        Resets this connection, making it ready for the next query.
        Fiber needs to have finished.

    ***************************************************************************/

    private void reset ( )
    {
        this.queryString.length = 0;
        this.callback = null;
        this.requestContext = ContextUnion.init;
    }
        
    /***************************************************************************

        Returns descriptive name of this class for debugging purposes

    ***************************************************************************/

//    override protected char[] id()
//    {
//        return "DrizzleConnection";
//    }
}
