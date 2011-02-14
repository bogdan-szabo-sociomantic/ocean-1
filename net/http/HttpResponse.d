/*******************************************************************************

    HTTP Response Handler

    Copyright:      Copyright (c) 2009-2010 sociomantic labs. All rights 
                    reserved

    Version:        Mar 2009: Initial release
                    Aug 2010: Revised version (socket method)
                    
    Authors:        Lars Kirchhoff, Thomas Nicolai & David Eckardt
    
*******************************************************************************/

module ocean.net.http.HttpResponse;

/*******************************************************************************

    Imports

********************************************************************************/

private     import      ocean.net.http.HttpCookie, ocean.net.http.HttpConstants, 
                        ocean.net.http.HttpHeader, ocean.net.http.HttpTime;

private     import      ocean.util.OceanException;

private     import      ocean.core.Array;

private     import      tango.net.http.HttpConst;

private     import      tango.net.device.Socket: Socket;

private     import      tango.net.device.Berkeley: IPv4Address;

private     import      Integer = tango.text.convert.Integer;

/*******************************************************************************

    Implements Http response handler that manages the socket write after 
    retrieving a Http request.   
    
    Usage example
    ---
    import tango.net.http.HttpConst;
        
    HttpResponse response;
    SocketConduit socket  = ServerSocket.accept();
    
    response.setSocket(socket);
    ---
    
    Sending a cookie in the header
    ---
    response.cookie.attributes[`spam`] = `sausage`;
    response.cookie.domain             = `www.example.net`;
    ---
    
    Sending response wit a body message
    ---
    char[] message = `hello world`;
    response.send(message);
    ---
    
    
    Advanced usage example for using zero-copy to send file 
    content over the network.
    -- 
    extern (C)  
    {
        size_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);
    }
    
    off_t offset = 0;
    
    FileInput fi = new FileInput(fileName);
    
    int file_handle = fi.fileHandle();
    int file_length = fi.length();
    
    int sock_handle = SocketConduit.fileHandle();
    
    int out_size = sendfile (sock_handle, file_handle, &offset, file_length);
    
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


********************************************************************************/

struct HttpResponse
{
    /**************************************************************************
    
        Cookie
    
     **************************************************************************/    

    public              HttpCookie                  cookie;
    
    /**************************************************************************
        
        HTTP version
    
     **************************************************************************/    
    
    private             char[]                      http_version = HttpVersion.v11;
    
    /**************************************************************************
    
        send_date: set to false to omit the Date header 
    
     **************************************************************************/    

    private              bool                       send_date = false;
    
    /**************************************************************************
    
        Cookie header line 
    
     **************************************************************************/    

   private              char[]                      cookie_header;
   
   /***************************************************************************
       
       Output buffer
    
    ***************************************************************************/  
   
   private              char[]                      buf;
   
    /***************************************************************************
        
        HTTP timestamp generator
     
     ***************************************************************************/ 
    
    private             HttpTime                    httptime;
    
   /***************************************************************************
       
       Response header
       
    ***************************************************************************/
    
    private             HeaderValues                header;
    
    /***************************************************************************
        
        Socket connection
        
     ***************************************************************************/
     
     private            Socket                      socket;
 
     /**************************************************************************
         
          Set Default Header
      
          Params:
             socket  = output conduit (socket)
              
      **************************************************************************/
     
    public void setSocket ( Socket socket )
    {
        this.socket = socket;
    }
    
    /**************************************************************************
    
        Retrieves the remote client address. A socket must been previously set.
    
        FIXME; use inet_ntop
        
        Params:
           remote_addr = remote client address destination string
            
    **************************************************************************/

    public char[] getRemoteAddress ()
    in
    {
        assert (this.socket !is null);
    }
    body
    {
        scope addr = cast (IPv4Address) this.socket.socket.remoteAddress; 
        
        return addr.toAddrString();
    }
    

    /***************************************************************************
    
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
            status  = response code
            msg     = optional response code message, e.g. error message
            
          Returns:
             true on success or false on error
         
    **************************************************************************/
    
    public bool send ( HttpStatus status = HttpResponses.OK, char[] msg = `` )
    {
        return this.send(``, status, msg);
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
              data   = message body data, may be empty
              status = response code
              msg    = optional response code mesage, e.g. error message
         
         Returns:
             true on success or false on error

     **************************************************************************/

    public bool send ( char[] data, HttpStatus status = HttpResponses.OK, 
                       char[] msg = `` )
    in
    {
        assert (this.socket !is null, `http response error: invalid socket given`);
    }
    body
    {
        bool ok = true;
        
        try 
        {
            this.socket.checkError();
            
            this.setDefaultHeader();
            this.setHeaderValue(HttpHeader.ContentLength.value, data.length);

            if ( this.send_date )
            {
                this.setHeaderValue(HttpHeader.Date.value, this.getGmtDate());
            }
            
            if ( this.cookie.isSet() )
            {
                this.cookie.write(this.cookie_header);
                this.setHeaderValue(HttpHeader.SetCookie.value, this.cookie_header);
            }
            
            this.setHeader(status, msg);
            this.setBody(data);
            
            this.write();
        }
        catch (Exception e)
        {
            OceanException.Warn(`Error on response: {}`, e.msg);
            
            ok = false;
        }
        
        return ok;
    }
    
    /***************************************************************************
        
        Reset response
        
        Note: Method should be called on reuse of the struct
        
     ***************************************************************************/
    
    public void reset ()
    {
        this.cookie.reset();
        this.header.reset();
        
        this.cookie_header.length = 0;
        this.buf.length           = 0;
    }
    
    /**************************************************************************
     
         Set value for HTTP header field 
         
         Params:
             name  = header parameter name
             value = value of header parameter
             
     **************************************************************************/
    
    public void setHeaderValue ( in char[] name, in char[] value )
    {
        this.header[name] = value;
    }
    
    /**************************************************************************
     
         Set value for HTTP header field
         
         Params:
             name  = header parameter name
             value = value of header parameter
             
     **************************************************************************/
    
    public void setHeaderValue ( in char[] name, int value )
    {
        this.header[name] = Integer.toString(value);
    }
    
    /**************************************************************************
     
        Set Default Header
     
     **************************************************************************/
    
    private void setDefaultHeader ()
    {
        if ( !(HttpHeader.ContentType.value in this.header) )
        {
            this.header[HttpHeader.ContentType.value] = HttpHeader.TextHtml.value;
        }
        
        if ( !(HttpHeader.Connection.value in this.header) )
        {
            this.header[HttpHeader.Connection.value] = `close`.dup;
        }
    }

    /**************************************************************************
     
         Write response to socket
     
         Params:
             socket = output socket conduit
             
         Returns:
             void
         
     **************************************************************************/

    private void write ()
    {
        // TODO: this.socket.write usually returns the number of written 
        //       bytes. are we missing something????? do we have to 
        //       bug fix this?
        //
        // David, 2010-11-17:
        //
        // FIXME: Yes, we should fix this for three reasons:
        //        1. write() returns the number written bytes because it does
        //           not guarantee that all data are written. It is the
        //           invoker's responsibility to wrap write() in a loop.
        //        2. On EOF condition, write() returns Conduit.Eof; write() does
        //           not throw an exception in that case. It is the invoker's
        //           responsibility to check and handle this.
        //        3. Socket.flush is a fake (no-op).
        //        
        //        SimpleSerializer.writeData() exactly implements 1. and 2. so
        //        the fix will be using SimpleSerializer.writeData().
        
        this.socket.write(this.buf);
        this.socket.flush();
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
        this.buf.append(data);
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
    
    private void setHeader ( HttpStatus status, char[] msg = `` )
    {
        this.buf.concat(this.http_version, ` `, Integer.toString(status.code), ` `, status.name);
        
        if ( msg.length )
        {
            this.buf.append(`: `, msg);
        }
        
        this.buf.append(HttpConst.Eol);
        
        foreach (name, value; this.header)
        {
            this.buf.append(name, `: `, value, HttpConst.Eol);
        }

        this.buf.append(HttpConst.Eol);
    }
    
    /**************************************************************************
    
        Returns GMT formatted date/time stamp

		Method formats the current wall clock time (GMT) as HTTP compliant time
        stamp (asctime).
                
        Returns:
            HTTP time stamp of current wall clock time (GMT). Do not modify
            (exposes an internal buffer).
        
        Throws:
            Exception if formatting failed (supposed never to happen)
         
     **************************************************************************/
    
    public char[] getGmtDate ()
    {
        return this.httptime.toString();
    }
}
