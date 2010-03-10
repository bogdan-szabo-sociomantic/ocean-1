/*******************************************************************************

    Module to send data out to the client. 

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Mar 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai

    --
    Description:
    
    This class sends out the data to the client, while adding common header 
    to the response. 
    
    --
        
    Usage Example:
    
    import tango.net.http.HttpConst;
    
    SocketConduit conduit = ServerSocket.accept();
    HttpResponse response = new HttpResponse(conduit);
    
    response.setProtocolVersion("HTTP/1.1");
    response.setResponseCode(HttpResponses.OK);
       
    response.send(someData);
    
    --
    
    TODO:
    
    1. Add stream buffer to conduit interface
    2. Add Epoll non-blocking writing
    
    
*******************************************************************************/

module ocean.net.http.HttpResponse;


/*******************************************************************************

    Imports

*******************************************************************************/

public      import      ocean.core.Exception: HttpResponseException;

private     import      ocean.net.http.HttpConstants;

private     import      tango.net.http.HttpConst;

private     import      tango.io.stream.Buffered;

private     import      tango.net.device.Socket; 
                            
private     import      Integer = tango.text.convert.Integer;


/*******************************************************************************

    HttpResponse

********************************************************************************/

class HttpResponse
{

    /*******************************************************************************
        
        Output Buffer
    
     *******************************************************************************/
    
    
    private             BufferedOutput          output_buffer;

    
    /*******************************************************************************
        
        Default Response Parameter
    
     *******************************************************************************/    

    
    private             char[]                  protocol = HttpProtocolVersion.V_11;
    private             int                     response_code = 200;
    private             char[]                  response_name = "OK";
    
    
    /*******************************************************************************
        
        Response Header
    
     *******************************************************************************/    
    
    
    private             char[][char[]]          response_header;     // response header values
    private             bool                    header_send = false; // header already sent?


    /*******************************************************************************
    
        Public Methods

     *******************************************************************************/
    
    
    /**
     * Constructor: Inititialize Socket & Ouput Buffer
     * 
     * Params:
     *     conduit = socket conduit on which to write on
     *     protocol = HTTP protocol version
     */
    this ( Socket socket ) 
    {
        this.output_buffer = new BufferedOutput(socket);        
        
        setDefaultHeader();
    }
    
    
    
    /**
     * Send HTTP response 
     * 
     * Sends response header and message body through the output 
     * buffer stream to the receiving client.
     * 
     * !! Please be aware not to use the write funtion
     * when the connection was going down. This will end
     * up in a permanent blocking state of the socket.
     * 
     * TODO: Maybe check if socket is still alive (alive check)
     */
    public void send ( char[] data, int response_code = 200 )
    {
        try 
        {
            if (!header_send)
            {
                this.setHeaderValue(HttpHeader.ContentLength.value, data.length);
                this.sendHeader();
            }
    
            if ( data[$-2..$] != "\n\n" )
            {
                data ~= "\n\n";
            }
            
            this.output_buffer.write(data);
            this.output_buffer.flush();
        }
        catch (Exception e)
        {
            HttpResponseException(e.msg);
        }
    }
    
    
    
    /**
     * Set HTTP protocol for response 
     * 
     * @see http://www.w3.org/Protocols/
     * 
     * Params:
     *     protocol = http protocol version
     */
    public void setProtocolVersion ( char[] protocol )
    {
        assert(protocol == HttpProtocolVersion.V_10 || HttpProtocolVersion.V_11);
        
        this.protocol = protocol;
    }
    
    
    
    /**
     * Set HTTP response code for response
     * 
     * Params:
     *     response_code = response code
     */
    public void setResponseCode ( HttpStatus status ) 
    {
        this.response_code = status.code;
        this.response_name = status.name;
    }
        
    
    
    /**
     * Set value for HTTP header parameter 
     * 
     * Params:
     *     name  = header parameter name
     *     value = value of header parameter
     */
    public void setHeaderValue ( char[] name, char[] value )
    {
        this.response_header[name] = value;
    }
    
    
    
    /**
     * Set value for HTTP header parameter 
     * 
     * Params:
     *     name  = header parameter name
     *     value = value of header parameter
     */
    public void setHeaderValue ( char[] name, uint value )
    {
        this.response_header[name] = Integer.toString(value);
    }
    
        
    /*******************************************************************************
        
        Private Methods
    
     *******************************************************************************/
    
    
    /**
     * Send Response Header
     * 
     * Creates response header based on request header and sends it out by 
     * flushing the buffer. do not send any header data beyond this point!
     */
    private void sendHeader ()
    {
        char[] header; 
        
        header ~= this.protocol ~ " " ~ Integer.toString(this.response_code) ~ " " ~ " " ~ this.response_name ~ HttpConst.Eol;
        
        foreach (header_name, header_value; response_header)
        {
            header ~= header_name ~ " " ~ header_value ~ HttpConst.Eol;
        }
        
        header ~= HttpConst.Eol;
                        
        this.output_buffer.write (header);
        this.output_buffer.flush();
        
        this.header_send = true;
    }  
    
    
    /**
     * Set Default Header
     *
     */
    private void setDefaultHeader ()
    {
        this.response_header[HttpHeader.Server.value]      = "ocean/sociomantic/0.1";
        this.response_header[HttpHeader.Connection.value]  = "close";
        this.response_header[HttpHeader.ContentType.value] = "text/html";
    }
    
}
