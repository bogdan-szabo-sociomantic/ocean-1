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

/******************************************************************************/

abstract class IRingQueue ( IBaseQueue ) : IBaseQueue
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
    
        Constructor.
        
        Params:
            dimension = size of queue in bytes
    
    ***************************************************************************/
    
    protected this ( size_t dimension )
    in
    {
        assert(dimension > 0, typeof(this).stringof ~ ": cannot construct a 0-length queue");
    }
    body
    {
        this.data = new ubyte[dimension];
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
    
    public void dispose ( )
    {
        delete this.data;
    }
}
