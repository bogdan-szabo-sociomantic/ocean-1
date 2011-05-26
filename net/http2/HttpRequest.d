/******************************************************************************

    HTTP request message parser
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
 ******************************************************************************/

module ocean.net.http2.HttpRequest;

/******************************************************************************

    Imports
    
 ******************************************************************************/

private import ocean.net.http2.message.HttpHeaderParser,
               ocean.net.http2.consts.HeaderFieldNames,
               ocean.net.http2.consts.HttpMethod,
               ocean.net.http2.consts.HttpVersion,
               ocean.net.http2.consts.StatusCodes: StatusCode;

private import ocean.net.http2.HttpException: HttpException, HeaderParameterException;

private import ocean.net.util.ParamSet;

private import tango.net.Uri: Uri;

private import tango.net.http.HttpConst: HttpResponseCode;

/******************************************************************************/

class HttpRequest : ParamSet
{
    /**************************************************************************
    
        Type alias for request header field constant definitions
        
     **************************************************************************/

    alias .HeaderFieldNames.Request.Names HeaderFieldNames;
    
    /**************************************************************************
    
        Message header parser
        
     **************************************************************************/

    private HttpHeaderParser header_;
    
    /**************************************************************************
    
        Maximum accepted request URI length
        
     **************************************************************************/

    public uint max_uri_length = 0x4000;
    
    /**************************************************************************
    
        Requested HTTP method
        
     **************************************************************************/

    public HttpMethod method;
    
    /**************************************************************************
    
        Requested HTTP version
        
     **************************************************************************/

    public HttpVersion http_version;
    
    /**************************************************************************
    
        Request message body
        
     **************************************************************************/

    private char[] msg_body_;
    
    /**************************************************************************
    
        Request message body position counter
        
     **************************************************************************/

    private size_t msg_body_pos;
    
    /**************************************************************************
    
        URI instance
        
     **************************************************************************/

    private Uri uri_;
    
    /**************************************************************************
    
        Tells whether the end of the message header has been reached and we are
        receiving the message body, if any
        
     **************************************************************************/
    
    private bool header_complete;
    
    /**************************************************************************
    
        Tells whether the end of the message has been reached
        
     **************************************************************************/

    private bool finished;
    
    /**************************************************************************
    
        Reusable exception instances
        
     **************************************************************************/

    private HttpException               http_exception;
    private HeaderParameterException    header_param_exception;
    
    /**************************************************************************
    
        Constructor
        
        Note: In addition to the standard HTTP request message header fields
              only the header fields corresponding to the names passed in
              header_field_names can be obtained from the request message.
              The standard HTTP request message header fields are those defined
              in the categories mentioned in the HTTP request message
              definition,
                  @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html
                  
              . These are the definitions:
                  - General header fields
                      @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5
                  - Request header fields
                      @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.3
                  - Entity header fields
                      @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1
              
        Params:
            header_field_names = names of message header fields of interest
                                 (case-insensitive)
        
     **************************************************************************/

    public this ( char[][] header_field_names ... )
    {
        super(.HeaderFieldNames.Request.NameList, header_field_names);
        
        this.header_ = new HttpHeaderParser;
        
        this.uri_ = new Uri;
        
        this.http_exception = new HttpException;
        this.header_param_exception = new HeaderParameterException;
        
        this.reset_();
    }
    
    /**************************************************************************
    
        Returns:
            message header parser instance to get header parse results and set
            limitations
        
     **************************************************************************/

    public IHttpHeaderParser header ( )
    {
        return this.header_;
    }
    
    /**************************************************************************
    
        Returns:
            slice to the method name in the message header start line if the
            start line has already been parsed or null otherwise
        
     **************************************************************************/

    public char[] method_name ( )
    {
        return this.header_.start_line_tokens[0];
    }
    
    /**************************************************************************
    
        Returns:
            URI instance which is set to the requested URI if the start line has
            already been parsed
        
     **************************************************************************/

    public Uri uri ( )
    {
        return this.uri_;
    }
    
    /**************************************************************************
    
        Returns:
            URI instance which is set to the requested URI if the start line has
            already been parsed
        
     **************************************************************************/

    public char[] uri_string ( )
    {
        return this.header_.start_line_tokens[1];
    }
    
    /**************************************************************************
    
        Obtains the request message body (which may be empty). It may be
        incomplete if parse() did not yet reach the end of the request message
        or null if parse() did not yet reach the end of the request message
        header.
    
        Returns:
            request message body parsed so far or null if parse() did not yet
            reach the end of the request message header
        
     **************************************************************************/

    public char[] msg_body ( )
    {
        return this.msg_body_;
    }
    
    /**************************************************************************
    
        Obtains the integer value of the request header field corresponding to
        header_field_name. The header field value is expected to represent an
        unsigned integer number in decimal representation.
        
        Params:
            header_field_name = request header field name (case-insensitive;
                                must be one of the message header field values
                                of interest passed on instantiation)
        
        Returns:
            integer value of the request header field
            
        Throws:
            HeaderParameterException if
                - the field is missing in the header or
                - the field does not contain an unsigned integer value in
                  decimal representation.
        
     **************************************************************************/

    public uint getUint ( char[] header_field_name )
    {
        uint n;
        
        bool is_set,
             ok = super.getUint(header_field_name, n, is_set);
        
        this.header_param_exception.assertEx(is_set, header_field_name, __FILE__, __LINE__, "header parameter missing");
        this.header_param_exception.assertEx(ok,     header_field_name, __FILE__, __LINE__, "decimal unsigned integer number expected");
        
        return n;
    }
    
    /**************************************************************************
    
        Parses content which is expected to be either the start of a HTTP
        message or a HTTP message fragment that continues the content passed on
        the last call to this method.
        If this method indicates that the end of the message has been reached,
        reset() must be called before calling this method again.
        
        Returns:
            the number of elements consumed from content, if finished, or
            content.length + 1 otherwise
        
        Throws:
            HttpParseException
                - on parse error: if
                    * the number of start line tokens is different from 3 or
                    * a regular header_line does not contain a ':';
                - on limit excess: if
                    * the header size in bytes exceeds the requested limit or
                    * the number of header lines in exceeds the requested limit.
            
            HttpException if
                - the HTTP method is unknown or
                - the HTTP version identifier is unknown or
                - the URI is missing or
                - the URI length exceeds the requested max_uri_length.
            
            Note that msg_body_length() may throw a HttpException, especially if
                - the announced message body length exceeds an allowed limit or
                - the announced message body length cannot be determined because
                  header parameters are missing.
            
     **************************************************************************/

    public size_t parse ( char[] content, lazy size_t msg_body_length = 0 )
    in
    {
        assert (!(this.header_complete && this.msg_body_pos >= this.msg_body_.length));
    }
    body
    {
        if (!this.header_complete)
        {
            char[] msg_body_start = this.header_.parse(content);
            
            this.header_complete = msg_body_start !is null;
            
            if (this.header_complete)
            {
                this.setRequestLine();
                
                foreach (element; this.header_.header_elements)
                {
                    super.set(element.key, element.val);
                }
                
                this.msg_body_.length = msg_body_length();
                
                content = msg_body_start;
           }
        }
        
        if (this.header_complete && this.msg_body_pos < this.msg_body_.length)
        {
            size_t len = min(content.length, this.msg_body_.length - this.msg_body_pos);
            
            this.msg_body_[this.msg_body_pos .. this.msg_body_pos + len] = content[0 .. len];
        }
        
        return content.length + !(this.header_complete && this.msg_body_pos >= this.msg_body_.length);
    }
    
    /**************************************************************************
    
        Obtains the request line parameters.
        
        Throws:
            HttpException if
                - the HTTP method is unknown or
                - the HTTP version identifier is unknown or
                - the URI is missing or
                - the URI length exceeds the requested max_uri_length.
        
     **************************************************************************/

    private void setRequestLine ( )
    {
        this.method = HttpMethodNames[this.method_name];
        
        this.http_exception.assertEx(this.method, __FILE__, __LINE__, StatusCode.BadRequest, "invalid HTTP method");
        
        this.http_version = HttpVersionIds[this.header_.start_line_tokens[2]];
        
        this.http_exception.assertEx(this.http_version, __FILE__, __LINE__, StatusCode.BadRequest, "invalid HTTP version");
        
        this.http_exception.assertEx(this.header_.start_line_tokens[1].length, __FILE__, __LINE__, StatusCode.BadRequest, "no uri in request");
        this.http_exception.assertEx(this.header_.start_line_tokens[1].length <= this.max_uri_length, __FILE__, __LINE__, StatusCode.RequestURITooLarge);
        
        this.uri_.parse(this.header_.start_line_tokens[1]);
    }
    
    /**************************************************************************
    
        Resets the state
        
     **************************************************************************/

    protected override void reset_ ( )
    {
        this.method             = this.method.init;
        this.http_version       = this.http_version.init;
        this.msg_body_pos       = 0;
        this.header_complete    = false;
        this.uri_.reset();
        this.header_.reset();
    }
    
    /**************************************************************************
    
        Returns the minimum of a and b.
        
        Returns:
            minimum of a and b
        
     **************************************************************************/

    static size_t min ( size_t a, size_t b )
    {
        return ((a < b)? a : b);
    }
}

//version = OceanPerformanceTest;

version (OceanPerformanceTest)
{
    import tango.io.Stdout;
    import tango.core.internal.gcInterface: gc_disable, gc_enable;
}

unittest
{
    const char[] content =
        "GET /dir?query=Hello%20World!&abc=def&ghi HTTP/1.1\r\n"
        "Host: www.example.org:12345\r\n"
        "User-Agent: Mozilla/5.0 (X11; U; Linux i686; de; rv:1.9.2.17) Gecko/20110422 Ubuntu/9.10 (karmic) Firefox/3.6.17\r\n"
        "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n"
        "Accept-Language: de-de,de;q=0.8,en-us;q=0.5,en;q=0.3\r\n"
        "Accept-Encoding: gzip,deflate\r\n"
        "Accept-Charset: UTF-8,*\r\n"
        "Keep-Alive: 115\r\n"
        "Connection: keep-alive\r\n"
        "Cache-Control: max-age=0\r\n"
        "\r\n";
    
    scope request = new HttpRequest("Keep-Alive", "User-Agent");
    
    version (OceanPerformanceTest)
    {
        const n = 1000_000;
    }
    else
    {
        const n = 1;
    }
    
    version (OceanPerformanceTest) gc_disable;
    
    for (uint i = 0; i < n; i++)
    {
        request.reset();
        request.parse(content);
        
        assert (request.method_name           == "GET");
        assert (request.method                == request.method.Get);
        assert (request.uri_string            == "/dir?query=Hello%20World!&abc=def&ghi");
        assert (request.http_version          == request.http_version.v1_1);
        assert (request["user-agent"]         == "Mozilla/5.0 (X11; U; Linux i686; de; rv:1.9.2.17) Gecko/20110422 Ubuntu/9.10 (karmic) Firefox/3.6.17");
        assert (request["Accept"]             == "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
        assert (request["Accept-Language"]    == "de-de,de;q=0.8,en-us;q=0.5,en;q=0.3");
        assert (request["Accept-Encoding"]    == "gzip,deflate");
        assert (request["Accept-Charset"]     == "UTF-8,*");
        assert (request.getUint("keep-alive") == 115);
        assert (request["connection"]         == "keep-alive");
        
        version (OceanPerformanceTest) if (!(i % 10_000))
        {
            Stderr(i)("\n").flush();
        }
    }
    
    version (OceanPerformanceTest) gc_enable;
}