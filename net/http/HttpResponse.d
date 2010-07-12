/*******************************************************************************

    HTTP Response Handler

    Copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    Version:        Mar 2009: Initial release

    Authors:        Lars Kirchhoff, Thomas Nicolai & David Eckardt
    
*******************************************************************************/

module ocean.net.http.HttpResponse;

/*******************************************************************************

    Imports

*******************************************************************************/

private     import      ocean.net.http.HttpCookie, ocean.net.http.HttpConstants, 
                        ocean.net.http.HttpHeader;

private     import      ocean.util.OceanException;

private     import      tango.net.http.HttpConst;

private     import      tango.net.device.Socket: Socket;

private     import      tango.stdc.time:  tm, time_t, time, gmtime;

private     import      tango.stdc.stdio: snprintf;

private     import      Integer = tango.text.convert.Integer;

debug
{
    private     import      tango.util.log.Trace;
}

/*******************************************************************************

    Implements Http response handler that manages the socket write after 
    retrieving a Http request.   
    
    Usage example
    ---
        import tango.net.http.HttpConst;
        
        SocketConduit socket  = ServerSocket.accept();
        HttpResponse response = new HttpResponse(socket);
    ---
    
    Sending a cookie in the header
    ---
        response.cookie.attributes["spam"] = "sausage";
        response.cookie.domain             = "www.example.net";
    ---
    
    Sending response wit a body message
    ---
    response.send(someData);
    ---
    ---
    
    
    Advanced usage example for using zero-copy to send file 
    content over the network.
    -- 
    extern (C)  
    {
        size_t sendfile(int out_fd, int in_fd, off_t *offset, 
            size_t count);
    }
    
    off_t offset = 0;
    
    FileInput fi = new FileInput(fileName);
    
    int file_handle = fi.fileHandle();
    int file_length = fi.length();
    
    int sock_handle = SocketConduit.fileHandle();
    
    int out_size = sendfile (sock_handle, file_handle, 
                             &offset, file_length);
    
    fi.close ();
    
    SocketConduit.detach()
    ---
    ---
    
    More information about using zero-copy can be found here:
    
    http://articles.techrepublic.com.com/5100-10878_11-1050878.html
    http://articles.techrepublic.com.com/5100-10878_11-1044112.html
    http://www.informit.com/articles/article.aspx?p=23618&seqNum=13
    
    TODO
     
    Add non-blocking writing with epoll


*******************************************************************************/

struct HttpResponse
{
    
    /**************************************************************************
        
        HTTP version
    
     **************************************************************************/    
    
    private             char[]                  http_version = HttpVersion.v11;
    
    /**************************************************************************
    
        Cookie
    
     **************************************************************************/    

    public              HttpCookie              cookie;
    
    /**************************************************************************
    
        send_date: set to false to omit the Date header 
    
     **************************************************************************/    

    private              bool                    send_date = false;
    
    /**************************************************************************
    
        Cookie header line 
    
     **************************************************************************/    

   private              char[]                   cookie_header;
   
   /**************************************************************************
       
       Output buffer
    
    **************************************************************************/  
   
   private              char[]                   buf;
   
   /**************************************************************************
       
       Header values
       
    ***************************************************************************/
    
    private              HeaderValues            response_header;
    
    /**************************************************************************
    
        Sends a HTTP response (without message body).
        
         = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
         
         !! Please be aware not to use the write funtion when the 
         connection was going down. This will end up in a permanent 
         blocking state of the socket.
         
         Please, always check status returned on request.read() 
         before using send().
         
         Usage example
         ---
         bool status = request.read(socket, buffer);
         
         if ( status )
         {
             response.send(...);
         }
         ---
         
         = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
         
        Params:
            socket	= output conduit (socket)
            status  = response code
            msg     = optional response code message, e.g. error message
            
          Returns:
             true on success or false on error
         
    **************************************************************************/
    
    public bool send ( Socket socket, HttpStatus status = HttpResponses.OK, 
                       char[] msg = `` )
    {
        return this.send(socket, ``, status, msg);
    }
    
    
    /**************************************************************************
    
         Send HTTP response with or without message body
         
         Sends response header and message body through the output 
         buffer stream to the receiving client.
         
         = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
         
         !! Please be aware not to use the write funtion when the 
         connection was going down. This will end up in a permanent 
         blocking state of the socket.
         
         Please, always check status returned on request.read()
         
         Usage example
         ---
         bool status = request.read(socket, buffer);
         
         if ( status )
         {
             response.send(...);
         }
         ---
         
         = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
         
         Params:
              socket = output conduit (socket)
              data   = message body data, may be empty
              status = response code
              msg    = optional response code mesage, e.g. error message
         
         Returns:
             true on success or false on error

     **************************************************************************/
    
    public bool send ( Socket socket, char[] data, 
                       HttpStatus status = HttpResponses.OK, char[] msg = `` )
    {
        bool ok = true;
        
        try 
        {
            socket.checkError();
            
            this.setDefaultHeader();
            this.setHeaderValue(HttpHeader.ContentLength.value, data.length);
            
            if (this.send_date)
            {
                this.setHeaderValue(HttpHeader.Date.value, this.formatTime());
            }
            
            if (this.cookie.isSet())
            {
                this.cookie.write(this.cookie_header);
                this.setHeaderValue(HttpHeader.SetCookie.value, this.cookie_header);
            }
            
            this.setHeader(status, msg);
            this.setBody(data);
            
            this.write(socket);
        }
        catch (Exception e)
        {
            debug
            {
                Trace.formatln(`Error on response: {}`, e.msg);
            }
            
            OceanException.Warn(`Error on response: {}`, e.msg);
            
            ok = false;
        }
        
        return ok;
    }
    
    /**************************************************************************
        
        Reset response
        
     ***************************************************************************/
    
    public void reset ()
    {
        this.cookie.reset();
        this.response_header.reset();
        
        this.cookie_header.length = 
        this.buf.length = 0;
    }
    
    /**************************************************************************
     
         Set value for HTTP header field 
         
         Params:
             name  = header parameter name
             value = value of header parameter
             
     **************************************************************************/
    
    public void setHeaderValue ( in char[] name, in char[] value )
    {
        this.response_header[name] = value;
    }
    
    /**************************************************************************
     
         Set value for HTTP header field
         
         Params:
             name  = header parameter name
             value = value of header parameter
             
     **************************************************************************/
    
    public void setHeaderValue ( in char[] name, int value )
    {
        this.response_header[name] = Integer.toString(value);
    }
    
    /**************************************************************************
     
        Set Default Header
     
     **************************************************************************/
    
    private void setDefaultHeader ()
    {
        if ( !(HttpHeader.ContentType.value in this.response_header) )
        {
            this.response_header[HttpHeader.ContentType.value] = HttpHeader.TextHtml.value;
        }
        
        if ( !(HttpHeader.Connection.value in this.response_header) )
        {
            this.response_header[HttpHeader.Connection.value] = `close`.dup;
        }
    }

    /**************************************************************************
     
         Write response to socket
     
         Params:
             socket = output socket conduit
             
         Returns:
             void
         
     **************************************************************************/

    private void write (Socket socket)
    {
        socket.write(this.buf);
        socket.flush();
    }
     
    /**************************************************************************
        
        Set response body message
     
         Params:
             data = body message payload
         
         Returns:
             void
         
     **************************************************************************/
    
    private void setBody ( in char[] data )
    {
        this.buf ~= data;
    }
    
    /**************************************************************************
        
        Set response header
     
         Params:
             conduit = output socket conduit
             status  = HTTP response status
             msg     = additional status message
         
         Returns:
             void
         
     **************************************************************************/
    
    private void setHeader ( HttpStatus status, char[] msg = "" )
    {
        this.buf  = this.http_version 
                  ~ ` `
                  ~ Integer.toString(status.code)
                  ~ ` `
                  ~ status.name;
        
        if ( msg.length )
        {
            this.buf ~= `: ` ~ msg;
        }
        
        this.buf ~= HttpConst.Eol;
        
        foreach (name, value; this.response_header)
        {
            this.buf ~= name ~ `: ` ~ value ~ HttpConst.Eol;
        }
        
        this.buf ~= HttpConst.Eol;
    }
    
    /**************************************************************************
    
        Formats the current GMT as RFC 1123 time stamp according to
        RFC 2616, 14.18:
        
        e.g. Sun, 06 Nov 1994 08:49:37 GMT
         
            http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.18
             
        Returns:
            HTTP time stamp of current GMT
         
     **************************************************************************/

    private char[] formatTime ()
    {
        const char[3][] Weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        const char[3][] Months   = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        
        char[0x20] result;
        
        int n;
        
        synchronized
        {
            time_t  t        = time(null);
            tm*     datetime = gmtime(&t);
            
            assert (datetime.tm_wday < Weekdays.length, "formatTime: invalid weekday");
            assert (datetime.tm_mon  < Months.length,   "formatTime: invalid month");
            
            char[] fmt = Weekdays[datetime.tm_wday] ~ ", %02d " ~
                         Months[datetime.tm_mon]    ~ " %04d %02d:%02d:%02d GMT" ~ '\0';
            
            n = snprintf(result.ptr, result.length, fmt.ptr,
                         datetime.tm_mday, datetime.tm_year + 1900,
                         datetime.tm_hour, datetime.tm_min, datetime.tm_sec);
            
            assert (n >= 0, "error formatting time");
        }
        
        return result[0 .. n].dup;
    }
    

}
