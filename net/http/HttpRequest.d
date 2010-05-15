/*******************************************************************************
                
    HTTP Request Handler

    Copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved
    
    Version:        Feb 2009: Initial release
    
    Authors:        Lars Kirchhoff, Thomas Nicolai & David Eckardt      
    
*******************************************************************************/

module      ocean.net.http.HttpRequest;


/*******************************************************************************

    Imports

********************************************************************************/

public      import      ocean.net.http.HttpResponse, 
                        ocean.net.http.HttpConstants,
                        ocean.net.http.Url;
                        
public      import      ocean.core.Exception: assertEx;

private     import      ocean.text.util.StringSearch;
private     import      ocean.text.util.StringReplace;

private     import      tango.io.selector.EpollSelector, 
                        tango.io.model.IConduit: IConduit;

private     import      tango.net.device.Socket;
private     import      tango.net.http.HttpConst;

private     import      Integer = tango.text.convert.Integer: toInt;

private     import      tango.math.Math: min;

private     import      tango.core.Exception: SocketException;

debug
{
    private     import      tango.util.log.Trace;
}


/*******************************************************************************

    Implements an Http request handler for reading and parsing the incoming 
    Http data from the given socket connection.
    
    ---
        import ocean.core.ObjectPool;
        
        import ocean.net.http.HttpServer;
        import ocean.net.http.HttpRequest;
        import ocean.net.http.HttpResponse;
        import ocean.net.http.HttpConstants;
        
        import tango.net.http.HttpConst;
        import tango.net.device.Socket;
        
        // Define a custom HttpRequest class which additionally supports the
        // "POST" and "TRACE" HTTP methods where a request message body is
        // accepted for "POST" but not for "TRACE".
        // Note that "GET" and "HEAD" are supported by default.
        //
        // In addition, we set the connection timeout to 20 s and the maximum
        // request message body length to 1 MB.
        
        class HttpRequestPostTrace : HttpRequest
        {
            this ( )
            {
                super.supported_methods["POST"]  = true;
                super.supported_methods["TRACE"] = false;
                
                super.selector_params.timeout    = 20_000;
                
                super.body_length_limit          = 0x10_0000;
            }
        }
        
        // Program main() method
        
        void main ( )
        {
            // Create the server with up to 20 threads.
             
            scope server = new HttpServer(20);
        
            // Create a pool of HttpRequestPostTrace objects
             
            scope requests_pool  = new ObjectPool!(HttpRequestPostTrace);
            
            // Define the connection handler callback method required by the
            // server.
            
            int reply ( Socket socket )
            {
                // Message body buffer
            
                char[] msg_body;
                
                // HttpResponse object
                
                HttpResponse response;
                
                // Get a HttpRequest instance from the object pool and recycle
                // it at the end
                
                auto request  = requests_pool.get();
                
                scope (exit)
                {
                    requests_pool.recycle(request);
                }
                
                // Read and process current request.
                
                bool ok = request.read(socket, msg_body);
                
                // - ok is true if the message has been successfully read and
                //          we are clear to send a response. If ok is false, a
                //          HTTP error response has already been sent to the
                //          client (unless the socket connection is broken).
                //
                // - request.method now contains the request method string, e.g.
                //          "GET".
                // 
                // - request.uri now contains the request URI string. 
                // 
                // - request.ver now contains the request HTTP method string.
                // 
                // - msg_body now contains the request message body if a body is
                //          present, accepted for the request method and does
                //          not exceed the limit of 1 MB in length defined
                //          above.
                //
                // - request.invalid_request is now true if the request was
                //          invalid for some reason and a corresponding HTTP
                //          error message has already been sent to the client.
                //
                // - request.request.socket_error is now true if the socket
                //          connection is broken.
                
                // Handle the request
                
                if (ok)
                {
                    switch (request.method)
                    {
                        case HttpMethod.Get:
                            // ...
                            break;
                            
                        case HttpMethod.Head:
                            // ...
                            break;
                            
                        case HttpMethod.Post:
                            // ...
                            break;
                            
                        case HttpMethod.Trace:
                            // ...
                            break;
                            
                        default:   
                            // ... if this happens, the program is buggy ...
                            assert (false, "no handler for '" ~ request.method ~
                                    "' method");
                    }
                    
                    // send a response like: response.send(socket, ...);
                }
                
                return 0;
            }
            
            // Now we defined the request handler so let's start the server!
            
            server.setThreadFunction(&reply);
            server.start();
        }
        
    ---

    See also

    http://labs.apache.org/webarch/http/draft-fielding-http/
    http://www.w3.org/Protocols/rfc2616/rfc2616.html


*******************************************************************************/

class HttpRequest
{
    /**************************************************************************

        Message body reader callback delegate type alias definition

     **************************************************************************/

    alias bool delegate ( ref char[] chunk )    ReadBodyDg;
    
    /**************************************************************************

        Default message which must be supported by all general-purpose servers
        as mandated in RFC 2616, 5.1.1:
        
        See also
        
        http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.1.1
    
     **************************************************************************/

    static const char[][]                       DefaultMethods =
                                                [
                                                    HttpMethod.Get,
                                                    HttpMethod.Head
                                                ];
    
    /**************************************************************************

        Default I/O buffer size (bytes)
    
     **************************************************************************/

    static const size_t                         DefaultIoBufferSize = 0x200;
    
    /**************************************************************************
    
        Supported HTTP methods
        
        May be changed at any time to fit your needs.
        
        Keys are the supported HTTP methods, values tell whether a method
        accepts a request message body.
    
    ***************************************************************************/    
    
    public              bool[char[]]            supported_methods;

    /**************************************************************************

        EPoll selector parameters
        
        May be changed at any time to fit your needs.
        
        Members:
            size       = maximum amount of conduits that will be registered;
                         it will grow dynamically if needed.
            max_events = maximum amount of conduit events that will be
                         returned in the selection set per call to select();
                         this limit is enforced by this selector.
            timeout  =   selector timeout in ms; -1 disables timeout
            
        (SelectorParams structure definition at the end of this class)
    
     **************************************************************************/

    public              SelectorParams          selector_params;
    
    /**************************************************************************
    
        Message header length limit (bytes)
        
        May be changed at any time to fit your needs.
        
        If the header length of a received message exceeds this value, message
        reception is aborted and a 413 "Request Entity Too Large" response is
        sent.
        
    ***************************************************************************/
    
    public              size_t                  header_length_limit   = 0x4000;
    
    /**************************************************************************
    
        Message body length limit (bytes)
        
        May be changed at any time to fit your needs.
        
        If the body length of a received message exceeds this value, message
        reception is aborted and a 413 "Request Entity Too Large" response is
        sent.
        
    ***************************************************************************/

    public              size_t                  body_length_limit  = 0x20_0000; // (2 MB) max bytes post data
    
    /**************************************************************************
    
        HTTP request method
        
        Reflects the HTTP method of the most recently received request.
        
    ***************************************************************************/

    public              char[]                  method;
    
    /**************************************************************************
    
        HTTP URI
        
        Reflects the HTTP URI of the most recently received request.
        
    ***************************************************************************/
    
    public              Url                     url;
    
    /**************************************************************************
    
        HTTP Version
        
        Reflects the HTTP Version of the most recently received request.
        
    ***************************************************************************/

    public              char[]                  ver;
    
    /**************************************************************************
    
        Header values
        
        Contains the header names and corresponding values.
        
        (HeaderValues structure definition at the end of this class)
        
    ***************************************************************************/
    
    public              HeaderValues            header_values;

    /**************************************************************************
    
        Invalid request
        
        Indicates whether the last request was invalid for any reason.
        
    ***************************************************************************/

    public              bool                    invalid_request    = false;
    
    /**************************************************************************
    
        Socket error
        
        Indicates whether a socket error occured during the last request.
        
    ***************************************************************************/

    public              bool                    socket_error       = false;
    
    /**************************************************************************
    
        EPoll selector
    
     **************************************************************************/    


    private             EpollSelector           selector;
    
    /**************************************************************************
        
        Input chunk buffer
        
    ***************************************************************************/                         
    
    private             char[]                  input_chunk;
    
    /**************************************************************************
        
        Header data buffer
    
    ***************************************************************************/     
    
    private             char[]                  header_data;
   
    /***************************************************************************
    
        Indicates that the message header has been completely received
    
    ***************************************************************************/     

    private             bool                    header_complete = false;

    
    /**************************************************************************
    
        Database of received header names/values
    
    ***************************************************************************/     

    private             char[][char[]]          header_values_;
    
    /**************************************************************************
    
        External body reader callback delegate if passed to read()
    
    ***************************************************************************/ 

    private             ReadBodyDg              read_body_dg       = null;
    
    /**************************************************************************
        
        true:  using appendBody() built-in message body reader callback delegate
        false: using an external message body reader callback delegate
    
    ***************************************************************************/ 
    
    private             bool                    using_builtin_dg;
    
    /**************************************************************************
    
        Message body buffer for built-in message body reader callback delegate
    
    ***************************************************************************/ 
    
    private             char[]                  msg_body;

    /**************************************************************************
    
        Announced message body length
    
    ***************************************************************************/ 

    private             size_t                  msg_body_length    = 0;
    
    /**************************************************************************
    
        Length of message body read so far
    
    ***************************************************************************/ 
    
    private             size_t                  body_length_read    = 0;
    
    /**************************************************************************
    
        Indicates that the message has been received completely
    
    ***************************************************************************/ 

    private             bool                    finished_reading = false;
    
    /***************************************************************************
        
        String replace instance
    
    ***************************************************************************/ 

    private             StringReplace!()        strrep;
    
    
    /**************************************************************************
    
        Maximum length of citations of received data appended to log messages
    
    ***************************************************************************/
    
    private const       size_t                  LogStringMaxLength = 0x40;
    
    /***************************************************************************
    
        Constructor
        
    ***************************************************************************/
    
    public this ( )
    {
        this(this.DefaultIoBufferSize);
    }

    /***************************************************************************
        
        Constructor
        
        Params:
            iobuffer_size = Socket I/O buffer size (bytes)
        
    ***************************************************************************/
   
    public this ( size_t iobuffer_size )
    in
    {
        assert (iobuffer_size, "zero length I/O buffer not allowed");
    }
    body
    {
        this.selector      = new EpollSelector;
        this.input_chunk   = new char[iobuffer_size];
        this.strrep        = new StringReplace!();
        this.msg_body      = new char[0];
        
        this.header_values = HeaderValues(&this.header_values_);
        
        this.setDefaultMethods();
    }
    
    
    /**************************************************************************
    
        Reads a request from socket.

        Params:
            socket = network connection socket
            data   = message body output buffer (remains empty if no body
                     attached or not accepted)
        
        Returns:
            - true if the message has been successfully read and the calling
              routine may send a response to the client,
            - false if an error occurred. In case of false, an error response
              has already been sent if possible so the calling routine should
              not send a response.
        
    ***************************************************************************/

    public bool read ( Socket socket, out char[] data )
    {
        this.using_builtin_dg = true;
        
        scope (exit) 
        {
            data = this.msg_body;
        }
        
        return this.read(socket, &this.appendBody);
    }
    
    /**************************************************************************
     
        Reads a request from socket.
        
        If a message body is attached and accepted, read_body_dg is invoked for
        each received message body chunk and receives that chunk. To continue
        receiving, read_body_dg must return false. If read_body_dg returns true,
        message body reception is prematurely aborted and a 500 "Internal Server
        Error" response is sent.
        
        Params:
            socket       = network connection socket
            read_body_dg = message body reader callback delegate
         
        Returns:
            - true if the message has been successfully read and the calling
              routine may send a response to the client,
            - false if an error occurred. In case of false, an error response
              has already been sent if possible so the calling routine should
              not send a response.
         
     **************************************************************************/
    
    public bool read ( Socket socket, ReadBodyDg read_body_dg = null )
    {
        this.resetState(read_body_dg);
        
        socket.socket.blocking(false);                                          
        
        this.selector.open(this.selector_params.size, this.selector_params.max_events);
        
        this.selector.register(socket, Event.Read);
        
        try while (!(this.finished_reading || this.invalid_request))
        {
            int event_count = this.selector.select(this.selector_params.timeout);
            
            assertEx!(RequestException.Timeout)(event_count > 0);
            
            foreach (key; this.selector.selectedSet())
            {
                scope (exit) this.selector.unregister(key.conduit);
                
                assertEx!(SocketException)(!key.isError(),         "socket error");
                assertEx!(SocketException)(!key.isHangup(),        "socket hung up");
                assertEx!(SocketException)(!key.isInvalidHandle(), "socket: invalid handle");
                
                if (key.isReadable)
                {
                    this.readInputChunk(cast (Socket) key.conduit);
                }
            }
        }
        catch (RequestException e)
        {
            this.reportErrorToClient(socket, e);
            this.invalid_request = true;
        }
        catch (Exception e)
        {
            debug
            {
                Trace.formatln(e.msg);
            }
            
            this.socket_error = true;
        }
        
        this.cleanupStatus();
        this.selector.close();
        
        return !(this.socket_error || this.invalid_request);
    }    
    
    
    /***************************************************************************
    
        Resets the internal state variables and prepares for reading.
        
        Params:
            read_body_dg: message body reader delegate

     ***************************************************************************/
    
    private void resetState ( ReadBodyDg read_body_dg )
    {
        this.read_body_dg       = read_body_dg;
        
        this.finished_reading   = false;
        this.header_complete    = false;
        this.invalid_request    = false;
        this.socket_error       = false;
        this.header_data.length = 0;
        this.msg_body.length    = 0;
        this.body_length_read   = 0;
        this.header_values_     = this.header_values_.init;
    }
    
    /***************************************************************************
    
        Clears the message body reader delegate after reading.
    
     ***************************************************************************/

    private void cleanupStatus ( )
    {
        this.read_body_dg     = null;
        this.using_builtin_dg = false;
    }

    /***************************************************************************
    
        Appends chunk to the message body buffer and returns false to continue
        receiving.
        
        This is the internal message body reader callback method. 
    
     ***************************************************************************/

    private bool appendBody ( ref char[] chunk )
    {
        this.msg_body ~= chunk;
        
        return false;
    }
    
    /**************************************************************************
    
        Reads the next input data chunk from socket and processes it.
        
        Params:
            socket = input socket
    
     **************************************************************************/

    private void readInputChunk ( Socket socket )
    {
        int input_length = 0;
        
        while (!this.finished_reading)
        {
            input_length = socket.read(this.input_chunk);
            
            assert (input_length != 0, "connection closed");
            assert (input_length >= 0, "connection reset by client");
            assert (input_length <= this.input_chunk.length, "input chunk too long");
            
            this.finished_reading = this.processInputChunk(this.input_chunk[0 .. input_length]);
        }
    }
    
    /**************************************************************************
    
        Processes the current input data chunk. That is,
        
            1. if the message header has not yet been received completely, chunk
               is appended to this.header_data and the end-of-header mark is
               searched,
            2. if the end-of-header mark is found, chunk is split at this mark,
               the header is parsed and the remaining data are forwarded to the
               message body reader callback delegate,
            3. if the message header has already been received completely, the
               chunk is forwarded to the message body reader callback delegate. 
        
        Params:
            chunk = current input data chunk
            
        Returns:
             true if the end of message has been reached or false if not
        
        TODO
         
        add functionality to handle post messages even if no content length 
        is given
            
     **************************************************************************/
    
    private bool processInputChunk ( char[] chunk )
    {   
        bool finished = false;
        
        assertEx!(RequestException.EntityTooLarge)
                 (this.header_data.length + chunk.length <= this.header_length_limit);
        
        if (!this.header_complete)
        {
            this.header_data ~= chunk;
            
            this.header_complete = this.stripBodyStart(chunk);
            
            if (this.header_complete)
            {
                this.parseHeader();
                
                this.getMessageBodyLength();
            }
        }
        
        if (this.header_complete)
        {
            finished = this.msg_body_length? this.readMessageBodyChunk(chunk) : true;
        }
        
        return finished;
    }
    
    
    /**************************************************************************
    
        Looks for the end-of-header mark in this.header_data. If found, the mark
        and everything after it is cut off from this.header_data and chunk is
        set to the slice after the mark.
        
        The following sequences are recognized as end-of-header mark:
        
            - "\r\n\r\n" (HttpConst.Eol ~ HttpConst.Eol) as mandated in RFC 2616
            - "\n\n"     to be nice to a non-compliant remote
        
        Note: If the end-of-header mark is found, the end-of-line tokens inside
              the HTTP header are changed from "\r\n" to "\n" to facilitate
              further processing.
        
        Params:
            chunk = output slice of data after end-of-header mark, if any
            
        Returns:
            true if the end-of-header mark has been found or false otherwise
            
     **************************************************************************/

    private bool stripBodyStart ( out char[] body_chunk )
    {
        size_t end;
        bool   found;
        
        found = this.lookupEndOfHeader!(HttpConst.Eol ~ HttpConst.Eol)(this.header_data, end);
        
        if (!found)
        {
            found = this.lookupEndOfHeader!("\n\n")(this.header_data, end);
        }
        
        if (found)
        {
            body_chunk = this.header_data[end .. $];
            
            this.header_data = this.header_data[0 .. end];
            
            this.strrep.replacePattern(this.header_data, HttpConst.Eol, "\n");
        }
        
        return found;
    }
    

    /**************************************************************************
     
        Parses the HTTP message header according to RFC 2616
        
     **************************************************************************/
    
    private void parseHeader ()
    {   
        char[][] lines = StringSearch!().splitCollapse(this.header_data, '\n'); // HttpConst.Eol (['\r', '\n]) has been
                                                                                // replaced by '\n' in processInputChunk()
        
        assertEx!(RequestException.BadRequest)(lines.length);
        
        this.parseRequestLine(StringSearch!().trim(lines[0]));
        
        if (lines.length > 1)
        {
            foreach (line; lines[1 .. $])
            {
                this.addHeaderParameter(StringSearch!().trim(line));            // Parse header key/value pairs like
            }
        }
    }
    
    
    /**************************************************************************
     
        Parses the HTTP request line
         
        Recognizes ' ' and '\t' as delimiters. 
         
        Params:
            request_line = HTTP request line
          
     **************************************************************************/
    
    private void parseRequestLine ( char[] request_line )
    {
        const char[] token_delims = [' ', '\t'];                                // split by space or tab character
        
        char[][] tokens = StringSearch!().splitCollapse(request_line, token_delims);
        
        assertEx!(RequestException.BadRequest)(tokens.length == 3,
                                               "not exactly 3 tokens -- '" ~
                                               this.toLogString(request_line) ~ '\'');
        
        this.method   = tokens[0].dup;
        this.url.parse(tokens[1].dup);
        this.ver = tokens[2].dup;
        
        assertEx!(RequestException.NotImplemented)
                 (this.method in this.supported_methods);
        
        assertEx!(RequestException.BadRequest)
                 (this.url.length, "empty url path in header");
        
        switch (this.ver)
        {
            default:
                assertEx!(RequestException.VersionNotSupported)(false);
            
            case HttpVersion.v10:
            case HttpVersion.v11:
        }
    }
    
    
    /**************************************************************************
    
        Parses a HTTP header line and adds the contained header parameter to
        this.header_values_, if found.
         
        Params:
            line = HTTP header line
          
        Returns:
            true if a header parameter was found or false otherwise
          
     **************************************************************************/
    
    private bool addHeaderParameter ( char[] line )
    {
        char[] key, val;
        
        bool found = false;
        
        if (line.length)
        {
            size_t n = StringSearch!().locateChar(line, ':');
            
            if (n < line.length)
            {
                key = StringSearch!().trim(line[0 .. n]);
                val = StringSearch!().trim(line[min(n + 1, $) .. $]);
            }
            
            found = n < line.length;
            
            if (found)
            {
                StringSearch!().strToLower(key);
                
                debug
                {
                    Trace.formatln("[request header] {} = {}", key, val);
                }
                
                this.header_values_[key.dup] = val.dup;
            }
        }
        
        return found;
    }
    
    /**************************************************************************

       Checks whether a message body is attached and retrieves the body length.
       
       Throws:
           RequestException.NotImplemented if the message header contains a
           Transfer-Encoding parameter
           
           RequestException.NotImplemented if a message body is announced and
           a message body is not accepted for the HTTP method this message is
           using. Whether a message body is accepted for each supported method
           is determined by this.supported_methods; see above.
           
           RequestException.EntityTooLarge if the announced message body length
           exceeds this.body_length_limit.
       
     **************************************************************************/
    
    private void getMessageBodyLength ( )
    {
        this.msg_body_length = 0;
        
        int blength = Integer.toInt(this.header_values[HttpHeader.ContentLength.value]);
        
        assertEx!(RequestException.BadRequest)
                 (blength >= 0, "negative message body length?!?");
        
        this.msg_body_length = cast (uint) blength;
        
        if (this.msg_body_length)
        {
            assertEx!(RequestException.NotImplemented)                          // if no body read delegate was supplied
                     (this.read_body_dg, "request message body not supported"); // reading a message body is not implemented
            
            assertEx!(RequestException.NotImplemented)
                     (this.requestBodySupportedForCurrentMethod(),
                      "request message body not supported for this method");
            
            assertEx!(RequestException.EntityTooLarge)                          // message body length may be at most
                     (msg_body_length <= this.body_length_limit);               // this.body_length_limit             
        }
        
        assertEx!(RequestException.NotImplemented)                              // Transfer-Encoding handling not implemented
                 (!(HttpHeader.TransferEncoding.value in this.header_values));
    }
    
    
    /**************************************************************************

        Checks whether a message body is supported for the method of the current
        message.
             
      *************************************************************************/
     
    private bool requestBodySupportedForCurrentMethod ( )
    {
        bool* supports_request_body = this.method in this.supported_methods;
        
        return supports_request_body? *supports_request_body : false;
    }
    
    
    /**************************************************************************
     
       Passes chunk to the message body reader callback delegate.
         
       Params:
            chunk = message body data chunk
             
       Returns:
            true if the message body has been read completely, that is, the
            length of message body data read so far has reached the value
            announced in the Content-Length header parameter, or false otherwise
             
        Throws:
            RequestException.BadRequest if the message body length exceeds the
            value announced by the Content-Length header parameter
              
            RequestException.InternalError if the callback delegate returns true
              
     **************************************************************************/
    
    private bool readMessageBodyChunk ( char[] chunk )
    in
    {
        assert (this.read_body_dg, "no body read delegate supplied");
    }
    body
    {
        assertEx!(RequestException.BadRequest)
                 (chunk.length <= this.msg_body_length - this.body_length_read, "body length exceeds Content-length value");
        
        bool error = this.read_body_dg(chunk);
        
        assertEx!(RequestException.InternalError)(!error);
        
        this.body_length_read += chunk.length;
        
        return this.body_length_read >= this.msg_body_length;
    }

    
    
    /**************************************************************************
    
        Looks up the end-of-header mark in header_data.
        
        Params:
            header_data = HTTP message header data
            end         = output index of the first character after the
                          end-of-header mark if mark was found
                          
        Returns:    
            bool if found or false otherwise
               
     **************************************************************************/
     
    private static bool lookupEndOfHeader ( char[] mark ) ( char[] header_data, out size_t end )
    {
        bool found;
        
        end = StringSearch!().locatePatternT!(mark)(header_data);
        
        found = end < header_data.length;
        
        if (found)
        {
            end += mark.length;
        }
        
        return found;
    }
    
        
    /**************************************************************************
    
        Sets the supported methods to the default ones as defined by
        this.DefaultMethods.
        
     **************************************************************************/
     
    private void setDefaultMethods ( )
    {
        foreach (method; this.DefaultMethods)
        {
            this.supported_methods[method] = false;
        }
    }
    
    /**************************************************************************
    
        Sends a HTTP response to the client taking status code and message 
        from Exception thrown.
        
        Params:
            socket: connection socket
            e:      RequestException instance
               
     **************************************************************************/
     
    private static void reportErrorToClient ( Socket socket, RequestException e )
    {
        HttpResponse response;
        
        auto status = e.getStatus();
        
        response.send(socket, status, e.msg);
        
        debug
        {
            Trace.formatln("Request error {}:{} with {}", status.code, 
                    status.name, e.msg);
        }
    }
    

    /**************************************************************************
    
        Truncates str to this.LogStringMaxLength characters.
        
        Params:
            str: input string
            
        Returns:
            truncated string
            
     **************************************************************************/
     
    private static char[] toLogString ( char[] str )
    {
        return str[0 .. min(str.length, this.LogStringMaxLength)];
    }


    /**************************************************************************
    
        Destructor

     **************************************************************************/
     
    private ~this ( )
    {
        delete this.selector;
        
        this.input_chunk.length = 0;
    }
    
    
    /**************************************************************************
    
        SelectorParams structure
        
        EPoll selector parameters
        
     **************************************************************************/
     
    struct SelectorParams
    {
        static int size        = EpollSelector.DefaultSize,
                   max_events  = EpollSelector.DefaultMaxEvents,
                   timeout     = 20;  // -1 = infinite
    }

    /**************************************************************************
    
        HeaderValues structure
        
        Keeps a pointer to an associative array of header names and their values
        and provides read-only access to this array.
        Header parameter names are case-insensitive; values are case-sensitive.  
        
     **************************************************************************/
     
    struct HeaderValues
    {
        /**********************************************************************
         
            Pointer to the header name/value associative array which will be
            a HttpRequest property.
         
         **********************************************************************/
        
        private char[][char[]]* values;
        
        /**********************************************************************
        
            Temporary string buffer for case conversion
     
         **********************************************************************/
        
        private char[] tmp_buf;
        
        /**********************************************************************
        
            Pointer validity checking
     
         **********************************************************************/
        
        invariant
        {
            assert (this.values, typeof (*this).stringof ~ ": no values");
        }
        
        /**********************************************************************
        
            Retrieves a header parameter value via indexing by name. If there
            is no header parameter with the provided name, an empty string is
            returned.
     
         **********************************************************************/
        
        char[] opIndex ( char[] name )
        {
            char[]* value = this.cleanHeaderName(name) in *(this.values);
            
            return value? *value : "";
        }
        
        /**********************************************************************
        
            'in' tells whether there is a header parameter named name.
     
         **********************************************************************/
        
        bool opIn_r ( char[] name )
        {
            return !!(this.cleanHeaderName(name) in *(this.values));
        }
        
        /**********************************************************************
        
            Strips a trailing ':' from name, trims off whitespace and converts
            name to lower case.
            ':' stripping is done since header name constants in HttpHeader in
            tango.net.http.HttpConst have a trailing ':'.
            
            Params:
                name = input header name
                
            Returns:
                cleaned header name
     
         **********************************************************************/
        
        private char[] cleanHeaderName ( char[] name )
        {
            bool trailing_colon = false;
            
            if (name.length)
            {
                trailing_colon = name[$ - 1] == ':';
            }
            
            this.tmp_buf = StringSearch!().trim(name[0 .. $ - trailing_colon]).dup;
            
            StringSearch!().strToLower(this.tmp_buf);
            
            return this.tmp_buf;
        }
    }
    
    
    /**************************************************************************
    
        RequestException classes:
        Generic abstract class and particular subclasses
        
        Each RequestException subclass corresponds to a HTTP status code that
        indicates a request related error to the client and contains the
        corresponding HttpStatus object.
        
        Note: Unless expressively mentioned, the constructors of the
              RequestException subclasses do not accept a message string.
        
     **************************************************************************/
    
    private static abstract class RequestException : Exception
    {
        /**********************************************************************
        
            This alias for derivation
            
         **********************************************************************/
        
        alias typeof (this) This;
        
        /**********************************************************************
        
            Returns the HttpStatus object of the particular RequestException
            
            Returns:
                HttpStatus of the particular RequestException
            
         **********************************************************************/
        
        abstract HttpStatus getStatus ( );
        
        /**********************************************************************
        
            Constructor
            
            Params:
                msg = exception message
            
         **********************************************************************/
    
        this ( char[] msg ) { super(msg); }
        
        /**********************************************************************
       
           Particular RequestException subclasses
           
         **********************************************************************/

        static:
        
        /**********************************************************************
        
            RequestException subclass template
            
         **********************************************************************/

        private abstract class RequestExceptionT ( alias Status ) : This
        {
            this ( char[] msg ) { super(msg); }
            this (            ) { super(""); }
            
            HttpStatus getStatus ( ) { return Status; }
        }
        
        /**********************************************************************
        
            BadRequest RequestException subclass
            
            Corresponds to 400 "Bad Request" status
            
            Note: Constructor does accept a message string.
            
         **********************************************************************/

        class BadRequest : RequestExceptionT!(HttpResponses.BadRequest)
        {
            this ( char[] msg ) { super(msg); }
            this (            ) { super(); }
        }
        
        /**********************************************************************
        
            Timeout RequestException subclass
            
            Corresponds to 408 "Request Time-out" status
            
         **********************************************************************/

        class Timeout             : RequestExceptionT!(HttpResponses.RequestTimeout)        { }

        /**********************************************************************
        
            EntityTooLarge RequestException subclass
            
            Corresponds to 413 "Request Entity Too Large" status
            
         **********************************************************************/

        class EntityTooLarge      : RequestExceptionT!(HttpResponses.RequestEntityTooLarge) { }
        
        
        /**********************************************************************
        
            InternalError RequestException subclass
            
            Corresponds to 500 "Internal Server Error" status
            
         **********************************************************************/

        class InternalError       : RequestExceptionT!(HttpResponses.InternalServerError)   { }
        
        /**********************************************************************
        
            BadRequest RequestException subclass
            
            Corresponds to 501 "Not implemented" status
            
            Note: Constructor does accept a message string.
            
         **********************************************************************/
    
        class NotImplemented      : RequestExceptionT!(HttpResponses.NotImplemented)
        {
            this ( char[] msg ) { super(msg); }
            this (            ) { super(); }
        }
        
        /**********************************************************************
        
            VersionNotSupported RequestException subclass
            
            Corresponds to 505 "HTTP Version not supported" status
            
         **********************************************************************/

        class VersionNotSupported : RequestExceptionT!(HttpResponses.VersionNotSupported)   { }
    }
}
