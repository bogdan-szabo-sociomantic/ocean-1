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
}

