module ocean.net.http2.HttpConnectionHandler;

private import ocean.net.http2.HttpRequest;
private import ocean.net.http2.HttpResponse;

private import tango.net.http.HttpConst: HttpResponseCode;

private import ocean.io.select.model.IFiberConnectionHandler;

private import tango.io.Stdout;

class HttpConnectionHandler : IFiberConnectionHandler, IFiberConnectionHandler.SelectWriter.IFinalizer
{
    alias .StatusCode   StatusCode;
    alias .HttpRequest  HttpRequest;
    alias .HttpResponse HttpResponse;
    
    protected HttpRequest request;
    protected HttpResponse response;
    
    protected uint keep_alive_maxnum = 0;
    
    public this ( EpollSelectDispatcher dispatcher, FinalizeDg finalizer )
    {
        this(dispatcher, finalizer, new HttpRequest, new HttpResponse);
    }
    
    public this ( EpollSelectDispatcher dispatcher, FinalizeDg finalizer,
                  HttpRequest request, HttpResponse response )
    {
        super(dispatcher, finalizer);
        
        this.request  = request;
        this.response = response;
    }
    
    final bool handle ( uint n )
    {
        this.request.reset();
        
        super.reader.reset().read(&this.request.parse!());
        
        char[] response_msg_body;
        
        StatusCode status = this.handle_request(response_msg_body);
        
        super.register(super.writer);
        
        super.writer.write(this.response.render(status, response_msg_body));
        
        bool more = n < this.keep_alive_maxnum;
        
        super.writer.finalizer =  more? null : this;
        
        return more;
    }
    
    abstract protected StatusCode handle_request ( out char[] response_msg_body );
    
    public void finalize ( )
    {
        Stderr("socked closed\n").flush();
        
        super.closeSocket();
    }
    
    protected uint keep_alive_seconds ( )
    {
        return 0;
    }
}
