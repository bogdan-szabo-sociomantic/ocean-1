/*******************************************************************************

    HTTP Server Response structure 

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Mar 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai, David Eckardt

    --
    Description:
    
    This class sends out the data to the client, while adding common header 
    to the response. 
    
    --
        
    Usage Example:
    
    ---
    
        import tango.net.http.HttpConst;
        
        SocketConduit conduit = ServerSocket.accept();
        HttpResponse response = new HttpResponse(conduit);
        
        // set a cookie
        
        response.cookie.attributes["spam"] = "sausage";
        response.cookie.domain             = "www.example.net";
           
        response.send(someData);        // sends a response message with 200 "OK"
                                        // status, including the cookie and someData
                                        // as body

    ---

    --
    
    TODO:
    
    Add Epoll non-blocking writing
    
    
*******************************************************************************/

module ocean.net.http.HttpResponse;


/*******************************************************************************

    Imports

*******************************************************************************/

private     import      ocean.net.http.HttpCookie;

private     import      ocean.net.http.HttpConstants;

private     import      tango.net.http.HttpConst;

private     import      tango.net.device.Socket: Socket; 

private     import      tango.io.model.IConduit: IConduit;

private     import      tango.stdc.time:  tm, time_t, time, gmtime;
private     import      tango.stdc.stdio: snprintf;

private     import      Integer = tango.text.convert.Integer;

private     import      tango.util.log.Trace;


/******************************************************************************

    HttpResponse

 ******************************************************************************/


struct HttpResponse
{
    /**************************************************************************
        
        HTTP version
    
     **************************************************************************/    
    
    public              HttpVersionId           http_version = HttpVersion.v11;
    
    /**************************************************************************
    
        Cookie
    
     **************************************************************************/    

    public              HttpCookie              cookie;
    
    /**************************************************************************
    
        send_date: set to false to omit the Date header 
    
     **************************************************************************/    

    public              bool                    send_date = true;
    
    /**************************************************************************
    
        Cookie header line 
    
     **************************************************************************/    

   private             char[]                  cookie_header;
    
    /*******************************************************************************
        
        Response Header
    
     *******************************************************************************/    
    
    
    private             char[][char[]]          response_header;     // response header values
    private             bool                    header_sent = false; // header already sent?
    
    /**************************************************************************
    
        Sends a HTTP response (without message body).
    
        Params:
            conduit     = output conduit (socket)
            code        = response code
            description = optional response code description, e.g. error message
            
          Returns:
             true on success or false on error
         
    **************************************************************************/
    
    
    public bool send ( Socket socket, HttpStatus status = HttpResponses.OK, char[] description = "" )
    {
        return this.send(socket, "", status, description);
    }
    
    /**************************************************************************
    
         Send HTTP response with or without message body
         
         Sends response header and message body through the output 
         buffer stream to the receiving client.
         
         !! Please be aware not to use the write funtion
         when the connection was going down. This will end
         up in a permanent blocking state of the socket.
         
         Params:
              conduit = output conduit (socket)
              data        = message body data, may be empty
              code        = response code
              description = optional response code description, e.g. error message
         
         Returns:
             true on success or false on error
         
     **************************************************************************/
    
    public bool send ( Socket socket, char[] data, HttpStatus status = HttpResponses.OK, char[] description = "" )
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
            
            this.sendHeader(socket, status, description);
            
            socket.write(HttpConst.Eol);
            
            socket.write(data);
            
            socket.flush();
        }
        catch (Exception e)
        {
            Trace.formatln("Error on response: {}", e.msg);
            
            ok = false;
        }
        
        return ok;
    }
    
    
    /**************************************************************************
     
         Set value for HTTP header parameter 
         
         Params:
             name  = header parameter name
             value = value of header parameter
             
     **************************************************************************/
    
    public void setHeaderValue ( char[] name, char[] value )
    {
        this.response_header[name.dup] = value.dup;
    }
    
    
    
    /**************************************************************************
     
         Set value for HTTP header parameter 
         
         Params:
             name  = header parameter name
             value = value of header parameter
             
     **************************************************************************/
    
    public void setHeaderValue ( char[] name, int value )
    {
        this.response_header[name.dup] = Integer.toString(value).dup;
    }
    
    /**************************************************************************
     
        Set Default Header
     
     **************************************************************************/
    private void setDefaultHeader ()
    {
        this.response_header[HttpHeader.Server.value]      = "ocean/sociomantic/0.1";
        this.response_header[HttpHeader.Connection.value]  = "close";
        this.response_header[HttpHeader.ContentType.value] = "text/html";
    }
    

    /**************************************************************************
     
        Send Response Header
     
         Params:
             conduit:     output conduit
             status:      HTTP response status
             description: additional status description
         
     **************************************************************************/
    
    private void sendHeader ( IConduit conduit, HttpStatus status, char[] description = "" )
    {
        conduit.write(this.http_version);
        conduit.write(" ");
        conduit.write(Integer.toString(status.code));
        conduit.write(" ");
        conduit.write(status.name);
        if (description.length)
        {
            conduit.write(": ");
            conduit.write(description);
        }
        conduit.write(HttpConst.Eol);
        
        foreach (header_name, header_value; this.response_header)
        {
            conduit.write(header_name);
            conduit.write(" ");
            conduit.write(header_value);
            conduit.write(HttpConst.Eol);
        }
    }  
    
    
    /**************************************************************************
    
        Formats the current GMT as RFC 1123 time stamp according to
        RFC 2616, 14.18:
        
            http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.18
             
        Returns:
            HTTP time stamp of current GMT
         
     **************************************************************************/

    private char[] formatTime ( )
    {
        // Sun, 06 Nov 1994 08:49:37 GMT
        
        const char[3][] Weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Sat"];
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
