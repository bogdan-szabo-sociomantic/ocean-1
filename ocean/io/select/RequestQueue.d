/*******************************************************************************

    Abstract classes for RequestQueues

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Mathias Baumann

    Generic interfaces and logic for RequestQueues and related classes.

    Genericly speaking, a request handler registers at the queue (ready()).
    The request queue will then call notify() to inform the handler that
    now it has requests, the handler is expected to call pop() to receive
    those events. It should keep calling pop() until no events are left
    and then re-register at the queue and wait for another call to notify().
    In other words:
    
    1) RequestQueue.ready(RequestHandler)
    2) RequestQueue calls RequestHandler.notify()
    3) RequestHandler calls RequestQueue.pop();
      a) pop() returned a request: RequestHandler processes data, back to 3)
      b) pop() returned null: continue to 4)
    4) RequestHandler calls RequestQueue.ready(RequestHandler)
    
    A more simple solution like this was considered:
    
    1) RequestQueue.ready(RequestHandler)
    2) RequestQueue calls RequestHandler.notify(Request)
    3) RequestHandler processes, back to 1)

    But was decided against because it would cause a stackoverflow for fibers,
    as a RequestHandler needs to call RequestQueue.ready() and if fibers are 
    involved that call will be issued from within the fiber. 
    If ready() calls notify again another processing of a request in the fiber
    will happen, causing another call to ready() leading to a recursion.  
    
    Now we require that the fiber calls pop in a loop.
    
    Usage example for a hypothetical client who writes numbers to a socket
    ---

        module NumberQueue;

        import ocean.io.select.RequestQueue;

        import ocean.io.select.EpollSelectDispatcher;


        class NumberHandler : RequestHandler!(ulong)
        {
            private ISelectClient.Event myEvents;
    
            private Socket socket;
            
            private EpollSelectDispatcher epoll;
            
            public this ( EpollSelectDispatcher epoll, 
                          RequestQueue!(ulong) queue, 
                          size_t buffer_size )
            {
                this.socket = new Socket;
                this.socket.connect ("example.org", 421);
            
                super(buffer_size, queue, socket);
                      
                this.epoll = epoll;
            }

            // called within the fiber of the base class
    	    protected void request ( ref T number );
            {
                // initialize the connection if not already initialized
                this.myEvents = Event.Write;
                this.epoll.register(this);
    
                // wait till it's ready for writing
                fiber.cede();
    
                // k, socket ready for writing
                socket.write(number);
            }
    
            public Event events ( )
            {
                return this.myEvents;
            }
    
            public bool handle ( Event event )
            {
                fiber.call(); 
            }
        }


        class EpollNumber
        {
            RequestQueue!(ulong) handlers;

            this ( EpollSelectDispatcher epoll )
            {
                const max_connections = 10;
                const max_requests_in_queue = 100;

                this.handlers = new RequestQueue!(ulong)(max_connections, max_requests_in_queue);

                for ( int i; i < max_connections; i++ )
                {
                    this.handlers.ready(new NumberHandler(epoll, handlers, ulong.sizeof));
                }
            }

            bool sendNumber ( ulong num )
            {
                return this.handlers.push(num);
            }
        }


        epoll = new EpollSelectDispatcher;
        numbers = new EpollNumber(epoll);

        // TODO
        for ( size_t i = 0; i < num_connections; i++ )
        {
            this.connections.handlerWaiting(new CurlConnection(&this.handleConnection, &this.cleanupConnection));
        }

        numbers.sendNumber(23);
        numbers.sendNumber(85);
        numbers.sendNumber(42);

        epoll.eventLoop;

    ---

*******************************************************************************/

module ocean.io.select.RequestQueue;

/*******************************************************************************

	General Private Imports

*******************************************************************************/

private import ocean.util.container.queue.FlexibleRingQueue;

private import ocean.util.container.queue.model.IByteQueue;

private import ocean.util.container.queue.model.IQueueInfo;

private import ocean.io.select.model.ISelectClient;

private import ocean.io.serialize.StructSerializer;

private import ocean.core.Array;

private import tango.core.Thread : Fiber;

debug private import ocean.util.log.Trace;

/*******************************************************************************

  Interface for a RequestHandler.

*******************************************************************************/

public interface IRequestHandler
{
    /***************************************************************************

	    Called by RequestQueue when this Handler is waiting for new
	    Requests. 
	    
	    The implementation is suppose to pop an item from the queue,
        process it and then do the same with the next until there are no more.
        Then it should registers back at the request queue (using handlerWaiting)
	
	***************************************************************************/

    public void notify ( );
    
    /***************************************************************************

        suspend this request handler
    
    ***************************************************************************/

    public void suspend ( );
    
    /***************************************************************************

        resume this request handler
    
    ***************************************************************************/

    public void resume ( );
}

/*******************************************************************************

	Abstract request handler.
    
    This is a template for a common case, if it doesn't suit your needs,
    implement the interface IRequestHandler (see above)
	 
	A concrete class connection inheriting from this class
    has to implement the request method which should .. start an request.
	
	request will be run inside IRequestHandler.fiber an is free
	to call fiber.cede/yield() as it pleases. Once the function 
	request returns, another request will be popped from the queue
	and the function will be called again until there are no more requests
	left.
	
	Template Params:
		T = the type of the request. Should be a struct.

*******************************************************************************/

abstract class RequestHandler ( T ) : ISelectClient, IRequestHandler
{
    /***************************************************************************

	    Whether the fiber is enabled or not
	
	***************************************************************************/

	private bool enabled = true;
	
    /***************************************************************************

	    Fiber instance.
	
	***************************************************************************/

	protected Fiber fiber;
	
    /***************************************************************************

    	Buffer for the struct deserialisation
	
	***************************************************************************/
		
	protected ubyte[] buffer;
	
    /***************************************************************************

	    Reference to the request queue to pop more requests
	
	***************************************************************************/
	
	protected RequestQueue!(T) request_queue;

	/***************************************************************************

	    Constructor
	    
	    Params:
	    	buffer_size      = size of the struct deserialization buffer
	    	request_queue    = reference to the request queue 
	    	fiber_stack_size = stack size of the fiber
	
	***************************************************************************/
	
	public this ( size_t buffer_size, RequestQueue!(T) request_queue, 
                  ISelectable selectclient, size_t fiber_stack_size = 4096)
	{
        super(selectclient);
        
		this.fiber  = new Fiber (&this.internalHandler, fiber_stack_size);
		
		this.buffer = new ubyte[buffer_size];
		
		this.request_queue = request_queue;
	}
	
    /***************************************************************************

	    Called by RequestQueue when this Handler is waiting for new
	    Requests. 
	    
	    The handler then starts popping items (from the queue) 
	    as if there is no tomorrow.
	    
	    When there are no more items to pop, it registers back in the 
	    request queue and yields/cedes.
	
	***************************************************************************/

	public void notify()
	{
        if ( this.fiber.state == Fiber.State.HOLD )
        {
            fiber.call();
        }
	}
	
    /***************************************************************************

	    Shutdown the fiber as good as possible
	
	***************************************************************************/
	
	public ~this ( )
	{
		this.enabled = false;
	}
	
    /***************************************************************************

	    Shutdown the fiber properly
	
	***************************************************************************/

	public void dispose ( )
	{
		this.enabled = false;
        
        if ( this.fiber.state != Fiber.State.TERM )
        {
            this.fiber.call();
        }
	}
	
    /***************************************************************************

	    Fiber function
	
	***************************************************************************/
    
	private void internalHandler ( )
	in
	{
		assert (this.fiber.state == Fiber.State.EXEC);
	}
	body
	{
		while (enabled)
		{
			T* request = this.request_queue.pop(this.buffer);

			if (request !is null)
			{
				this.request(*request);
			}
			else if ( this.request_queue.ready(this) )
            {
		        this.fiber.cede();
            }
		}
	}
    
    /***************************************************************************

        suspend this request handler
    
    ***************************************************************************/

    public void suspend ( )
    {
        this.enabled = false;
    }
    
    /***************************************************************************

        resume this request handler
    
    ***************************************************************************/

    public void resume ( )
    {
        this.enabled = true;
        
        if (fiber.state == Fiber.State.TERM)
        {
            this.fiber.reset();
        }
    }
    
    /***************************************************************************

	    Inheriting classes should implement this function so it sends the 
	    actual request.
	    
	    The function will only be called within the context of 
	    IRequestHandler.fiber. If it chooses to yield/cede it should
	    use the handler() function to continue operations based on 
	    new data.
	    
	    Params:
	    	request_instance = data of the request
	
	***************************************************************************/

	protected void request ( ref T request_instance );
}

/*******************************************************************************

	Request Queue implementation and logic. 
	
	A concrete client will probably prefer to use the templated version

*******************************************************************************/

class RequestByteQueue : IQueueInfo
{     
    /***************************************************************************
    
        Queue being used
    
    ***************************************************************************/
   
    private IByteQueue queue;
    
    /***************************************************************************
    
        Whether the queue is enabled or not
    
    ***************************************************************************/

    private bool enabled = true;
    
    /***************************************************************************
	
	    Array of handler references
	
	***************************************************************************/

    private IRequestHandler[] handlers;
    
    /***************************************************************************

	    Currently available handlers
	
	***************************************************************************/

    private size_t waiting_handlers;

    /***************************************************************************

	    Constructor
	    
	    Params:
	    	handlers  = amount of handlers/connections
            max_bytes = size of the queue in bytes
	
	***************************************************************************/
    
    public this ( size_t handlers, size_t max_bytes, IByteQueue queue = null )
    {
        if ( queue is null )
        {
            this.queue = new FlexibleByteRingQueue(max_bytes);
        }
        else
        {
            this.queue = queue;
        }
        
    	this.handlers = new IRequestHandler[handlers];
    	
    	this.waiting_handlers = 0;
    }
            

    /***************************************************************************

        Finds out whether the provided number of bytes will fit in the queue.
        Also considers the need of wrapping.

        Note that this method internally adds on the extra bytes required for
        the item header, so it is *not* necessary for the end-user to first
        calculate the item's push size.

        Params:
            bytes = size of item to check 

        Returns:
            true if the bytes fits, else false

    ***************************************************************************/

    public bool willFit ( size_t bytes )
    {
        return this.queue.willFit(bytes);
    }
        
        
    
    /***************************************************************************
    
        Returns:
            total number of bytes used by queue (used space + free space)
    
    ***************************************************************************/
    
    public ulong totalSpace ( )
    {
        return this.queue.totalSpace();
    }
    
    
    /***************************************************************************
    
        Returns:
            number of bytes stored in queue
    
    ***************************************************************************/
    
    public ulong usedSpace ( )
    {
        return this.queue.usedSpace();
    }    
    
    
    /***************************************************************************
    
        Returns:
            number of bytes free in queue
    
    ***************************************************************************/
    
    public ulong freeSpace ( )
    {
        return this.queue.freeSpace();
    }
    
       
    /***************************************************************************
    
        Returns:
            the number of items in the queue
    
    ***************************************************************************/
    
    public uint length ( )
    {
        return this.queue.length();
    }
        
    
    /***************************************************************************
    
        Tells whether the queue is empty.
    
        Returns:
            true if the queue is empty
    
    ***************************************************************************/
    
    public bool isEmpty ( )
    {
        return this.queue.isEmpty();
    }
    
    
    /***************************************************************************
	
	    register an handler as available
        
        Params:
            handler = handler that is now available
            
        Returns:
            false if the handler was called right away without 
            even registering
            true if the handler was just added to the queue
	
	***************************************************************************/
	    
    public bool ready ( IRequestHandler handler )
    in
    {
        debug scope (failure) Trace.formatln("waiting: {} len: {}",
                waiting_handlers, handlers.length);

    	assert (waiting_handlers <= handlers.length, "Maximum handlers reached");
        
        debug foreach ( rhandler; this.handlers[0 .. waiting_handlers] ) 
        {
            assert (rhandler !is handler, "RequestQueue.handlerWaiting: "
                                          "Handler already registered");
        }
    }
    body
    {
        if (!this.isEmpty() && this.enabled)
        {
            handler.notify();
            return false;
        }
        else
        {
            this.handlers[waiting_handlers++] = handler;
            return true;
        }  
    }
        
    /***************************************************************************
    
        Returns how many handlers are waiting for data
    
    ***************************************************************************/
        
    final public size_t waitingHandlers ( )
    {
        return this.waiting_handlers;
    }
           
    /***************************************************************************
    
        Returns how many handlers exist
    
    ***************************************************************************/
        
    final public size_t existingHandlers ( )
    {
        return this.handlers.length;
    }
    
    /***************************************************************************
		
	    Push an item into the queue and notify the next waiting handler about
	    it.
	    
	    Params:
	    	data = array of data that the item consists of
	    
	    Returns:
	    	true if push was successful
	    	false if not
	
	***************************************************************************/
	  
    public bool push ( ubyte[] data )
    {
    	if ( !this.queue.push(data) ) return false;    	
        
    	this.notifyHandler();
    	
    	return true;
    }
            
    /***************************************************************************
        
        Push an item into the queue and notify the next waiting handler about
        it.
        
        Params:
            size   = size of the item to push
            filler = delegate that will be called with that item to fill in the
                     actual data
        
        Returns:
            true if push was successful
            false if not
    
    ***************************************************************************/
      
    public bool push ( size_t size, void delegate ( ubyte[] ) filler )
    {
        auto target = this.queue.push(size);
        
        if (target is null) return false;
        
        filler(target);
        
        this.notifyHandler();
        
        return true;
    }   
    
    /***************************************************************************

        suspend consuming of the queue
    
    ***************************************************************************/

    public void suspend ( )
    {
        if (this.enabled == false)
        {
            return;
        }
        
        this.enabled = false;
        
        foreach (handler; this.handlers[0 .. waiting_handlers])
        {            
            handler.suspend();
        }
    }
    
    /***************************************************************************

        resume consuming of the queue
    
    ***************************************************************************/

    public void resume ( )
    {
        if (this.enabled == true)
        {
            return;
        }
        
        this.enabled = true;
                
        foreach (handler; this.handlers[0 .. waiting_handlers])
        {   
            handler.resume();
        }
        
        for ( size_t i = waiting_handlers; i > 0; --i )
        {
            this.notifyHandler();
        }
    }
    
    /***************************************************************************

        pops an element if the queue is enabled
    
    ***************************************************************************/

    public ubyte[] pop ( )
    {
        if ( !this.enabled )
        {
            return null;
        }
        
        return this.queue.pop();
    }
        
    /***************************************************************************

        Notifies the next waiting handler, if queue is enabled
    
    ***************************************************************************/

    private void notifyHandler ( )
    {
        if ( this.waiting_handlers > 0 && this.enabled )
        {
            handlers[waiting_handlers-- - 1].notify();          
        }
    }
}


/*******************************************************************************

	Templated Request Queue implementation
	
	A concrete client should have an instance of this class and use it
	to manage the connections and requests

*******************************************************************************/

class RequestQueue ( T ) : RequestByteQueue
{
    /***************************************************************************

	    Constructor
	    
	    Params:
	    	handlers  = amount of handlers/connections
	        max_bytes = size of the queue in bytes
	
	***************************************************************************/
    
    public this ( size_t handlers, size_t max_bytes, IByteQueue queue = null )
	{
		super(handlers, max_bytes, queue);
	}
	
    /***************************************************************************

	    Push a new request on the queue

	    Params:
	    	request = The request to push

        Returns:
            true if push was successful
            false if not

	***************************************************************************/

    bool push ( ref T request )
    {
    	auto length = StructSerializer!().length(&request);

        void filler ( ubyte[] target )
        {
            StructSerializer!().dump(&request, target);
        }
        
    	return super.push(length, &filler);
    }
    
    /***************************************************************************
	
	    Pops an Request instance from the queue
	    
	    Params:
	    	buffer = deserialisation buffer to use
	    	
	   	Returns:
	   		pointer to the deserialized struct, completely allocated in the
	   		given buffer
	
	***************************************************************************/
	    
    T* pop ( ref ubyte[] buffer )
    {
        if ( !this.enabled ) return null;
        
        T* instance;

    	auto data = super.pop();

        if (data is null)
        {
            return null;
        }

        buffer.copy(data);

    	StructSerializer!().loadSlice (instance, buffer);
    	
    	return instance; 
    }
}
