/*******************************************************************************

    Wrapper for libdrizzle, a flexible mysql/drizzle library

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Mathias Baumann

    LibDrizpleEpoll uses the c library libdrizzle to communicate with
    mysql and drizzle servers.
    
    It uses an internal queue to store all queries which are not yet sent.
    The size of that queue depends on how many queries you plan to send
    simultaneously and how long they are, as well as how many connections
    you plan to use. One query needs roughly 10 bytes + the length
    of the query string.  
    
    Usage Example:

    ---

    void resultHandler (RequestContext rc, Result result, DrizzleException e )
    {
        if (result !is null)
        {
            foreach (row; result)
            {
                Stdout.format("Row: ");
                
                foreach (field; row)
                {
                    Stdout.format("\t{}", field);
                }
    
                Stdout.formatln("");
            }
        }
        else
        {
            if (e !is null)
            {
                Stdout.formatln("Query {} failed: {}", e.query, e.msg);
            }
        }
    }

    auto epoll   = new EpollSelectDispatcher;

    auto drizzle = new LibDrizzleEpoll(epoll, "mysql.host.tld", 
                                       "username", "password",
                                       "database", 1024);

    bool added = drizzle.query("SELECT 'this', 'is', 'an', 'example', 'query'",
                               &resultHandler);

    if ( added == false )
    {
        Stdout.formatln("Couldn't add query, queue full"); // also calling the callback
    }

    epoll.eventLoop;

    ---

    Link with:
        -L-ldrizzle

*******************************************************************************/

module ocean.db.drizzle.LibDrizzleEpoll;

/*******************************************************************************

    Private local Imports

*******************************************************************************/

private import ocean.db.drizzle.Connection;

/*******************************************************************************

    C-Binding Imports

*******************************************************************************/

private import ocean.db.drizzle.c.drizzle_client;

private import ocean.db.drizzle.c.drizzle;

private import ocean.db.drizzle.c.conn;

private import ocean.db.drizzle.c.query;

private import ocean.db.drizzle.c.constants;

private import ocean.db.drizzle.c.result;

private import ocean.db.drizzle.c.structs;

/*******************************************************************************

    Public Imports

*******************************************************************************/

public import ocean.db.drizzle.RequestContext;

public import ocean.db.drizzle.Result;

/*******************************************************************************

    General Private Imports

*******************************************************************************/

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.io.select.model.ISelectClient;

private import ocean.io.select.RequestQueue;

/*******************************************************************************

    Tango Imports

*******************************************************************************/

private import tango.stdc.stringz;

private import tango.stdc.posix.netinet.in_;

/*******************************************************************************

    Debug Imports

*******************************************************************************/

private debug import ocean.io.SyncOut;

class LibDrizzleEpoll
{
    /***************************************************************************

        QueueFull Exception

    ***************************************************************************/

    static class QueueFullException : DrizzleException
    {
        this ( )
        {
        }
    }
    
    /***************************************************************************

        Host, username, password and port for the connections, prepared as
        \0 terminated strings

    ***************************************************************************/

    package char*  host,
                   username,
                   password,
                   database;

    package in_port_t port;
                   
    /***************************************************************************

        Drizzle instance

    ***************************************************************************/

    package drizzle_st drizzle = void;

    /***************************************************************************

        EpollSelectDispatcher instance

    ***************************************************************************/

    private EpollSelectDispatcher epoll = void;

    /***************************************************************************

        Array of connections 

    ***************************************************************************/

    struct DrizzleRequest
    {
        char[] query;
        ubyte[QueryCallback.sizeof] callback;
        ubyte[RequestContext.sizeof] context;
    }

    package RequestQueue!(DrizzleRequest) connections;
    
    QueueFullException queue_full_exc;
    
    /***************************************************************************

        Constructor. Creates a new LibDrizzleEpoll instance

        Params:
            epoll       = EpollSelectDispatcher instance to use
            host        = Address of the server to connect to
            port        = Port of the Server to connect to
            username    = Username to use for logging in
            password    = Password to use for logging in
            database    = Database to use
            bytes       = How many bytes the queue is able to store
            connections = Amount of connections to use

    ***************************************************************************/

    this ( EpollSelectDispatcher epoll, char[] host, in_port_t port,
           char[] username, char[] password, char[] database, 
           size_t bytes, size_t connections = 1 )
    {
        this(epoll, host, username, password, database, bytes, connections);
        this.port = port;
    }

    /***************************************************************************

        Constructor. Creates a new LibDrizzleEpoll instance

        Note: according to a little benchmark over the local
              network, 10 connections are a reasonable value.
              It didn't get much better after that.

        Params:
            epoll       = EpollSelectDispatcher instance to use
            host        = Address of the server to connect to
            username    = Username to use for logging in
            password    = Password to use for logging in
            database    = Database to use
            bytes       = How many bytes the queue is able to store
            connections = Amount of connections to use

    ***************************************************************************/

    this ( EpollSelectDispatcher epoll, char[] host, char[] username, 
           char[] password, char[] database, size_t bytes,
           size_t connections = 10 )
    in
    {
        assert (epoll !is null, "Epoll is null");
    }
    body
    {
        this.epoll         = epoll;
        
        this.host     = toStringz(host);
        this.username = toStringz(username);
        this.password = toStringz(password);
        this.database = toStringz(database);
        this.port     = 3306;

        this.connections = new RequestQueue!(DrizzleRequest)(connections, bytes);
        
        if (null == drizzle_create(&this.drizzle))
        {
            throw new Exception("Could not initialize libdrizzle instance!");
        }

        drizzle_add_options(&this.drizzle, drizzle_options_t.DRIZZLE_NON_BLOCKING);
        drizzle_set_event_watch_fn(&this.drizzle, &drizzleCallback, cast(void*) this);
      
        for (uint i = 0; i < connections; ++i)
        {
            this.connections.handlerWaiting(new Connection(this));
        }
        
        this.queue_full_exc = new QueueFullException;
    }
    
    /***************************************************************************

        Number of requests stored in the queue
    
    ***************************************************************************/

    final public size_t requests ( )
    {
        return this.connections.length;
    }
        
    /***************************************************************************
    
        Returns how many handlers are waiting for data
    
    ***************************************************************************/
        
    final public size_t waitingHandlers ( )
    {
        return this.connections.waitingHandlers;
    }
                   
    /***************************************************************************
    
        Returns how many handlers exist
    
    ***************************************************************************/
        
    final public size_t existingHandlers ( )
    {
        return this.connections.existingHandlers;
    }
    
    /***************************************************************************

        Used size in the queue

        Returns:
            how much of the queue is used up. 
            Return value ranges are [0..1]
    
    ***************************************************************************/

    final public float queueUse ( )
    {
        with (this.connections) 
        {
            return cast(float) usedSpace / cast(float) (usedSpace + freeSpace);
        }
    }
    
    /***************************************************************************

        Adds a new query to the internal queue.
        
        The QueryCallback is defined in Connection.d and
        must have the following signature:
        
            void delegate ( RequestContext context, 
                            Result result, 
                            Exception exception )

        CallbackParams:
            context   = An arbitrary context object set by the user
            result    = Result Object providing functions and iterators to 
                        access the result. Will be null in case of an error.
            exception = null on success, else the exception that was thrown. 
                        If it was a drizzle/sql error the exception is of type 
                        DrizzleException and contains the failed query along 
                        with a message of what went wrong.
                        (Though, drizzle provides rather rudimentary 
                         error descriptions)
                
        Note however that drizzle provides rather rudimentary 
        error descriptions.
        
        Params:
            query = query to send
            cb    = callback to call on success or error
            rc    = request context to pass to the callback

        Returns:
            true if the query could be added to the queue,
            false if the queue is full

    ***************************************************************************/

    public bool query ( char[] query, QueryCallback cb, 
                        RequestContext rc = RequestContext.init )
    {
        DrizzleRequest req;
        
        req.query = query;
        req.callback[] = (cast(ubyte*)&cb)[0 .. cb.sizeof];
        req.context[] =  (cast(ubyte*)&rc)[0 .. rc.sizeof];

        auto added = connections.push(req);
        
        if ( added == false )
        {
            cb(rc, null, queue_full_exc.reset(query, 
                                        drizzle_return_t.DRIZZLE_RETURN_INTERNAL_ERROR, 
                                        "Queue full", null));
        }
        
        return added;
    }
    
    /***************************************************************************

        Returns whether the query would fit on the queue
        
        Params:
            query = query to test

    ***************************************************************************/

    public bool mayQuery ( char[] query )
    {
        return connections.willFit(query.length + 
                                   RequestContext.sizeof + 
                                   QueryCallback.sizeof);
    }

    /***************************************************************************

        Drizzle uses this callback to show interest in certain events for the
        given connection.

        Params:
            con     = connection that has changed the events it is interested in. 
                      Use drizzle_con_fd() to get the file descriptor.
            action  = A bit mask of POLLIN | POLLOUT, specifying if the connection
                      is waiting for read or write events.
            context = Application context pointer registered 
                      with drizzle_set_event_watch_fn(). In our case this is
                      the LibDrizzleEpoll instance.

    ***************************************************************************/

    static private extern (C) drizzle_return_t drizzleCallback ( drizzle_con_st* con, 
                                                                 short action, 
                                                                 void* context)
    {
        auto connection = cast(Connection) drizzle_con_context(con);
        auto instance   = cast(LibDrizzleEpoll) context;

        ISelectClient.Event events;

        if (action & Event.Read)  events |= Event.Read;

        if (action & Event.Write) events |= Event.Write;

        connection.setEvents(events);
        connection.fd = cast(ISelectable.Handle) drizzle_con_fd(con);

        try 
        {
            instance.epoll.register(connection);
        }
        catch (Exception e)
        {
            debug (Drizzle) Trace.formatln("DrizzleCallbackException: {}", 
                                           e.msg);
            
            connection.callbackError(e);
            
            return drizzle_return_t.DRIZZLE_RETURN_COULD_NOT_CONNECT;
        }

        return drizzle_return_t.DRIZZLE_RETURN_OK;
    }
    
    /***************************************************************************

        suspend the processing of the queue
    
    ***************************************************************************/

    public void suspend ( )
    {
        this.connections.suspend();
    }
    
    /***************************************************************************

        resume the processing of the queue
    
    ***************************************************************************/

    public void resume ( )
    {
        this.connections.resume();
    }
}
