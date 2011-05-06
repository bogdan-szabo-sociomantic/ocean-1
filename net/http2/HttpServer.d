module net.http2.HttpServer;

private import ocean.io.coronet.c.pcl,
               ocean.io.coronet.c.coronet,
               ocean.net.http2.HttpListener;

private import tango.net.device.Berkeley;

private import tango.io.Stdout;

class HttpServer
{
    private IPv4Address  address;
    
    private HttpListener listener;
    
    private const backlog = 0x400;
    
    this ( char[] host, ushort port = 80 )
    {
        this(new IPv4Address(host, port));
    }
    
    this ( ushort port = 80 )
    {
        this(new IPv4Address(port));
    }
    
    this ( IPv4Address address )
    {
        Berkeley socket;
        
        with (socket)
        {
            family   = AddressFamily.INET;
            type     = SocketType.STREAM;
            protocol = ProtocolType.TCP;
            
            sock = cast (socket_t) Coronet.socket(family, type, 0);
            
            if (sock < 0)
            {
                exception("Unable to create socket: ");
            }
            
            addressReuse(true).bind(this.address = address).listen(this.backlog); // ServerSocket() constructor
            
            this.listener = new HttpListener(sock);
        }
    }
    
    void start ( )
    {
        this.listener.call();
        
        while (true)
        {
            Coronet.select(-1);
            Coronet.dispatch(0);
        }
    }
}