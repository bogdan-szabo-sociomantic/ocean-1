/*******************************************************************************

    Queue that provides a notification mechanism for when new items were added

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Mathias Baumann

    Generic interfaces and logic for RequestQueues and related classes.

    Genericly speaking, a request handler delegate is being registered at
    the queue (ready()). The notifying queue will then call notify() to inform
    it about a new item added, notify() is expected to call pop() to receive
    that item. It should keep calling pop() until no items are left
    and then re-register at the queue and wait for another call to notify().
    In other words:

    1) NotifyingQueue.ready(&notify)
    2) NotifyingQueue.ready calls notify()
    3) notify() calls NotifyingQueue.pop();
      a) pop() returned a request: notify() processes data, back to 3)
      b) pop() returned null: continue to 4)
    4) notify() calls NotifyingQueue.ready(&notify)

    A more simple solution like this was considered:

    1) NotifyingQueue.ready(&notify)
    2) NotifyingQueue calls notify(Request)
    3) notify() processes, back to 1)

    But was decided against because it would cause a stack overflow for fibers,
    as a RequestHandler needs to call RequestQueue.ready() and if fibers are
    involved that call will be issued from within the fiber.
    If ready() calls notify again another processing of a request in the fiber
    will happen, causing another call to ready() leading to a recursion.

    Now we require that the fiber calls pop in a loop.

    Usage example for a hypothetical client who writes numbers to a socket
    ---
        module NotifyingQueueExample;

        import ocean.util.log.Trace;
        import ocean.util.container.queue.NotifyingQueue;

        void main ( )
        {
            auto notifying_queue = new NotifyingByteQueue(1024 * 40);

            void notee ( )
            {
                while (true)
                {
                    auto popped = cast(char[]) notifying_queue.pop()

                    if ( popped !is null )
                    {
                        Trace.formatln("Popped from the queue: {}", popped);
                    }
                    else break;
                }

                notifying_queue.ready(&notee);
            }

            notifying_queue.ready(&notee);

            numbers.sendNumber(23);
            numbers.sendNumber(85);
            numbers.sendNumber(42);
        }
    ---

*******************************************************************************/

module ocean.util.container.queue.NotifyingQueue;

/*******************************************************************************

    General Private Imports

*******************************************************************************/

private import ocean.util.container.queue.FlexibleRingQueue;

private import ocean.util.container.queue.model.IByteQueue;

private import ocean.util.container.queue.model.IQueueInfo;

private import ocean.io.serialize.StructSerializer;

private import ocean.core.Array;

private import ocean.util.container.AppendBuffer;

debug private import ocean.util.log.Trace;


/*******************************************************************************

    Request Queue implementation and logic.

    A concrete client will probably prefer to use the templated version

*******************************************************************************/

class NotifyingByteQueue : IQueueInfo
{
    /***************************************************************************

        Type of the delegate used for notifications

    ***************************************************************************/

    public alias void delegate ( ) NotificationDg;

    /***************************************************************************

        Queue being used

    ***************************************************************************/

    const private IByteQueue queue;

    /***************************************************************************

        Whether the queue is enabled or not. Set/unset by the suspend() /
        resume() methods. When enabled is false, the queue behaves as if it is
        empty (no waiting notification delegates will be called).

    ***************************************************************************/

    private bool enabled = true;

    /***************************************************************************

        Array of delegates waiting for notification of data in queue

    ***************************************************************************/

    const private AppendBuffer!(NotificationDg) notifiers;

    /***************************************************************************

        Constructor

        Params:
            max_bytes = size of the queue in bytes

    ***************************************************************************/

    public this ( size_t max_bytes )
    {
        this(new FlexibleByteRingQueue(max_bytes));
    }


    /***************************************************************************

        Constructor

        Params:
            queue = instance of the queue implementation that will be used

    ***************************************************************************/

    public this ( IByteQueue queue )
    {
        this.queue = queue;

        this.notifiers = new AppendBuffer!(NotificationDg);
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

    public ulong total_space ( )
    {
        return this.queue.total_space();
    }


    /***************************************************************************

        Returns:
            number of bytes stored in queue

    ***************************************************************************/

    public ulong used_space ( )
    {
        return this.queue.used_space();
    }


    /***************************************************************************

        Returns:
            number of bytes free in queue

    ***************************************************************************/

    public ulong free_space ( )
    {
        return this.queue.free_space();
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

    public bool is_empty ( )
    {
        return this.queue.is_empty();
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

    public bool ready ( NotificationDg notifier )
    in
    {
        debug foreach ( waiting_notifier; this.notifiers[] )
        {
            assert (waiting_notifier !is notifier, "RequestQueue.ready: "
                                          "notifier already registered");
        }
    }
    body
    {
        if (!this.is_empty() && this.enabled)
        {
            notifier();
            return false;
        }
        else
        {
            this.notifiers ~= notifier;
            return true;
        }
    }


    /***************************************************************************

        Returns:
            how many notification delegates are waiting for data

    ***************************************************************************/

    final public size_t waiting ( )
    {
        return this.notifiers.length;
    }


    /***************************************************************************

        Push an item into the queue and notify the next waiting notification
        delegate about it.

        Params:
          data = array of data that the item consists of

        Returns:
          true if push was successful
          false if not

   **************************************************************************/

    public bool push ( ubyte[] data )
    {
        if ( !this.queue.push(data) ) return false;

        this.notify();

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

        this.notify();

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
    }


    /***************************************************************************

        Returns true if the queue is suspended, else false

    ***************************************************************************/

    public bool suspended ( )
    {
        return this.enabled == false;
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

        foreach (notifier; this.notifiers[])
        {
            this.notify();
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

        Calls the next waiting notification delegate, if queue is enabled.

    ***************************************************************************/

    private void notify ( )
    {
        if ( this.notifiers.length > 0 && this.enabled )
        {
            auto dg = notifiers.cut();

            dg();
        }
    }
}


/*******************************************************************************

    Templated Notifying Queue implementation

    A concrete client should have an instance of this class and use it
    to manage the connections and requests

    Note: the stored type T is automatically de/serialized using the
    StructSerializer. This performs a deep serialization of sub-structs and
    array members. Union members are shallowly serialized. Delegate and class
    members cannot be serialized.

*******************************************************************************/

class NotifyingQueue ( T ) : NotifyingByteQueue
{
    /***************************************************************************

        Constructor

        Params:
            max_bytes = size of the queue in bytes

    ***************************************************************************/

    public this ( size_t max_bytes )
    {
        super(max_bytes);
    }


    /***************************************************************************

        Constructor

        Params:
            queue = instance of the queue implementation that will be used

    ***************************************************************************/

    public this ( IByteQueue queue )
    {
        super(queue);
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
        auto length = StructSerializer!(true).length(&request);

        void filler ( ubyte[] target )
        {
            StructSerializer!(true).dump(&request, target);
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

        StructSerializer!(true).loadSlice (instance, buffer);

        return instance;
    }
}