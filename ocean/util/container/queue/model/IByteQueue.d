/*******************************************************************************

    Base class for a queue.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        June 2011: Initial release

    authors:        Mathias Baumann, Gavin Norman

*******************************************************************************/

module ocean.util.container.queue.model.IByteQueue;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.container.queue.model.IQueueInfo;

/******************************************************************************/

interface IByteQueue : IQueueInfo
{
    /***************************************************************************
    
        Removes all items from the queue.
    
    ***************************************************************************/
    
    public void clear ( ); 
     
    
    /***************************************************************************
    
        Reserves space for an item of <size> bytes on the queue but doesn't
        fill the content. The caller is expected to fill in the content using
        the returned slice. 
    
        Params:
            size = size of the space of the item that should be reserved
    
        Returns:
            slice to the reserved space if it was successfully reserved, 
            else null

    ***************************************************************************/
    
    public ubyte[] push ( size_t size );

    
    /***************************************************************************
    
        Pushes an item into the queue.
    
        Params:
            item = data item to push
    
        Returns:
            true if the item was pushed successfully, false if it didn't fit

    ***************************************************************************/
    
    public bool push ( ubyte[] item );
   
    
    /***************************************************************************

        Pops an item from the queue.
    
        Returns:
            item popped from queue, may be null if queue is empty

    ***************************************************************************/

    public ubyte[] pop ( );   
    
   
    /***************************************************************************

        NOT IMPLEMENTED

        Peek at the next item that would be popped from the queue.
    
        Returns:
            item that would be popped from queue, may be null if queue is empty

    ***************************************************************************/

    //public ubyte[] peek ( );        
}
