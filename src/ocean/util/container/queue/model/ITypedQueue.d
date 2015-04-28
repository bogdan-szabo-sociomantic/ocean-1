/******************************************************************************

    copyright:      Copyright (c) 2015 sociomantic labs. All rights reserved

    An interface for a FIFO queue with items of a specific type.

    This interface is deliberately designed to be as minimal as possible,
    only covering the core functionality shared by the wide variety of possible
    queue implementations. For example, even a basic pop function which returns
    an item is not generic -- certain implementations may need to relinquish the
    item after popping it, making a simple pop-then-return implementation
    impossible. For this reason, some additional helper functions are provided,
    which may be useful with some queue implementations.

*******************************************************************************/

module ocean.util.container.queue.model.ITypedQueue;


/******************************************************************************

    An interface for a FIFO queue with items of a specific type.

    Template params:
        T = Type of items to be stored in the queue

*******************************************************************************/

public interface ITypedQueue ( T )
{
    /**************************************************************************

        Returns:
            true if queue is empty, false otherwise

    ***************************************************************************/

    bool empty ( );
    

    /**************************************************************************

        Returns:
            number of items in the queue

    ***************************************************************************/

    size_t length ( );


    /**************************************************************************

        Removes all items from the queue

    ***************************************************************************/

    void clear ( );


    /**************************************************************************

        Pushes an item to the queue. The caller should set the returned item as 
        desired

        Returns:
            Pointer to the newly pushed item, null if the item could not be pushed 
            (see documentation of implementing class for possible failure reasons)

    ***************************************************************************/

    T* push ( );


    /**************************************************************************

        Discards the item at the top of the queue.

    ***************************************************************************/

    void discardTop ( );


    /**************************************************************************

        Returns:
            A pointer to the item at the top of the queue, null if the queue is 
            empty

    ***************************************************************************/

    T* top ( );
}


/******************************************************************************

    A helper function to push an item into ITypedQueue.

    Note: this function performs a shallow copy of t into the queue.
    If this is not desired, the caller class is to call `push()` method of
    `ITypedQueue` and apply desired logic on returned pointer.

    Template params:
        T = type of items stored in queue

    Params:
        q = A queue to push into
        t = An item to push into q

    Returns:
        true if t pushed into q, false otherwise

*******************************************************************************/

public bool push ( T ) ( ITypedQueue!(T) q, T t )
{
    auto p = q.push();
    if ( p is null ) return false;
    *p = t;
    return true;
}


/******************************************************************************

    A helper function to pop an item from ITypedQueue.

    Note: this function performs a shallow copy of the popped item into t.
    if this is not desired, the caller class is to call `top()` method of
    `ITypedQueue` and apply desired logic on returned pointer and then call
    `discardTop()`.
    
    Template params:
        T = type of items stored in queue

    Params:
        q = A queue to pop from
        t = if pop succeeds, will hold item popped from q, when function ends

    Returns:
        true if top item was popped and copied to t, false otherwise

*******************************************************************************/

public bool pop ( T ) ( ITypedQueue!(T) q, ref T t )
{
    auto p = q.top();
    if ( p is null )
    {
        return false;
    }
    t = *p;
    q.discardTop();
    return true;
}
