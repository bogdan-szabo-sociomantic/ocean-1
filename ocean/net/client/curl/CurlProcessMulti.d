/*******************************************************************************

    HTTP request functionality using a set of child processes running curl.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        January 2012: Initial release
                    August  2012: Added support for other request then get.

    authors:        Gavin Norman, Hans Bjerkander

    Usage example:

    ---

import ocean.io.Stdout;
import ocean.net.client.curl.CurlProcessMulti;
import ocean.io.select.EpollSelectDispatcher;
import ocean.core.ContextUnion;
import ocean.net.client.curl.process.NotificationInfo;

void main()
{
        char[] rec_data;
        char[] err_data;
        bool ok,err;
        
        void rec ( ContextUnion context, char[] url, ubyte[] data )
        {
            rec_data ~= cast( char[] ) data;
            Stdout.formatln("{}",rec_data);
        }
        void not ( NotificationInfo info )
        {
            ok = info.succeeded ( );
        }
        void error ( ContextUnion context, char[] url, ubyte[] data )
        {
            err_data ~= cast(char[])data;
            err = true;
        }     
        
        // Create epoll selector instance.
        auto epoll = new EpollSelectDispatcher;
    
        // Create a curl downloads instance which can process a maximum of 10
        // requests in parallel.
        const max_processes = 10;
        auto curl = new QueuedRequests(epoll, max_processes, size_t.max);
    
        // Initialise some downloads, one with authorization.
        
        curl.assign( curl.get("http://www.google.com",    &rec, &error, &not) );
        curl.assign( curl.get("http://www.wikipedia.org", &rec, &error, &not) );
        curl.assign( curl.get(
            "http://www.zalando.de/var/export/display_zalando_de.csv",
            &rec, &error, &not)
            .authenticate("zalando-user", "dewE23#f4") );
    
        // Handle arriving data.
        epoll.eventLoop;
}

    ---

    TODO: the structure of this client is very similar to the swarm clients. It
    could perhaps be integrated, if it were either moved to swarm, or if the
    core of swarm were moved to ocean. Not sure which would make more
    sense. Two great benefits of integration would be a common interface and a
    base of shared code (leading to greater stability and wider functionality in
    all sharing clients).

    It'd require the creation of a client base class which did not assume the
    existence of a multi-node structure (this makes no sense in the context of
    curl, which can download from any number of different urls). This would
    probably be a nice thing to do though, and would make the creation of
    further such fully-featured clients much easier in the future.

*******************************************************************************/

module ocean.net.client.curl.CurlProcessMulti;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.net.client.curl.process.RequestParams;

private import ocean.net.client.curl.CurlProcessSingle;

private import ocean.net.client.curl.process.ExitStatus;
private import ocean.net.client.curl.process.NotificationInfo;
private import ocean.net.client.curl.process.RequestSetup;

private import ocean.core.ContextUnion;

private import ocean.core.ObjectPool;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.io.serialize.StructSerializer;

private import ocean.util.container.queue.FlexibleRingQueue;

debug private import ocean.io.Stdout;



/*******************************************************************************

    Class encapsulating a set of one or more parallel url request using curl.
    The maximum number of parallel requests is set in the constructor. When all
    requests are busy, any further requests which are assigned will simply be
    ignored.

*******************************************************************************/

public abstract class CurlRequests
{
    /***************************************************************************

        Local type aliases.

    ***************************************************************************/

    public alias ContextUnion Context;

    public alias .NotificationInfo NotificationInfo;

    public alias .ExitStatus ExitStatus;

    public alias CurlProcess.HttpStatus HttpStatus;


    /***************************************************************************

        Curl process which request with a url. Class derived in order to allow 
        it to be used in a Pool. The pool (in the outer class) needs to be 
        notified when a request has finished, so that it can be recycled.

    ***************************************************************************/

    private class CurlRequestProcess : CurlProcess
    {
        /***********************************************************************

            Object pool index -- allows the construction of a pool of objects of
            this type.

        ***********************************************************************/

        public uint object_pool_index;


        /***********************************************************************

            Constructor.

        ***********************************************************************/

        public this ( )
        {
            super(this.outer.epoll);
        }


        /***********************************************************************

            Called when the process has finished. Calls the super method for the
            standard behaviour, and also notifies the outer class that this
            request can be recycled.

            Params:
                exited_ok = if true, the process exited normally and the
                    exit_code parameter is valid. Otherwise the process exited
                    abnormally, and exit_code will be 0.
                exit_code = the process' exit code, if exited_ok is true.
                    Otherwise 0.

        ***********************************************************************/

        override protected void finished ( bool exited_ok, int exit_code )
        {
            super.finished(exited_ok, exit_code);
            this.outer.requestFinished(this);
        }
    }


    /***************************************************************************

        Maximum number of concurrent processes.

    ***************************************************************************/

    public const size_t max;


    /***************************************************************************

        Pool of requests processes.

    ***************************************************************************/

    private alias Pool!(CurlRequestProcess) RequestPool;

    private const RequestPool requests;


    /***************************************************************************

        Epoll selector used by processes. Passed as a reference to the
        constructor.

    ***************************************************************************/

    private const EpollSelectDispatcher epoll;


    /***************************************************************************

        Flag which is set when requests are suspended using the supsend()
        method. Reset by resume(). When suspended_ is true, no new requests may
        be assigned.

    ***************************************************************************/

    private bool suspended_;


    /***************************************************************************

        Constructor.

        Params:
            epoll = epoll dispatcher to use
            max = maximum number of concurrent request processes

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, size_t max )
    {
        this.epoll = epoll;
        this.max = max;

        this.requests = new RequestPool;
    }


    /***************************************************************************

        Struct describing a request with no data to send.

    ***************************************************************************/
    
    private struct BaseRequest
    {
        mixin RequestBase; //contains the base functionality
    }    


    /***************************************************************************

        Struct describing a request with the possibility to send data.

    ***************************************************************************/

    private struct DataRequest
    {
        mixin RequestBase; //contains the base functionality
        mixin RequestData; //contains the data method        
    }


    /***************************************************************************

        Sets up a BaseRequest struct describing a get request. Any desired
        methods of the struct should be called (to configure optional settings),
        and it should be passed to the assign() method to start the request.

        Params:
            url = url to use
            receive_dg = delegate which will be called when data is received
                from the url
            error_dg = delegate which will be called when error data are
                sent from curl
            finished_dg = delegate which will be called when the request
                process changes status.

        Returns:
            BaseRequest struct to be passed to assign

    ***************************************************************************/

    public BaseRequest get ( char[] url, CurlReceiveDg receive_dg,
            CurlReceiveDg error_dg, CurlNotificationDg finished_dg)
    {
        return BaseRequest (url, receive_dg, error_dg, finished_dg, "GET");
    }


    /***************************************************************************

        The old version of this class had a method called download whith the 
        same functionality and arguments as get. This alias exist only for
        backwards compatibility.

    ***************************************************************************/

    public alias get download;


    /***************************************************************************

        Sets up a BaseRequest struct describing a delete request. Any desired
        methods of the struct should be called (to configure optional settings),
        and it should be passed to the assign() method to start the request.

        Params:
            url = url to use
            receive_dg = delegate which will be called when data is received
                from the url
            error_dg = delegate which will be called when error data are
                sent from curl
            finished_dg = delegate which will be called when the request
                process changes status.

        Returns:
            BaseRequest struct to be passed to assign

    ***************************************************************************/

    public BaseRequest del ( char[] url, CurlReceiveDg receive_dg,
            CurlReceiveDg error_dg, CurlNotificationDg finished_dg)
    {
        return BaseRequest (url, receive_dg, error_dg, finished_dg, "DELETE");
    }


    /***************************************************************************

        Sets up a DataRequest struct describing a post request. Any desired
        methods of the struct should be called (to configure optional settings),
        and it should be passed to the assign() method to start the request.

        Params:
            url = url to use
            receive_dg = delegate which will be called when data is received
                from the url
            error_dg = delegate which will be called when error data are
                sent from curl
            finished_dg = delegate which will be called when the request
                process changes status.

        Returns:
            BaseRequest struct to be passed to assign

    ***************************************************************************/
    
    public DataRequest post (char[] url, CurlReceiveDg receive_dg,
            CurlReceiveDg error_dg, CurlNotificationDg finished_dg, char[] data)
    {
        return *DataRequest (url, receive_dg, error_dg, finished_dg, "POST").
            setRequestData (data);
    }


    /***************************************************************************

        Sets up a DataRequest struct describing a put request. Any desired
        methods of the struct should be called (to configure optional settings),
        and it should be passed to the assign() method to start the request.

        Params:
            url = url to use
            receive_dg = delegate which will be called when data is received
                from the url
            error_dg = delegate which will be called when error data are
                sent from curl
            finished_dg = delegate which will be called when the request
                process changes status.

        Returns:
            BaseRequest struct to be passed to assign

    ***************************************************************************/
    
    public DataRequest put (char[] url, CurlReceiveDg receive_dg,
            CurlReceiveDg error_dg, CurlNotificationDg finished_dg, char[] data)
    {
        return *DataRequest (url, receive_dg, error_dg, finished_dg, "PUT").
            setRequestData (data);
    }


    /***************************************************************************

        Assigns a new request as described by a BaseRequest or DataRequest 
        struct.

        This method accepts either a struct, or a pointer to such a struct.

        Params:
            setup = a struct or pointer to a struct describing a new request

        Returns:
            true if the request was started, or false if all processes are 
            busy or suspended.

    ***************************************************************************/

    public bool assign (T) ( T setup )
    {
        if ( this.all_busy || this.suspended_ )
        {
            return false;
        }

        auto dl = this.requests.get(new CurlRequestProcess);
        dl.start(setup.params);

        return true;
    }


    /***************************************************************************

        Returns:
            the number of currently active requests

    ***************************************************************************/

    public size_t num_busy ( )
    {
        return this.requests.num_busy;
    }


    /***************************************************************************

        Returns:
            true if all request processes are busy

    ***************************************************************************/

    public bool all_busy ( )
    {
        return this.num_busy == this.max;
    }


    /***************************************************************************

        Suspends all active requests.

    ***************************************************************************/

    public void suspend ( )
    {
        if ( this.suspended_ )
        {
            return;
        }

        this.suspended_ = true;

        scope active_requests = this.requests.new BusyItemsIterator;
        foreach ( dl; active_requests )
        {
            dl.suspend;
        }
    }


    /***************************************************************************

        Returns:
            true if the request processes are suspended

    ***************************************************************************/

    public bool suspended ( )
    {
        return this.suspended_;
    }


    /***************************************************************************

        Resumes any suspended requests.

    ***************************************************************************/

    public void resume ( )
    {
        if ( !this.suspended_ )
        {
            return;
        }

        this.suspended_ = false;

        scope active_requests = this.requests.new BusyItemsIterator;
        foreach ( dl; active_requests )
        {
            dl.resume;
        }
    }


    /***************************************************************************

        Called when a request process finishes. Recycles the request process
        to the pool.

        Params:
            process = request process which has just finished

    ***************************************************************************/

    protected void requestFinished ( CurlRequestProcess process )
    {
        this.requests.recycle(process);
    }
}


/*******************************************************************************

    Expands the CurlRequests class with a requests queue. When all requests
    are busy, any further requests which are assigned will be pushed into the
    queue and processed when one of the active request processes becomes free.

*******************************************************************************/

public class QueuedRequests : CurlRequests
{
    /***************************************************************************

        Queue used to store requests which are assigned when all requests
        processes are busy or when requests is suspended.

    ***************************************************************************/

    private const FlexibleByteRingQueue queue;


    /***************************************************************************

        Constructor.

        Params:
            epoll = epoll dispatcher to use
            max = maximum number of concurrent request processes
            queue_size = maximum size of request queue (in bytes)

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, size_t max, size_t queue_size )
    {
        super(epoll, max);

        this.queue = new FlexibleByteRingQueue(queue_size);
    }


    /***************************************************************************

        Assigns a new request as described by a BaseRequest or DataRequest 
        struct.

        This method accepts either a struct, or a pointer to such a struct.

        Params:
            setup = a struct or pointer to a struct describing a new request

        Returns:
            true if the request was started, or false if all processes are 
            busy or suspended.

    ***************************************************************************/

    public bool assign (T) ( T setup )
    {
        if ( this.all_busy || this.suspended_ )
        {
            auto length = StructSerializer!().length(&setup.params);

            auto target = this.queue.push(length);
            if ( target is null )
            {
                return false;
            }
            
            StructSerializer!().dump(&setup.params, target);

            auto notification_dg = setup.params.notification_dg.get();
            
            notification_dg(NotificationInfo(NotificationInfo.Type.Queued,
                        setup.params.context.get(), setup.params.url));

            return true;
        }

        auto dl = this.requests.get(new CurlRequestProcess);
        dl.start(setup.params);

        return true;
    }


    /***************************************************************************

        Returns:
            the number of queued requests

    ***************************************************************************/

    public size_t num_queued ( )
    {
        return this.queue.length;
    }


    /***************************************************************************

        Called when a request process finishes. Recycles the request to the
        pool (by calling the super method), and pops the next request from the
        queue, if one is waiting.

        Params:
            process = request process which has just finished

    ***************************************************************************/

    override protected void requestFinished ( CurlRequestProcess process )
    {
        super.requestFinished(process);

        assert(this.requests.num_idle > 0);

        // pop from queue
        if ( !this.queue.is_empty )
        {
            auto serialized_setup = this.queue.pop;

            auto dl = this.requests.get(new CurlRequestProcess);
            dl.start(serialized_setup);
        }
    }
}