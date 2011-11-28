/******************************************************************************

    HTTP response message generator
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
    Before rendering an HTTP response message, the names of all header fields
    the response may contain must be added, except the General-Header,
    Response-Header and Entity-Header fields specified in RFC 2616 section 4.5,
    6.2 and 7.1, respectively.
    Before calling render(), the values of these message header fields of
    interest can be assigned by the ParamSet (HttpResponse super class) methods.
    Header fields with a null value (which is the value reset() assigns to all
    fields) will be omitted when rendering the response message header.
    Specification of General-Header fields:
    
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5
        
    Specification of Request-Header fields:
        
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html#sec6.2
        
    Specification of Entity-Header fields:
        
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1
    
    For the definition of the categories the standard request message header
    fields are of
    
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5

 ******************************************************************************/

module ocean.net.http2.HttpResponse;

/******************************************************************************

    Imports
    
 ******************************************************************************/

private import ocean.net.http2.message.HttpHeader;

private import ocean.net.http2.consts.StatusCodes: StatusCode, StatusPhrases;
private import ocean.net.http2.consts.HttpVersion: HttpVersion, HttpVersionIds;

private import ocean.net.http2.time.HttpTimeFormatter;

private import ocean.core.AppendBuffer;

/******************************************************************************/

class HttpResponse : HttpHeader
{
    /**************************************************************************
    
        Struct holding string buffers for header value formatting 
        
     **************************************************************************/

    private struct FormatBuffers
    {
        /**********************************************************************
        
            Content-Length header value
            
         **********************************************************************/

        char[] content_length;
    }
    
    /**************************************************************************
        
        Response HTTP version; defaults to HTTP/1.1
        
     **************************************************************************/

    private HttpVersion http_version_ = HttpVersion.v1_1;
    
    /**************************************************************************
    
        Content string buffer
        
     **************************************************************************/

    private AppendBuffer!(char) content;
    
    /**************************************************************************
    
        Header value formatting string buffers for  
        
     **************************************************************************/

    private FormatBuffers fmt_buffers;
    
    /**************************************************************************
    
        Time formatter
        
     **************************************************************************/

    private HttpTimeFormatter time;
    
    /**************************************************************************
    
        Constructor
        
     **************************************************************************/

    public this ( )
    {
        super(HeaderFieldNames.Response.NameList,
              HeaderFieldNames.Entity.NameList);
        
        this.content = new AppendBuffer!(char)(0x400);
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
        If a message body is provided, it is appended to the response message
        according to RFC 2616, section 4.3; that is,
        - If status is either below 200 or 204 or 304, neither a message body
          nor a "Content-Length" header field are appended.
        - Otherwise, if head is true, a "Content-Length" header field reflecting
          msg_body.length is appended but the message body itself is not.
        - Otherwise, if head is false, both a "Content-Length" header field
          reflecting msg_body.length and the message body itself are appended.
        
        If a message body is not provided, the same is done as for a message
        body with a zero length.
        
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
        bool append_msg_body = this.setContentLength(status, msg_body);
        
        this.content.clear();
        
        this.setStatusLine(status);
        
        this.setDate();
        
        foreach (key, val; super) if (val)
        {
            this.content.append(key, ": ", val, "\r\n");
        }
        
        this.content.append("\r\n", (append_msg_body && !head)? msg_body : null);
        
        return this.content[];
    }
    
    /**************************************************************************
    
        Sets the content buffer length to the lowest currently possible value.
        
        Returns:
            this instance
    
     **************************************************************************/
    
    public typeof (this) minimizeContentBuffer ( )
    {
        this.content.minimize();
        
        return this;
    }

    /**************************************************************************
    
        Sets the Content-Length response message header.
        
        Params:
            status   = HTTP status code
            msg_body = HTTP response message body
        
        Returns:
            true if msg_body should be appended to the HTTP response or false
            if it should not be appended because a message body is not allowed
            with the provided status code. 
    
     **************************************************************************/

    private bool setContentLength ( StatusCode status, char[] msg_body )
    {
        switch (status)
        {
            default:
                if (status >= 200)
                {
                    bool b = super.set("Content-Length", msg_body.length, this.fmt_buffers.content_length);
                    assert (b);
                    
                    return true;
                }
            
            case 204, 304:
                return false;
        }
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
        
        return this.content.append(HttpVersionIds[this.http_version_],    " ",
                                   super.writeUintFixed(statbuf, status), " ",
                                   StatusPhrases[status],                 "\r\n");
    }
    
    /**************************************************************************
    
        Sets the Date message header to the current wall clock time if it is not
        already set.
        
     **************************************************************************/

    private void setDate ( )
    {
        super.access(HeaderFieldNames.General.Names.Date, (char[], ref char[] val)
        {
            if (!val)
            {
                val = this.time.format();
            }
        });
    }
}
