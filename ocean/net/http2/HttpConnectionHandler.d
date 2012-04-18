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
private import ocean.net.http2.consts.HeaderFieldNames;

private import ocean.io.select.model.IFiberConnectionHandler,
               ocean.io.select.protocol.fiber.model.IFiberSelectProtocol;

private import ocean.core.ErrnoIOException;

/******************************************************************************/

abstract class HttpConnectionHandler : IFiberConnectionHandler
{
    /**************************************************************************

        Type aliases as convenience for a subclass
    
     **************************************************************************/

    protected alias .StatusCode                         StatusCode;
    protected alias .HttpRequest                        HttpRequest;
    protected alias .HttpResponse                       HttpResponse;
    protected alias .HttpMethod                         HttpMethod;
    protected alias .HttpException                      HttpException;
    protected alias .HttpServerException                HttpServerException;
    protected alias .ErrnoIOException                   ErrnoIOException;
    protected alias .IFiberSelectProtocol.IOError       IOError;
    protected alias .IFiberSelectProtocol.IOWarning     IOWarning;
    
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

    protected this ( EpollSelectDispatcher dispatcher, FinalizeDg finalizer,
                     HttpMethod[] supported_methods ... )
    {
        this(dispatcher, finalizer, new HttpRequest, new HttpResponse, supported_methods);
    }
    
    /**************************************************************************

        Constructor
        
        Params:
            dispatcher        = select dispatcher instance to register to
            request           = request message parser
            response          = response message generator
            finalizer         = called when the connection is shut down
                                (optional, may be null)
            supported_methods = list of supported HTTP methods
            
     **************************************************************************/

    protected this ( EpollSelectDispatcher dispatcher, FinalizeDg finalizer,
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
    
        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)
    
     **************************************************************************/

    protected override void dispose ( )
    {
        super.dispose();
        
        delete this.request;
        delete this.response;
        delete this.http_exception;
    }
    
    /***************************************************************************
    
        Connection handler method.
        
    ***************************************************************************/

    final protected void handle ( )
    {
        bool keep_alive = false;
        
        uint n = 0;
        
        try
        {
            super.reader.reset();
            
            do
            {
                StatusCode status = StatusCode.OK; 
                
                char[] response_msg_body = null;
                
                try
                {
                    this.receiveRequest();
                    
                    keep_alive = n? n < this.keep_alive_maxnum :
                                    this.keep_alive_maxnum && this.keep_alive;
                    
                    n++;
                    
                    status = this.handleRequest(response_msg_body);
                }
                catch (HttpException e)
                {
                    keep_alive &= this.handleHttpException(e);
                    status      = e.status;
                }
                catch (HttpServerException e)
                {
                    keep_alive &= this.handleHttpServerException(e);
                    status      = this.default_exception_status_code;
                }
                
                this.sendResponse(status, response_msg_body, keep_alive);
            }
            while (keep_alive)
        }
        catch (IOError e)
        {
            this.notifyIOException(e, true);
        }
        catch (IOWarning e)
        {
            this.notifyIOException(e, false);
        }
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

        Receives the HTTP request message.
        
        Throws:
            - HttpParseException on request message parse error,
            - HttpException if the request contains parameter values that are
              invalid, of range or not supported (unsupported HTTP version or
              method, for example),
            - HeaderParameterException if a required header parameter is missing
              or has an invalid value (a malformated number, for example),
            - IOWarning  when a socket read/write operation results in an
              end-of-flow or hung-up condition,
            - IOError when an error event is triggered for a socket.
        
     **************************************************************************/
    
    private void receiveRequest ( )
    {
        this.request.reset();
        
        super.reader.read((void[] data)
        {
             size_t consumed = this.request.parse(cast (char[]) data, this.request_msg_body_length);
             
             return this.request.finished? consumed : data.length + 1;
        });
        
        this.http_exception.assertEx!(__FILE__, __LINE__)(this.request.method in this.supported_methods,
                                                          StatusCode.NotImplemented);
    }
    
    /**************************************************************************

        Sends the HTTP response message.
        
        Params:
            status            = HTTP status
            response_msg_body = response message body, if any
            keep_alive        = tell the client that this connection will
                                    - true: stay persistent or
                                    - false: be closed
                                after the response message has been sent.
        
        Throws:
            IOError on socket I/O error.
        
     **************************************************************************/

    private void sendResponse ( StatusCode status, char[] response_msg_body, bool keep_alive )
    {
        with (this.response)
        {
            http_version = this.request.http_version;
            
            set(HeaderFieldNames.General.Names.Connection, keep_alive? "keep-alive" : "close");
            
            super.writer.send(render(status, response_msg_body));
        }
    }
    
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
        request message or from handleRequest() or request_msg_body_length() and
        is not a HttpException.
        A subclass may override this method to be notified when an exception is
        thrown and decide whether the connection may stay persistent or should
        be closed after the response has been sent.
        The default behaviour is allowing the connection to stay persistent.
        
        Params:
            e = HTTP server exception e which was thrown while parsing the
                request message or from handleRequest() or
                request_msg_body_length() and is not a HttpException.
                
        Returns:
            true if the connection may stay persistent or false if it must be
            closed after the response has been sent.
            
     **************************************************************************/
    
    protected bool handleHttpServerException ( HttpServerException e )
    {
        return true;
    }
    
    /**************************************************************************

        Handles HTTP exception e which was thrown while parsing the request
        message or from handleRequest() or request_msg_body_length().
        A subclass may override this method to be notified when an exception is
        thrown and decide whether the connection may stay persistent or should
        be closed after the response has been sent.
        The default behaviour is allowing the connection being persistent unless
        the status code indicated by the exception is 413: "Request Entity Too
        Large".
        
        Params:
            e = HTTP server exception e which was thrown while parsing the
                request message or from handleRequest() or
                request_msg_body_length(). e.status reflects the response status
                code and may be changed when overriding this method.
                
        Returns:
            true if the connection may stay persistent or false if it should be
            closed after the response has been sent.
            
     **************************************************************************/

    protected bool handleHttpException ( HttpException e )
    {
        return e.status != e.status.RequestEntityTooLarge;
    }
    
    /**************************************************************************

        Called when an IOWarning or IOError is caught. May be overridden by a
        subclass to be notified.
        
        An IOWarning is thrown when a socket read/write operation results in an
        end-of-flow or hung-up condition, an IOError when an error event is
        triggered for a socket.
        
        Params:
            e        = caught IOWarning or IOError
            is_error = true: e was an IOError, false: e was an IOWarning
            
     **************************************************************************/

    protected void notifyIOException ( ErrnoIOException e, bool is_error ) { }
    
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
 