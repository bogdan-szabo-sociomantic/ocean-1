/*******************************************************************************

    libcurl multi interface

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        September 2010: Initial release

    authors:        Gavin Norman

    Asynchronous fetching of content from one or more urls.

    See:
    
        http://curl.haxx.se/libcurl/c/libcurl-multi.html

    Usage example:

    ---

        size_t receiveContent ( char[] url, char[] content )
        {
            Trace.formatln("Curl received content from '{}': '{}'", url, content);
            return content.length;
        }

        void initConnection ( LibCurl connection )
        {
            const user_agent = "User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.3; de; rv:1.9.1.10) Gecko/2009102316 Firefox/3.1.10";

            connection.setUserAgent(user_agent);
            connection.setGzipEncoding();
        }

        scope curl = new LibCurlMulti();

        curl.read("http://www.sociomantic.com/", &initConnection, &receiveContent);
        curl.read("http://curl.haxx.se/libcurl/c/libcurl-multi.html", &initConnection, &receiveContent);

        curl.eventLoop(); // execution blocks until all requests processed

    ---

*******************************************************************************/

module ocean.net.client.curl.LibCurlMulti;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import ocean.core.ObjectPool;

public import ocean.core.Exception: assertEx, CurlException;

public import ocean.net.client.curl.LibCurl;

private import ocean.net.client.curl.c.multi;

private import tango.stdc.posix.sys.select;

debug private import tango.util.log.Trace;



/*******************************************************************************

    A single curl_easy request suitable for storing in an ObjectPool and
    registering with a curl multi-stack as part of an asynchronous request.
    
*******************************************************************************/

class CurlConnection : LibCurl, Resettable
{
    /***************************************************************************
    
        Handle of curl multi which this request is registered to
            
    ***************************************************************************/

    private CURLM curlm;


    /***************************************************************************
    
        Sets up this curl request and adds it to the specified multi-stack.
        
        The request is not actually activated at this point, it is simply
        registered in the multi stack.

        Params:
            curlm = handle of curl multi which this request is to be registered
                    to
            read_dg = delegate to call when content is received for this request

    ***************************************************************************/

    public void addToCurlMulti ( CURLM curlm, char[] url, LibCurl.ReadDg read_dg )
    {
        this.curlm = curlm;
        this.setupRead(url, read_dg);
        curl_multi_add_handle(this.curlm, this.curl);
    }


    /***************************************************************************

        Called when this object is returned to the object pool from whence it
        came.

        Removes the request from the multi stack it's registered with.
    
    ***************************************************************************/

    void reset ( )
    {
        if ( this.curlm )
        {
            curl_multi_remove_handle(this.curlm, this.curl);
            this.curlm = null;
        }
    }
}



/*******************************************************************************

    Curl asynchronous multi-request class

*******************************************************************************/

class LibCurlMulti
{
    /***************************************************************************
    
        Pool of curl_easy requests
            
    ***************************************************************************/

    private alias ObjectPool!(CurlConnection) ConnectionPool;

    private ConnectionPool conn_pool;


    /***************************************************************************
    
        CurlM status code
            
    ***************************************************************************/
    
    alias           CURLMcode                    CurlMCode;


    /***************************************************************************

        Curl multi handle

    ***************************************************************************/

    private         CURLM                        curlm;


    /***************************************************************************

        Timeout (in milliseconds) for asynchronous transfer (select).
    
    ***************************************************************************/

    private long timeout_ms;


    /***************************************************************************

        Default maximum number of parallel requests
    
    ***************************************************************************/

    public const DEFAULT_MAX_CONNECTIONS = 20;


    /***************************************************************************

        Error codes enum. Combines the curl multi error codes (see
        ocean.net.util.c.multi) with one extra code indicating a select error.

    ***************************************************************************/

    public enum ErrorCode
    {
        CallMultiPerform = -1,
        OK,
        BadHandle,
        BadEasyHandle,
        OutOfMemory,
        InternalError,
        BadSocket,
        UnknownOption,
        SelectTimeout // the call to .select timed out with no events
    }


    /***************************************************************************

        Error callback delegate.

    ***************************************************************************/

    public alias void delegate ( ErrorCode err ) ErrorCallback;

    private ErrorCallback error_dg;


    /***************************************************************************

        Constructor - init curl multi and set options

        Throws:
            if initialisation of libcurl multi fails

    ***************************************************************************/

    public this ( uint max_connections = DEFAULT_MAX_CONNECTIONS )
    {
        this.curlm = curl_multi_init();

        assertEx!(CurlException)(this.curlm, typeof(this).stringof ~ ".this - Error on curl_multi_init!");

        this.setOption(CURLMoption.PIPELINING, 1);
        this.setOption(CURLMoption.MAXCONNECTS, max_connections);

        this.conn_pool = new ConnectionPool;
        this.conn_pool.limit(max_connections);
    }


    /***************************************************************************

        Desctructor - close curl session. (Note that the pool of curl easy
        connections will be automatically cleaned up when the object pool is
        destroyed.)

    ***************************************************************************/

    public ~this ( )
    {
        if ( !(this.curlm is null) )
        {
            curl_multi_cleanup(this.curlm);
            this.curlm = null;
        }
    }


    /***************************************************************************

        Sets up a request to read content from Url, if there is a free
        connection.

        Params:
            url = url to download content from
            init_dg = delegate which is passed the curl easy connection for
                initialisation (setting up authorisation or encoding options,
                for example)
            read_dg = delegate to call upon receiving content

        Returns:
            true if the request could be added

    ***************************************************************************/

    public bool read ( char[] url, void delegate ( LibCurl ) init_dg, LibCurl.ReadDg read_dg )
    {
        if ( this.conn_pool.num_idle() == 0 )
        {
            return false;
        }

        auto connection = this.conn_pool.get();
        init_dg(connection);
        connection.addToCurlMulti(this.curlm, url, read_dg);

        return true;
    }


    /***************************************************************************

		Checks whether the given url has already been requested.        

        Params:
            url = url to check

        Returns:
            true if the request has already been added to the connection pool
            
    ***************************************************************************/

    public bool isRequested ( char[] url )
    {
        foreach ( conn; this.conn_pool )
        {
            if ( url == conn.url )
            {
                return true;
            }
        }
        return false;
    }


    /***************************************************************************

        Sets all registered curl requests going. The method does not return
        until all requests have been processed.
    
    ***************************************************************************/

    public void eventLoop ( )
    {
        int num_active_transfers;
        CurlMCode ret;

        do
        {
            do
            {
                ret = curl_multi_perform(this.curlm, &num_active_transfers);
            }
            while ( ret == CurlMCode.CURLM_CALL_MULTI_PERFORM );

            if ( num_active_transfers > 0 )
            {
                ret = this.sleepUntilMoreIO();
                if ( ret != CurlMCode.CURLM_OK )
                {
                    this.error(ret);
                }
            }
        }
        while ( num_active_transfers );

        // Return all requests to the pool
        this.clear();
    }

    
    /***************************************************************************

        Sets the error callback delegate.
        
        Params:
            error_dg = delegate to be called on a select timeout or an error
                code returned from lib curl

    ***************************************************************************/

    public void setErrorCallback ( ErrorCallback error_dg )
    {
        this.error_dg = error_dg;
    }


    /***************************************************************************

        Sets the timeout value for all requests registered in the future.
    
        Params:
            timeout_ms = milliseconds timeout
    
    ***************************************************************************/

    public void setTimeout ( long timeout_ms )
    {
        this.timeout_ms = timeout_ms;
    }


    /***************************************************************************

        Returns:
            number of requests in the multi-stack

    ***************************************************************************/

    public size_t getNumRegisteredRequests ( )
    {
        return this.conn_pool.num_busy();
    }
    

    /***************************************************************************

        Returns:
            number of requests which could yet be added to the multi-stack
    
    ***************************************************************************/

    public size_t getNumFreeRequests ( )
    {
        return this.conn_pool.num_idle();
    }


    /***************************************************************************
    
        Closes all active connections. They are returned to the object pool of
        connections, and can be reused.
        
    ***************************************************************************/

    public void clear ( )
    {
        foreach ( conn; this.conn_pool )
        {
            this.conn_pool.recycle(conn); // calls curl_multi_remove_handle
        }
    }


    /***************************************************************************

        Sets up a select() wait until one of the registered requests has more
        I/O which needs processing.
    
        Returns:
            curl return code
    
    ***************************************************************************/
    
    private CurlMCode sleepUntilMoreIO ( )
    {
        fd_set read_fd_set, write_fd_set, exc_fd_set;
        int max_fd;

        FD_ZERO(&read_fd_set);
        FD_ZERO(&write_fd_set);
        FD_ZERO(&exc_fd_set);

        CurlMCode ret = curl_multi_fdset(this.curlm, &read_fd_set, &write_fd_set, &exc_fd_set, &max_fd);

        if ( ret == CurlMCode.CURLM_OK && max_fd > -1 )
        {
            timeval timeout;
            timeval* timeout_ptr = null;
            if ( this.timeout_ms > 0 )
            {
                timeout.tv_sec = this.timeout_ms / 1000;
                timeout.tv_usec = (this.timeout_ms % 1000) * 1000;
                timeout_ptr = &timeout;
            }

            auto r = .select(max_fd + 1, &read_fd_set, &write_fd_set, &exc_fd_set, timeout_ptr);
            if ( r == 0 )
            {
                this.timeout();
            }
            // TODO: r == -1 indicates an error, with errno set. Check this as well?
        }

        return ret;
    }


    /***************************************************************************
    
        Set LibCurlM Option
            
        Params:
            option = libcurl option to set
            l      = parameter long value
        
        Returns:
            0 on success or Curl error code on failure
        
     **************************************************************************/
    
    private CurlMCode setOption ( CURLMoption option, long l )
    {
        return curl_multi_setopt(this.curlm, option, l);
    }


    /***************************************************************************
        
        Set LibCurlM Option
            
        Params:
            option = libcurl option to set
            p      = parameter value pointer
            
        Returns:
            0 on success or Curl error code on failure
        
     **************************************************************************/

    private CurlMCode setOption ( CURLMoption option, void* p ) 
    {
        return curl_multi_setopt(this.curlm, option, p);
    }


    /***************************************************************************

        Called when a select timeout occurs. Calls the error delegate and resets
        all connections.
    
    ***************************************************************************/
    
    private void timeout ( )
    {
        debug Trace.formatln("{} select timeout", typeof(this).stringof);
    
        if ( this.error_dg )
        {
            this.error_dg(ErrorCode.SelectTimeout);
        }
    
        // Return all requests to the pool
        this.clear();
    }
    
    
    /***************************************************************************
    
        Called when a lib curl error occurs. Calls the error delegate.
    
        Params:
            err_code = code of error which occurred
    
    ***************************************************************************/
    
    private void error ( CurlMCode err_code )
    {
        debug Trace.formatln("{} error: {}", typeof(this).stringof, err_code);
        if ( this.error_dg )
        {
            this.error_dg(cast(ErrorCode)err_code);
        }
    }
}

