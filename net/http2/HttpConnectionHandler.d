/******************************************************************************

    HTTP connection handler base class for use with the SelectListener
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
    Fiber based HTTP server base class, derived from IFiberConnectionHandler.
    
    To build a HTTP server, create a HttpConnectionHandler subclass which
    implements handleRequest() and use that subclass as connection handler in
    the SelectListener.
    
 ******************************************************************************/

module ocean.net.http2.HttpConnectionHandler;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.net.http2.HttpRequest,
               ocean.net.http2.HttpResponse,
               ocean.net.http2.HttpException;

private import ocean.net.http2.consts.StatusCodes: StatusCode;
private import ocean.net.http2.consts.HttpMethod: HttpMethod;

private import ocean.io.select.model.IFiberConnectionHandler,
               ocean.io.select.protocol.fiber.model.IFiberSelectProtocol;

private import tango.io.Stdout;

/******************************************************************************/

abstract class HttpConnectionHandler : IFiberConnectionHandler
{
    /**************************************************************************

        Type aliases as convenience for a subclass
    
     **************************************************************************/

    protected alias .StatusCode   StatusCode;
    protected alias .HttpRequest  HttpRequest;
    protected alias .HttpResponse HttpResponse;
    protected alias .HttpMethod   HttpMethod;
    protected alias .HttpException HttpException;
    
    /**************************************************************************

        HTTP request message parser and response message generator
    
     **************************************************************************/

    protected HttpRequest   request;
    protected HttpResponse  response;
    
    /**************************************************************************

        Reused exception instance; may be thrown by a subclass as well.
        
     **************************************************************************/

    protected HttpException             http_exception;
    
    /**************************************************************************

        Maximum number of requests through the same connection when using
        persistent connections; 0 disables using persistent connections.
        
     **************************************************************************/

    protected uint keep_alive_maxnum = 0;
    
    /**************************************************************************

        Status code for the case when a message parse error occurs or required
        message header parameters are missing
        
     **************************************************************************/

    protected StatusCode default_exception_status_code = StatusCode.InternalServerError;
    
    /**************************************************************************

        Supported HTTP methods, set in the constructor (only checked for element
        existence; the actal value is irrelevant)
        
     **************************************************************************/

    private bool[HttpMethod] supported_methods;
    
    /**************************************************************************

        Constructor
        
        Uses the default request message parser/response generator settings;
        that is, the request parser will 
        
        Params:
            dispatcher        = select dispatcher instance to register to
            finalizer         = called when the connection is shut down
                                (optional, may be null)
            supported_methods = list of supported HTTP methods
            
     **************************************************************************/

    public this ( EpollSelectDispatcher dispatcher, FinalizeDg finalizer,
                  HttpMethod[] supported_methods ... )
    {
        this(dispatcher, finalizer, new HttpRequest, new HttpResponse, supported_methods);
    }
    
    /**************************************************************************

        Constructor
        
        Params:
            dispatcher        = select dispatcher instance to register to
            request           = request message parser 
            response          = 
            finalizer         = called when the connection is shut down
                                (optional, may be null)
            supported_methods = list of supported HTTP methods
            
     **************************************************************************/

    public this ( EpollSelectDispatcher dispatcher, FinalizeDg finalizer,
                  HttpRequest request, HttpResponse response,
                  HttpMethod[] supported_methods ... )
    {
        super(dispatcher, finalizer);
        
        this.request  = request;
        this.response = response;
        this.http_exception = new HttpException;
        
        foreach (method; supported_methods)
        {
            this.supported_methods[method] = true;
        }
        
        this.supported_methods.rehash;
    }
    
    /**************************************************************************

        Handles an incoming HTTP request. (Implements an abstract method.)
            
        Params:
            n = number of request that have been handled before through the same
                connection
                
        Returns:
            true if the connection should stay persistent for the next request
            or false if it should be closed.
            
     **************************************************************************/

    final bool handle ( uint n )
    {
        bool more = false;
        
        try
        {
            StatusCode status; 
            
            char[] response_msg_body;
            
            try
            {
                this.request.reset();
                
                super.reader.reset().read((void[] data)
                {
                    return this.request.parse(cast (char[]) data, this.request_msg_body_length);
                });
                
                this.http_exception.assertEx(this.request.method in this.supported_methods,
                                             StatusCode.NotImplemented);
                
                status = this.handleRequest(response_msg_body);
                
                more = n < this.keep_alive_maxnum && this.keep_alive;
            }
            catch (HttpException e)
            {
                more   = this.handleHttpServerException(e);
                status = e.status;
            }
            catch (HttpServerException e)
            {
                more   = this.handleHttpServerException(e);
                status = this.default_exception_status_code;
            }
            
            super.register(super.writer);
            
            if (more)
            {
                super.writer.finalizer = null;
            }
            
            with (this.response)
            {
                http_version = this.request.http_version;
                
                set(HeaderFieldNames.Connection, more? "Keep-Alive" : "close");
                
                super.writer.send(render(status, response_msg_body));
            }
        }
        catch (IFiberSelectProtocol.IOError e)
        {
            Stderr(typeof (this).stringof ~ " - IOException - ")(e.msg)(" @")(e.file)(':')(e.line)("\n").flush();
        }
        catch (IFiberSelectProtocol.IOWarning e)
        {
            Stderr(e.msg)(" @")(e.file)(':')(e.line)("\n").flush();
        }
        
        return more;
    }
    
    /**************************************************************************

        Tells the request message body length.
        
        Params:
            e = HTTP server exception e which was thrown while parsing the
                request message or from handleRequest()
                
        Returns:
            true if the connection may stay persistent or false if it must be
            closed after the response has been sent.
            
        Throws:
            HttpException (use the http_exception member) with status set to the
            appropriate status code to abort request processing and immediately
            send the response.
        
     **************************************************************************/

    abstract protected StatusCode handleRequest ( out char[] response_msg_body );

    /**************************************************************************

        Tells the request message body length.
        This method should be overridden when a request message body is
        expected. It is invoked when the message header is completely parsed.
        The default behaviour is expecting no request message body.
        
        Returns:
            the request message body length in bytes (0 indicates that no
            request message body is expected)
        
        Throws:
            HttpException (use the http_exception member) with status set to
                - status.RequestEntityTooLarge to reject a request whose message
                  body is too long or
                - an appropriate status to abort request processing and
                  immediately send the response if the message body length
                  cannot be determined, e.g. because required request header
                  parameters are missing.

        
     **************************************************************************/
    
    protected size_t request_msg_body_length ( )
    {
        return 0;
    }
    
    /**************************************************************************

        Handles HTTP server exception e which was thrown while parsing the
        request message or from handleRequest() or request_msg_body_length().
        A subclass may override this method to be notified when an exception is
        thrown and decide whether the connection may stay persistent or must be
        closed after the response has been sent.
        The default behaviour is allowing the connection being persistent unless
        the status code indicated by the exception is 413: Request Entity Too
        Large.
        If e was downcast from HttpServerException, e.status will determine the
        response status code. A subclass may set the status code by changing
        e.status.
        
        Params:
            e = HTTP server exception e which was thrown while parsing the
                request message or from handleRequest() or
                request_msg_body_length(). If it is HttpServer instance,
                (cast (HttpServer) e).status reflects the response status code
                and may be changed when overriding this method.
                
        Returns:
            true if the connection may stay persistent or false if it must be
            closed after the response has been sent.
            
     **************************************************************************/

    protected bool handleHttpServerException ( HttpServerException e )
    {
        bool keep_going = true;
        
        HttpException http_exception = cast (HttpException) e;
        
        if (http_exception !is null)
        {
            Stderr(http_exception.status_phrase)(" - ");
            
            switch (http_exception.status)
            {
                case http_exception.status.RequestEntityTooLarge:
                    keep_going = false;
                
                default:
            }
        }
        
        Stderr(e.msg)("\n").flush();
        
        return keep_going;
    }
    
    /**************************************************************************

        Closes the connection when this instance is finalized.
        
     **************************************************************************/

    override void finalize ( )
    {
        super.closeSocket();
        super.finalize();
    }
    
    /**************************************************************************

        Detects whether the connection should stay persistent or not.
        
        Returns:
            true if the connection should stay persistent or false if not
        
     **************************************************************************/

    private bool keep_alive ( )
    {
        switch (this.request.http_version)
        {
            case this.request.http_version.v1_1:
                return !this.request.matches("connection", "close");
         
            case this.request.http_version.v1_0:
            default:
                return this.request.matches("connection", "keep-alive");
        }
    }
}
