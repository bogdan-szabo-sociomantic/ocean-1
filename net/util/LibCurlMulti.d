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
        }

        scope curl = new LibCurlMulti();
        const char[] user_agent = "User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.3; de; rv:1.9.1.10) Gecko/2009102316 Firefox/3.1.10";
        curl.setUserAgent(user_agent);

        curl.read("http://www.sociomantic.com/", &receiveContent);
        curl.read("http://curl.haxx.se/libcurl/c/libcurl-multi.html", &receiveContent);

        curl.eventLoop(); // execution blocks until all requests processed

    ---

*******************************************************************************/

module net.util.LibCurlMulti;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.net.util.LibCurl;

private import ocean.net.util.c.multi;

private import ocean.core.Array;

private import ocean.core.ObjectPool;

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

        User agent for curl requests
    
    ***************************************************************************/

    private char[] user_agent;

    
    /***************************************************************************

        Default maximum number of parallel requests
    
    ***************************************************************************/

    // TODO: lower values seem better - 200 seems slow - test this
    public const DEFAULT_MAX_CONNECTIONS = 20;


    /***************************************************************************

        Constructor - init curl multi and set options

    ***************************************************************************/

    public this ( uint max_connections = DEFAULT_MAX_CONNECTIONS )
    {
        this.curlm = curl_multi_init();
        assert (this.curlm, typeof(this).stringof ~ ".this - Error on curl_multi_init!");

//        this.setOption(CURLMoption.SOCKETFUNCTION, &this.socketCallback);
        this.setOption(CURLMoption.PIPELINING, 1);
        this.setOption(CURLMoption.MAXCONNECTS, max_connections);

        this.conn_pool = new ConnectionPool();
        this.conn_pool.limit(max_connections);
    }


    /***************************************************************************
    
        Desctructor - close curl session
            
    ***************************************************************************/

    public ~this ( )
    {
        this.close();
    }


    /***************************************************************************

        Sets up a request to read content from Url, if there is a free
        connection.

        Params:
            url = url to download content from
            read_dg = delegate to call upon receiving content

        Returns:
            true if the request could be added
            
    ***************************************************************************/

    public bool read ( char[] url, LibCurl.ReadDg read_dg )
    {
        if ( this.conn_pool.getNumAvailableItems() == 0 )
        {
            return false;
        }

        auto connection = this.conn_pool.get();
        connection.addToCurlMulti(this.curlm, url, read_dg);
        connection.setUserAgent(this.user_agent);

        return true;
    }


    /***************************************************************************

        Sets all registered curl requests going. The method does not return
        until all requests have been processed.
    
    ***************************************************************************/

    public void eventLoop ( )
    {
        int active;
        CurlMCode ret;

        do
        {
            do
            {
                ret = curl_multi_perform(this.curlm, &active);
            }
            while ( ret == CurlMCode.CURLM_CALL_MULTI_PERFORM );

            if ( active )
            {
                ret = this.sleepUntilMoreIO();
            }
        }
        while ( active );

        // Return all requests to the pool
        foreach ( conn; this.conn_pool )
        {
            conn.recycle();
        }
    }


    /***************************************************************************

        Sets the user agent string for all requests registered in the future.

        Params:
            user_agent = user agent string
    
    ***************************************************************************/

    public void setUserAgent ( char[] user_agent )
    {
        this.user_agent.copy(user_agent);
    }

    
    /***************************************************************************

        Returns:
            number of requests in the multi-stack

    ***************************************************************************/

    public size_t getNumRegisteredRequests ( )
    {
        return this.conn_pool.getNumItems();
    }
    

    /***************************************************************************

        Returns:
            number of requests which could yet be added to the multi-stack
    
    ***************************************************************************/

    public size_t getNumFreeRequests ( )
    {
        return this.conn_pool.getNumAvailableItems();
    }


    /***************************************************************************
    
        Close curl session. Cleans up all curl easy connections.
        
    ***************************************************************************/

    public void close ( )
    {
        foreach ( conn; this.conn_pool )
        {
            auto handle = conn.curl;
            conn.recycle(); // calls curl_multi_remove_handle
            curl_easy_cleanup(handle);
        }

        curl_multi_cleanup(this.curlm);
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
        // TODO: check ret?

        long timeout_ms;
        ret = curl_multi_timeout(this.curlm, &timeout_ms);
        // TODO: check ret?

        long timeout_s = timeout_ms / 1000;
        long timeout_us = (timeout_ms % 1000) * 1000;
        timeval timeout = { timeout_s, timeout_us };

        if ( max_fd > -1 )
        {
            .select(max_fd + 1, &read_fd_set, &write_fd_set, &exc_fd_set, &timeout);
            // TODO: check ret?
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
}

