/*******************************************************************************
                
    HTTP Server Request object that handles reading and parsing the input data 
    from a HTTP request. 

    Copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved
    
    Version:        Feb 2009: Initial release
    
    Authors:        Lars Kirchhoff, Thomas Nicolai      
    
    --
    
    Description:
    
    The request object reads the input data from a socket conduit, that has been
    returned from a ServerSocket.accept(). It reads the request line, header data
    and the POST data if available.
    
    The header is completely read into an internal array and then parsed into the 
    specific parts. If POST data is available the post data is read and passed to 
    a delegate function that needs to be provided by the calling class.     
    This way the POST data is streamed into the calling class, which then can 
    decide how to handle the data. 
    
    The post data is completely read within the initialization of the object, 
    because of the non-blocking manner. Therefore it is important to define a 
    POST data handling function with the calling class.
    If the object is initialize without any POST data handling function, all 
    POST data is dropped. This is only helpful if the server should only 
    accept request like GET, PUT, HEAD, etc. 
    
    --
    
    Usage Example:
    

    char[] post_data;
        
    SocketConduit conduit  = ServerSocket.accept();
    HttpRequest request    = new HttpRequest(conduit, &this.handle_post_data, 3_145_728);
    
    request.read();
    
    char[] method   = request.getMethod();
    char[] url      = request.getURL();
    char[] protocol = request.getProtocol();
        
    private void handle_post_data ( char[] chunk )
    {
        post_data ~= chunk;
    }
     
    --
    
    TODO:
    
    1. Add proper exception handling    
           
    -- 
    
    Additional Information:
    
    http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.4
    
    --
    
    
*******************************************************************************/

module      ocean.net.http.HttpRequest;


/*******************************************************************************

    Imports

********************************************************************************/

private     import      tango.io.Stdout, tango.io.selector.EpollSelector,
                        tango.io.stream.Buffered, tango.io.stream.Lines;

private     import      tango.net.device.Socket, tango.net.http.HttpConst;

private     import      TextUtil = tango.text.Util: containsPattern, substitute, split, trim;                        

private     import      Integer = tango.text.convert.Integer;

private     import      ocean.net.http.HttpConstants;

private     import      ocean.util.OceanException, ocean.util.TraceLog;

private import tango.util.log.Trace;
/*******************************************************************************

    HttpRequest

********************************************************************************/

class HttpRequest
{
    
    /***************************************************************************
    
         EPoll

     ***************************************************************************/    
    

    private             const int               EPOLL_WAIT_LIMIT   = 20; // (-1 = unfinite)
    private             const Event             EPOLL_EVENTS = Event.Read | 
                                                               Event.Error | 
                                                               Event.Hangup | 
                                                               Event.InvalidHandle;

    /***************************************************************************
        
        Socket    
        
    ***************************************************************************/                         
    
    
    private             const int               IO_SOCK_BUF_SIZE = 512;
    
    private             Socket                  conduit;
    
    
    /***************************************************************************
        
        Header
    
    ***************************************************************************/     
    
    
    private             const uint              MAX_HEADER_SIZE = 8_192; // max header size
    private             alias Lines!(char)      LineIterator;            // line iterator for header  
    private             char[]                  header_data;             // raw header
    private             char[][char[]]          header_tokens;           // parsed header
    private             bool                    header_complete = false; // header read status
    
    
    /***************************************************************************
        
        Request Line
    
    ***************************************************************************/
    
    
    //private             char[][]                request_tokens;     // request string
    private             char[]                  method;
    private             char[]                  urlpath;
    private             char[]                  protocol;
    
    
    /***************************************************************************
        
        Message Body
    
    ***************************************************************************/ 
    
    
    private             uint                    read_post_bytes = 0;         // bytes read
    private             uint                    msg_body_length = 0;         // post body length
    private             uint                    max_body_size   = 2_097_152; // max bytes post data  
    private             void delegate(void[])   msg_body_dg  ;               // delegate
    
    
    /***************************************************************************
        
        Error
    
    ***************************************************************************/ 
    

    private             bool                    socket_error = false;     // connection error
    private             bool                    request_invalid = false;  // invalid request
    private             bool                    size_limit_error = false; // msg body size limit

    
    /***************************************************************************
        
        Public Methods
    
    ***************************************************************************/
   
    
    
    /**
     * Constructor: Initialize Socket
     * 
     * Set internal variable to access the conduit input stream. 
     * Start reading & parsing the input stream.
     *  
     * 
     * Params:
     *     conduit = socket conduit input stream object
     */
    public this ( Socket conduit )
    {     
        this.conduit = conduit;
    }
    
    
    
    /**
     * Constructor: Initialize Socket & Parameter
     * 
     * Set internal variable to access the conduit input stream. 
     * Start reading & parsing the input stream.  
     *  
     * Params:
     *     conduit             = socket conduit input stream object
     *     post_handle_dg      = sink for message body (delegate)
     */
    public this ( Socket socket, void delegate(void[]) dg )
    {          
        this.conduit     = socket;
        this.msg_body_dg = dg;
    }
    
    
    
    /**
     * Read Request Async (EPoll)
     * 
     * Read request data from socket conduit in a non-blocking manner, by using
     * EPollSelector. EPollSelector listens on the socket conduit for read events
     * and passes the read data to appendMsgBodyData(), which handles all
     * reading and parsing of the request data.
     * 
     * As the non-blocking reading is asynchronous reading, it is important to 
     * know when the data stream ends. Therefore the bool variable finished_reading
     * is introduced, which is set by appendMsgBodyData depending on the kind
     * of request. In case the of the POST request the stream ends when the number of 
     * bytes defined by Content-Length is read from the conduit. In all other cases 
     * the stream ends if the end of the header data is found.
     *  
     */
    public void read ()
    {
        int             event_count;              
        bool            finished_reading;
        int             input_length;
        int             eof_count;

        char[this.IO_SOCK_BUF_SIZE] input_chunk;  // tmp read buffer for socket input
        
        this.conduit.socket.blocking(false); // set conduit to non-blocking
        
        scope selector = new EpollSelector();
        
        selector.open(10, 64);
        
        selector.register(this.conduit, EPOLL_EVENTS);
        //selector.register(this.conduit, Event.Read | Event.Error | Event.Hangup | Event.InvalidHandle);
        
        scope(exit) 
            selector.close();
        
        while(!finished_reading)
        {
            event_count = selector.select(EPOLL_WAIT_LIMIT);
            //event_count = selector.select(10);
            
            if (event_count > 0) 
            {  
                foreach (SelectionKey key; selector.selectedSet())
                {
                    if (key.isReadable) 
                    {
                        
//                        Trace.formatln("#{}#",IConduit.Eof).flush;
//                      while (input_length != IConduit.Eof) 
                        do 
                        {
                            // read data from socket
                            input_length = (cast(Socket) key.conduit).read(input_chunk);
//                            Trace.formatln("[len = {}]", input_length).flush;
                            // if no data is available anymore, do not try to append it, as 
                            // IConduit.Eof equals -1, which would lead to chunk[0..-1], 
                            // which in turn is not possible.
                            //if (input_length != IConduit.Eof) 
                            if (input_length > 0) 
                            {
                                // append data to request data property in order to parse it.
                                // If readSocketData returns true, no more data needs to be 
                                // read.
                                if ( consumeSlice(input_chunk[0..input_length]) )
                                {
//                                    Trace.formatln("Finished READING!").flush;
                                    finished_reading = true;
                                    selector.unregister(key.conduit);
                                    
                                    break;
                                }
                            }
                            /+
                            else if (input_length == 0)
                            {   
                                /*connection closed by client*/
                                this.socket_error = true;
                                selector.unregister(key.conduit);
                                return;
                                // leave epoll if we got than 3 EOF's (indicates a 
                                // broken socket by the client)
                                /*
                                if ( eof_count > 3 )
                                {
                                    finished_reading = true;
                                    selector.unregister(key.conduit);
                                    this.socket_error = true;
                                    //HttpRequestException("HttpRequest: multiple EOF while reading");
                                    
                                    break;
                                }
                                
                                eof_count++;
                                */
                            }
                            else
                            {
                                /*connection reset by client*/
                                this.socket_error = true;
                                selector.unregister(key.conduit);
                                return;
                            }
                            +/
                        } 
                        while (input_length > 0)
                        
//                        Trace.formatln("length out = {}", input_length);
                        
                        if (input_length <= 0)
                        {   
                            /* 0 = connection closed by client*/
                            /*-1 = connection reset by client*/
                            this.socket_error = true;
                            selector.unregister(key.conduit);
                            return;
                        }
                        
                        
                        
                        //input_length = 0; // reset input length for the next SelectionKey event 
                    }
                    
                    if ( key.isError || key.isHangup || key.isInvalidHandle )
                    {
                        // Only unregister from further reading. The conduit will be
                        // detached in the HttpServer class (_threadAction)
                        selector.unregister(key.conduit);                        
                        //finished_reading = true;
                        this.socket_error = true;
                        //HttpRequestException("HttpRequest: epoll hangup or error while reading");
                        
                        return;
                    }
                }
            }
            else 
            {
                //finished_reading = true;
                this.socket_error = true;
                return;
                //HttpRequestException("HttpRequest: epoll event count error");
                TraceLog.write("HttpRequest: event count = {}", event_count);
            }
            
        }
        
        // set blocking back to true in case another process 
        // would like to read or write this way        
        //this.conduit.socket.blocking(false);
    }    

    

    /**
     * Set maximum size for body data
     * 
     * Params:
     *     max_bytes_post_data = maximum size of POST data
     */
    public void setSizeLimit( uint size )
    {
        this.max_body_size = size;
    }
    
    
    
    /**
     * Returns the HTTP request method (GET/POST)
     *
     * Returns:
     *      HTTP Request method
     */
    public char[] getRequestMethod ()
    {   
        return this.method;
    }
    
    
    
    /**
     * Returns the URI of the request
     * 
     * Returns:
     *      HTTP URI 
     */
    public char[] getRequestUrl ()
    {
        return this.urlpath;
    }
    
    
    
    /**
     * Returns the protocol of the request
     * 
     * @see http://www.w3.org/Protocols/
     * 
     * Returns:
     *      Requested HTTP protocol (e.g. HTTP/1.0 or HTTP/1.1)
     */
    public char[] getProtocolVersion ()
    {
        return this.protocol; 
    }
    
    
    
    /**
     * Returns the value of a header element
     * 
     * Params:
     *     name = header parameter name 
     *      
     * Returns:
     *     Value of a HTTP header 
     */
    public char[] getHeaderValue ( char[] name )
    {
        if (name in this.header_tokens) 
        {
            return this.header_tokens[name].dup;
        }
        
        return null;
    }
    
    
    
    /**
     * Returns true if socket error
     * 
     * Method returns true if we received an socket i/o error during
     * the asynchronous read operation.
     * 
     * Returns:
     *      true, if socket error occured during read
     */
    public bool isSocketError ()
    {
        return this.socket_error;        
    }
    
    
    
    /**
     * Returns true if request is valid
     * 
     * Status is set to false in case the header or post body is incorrect.
     * This might happend if we find a invalid request or the post message
     * body is too large.
     * 
     * Returns:
     *      false, if request is invalid
     */
    public bool isInvalidRequest ()
    {
        return this.request_invalid;        
    }

    
    
    /**
     * Returns true if message body size limited is exceeded
     * 
     * Status is set to false in case the header or post body is incorrect.
     * This might happend if we find a invalid request or the post message
     * body is too large.
     * 
     * Returns:
     *      false, if request is invalid
     */
    public bool isSizeLimitExceeded ()
    {
        return this.size_limit_error;        
    }    

    
    
    /***************************************************************************
    
            Private Methods

     ***************************************************************************/
    
    
    
    /**
     * Consumes request header and message body
     * 
     * Params:
     *     chunk = data chunk that has been read from EPoll selector
     *     
     * Returns:
     *      true, if the end of data has been reached. The end of the
     *      data stream is defined as follows:
     *        1. For all request methods other than POST the end 
     *           of the data stream is, when the HttpHeaderSeparator
     *           is found in the data chunk
     *        2. For POST data the end of the data stream is defined 
     *           by the content-length defined in the header or the 
     *           maximum byte size that should be read for a POST        
     *              
     *      false, if there is still data to be read 
     * 
     * TODO: 
     *      1. Add functionality to handle post messages even if no 
     *         content length is given    
     */
    private bool consumeSlice ( char[] chunk )
    {   
        // If header is read completely and no error occured while
        // reading the header, start reading POST data. Otherwise 
        // add the chunk to the header data.
        if (!this.request_invalid)
        {
//            Trace.formatln("head compl: {}", header_complete).flush;
            
            if (this.header_complete)
            {
                // If no post handle function is defined
                //if (this.msg_body_dg != null)
                //{
                    return this.readMessageBody(chunk);
                //}
                //else 
                //{
                //    return true;
                //}
                    
                    
            }
            else 
            {
                this.header_data ~= chunk;
            }
        }
        else
        {
//            Trace.formatln("invalid request...done");
            return true;
        }

        // 1. Check if the header seperator is found
        // 2. Security check: check if header data is too large. This could 
        //    indicate a malformed request
        if (TextUtil.containsPattern(this.header_data, HttpHeaderSeparator) || 
            this.header_data.length > this.MAX_HEADER_SIZE)        
        {   
            return readHeader();
        }
        
        
        return false;
    }

    
    
    /**
     * Parses the header data and checks if it is a valid request
     * and if more data needs to be read from the socket conduit.
     * If it is a POST request, than get Content-Length and check 
     * if it is within the POST data size limits. If Content-Length 
     * is set properly pass the POST data that has been read already, 
     * to the delegate function.  
     *     
     * Returns:
     *     true, if header data could be read and if request method 
     *           is not POST. If request method is post, but Content-Length
     *           is either not defined or larger then the defined maximum 
     *           POST data size 
     *     false, otherwise
     */
    private bool readHeader ()
    {
        this.parseHeader();
        
        // clean header data string, because otherwise this function will be 
        // called everytime a new post data chunk is read
        scope (exit)
            this.header_data.length = 0;
        
        if ( !this.request_invalid )
        {
//            Trace.formatln("read header").flush;
            this.header_complete = true;
            
            if ( this.hasMessageBody() )
            {
//                Trace.formatln("hash message body").flush;
                // get the bytes from the POST data that have been read already
                // and push
                char[][] token = TextUtil.split(this.header_data, HttpHeaderSeparator);
                bool result    = readMessageBody(token[1]);
                
//                Trace.formatln("token = {}", token).flush;
//                Trace.formatln("token[1].length = {}", token[1].length).flush;
//                Trace.formatln("result = {}", readMessageBody(token[1])).flush;
                
                //if ( token[1].length )
                    return result;
            }
            
            return true;
        }
        else
        {
            TraceLog.write("HttpRequest: invalid request header");            
            this.request_invalid = true;            
            
            return true;
        }
        
    }     
    
    
    
    /**
     * Checks if a message is attached in the body
     * 
     * Returns:
     *      true, if message body is found
     */
    private bool hasMessageBody ()
    {
        if ( this.getRequestMethod == HttpRequestType.Post )
        {
            this.msg_body_length = Integer.toInt(this.getHeaderValue("Content-Length"));
            
            // check content-length 
            if ( this.msg_body_length > 0 )
            {
                // If number of bytes is larger than the maximum defined 
                // size of POST data stop reading and return error 
                if ( this.msg_body_length > this.max_body_size )
                {
                    TraceLog.write("HttpRequest: exceeding message body size limit");
                    this.size_limit_error = true;
                    //this.request_invalid = true;
                }
                
                return true;
            }
            /*
            else 
            {
                TraceLog.write("HttpRequest: no content-length defined");
                this.request_invalid = true;

                return true;
            }
            */
        }

        // only certain methods have a message body
        return false;
    }
    
    
    
    /**
     * Reads message body data and passes it to a delegate function (POST/PUT). 
     *  
     * Params:
     *     chunk = data chunk that has been read from EPoll selector
     *     
     * Returns:
     *     true, if all POST data has been read and the end of POST 
     *           data has been found or the maximum byte size for 
     *           POST data has been reached. In the later cases 
     *           stop reading more data and return to calling class.           
     *     false, otherwise   
     */
    private bool readMessageBody ( char[] chunk )
    {
//        Trace.formatln("read msg body");
        //if (this.msg_body_dg != null)
        //{
            // Add read bytes to read_post_length to find 
            // end of the post data stream
            this.read_post_bytes += chunk.length;
           
            // Check if all post data is read          
            if ( this.read_post_bytes < this.msg_body_length )
            {   
                // Check if the read bytes is larger than the 
                // defined POST data size 
                if (this.read_post_bytes < this.max_body_size)
                {               
                    // pass the read chunks to this handling function
                    if (this.msg_body_dg != null)
                        this.msg_body_dg(chunk);                   
                }
                //else 
                //{
                    // Set error that the POST data is to large 
                    //TraceLog.write("HttpRequest: message body exceeded size limit");
                    //this.request_invalid = true;
                    
                    //return true;
                //}
            }
            else 
            {
                // Pass the last chunk to the handling function
                if (this.msg_body_dg != null)
                    this.msg_body_dg(chunk);
                
                return true;
            }
        //}
        //else 
        //{
        //    return true;
        //}
        
        return false;
    }

    
    
    /**
     * Parse header data according to RFC 2616
     * 
     * Parse first line/request line from http request and identify request method, 
     * URI & HTTP protocol version.
     * 
     */
    private void parseHeader ()
    {    
        char[][] token, lines;
        
        lines = TextUtil.split(this.header_data.dup, HttpQueryLineSeparator);
        
        lines[0] = removeHttpEol(lines[0].dup);     
        token    = TextUtil.split(lines[0].dup, " ");
        
        if ( token.length > 1 &&  token.length < 4)
        {
            this.parseRequestLine(token);
            
            if ( !this.request_invalid )
            {
                this.parseGeneralHeader(lines);
            }
        }            
        else
        {
           this.request_invalid = true;
           
           TraceLog.write("HttpRequest Error: malformed request header line [" ~ lines[0] ~ "]");
        }
    }
    
    
        
    /**
     * Parses the read http header data including the request line
     * 
     * Params: 
     *     header_data = array with header data
     *      
     */
    private void parseRequestLine ( char[][] token )
    {
        if ( token[0] == HttpRequestType.Options ||
             token[0] == HttpRequestType.Get     ||
             token[0] == HttpRequestType.Head    ||
             token[0] == HttpRequestType.Post    ||
             token[0] == HttpRequestType.Put     ||
             token[0] == HttpRequestType.Delete  ||
             token[0] == HttpRequestType.Trace   ||
             token[0] == HttpRequestType.Connect ) 
        {
            this.method = token[0].dup;
        }
        else
        {
            this.request_invalid = true;
            TraceLog.write("HttpRequest Error: unsupported request method in header");
        }
       
        if ( token[1].length ) 
        {
            this.urlpath = token[1].dup;
        }
        else
        {
            this.request_invalid = true;
            TraceLog.write("HttpRequest Error: zero url path length in header");
        }
       
        if ( token[2] == HttpProtocolVersion.V_10 || token[2] == HttpProtocolVersion.V_11 ) 
        {
            this.protocol = token[2].dup;
        }
        else
        {
            this.request_invalid = true;
            TraceLog.write("HttpRequest Error: unsupported http version in header [" ~ token[2] ~ "]");
        }

    }
    
    
    
    /**
     * Parses the read http header data including the request line
     * 
     * Params: 
     *     header_data = array with header data
     *      
     */
    private void  parseGeneralHeader ( char[][] header_data )
    {   
        uint i = 0;
        
        foreach (header_line; header_data)
        {
            // Skip first line (request line)
            if (i > 0)
            {
                // Identify end of request header
                if (TextUtil.trim(header_line) != "")
                {
                    // Parse header key/value pairs like
                    char[][] tokens = TextUtil.split(header_line.dup, ":");
                    
                    if (tokens.length > 1) 
                    {   
                        this.header_tokens[TextUtil.trim(tokens[0].dup)] = TextUtil.trim(tokens[1].dup);
                    }
                }
            }
            
            i++;
        }
    }
    
    
    
    /**
     * Removes EOL chars from a string
     *     
     * Params:
     *     str = string to be formatted
     *      
     * Returns:
     *     formatted string    
     */
    private char[] removeHttpEol ( char[] str )
    {
        str = TextUtil.substitute(str.dup, HttpConst.Eol, "");        
        str = TextUtil.substitute(str.dup, "\n", "");
        
        return str.dup;         
    }      

    
}


/*******************************************************************************

    HttpRequestException

********************************************************************************/

class HttpRequestException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }

    private:
        static void opCall(char[] msg) { throw new HttpRequestException(msg); }

}
