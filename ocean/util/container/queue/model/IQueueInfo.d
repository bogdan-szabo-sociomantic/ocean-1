/*******************************************************************************

    Information only interface to a queue.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        September 2011: Initial release

    authors:        Gavin Norman

*******************************************************************************/

module ocean.util.container.queue.model.IQueueInfo;



/*******************************************************************************

    Information interface to a queue.

*******************************************************************************/

public interface IQueueInfo
{
    /***************************************************************************
    
        Returns:
            the number of items in the queue
    
    ***************************************************************************/
    
    public uint length ( );
    
    
    /***************************************************************************
    
        Returns:
            number of bytes stored in queue
    
    ***************************************************************************/
    
    public ulong usedSpace ( );
    
    
    /***************************************************************************
    
        Returns:
            number of bytes free in queue
    
    ***************************************************************************/
    
    public ulong freeSpace ( );
    
    
    /***************************************************************************
    
        Returns:
            total number of bytes used by queue (used space + free space)
    
    ***************************************************************************/
    
    public ulong totalSpace ( );
    
    
    /***************************************************************************
    
        Tells whether the queue is empty.
    
        Returns:
            true if the queue is empty
    
    ***************************************************************************/
    
    public bool isEmpty ( );
    

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

    public bool willFit ( size_t bytes );
}