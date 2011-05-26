/******************************************************************************

    HTTP response message generator
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
 ******************************************************************************/

module ocean.net.http2.HttpResponse;

/******************************************************************************

    Imports
    
 ******************************************************************************/

private import ocean.net.http2.consts.HeaderFieldNames;
private import ocean.net.http2.consts.StatusCodes: StatusCode, StatusPhrases;
private import ocean.net.http2.consts.HttpVersion: HttpVersion, HttpVersionIds;

private import ocean.net.util.ParamSet;

/******************************************************************************/

class HttpResponse : ParamSet
{
    /**************************************************************************
    
        Type alias for request header field constant definitions
        
     **************************************************************************/

    alias .HeaderFieldNames.Response.Names HeaderFieldNames;
    
    /**************************************************************************
    
        Struct holding string buffers for header value formatting 
        
     **************************************************************************/

    private struct FormatBuffers
    {
        char[] content_length;
    }
    
    /**************************************************************************
        
        Response HTTP version; defaults to HTTP/1.1
        
     **************************************************************************/

    private HttpVersion http_version_ = HttpVersion.v1_1;
    
    /**************************************************************************
    
        Content string buffer
        
     **************************************************************************/

    private char[] content;
    
    /**************************************************************************
    
        Actual content length
        
     **************************************************************************/

    private size_t content_length;
    
    /**************************************************************************
    
        Header value formatting string buffers for  
        
     **************************************************************************/

    private FormatBuffers fmt_buffers;
    
    /**************************************************************************
    
        Constructor
        
        Note: In addition to the standard HTTP response message header fields
              only the header fields corresponding to the names passed in
              header_field_names can be set in the response message.
              The standard HTTP response message header fields are those defined
              in the categories mentioned in the HTTP response message
              definition,
                  @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html
                  
              . These are the definitions:
                  - General header fields
                      @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5
                  - Response header fields
                      @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html#sec6.2
                  - Entity header fields
                      @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1
                      
        Params:
            header_field_names = names of message header fields of interest
                                 (case-insensitive)
        
     **************************************************************************/

    public this ( char[][] header_field_names ... )
    {
        super(.HeaderFieldNames.Response.NameList, header_field_names);
    }
    
    /**************************************************************************
    
        Sets the response HTTP version to v. v must be a known HttpVersion
        enumerator value and not be HttpVersion.Undefined.
        
        reset() will not change this value.
        
        Params:
            v = response HTTP version
            
        Returns
            response HTTP version
        
     **************************************************************************/

    public HttpVersion http_version ( HttpVersion v )
    in
    {
        assert (v,          "HTTP version undefined");
        assert (v <= v.max, "invalid HttpVersion enumerator value");
    }
    body
    {
        this.http_version_ = v;
        
        return v;
    }
    
    /**************************************************************************
    
        Gets the response HTTP version.
        
        Returns
            response HTTP version
        
     **************************************************************************/

    public HttpVersion http_version ( )
    {
        return this.http_version_;
    }
    
    /**************************************************************************
    
        Renders the response message, using the 200 "OK" status code.
        If a message body is provided, the "Content-Length" header field will be
        set and, if head is false, msg_body will be copied into an internal
        buffer.
        
        Params:
            msg_body = response message body
            head     = set to true if msg_body should actually not be appended
                       to the response message (HEAD response)
        
        Returns:
            
        
     **************************************************************************/

    public char[] render ( char[] msg_body = null, bool head = false )
    {
        return this.render(StatusCode.init, msg_body);
    }
    
    /**************************************************************************
    
        Renders the response message.
        If a message body is provided, the "Content-Length" header field will be
        set and, if head is false, msg_body will be copied into an internal
        buffer.
        
        Params:
            status   = status code; must be at least 100 and less than 1000
            msg_body = response message body
            head     = set to true if msg_body should actually not be appended
                       to the response message (HEAD response)
        
        Returns:
            response message (exposes an internal buffer)
        
     **************************************************************************/

    public char[] render ( StatusCode status, char[] msg_body = null, bool head = false )
    in
    {
        assert (100 <= status, "invalid HTTP status code (below 100)");
        assert (status < 1000, "invalid HTTP status code (1000 or above)");
    }
    body
    {
        if (msg_body)
        {
            bool b = super.set("Content-Length", msg_body.length, this.fmt_buffers.content_length);
            
            assert (b);
        }
        
        this.setStatusLine(status);
        
        foreach (key, val; super) if (val)
        {
            this.appendContent(key, ": ", val, "\r\n");
        }
        
        return this.appendContent("\r\n", head? null : msg_body);
    }
    
    /**************************************************************************
    
        Sets the content buffer length to the lowest currently possible value.
        
        Returns:
            this instance
    
     **************************************************************************/

    public typeof (this) minimizeContentBuffer ( )
    {
        this.content.length = this.content_length;
        
        return this;
    }
    
    /**************************************************************************
    
        Resets the content and renders the response status line.
        
        Params:
            status   = status code
        
        Returns:
            response status line

     **************************************************************************/

    private char[] setStatusLine ( StatusCode status )
    in
    {
        assert (this.http_version_, "HTTP version undefined");
    }
    body
    {
        char[3] statbuf;
        
        this.content_length = 0;
        
        return this.appendContent(HttpVersionIds[this.http_version_],    " ",
                                  super.writeUintFixed(statbuf, status), " ",
                                  StatusPhrases[status],                 "\r\n");
    }
    
    /**************************************************************************
    
        Extends content by n characters.
        
        Params:
            n = number of characters to extend content by
        
        Returns:
            slice to the last n characters in content after extension
    
     **************************************************************************/

    private char[] extendContent ( size_t n )
    {
        this.content_length += n;
        
        if (this.content.length < this.content_length)
        {
            this.content.length = this.content_length;
        }
        
        return this.content[$ - n .. $];
    }
    
    /**************************************************************************
    
        Concatenates strs and appends them to content.
        
        Params:
            strs = strings to concatenate and append to content
        
        Returns:
            slice to the result of concatenating strs in content
    
     **************************************************************************/

    private char[] appendContent ( char[][] strs ... )
    {
        size_t start = this.content_length;
        
        foreach (str; strs) if (str.length)
        {
            this.extendContent(str.length)[] = str[];
        }
        
        return this.content[$ - start .. $];
    }
}
