/*******************************************************************************

    Base class for a fixed size memory-based ring queue.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        June 2011: Initial release

    authors:        Mathias Baumann, Gavin Norman

*******************************************************************************/

module ocean.util.container.queue.model.IRingQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.container.queue.model.IQueueInfo;

private import ocean.util.container.mem.MemManager;



/*******************************************************************************

    Base class for a fixed size memory-based ring queue.

*******************************************************************************/

public abstract class IRingQueue ( IBaseQueue ) : IBaseQueue
{
    /***************************************************************************
    
        Data array -- the actual queue where the items are stored.
    
    ***************************************************************************/
    
    protected ubyte[] data;
    
    
    /***************************************************************************
    
        Read & write positions (indices into the data array).
    
    ***************************************************************************/
    
    protected size_t write_to = 0;
    
    protected size_t read_from = 0;
    
    
    /***************************************************************************

        Number of items in the queue.
    
    ***************************************************************************/
    
    protected uint items = 0;
    

    /***************************************************************************

        Memory manager used to allocated / deallocate the queue's buffer.

    ***************************************************************************/

    private IMemManager mem_manager;


    /***************************************************************************

        Constructor. The queue's memory buffer is allocated by the GC.

        Params:
            dimension = size of queue in bytes

    ***************************************************************************/

    protected this ( size_t dimension )
    {
        auto manager = new GCMemManager;
        this(manager, dimension);
    }


    /***************************************************************************

        Constructor. Allocates the queue's memory buffer with the provided
        memory manager.

        Params:
            mem_manager = memory manager to use to allocate queue's buffer
            dimension = size of queue in bytes

    ***************************************************************************/

    protected this ( IMemManager mem_manager, size_t dimension )
    in
    {
        assert(mem_manager !is null, typeof(this).stringof ~ ": memory manager is null");
        assert(dimension > 0, typeof(this).stringof ~ ": cannot construct a 0-length queue");
    }
    body
    {
        this.mem_manager = mem_manager;

        this.data = this.mem_manager.create(dimension);
    }


    /***************************************************************************

        Destructor. Destroys the memory buffer allocated for the queue.

    ***************************************************************************/

    override public void dispose ( )
    {
        this.mem_manager.destroy(this.data);
    }


    /***************************************************************************
    
        Returns:
            the number of items in the queue
    
    ***************************************************************************/
    
    uint length ( )
    {
        return this.items;
    }
    
    
    /***************************************************************************

        Tells whether the queue is empty.
    
        Returns:
            true if the queue is empty
    
    ***************************************************************************/
    
    public bool isEmpty ( )
    {
        return this.items == 0;
    }
    

    /***************************************************************************
    
        Returns:
            number of bytes free in queue
    
    ***************************************************************************/
    
    public ulong freeSpace ( )
    {
        return this.data.length - this.usedSpace; 
    }
    
    
    /***************************************************************************
    
        Returns:
            number of bytes stored in queue
    
    ***************************************************************************/
    
    abstract ulong usedSpace ( );
    

    /***************************************************************************
    
        Returns:
            total number of bytes used by queue (used space + free space)
    
    ***************************************************************************/
    
    public ulong totalSpace ( )
    {
        return this.data.length;
    }
    
    
    /***************************************************************************
    
        Removes all items from the queue.
    
    ***************************************************************************/
    
    final void clear ( )
    {
        this.write_to   = 0;
        this.read_from  = 0;
        this.items      = 0;
        this.clear_();
    }
    
    
    /***************************************************************************
    
        Invoked by clear(), may be overridden by a subclass
    
    ***************************************************************************/

    protected void clear_ ( ) { }
}

