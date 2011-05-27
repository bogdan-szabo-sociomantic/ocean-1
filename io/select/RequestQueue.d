/*******************************************************************************

    Abstract classes for RequestQueues

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Mathias Baumann

*******************************************************************************/

module ocean.io.select.RequestQueue;

/*******************************************************************************

	General Private Imports

*******************************************************************************/

private import ocean.io.device.queue.RingQueue;

private import ocean.io.select.model.ISelectClient;

private import ocean.io.serialize.StructSerializer;

private import ocean.core.Array;

private import tango.core.Thread : Fiber;

interface IRequestHandler
{
    public void notify ( );
}

/*******************************************************************************

	Abstract request handler.
	 
	Any concrete class connection should inherit from this class.
	It has to implement startRequest which should .. start an request.
	
	startRequest will be run inside IRequestHandler.fiber an is free
	to call fiber.cede/yield() as it pleases. Once the function 
	startRequest returns, another request will be popped from the queue
	and the function will be called again until there are no more requests
	left.
	
	Template Params:
		T = the type of the request. Should be a struct.

*******************************************************************************/

abstract class RequestHandler ( T ) : ISelectClient, IRequestHandler
{
    /***************************************************************************

	    Should we cause the fiber to exit or not
	
	***************************************************************************/

	private bool exit = false;
	
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
	
	protected RequestQueue request_queue;

	/***************************************************************************

	    Constructor
	    
	    Params:
	    	buffer_size      = size of the struct deserialization buffer
	    	request_queue    = reference to the request queue 
	    	fiber_stack_size = stack size of the fiber
	
	***************************************************************************/
	
	public this ( size_t buffer_size, RequestQueue request_queue, 
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
		fiber.call();
	}
	
    /***************************************************************************

	    Shutdown the fiber as good as possible
	
	***************************************************************************/
	
	public ~this ( )
	{
		this.exit = true;
	}
	
    /***************************************************************************

	    Shutdown the fiber properly
	
	***************************************************************************/

	public void dispose ( )
	{
		this.exit = true;
		this.fiber.call();
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
		while (!exit)
		{
			T* request = this.request_queue.pop!(T)(this.buffer);
			
			if (request !is null)
			{
				this.startRequest(*request);
			}
			else
			{
				this.request_queue.handlerWaiting(this);
				fiber.cede();
			}
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

	protected void startRequest ( ref T request_instance );
}

/*******************************************************************************

	Request Queue implementation and logic. 
	
	A concrete client will probably prefer to use the templated version

*******************************************************************************/

abstract class RequestByteQueue : RingQueue
{
    /***************************************************************************
	
	    Whether the last push failed and the next pop should notify
	    the application that it might try again now
	
	***************************************************************************/

	private bool is_full = false;
	
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
	    	handlers        = amount of handlers/connections
	
	***************************************************************************/
    
    public this ( size_t handlers )
    {
    	this.handlers = new IRequestHandler[handlers];
    	
    	this.waiting_handlers = 0;
    }
    
    /***************************************************************************
	
	    Currently available handlers
	
	***************************************************************************/
	    
    public void handlerWaiting ( IRequestHandler handler )
    in
    {
    	assert (handler + 1 < waiting_handlers.length);
    }
    body
    {
        this.handlers[waiting_handlers++] = handler;
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
    	if (!super.push(data))
    	{
    		return false;
    	}
    	
    	if (this.waiting_handlers > 0)
    	{
    		handlers[waiting_handlers-- - 1].notify();    		
    	}
    	
    	return true;
    }    
}


/*******************************************************************************

	Templated Request Queue implementation
	
	A concrete client should have an instance of this class and use it
	to manage the connections and requests

*******************************************************************************/

class RequestQueue : RequestByteQueue
{
    /***************************************************************************

	    Serialization buffer
	
	***************************************************************************/
		
	private ubyte[] buffer;
	
    /***************************************************************************

	    Constructor
	    
	    Params:
	    	handlers        = amount of handlers/connections
	
	***************************************************************************/

	public this ( size_t handlers )
	{
		super(handlers);
		
		this.buffer = new ubyte[1024]; 
	}
	
    /***************************************************************************

	    Push a new request on the queue
	    
	    Params:
	    	request = The request to push
	
		TODO: find a way that doesn't require a buffer but instead uses
		      the queue's buffer directly. Maybe a new method in the 
		      RingQueue:  ubyte[] push ( size_t size ) and then 
		      write to the returning slice?
	
	***************************************************************************/

    bool push ( T ) ( ref T request )
    {
    	this.buffer.length = StructSerializer.length(&request);
    	
    	auto written = StructSerializer.dump(&request, this.buffer);
    	
    	return super.push(this.buffer[0 .. written]);
    }
    
    /***************************************************************************
	
	    Pops an Request instance from the queue
	    
	    Params:
	    	buffer = deserialisation buffer to use
	    	
	   	Returns:
	   		pointer to the deserialized struct, completely allocated in the
	   		given buffer
	
	***************************************************************************/
	    
    T* pop ( T ) ( ref ubyte[] buffer )
    {   
    	T* instance;
    	
    	buffer.copy(cast(ubyte[])super.pop());
    	
    	StructSerializer.loadSlice (instance, buffer);
    	
    	return instance; 
    }
}
