/*******************************************************************************

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved
    
    version:        Feb 2009: Initial release
    
    authors:        Lars Kirchhoff & Thomas Nicolai
            
    Basic HTTP Server implementation to serve HTTP requests.
     
    
    --
    
    Description:
    
    --
    
    Usage:
    
    // initialize the object, that will be executed in the HttpServer 
    // class.
    auto worker = new Worker();
                          
    // initialize the server         
    HttpServer http_server  = new HttpServer(10, 8000, 400, true); 
    
    // set the function that should be executed
    http_server.setThreadFunction(&worker.categorize);
    
    // finally start the server
    http_server.start();  
    
    -- 
    
    Additional information:
    
    Fast file copy over a socket with sendfile()
    
    // c function declaration
    extern (C)  {
        size_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);
    }
    
    // file position pointer
    off_t offset = 0;
    
    // get file handle
    FileInput fi = new FileInput(fileName);
    int file_handle = fi.fileHandle();
    
    // get file length
    int file_length = fi.length();
    
    // get socket file handle
    int sock_handle = SocketConduit.fileHandle();
    
    // use sendfile
    int out_size = sendfile (sock_handle, file_handle, &offset, file_length);
    
    // close file handle
    fi.close ();
    
    // close socket handle
    SocketConduit.detach()
  
    http://articles.techrepublic.com.com/5100-10878_11-1050878.html
    http://articles.techrepublic.com.com/5100-10878_11-1044112.html
    http://www.informit.com/articles/article.aspx?p=23618&seqNum=13
    
    --
    
    IMPORTANT 
    
    tango.net.Socket --> send() needs to be patched  
    
    enum SocketFlags: int
    {
            NONE =           0,
            OOB =            0x1, //out of band
            PEEK =           0x02, //only for receiving
            DONTROUTE =      0x04, //only for sending
            MSG_NOSIGNAL =   0x4000,
    }
    
    int send(void[] buf, SocketFlags flags=SocketFlags.MSG_NOSIGNAL)   
     
    SIGPIPE will kill program:
    http://www.digitalmars.com/d/archives/digitalmars/D/bugs/Issue_1491_New_if_working_with_timed-out_socket_SIGPIPE_will_kill_program_12123.html
    http://www.dsource.org/projects/tango/ticket/968
     
    Good non-blocking socket tutorial:
    http://www.scottklement.com/rpg/socktut/selectserver.html

    Enabling High Performance Data Transfers:
    http://www.psc.edu/networking/projects/tcptune/
    
    
*******************************************************************************/

module      ocean.net.http.HttpServer;


/*******************************************************************************

    Imports

*******************************************************************************/


private     import      tango.core.Thread, tango.core.ThreadPool;

private     import      tango.io.selector.EpollSelector;

private     import      tango.net.device.Berkeley, tango.net.device.Socket,                            
                        tango.net.InternetAddress, tango.net.http.HttpConst;

private     import      tango.sys.linux.linux;

private     import      Integer = tango.text.convert.Integer;

private     import      ocean.util.OceanException, ocean.util.TraceLog;


/*******************************************************************************

    Module Constants

********************************************************************************/


private     const int[1]        TCP_OPTION_ENABLE  = true;   // TCP Options enable
private     const int[1]        TCP_OPTION_DISABLE = false; // TCP Options disable

private     const int           EPOLLWAIT_INFINITE = -1;    // Infinite Wait for EPoll 


/*******************************************************************************

    HttpServer

********************************************************************************/

class HttpServer
{
    
    /*******************************************************************************

         Server Configuration

     *******************************************************************************/
       
    private             uint                            number_threads;  // number of threads          
    private             uint                            socket_port;     // port      
    private             uint                            back_log;        // size of backlog

    private             bool                            reuse;           // socket reuse
    
    private             pid_t                           child_id;        // child process id
    
    
    /*******************************************************************************

         Socket & EPoll

    *******************************************************************************/
    
    private             ServerSocket                    socket;     
    private             EpollSelector                   selector;

    
    /*******************************************************************************
    
        Socket Connection Handler Thread
            
        thread_pool = thread pool managing socket connections
        thread_func     delegate called to handle socket connections
    
    *******************************************************************************/
    
    
    private             ThreadPool!(Socket)             thread_pool;
    private             int delegate(Socket)            thread_func;
    
    
    /*******************************************************************************
        
        Public Methods
    
     *******************************************************************************/
    
    
    /**
     * Initialize server object with parameter
     *
     * Params:
     *     number_threads = number of worker threads
     *     socket_port = server port
     *     back_log = size of backlog
     *     reuse = enable/disable socket reuse
     */
    this ( uint number_threads = 1, uint socket_port = 80, uint back_log = 128, bool reuse = false )
    {
        this.number_threads = number_threads;
        this.socket_port    = socket_port;
        this.back_log       = back_log;
        this.reuse          = reuse;  
        this.child_id       = getpid();   
        
        createSocket();    
    }
        
    
    
    /**
     * Set function that should be executed with a single thread
     * 
     */
    public void setThreadFunction ( int delegate(Socket conduit) func_dg )
    {
        this.thread_func = func_dg;
    }
    
        
    
    /**
     * Start the Asnychronous EPoll Server. 
     * 
     * First the EPollSelector object is created, which lists for events 
     * on the socket and on the conduits afterwards.
     * 
     * The EPollSelector listens on two different interface:
     * 
     * 1. ServerSocket (this.socket), which listens to any connection 
     *    attempt by a client
     *    
     * 2. SocketConduit (_conduit), which is the conduit, that is returned
     *    from the ServerSocket on accept. On this interface it listens 
     *    to any read events.
     *  
     * Returns:
     *      success or failure
     */
    public int start () 
    {   
        int                 event_count;         
        Socket              conduit;
        int                 conduit_filehandle;
        Socket[int]         connections;        // socket conduit connection pool
        
        createThreadpool();
        
        this.selector = new EpollSelector(); 
        
        this.selector.open(500, 64);
        this.selector.register(this.socket, Event.Read | Event.Hangup | Event.Error | Event.InvalidHandle);     
        
        scope(exit) 
        {
            this.selector.close;
            this.socket.shutdown;
            this.socket.close;
        }
        
        this.socket.socket.blocking(false);     //  socket to non-blocking
       
        while(true)
        {  
            try 
            {
                // wait for connections to arrive
                event_count = this.selector.select(EPOLLWAIT_INFINITE);
            }
            catch (Exception e) 
            {
                TraceLog.write("HttpServer (EPoll Selector select): " ~ e.msg);
            } 
            
            if (event_count > 0) 
            {   
                foreach (SelectionKey key; this.selector.selectedSet())
                {
                    // Check if key event conduit is a ServerSocket. If yes
                    // accept socket connection and put socket conduit in 
                    // socket conduit array for later usage.
                    // Assign the new socket conduit to EPollSelector.
                    if (key.conduit is socket) 
                    {
                        conduit = (cast(ServerSocket) key.conduit).accept();
                        
                        conduit_filehandle              = conduit.fileHandle();
                        connections[conduit_filehandle] = conduit; 

                        // Run thread non blocking reading/writing is done in the 
                        // HttpRequest/HttpResponse object                
                        this.serviceThread(connections[conduit_filehandle]);                        
                    }
                    
                    // If an error on the SelectionKey occurs
                    else if (key.isError() || key.isHangup() || key.isInvalidHandle())
                    {
                        TraceLog.write("HttpServer: key.conduit error");
                        this.selector.unregister(key.conduit);                              
                    }
                    
                    else
                    {
                        TraceLog.write("HttpServer: unknown conduit");
                    }
                }  
            }
            else 
            {
                TraceLog.write("HttpServer: event count <= 0");
            }
            
            selector.register(this.socket, Event.Read | Event.Hangup | Event.Error | Event.InvalidHandle);
        }
        
        
       
        return 0;
    }
    
    
    /*******************************************************************************
        
        Private Methods
    
    ********************************************************************************/
    
    /**
     * Create Server Socket 
     *
     */
    private void createSocket () 
    {
        socket = new ServerSocket(new InternetAddress(socket_port), back_log, reuse);
    }
        
    
    
    /**
     * Create ThreadPool
     *
     */
    private void createThreadpool ()
    {   
        this.thread_pool = new ThreadPool!(Socket)(this.number_threads);                
    }
    
    
    
    /**
     * Function that assigns the thread action to the ThreadPool together
     * with the SocketConduit. This is packaged in this function for possible 
     * later additions to thread functionality.
     * 
     * Params:     
     *     socket_conduit   = conduit for writing and reading on the socket
     *                
     * TODO: 
     * Add a timeout after which a thread is freed again --> setting 
     * running to false               
     */
    private void serviceThread ( Socket socket_conduit ) 
    {   
        thread_pool.assign(&threadAction, socket_conduit);
    }
    
    
    
    /**
     * Executes the function that is provide by this.thread_func 
     * and detaches the socket conduit if socket action is finished.
     * 
     * Params:
     *     socket_conduit = socket conduit 
     */
    private void threadAction ( Socket socket_conduit )
    {      
        // start socket action defined by this.thread_func delegate
        if (thread_func)
        {   
            thread_func(socket_conduit);         
        }
        else 
        {
            throw new HttpServerException("HttpServer Exception (_threadAction): thread function/object is not defined");     
        }
       
        // detach socket conduit, which will close the client connection 
        try 
        {
            if (socket_conduit)
            {
                socket_conduit.shutdown();
                socket_conduit.detach();
                this.selector.unregister(socket_conduit);
            }
        }
        catch (Exception e)
        {
            throw new HttpServerException("HttpServer Exception (_threadAction): " ~ e.msg);            
        }
    }
    
}


/*******************************************************************************

        HttpServerException

********************************************************************************/

class HttpServerException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }

    private:
        static void opCall(char[] msg) { throw new HttpServerException(msg); }

}
