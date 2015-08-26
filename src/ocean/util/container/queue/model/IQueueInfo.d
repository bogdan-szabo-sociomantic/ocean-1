/*******************************************************************************

    Information only interface to a queue. Provides no methods to modify the
    contents of the queue.

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

    public size_t length ( );


    /***************************************************************************

        Returns:
            number of bytes stored in queue

    ***************************************************************************/

    public ulong used_space ( );


    /***************************************************************************

        Returns:
            number of bytes free in queue

    ***************************************************************************/

    public ulong free_space ( );


    /***************************************************************************

        Returns:
            total number of bytes used by queue (used space + free space)

    ***************************************************************************/

    public ulong total_space ( );


    /***************************************************************************

        Tells whether the queue is empty.

        Returns:
            true if the queue is empty

    ***************************************************************************/

    public bool is_empty ( );


    /***************************************************************************

        Finds out whether the provided number of bytes will fit in the queue.

        Params:
            bytes = size of item to check

        Returns:
            true if the bytes fits, else false

    ***************************************************************************/

    public bool willFit ( size_t bytes );
}

