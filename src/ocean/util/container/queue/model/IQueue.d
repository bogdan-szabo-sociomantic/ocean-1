/*******************************************************************************

    Base class template for a queue storing items of a specific type.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        June 2011: Initial release

    authors:        Mathias Baumann, Gavin Norman

*******************************************************************************/

module ocean.util.container.queue.model.IQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.queue.model.IQueueInfo;



/*******************************************************************************

    Base class template for a queue storing items of a specific type.

*******************************************************************************/

public interface IQueue ( T ) : IQueueInfo
{
    /***************************************************************************

        Removes all items from the queue.

    ***************************************************************************/

    public void clear ( );


    /***************************************************************************

        Reserves space for an element of the size T.sizeof at the queue and
        returns a pointer to it.
        The value of the element must then be copied to the location pointed to
        before calling push() or pop() the next time.

        Returns:
            pointer to the element pushed into the queue or null if the queue is
            full.

    ***************************************************************************/

    public T* push ( );


    /***************************************************************************

        Pushes an element into the queue.

        Params:
            element = element to push (will be left unchanged)

        Returns:
            true on success or false if the queue is full.

    ***************************************************************************/

    public bool push ( T element );


    /***************************************************************************

        Pops an element from the queue and returns a pointer to that element.
        The value of the element must then be copied from the location pointed
        to before calling push() or pop() the next time.

        Returns:
            pointer to the element popped from the queue or null if the queue is
            empty.

    ***************************************************************************/

    public T* pop ( );


    /***************************************************************************

        NOT IMPLEMENTED

        Peek at the next item that would be popped from the queue.

        Returns:
            pointer to the element that would be popped from queue,
            may be null if queue is empty

    ***************************************************************************/

    //public T* peek ( );
}

