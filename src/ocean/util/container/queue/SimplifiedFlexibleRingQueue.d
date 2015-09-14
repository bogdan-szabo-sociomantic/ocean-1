/*******************************************************************************

    Fixed size memory-based ring queue for elements of flexible size.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        June 2011: Initial release

    authors:        Mathias Baumann, Gavin Norman, David Eckardt

*******************************************************************************/

deprecated module ocean.util.container.queue.SimplifiedFlexibleRingQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.queue.model.IRingQueue;

import ocean.util.container.queue.model.IByteQueue;

import ocean.util.container.mem.MemManager;

import tango.io.model.IConduit: InputStream, OutputStream;

import ocean.io.serialize.SimpleSerializer;

debug import ocean.io.Stdout;



/*******************************************************************************

    Simple ubyte-based ring queue.

    TODO: usage example

*******************************************************************************/

deprecated("Use ocean.util.container.queue.FlexibleRingQueue instead.")
class FlexibleByteRingQueue : IRingQueue!(IByteQueue)
{
    /***************************************************************************

        Location of the gap at the rear end of the data array where the unused
        space starts.

    ***************************************************************************/

    private size_t gap;


    /***************************************************************************

        Header for queue items

    ***************************************************************************/

    private struct Header
    {
        size_t length;
    }


    /***************************************************************************

        Invariant to assert queue position consistency: When the queue is empty,
        read_from and write_to must both be 0.

    ***************************************************************************/

    invariant ()
    {
        debug scope ( failure ) Stderr.formatln(typeof(this).stringof ~ ".invariant failed with items = {}, read_from = {}, write_to = {}",
                super.items, super.read_from, super.write_to);

        assert (super.items || !(super.read_from || super.write_to),
                typeof(this).stringof ~ ".invariant failed");
    }


    /***************************************************************************

        Constructor. The queue's memory buffer is allocated by the GC.

        Params:
            dimension = size of queue in bytes

    ***************************************************************************/

    public this ( size_t dimension )
    in
    {
        assert(dimension > 0, typeof(this).stringof ~ ": cannot construct a 0-length queue");
    }
    body
    {
        super(dimension);
    }


    /***************************************************************************

        Constructor. Allocates the queue's memory buffer with the provided
        memory manager.

        Params:
            mem_manager = memory manager to use to allocate queue's buffer
            dimension = size of queue in bytes

    ***************************************************************************/

    public this ( IMemManager mem_manager, size_t dimension )
    {
        super(mem_manager, dimension);
    }


    /***************************************************************************

        Pushes an item into the queue.

        Params:
            item = data item to push

        Returns:
            true if the item was pushed successfully, false if it didn't fit

    ***************************************************************************/

    public bool push ( ubyte[] item )
    {
        auto data = this.push(item.length);

        if ( data is null )
        {
            return false;
        }

        data[] = item[];

        return true;
    }


    /***************************************************************************

        Acquires space in the queue into which a new item can be written.

        Params:
            size = number of bytes to acquire for new item

        Returns:
            slice to data buffer which can be written to, may be null if item
            cannot fit

    ***************************************************************************/

    public ubyte[] push ( size_t size )
    {
        if ( size > 0 && this.willFit(size) )
        {
            Header h; h.length = size;
            ubyte[] header = (cast(ubyte*)&h)[0 .. Header.sizeof];

            if (this.needsWrapping(size))
            {
                this.gap = super.write_to;
                super.write_to = 0;
            }

            super.data[super.write_to .. super.write_to + header.length] = header[];

            auto pos = super.write_to + header.length;

            super.write_to += this.pushSize(size);
            super.items++;

            return super.data[pos .. pos + size];
        }

        return null;
    }


    /***************************************************************************

        Peeks at the item that would be popped next.

        Returns:
            item that would be popped from queue,
            may be null if queue is empty

    ***************************************************************************/

    public ubyte[] peek ( )
    {
        auto read_pos = super.read_from;

        if (read_pos >= this.gap)                                  // check whether there is an item at this offset
        {
            read_pos = 0;                                          // if no, set it to the beginning (wrapping around)
        }

        Header* header = cast(Header*) (this.data.ptr + read_pos);

        auto pos = read_pos + header.sizeof;

        return this.data[pos .. pos + header.length];
    }


    /***************************************************************************

        Pops an item from the queue.

        Returns:
            item popped from queue

    ***************************************************************************/

    public ubyte[] pop ( )
    {
        if ( this.items == 0 ) return null;

        if ( super.read_from >= this.gap )                                  // check whether there is an item at this offset
        {
            super.read_from = 0;                                          // if no, set it to the beginning (wrapping around)
            this.gap = super.data.length;
        }

        Header* header = cast(Header*) (this.data.ptr + this.read_from);

        auto pos = super.read_from + header.sizeof;

        super.items--;

        if ( super.items == 0 )
        {
            super.read_from = 0;
            super.write_to  = 0;
        }
        else
        {
            super.read_from += this.pushSize(header.length);

            if ( super.read_from >= super.data.length )
            {
                super.read_from = 0;
            }
        }

        return this.data[pos .. pos + header.length];
    }

    /***************************************************************************

        Returns:
            number of bytes stored in queue

    ***************************************************************************/

    public override ulong used_space ( )
    {
        if (super.items == 0)
        {
            return 0;
        }

        if (super.write_to > super.read_from)
        {
            return super.write_to - super.read_from;
        }

        return this.gap - super.read_from + super.write_to;
    }


    /***************************************************************************

        Removes all items from the queue.

    ***************************************************************************/

    public override void clear ( )
    {
        super.clear();
        super.items = 0;
        this.gap = 0;
    }


    /***************************************************************************

        Tells how much space an item would take up when written into the queue.
        (Including the size of the required item header.)

        Params:
            item = item to calculate push size of

        Returns:
            number of bytes the item would take up if pushed to the queue

    ***************************************************************************/

    static public size_t pushSize ( ubyte[] item )
    {
        return pushSize(item.length);
    }


    /***************************************************************************

        Tells how much space an item of the specified size would take up when
        written into the queue. (Including the size of the required item
        header.)

        Params:
            bytes = number of bytes to calculate push size of

        Returns:
            number of bytes the item would take up if pushed to the queue

    ***************************************************************************/

    static public size_t pushSize ( size_t bytes )
    {
        return Header.sizeof + bytes;
    }


    /***************************************************************************

        Finds out whether the provided item will fit in the queue. Also
        considers the need of wrapping.

        Params:
            item = item to check

        Returns:
            true if the item fits, else false

    ***************************************************************************/

    public bool willFit ( ubyte[] item )
    {
        return this.willFit(item.length);
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
        size_t push_size = this.pushSize(bytes);

        if (super.items)
        {
            if (this.needsWrapping(bytes))
            {
                // check also if read needs to wrap in that case will not fit
                if ( super.read_from >= this.gap )
                {
                    return false;
                }

                return push_size <= super.read_from;
            }
            else
            {
                long d = super.read_from - super.write_to;

                return push_size <= d || d < 0;
            }
        }
        else
        {
            assert(super.write_to == 0, typeof(this).stringof ~ ".willFit: queue should be in the zeroed state");
            return push_size <= super.data.length;                              // Queue is empty and item at most
        }                                                                       // as long as the whole queue
    }


    /***************************************************************************

        Writes the queue's state and contents to the given output stream.

        Params:
            stream = output to write to

        Returns:
            number of bytes written

    ***************************************************************************/

    public size_t serialize ( OutputStream stream )
    {
        size_t bytes;

        bytes += SimpleSerializer.write(stream, this.gap);
        bytes += SimpleSerializer.write(stream, super.write_to);
        bytes += SimpleSerializer.write(stream, super.read_from);
        bytes += SimpleSerializer.write(stream, super.items);
        bytes += SimpleSerializer.write(stream, super.data);

        return bytes;
    }


    /***************************************************************************

        Reads the queue's state and contents from the given input stream.

        Params:
            stream = input to read from

        Returns:
            number of bytes read

    ***************************************************************************/

    public size_t deserialize ( InputStream stream )
    {
        size_t bytes;

        bytes += SimpleSerializer.read(stream, this.gap);
        bytes += SimpleSerializer.read(stream, super.write_to);
        bytes += SimpleSerializer.read(stream, super.read_from);
        bytes += SimpleSerializer.read(stream, super.items);
        bytes += SimpleSerializer.read(stream, super.data);

        return bytes;
    }


    /***************************************************************************

        Tells whether data of the specified length would need to be wrapped if
        it were pushed to the queue.

        Params:
            bytes = length of data to test

        Returns:
            true if the data needs wrapping, else false

    ***************************************************************************/

    private bool needsWrapping ( size_t bytes )
    {
        return pushSize(bytes) + super.write_to > super.data.length;
    }
}

/*******************************************************************************

    UnitTest

*******************************************************************************/

deprecated unittest
{
    scope queue = new FlexibleByteRingQueue((9+FlexibleByteRingQueue.Header.sizeof)*10);
    assert(!queue.free_space == 0);
    assert(queue.is_empty);

    assert(queue.push(cast(ubyte[])"Element 1"));
    assert(queue.pop() == cast(ubyte[])"Element 1");
    assert(queue.items == 0);
    assert(!queue.free_space == 0);
    assert(queue.is_empty);
    assert(queue.used_space() == 0);

    assert(queue.push(cast(ubyte[])"Element 1"));
    assert(queue.push(cast(ubyte[])"Element 2"));
    assert(queue.push(cast(ubyte[])"Element 3"));
    assert(queue.push(cast(ubyte[])"Element 4"));
    assert(queue.push(cast(ubyte[])"Element 5"));
    assert(queue.push(cast(ubyte[])"Element 6"));
    assert(queue.push(cast(ubyte[])"Element 7"));
    assert(queue.push(cast(ubyte[])"Element 8"));
    assert(queue.push(cast(ubyte[])"Element 9"));
    assert(queue.push(cast(ubyte[])"Element10"));

    assert(queue.length == 10);
    assert(queue.free_space == 0);
    assert(!queue.is_empty);

    assert(!queue.push(cast(ubyte[])"more"));
    assert(queue.length == 10);

    scope middle = new FlexibleByteRingQueue((1+FlexibleByteRingQueue.Header.sizeof)*5);
    middle.push(cast(ubyte[])"1");
    middle.push(cast(ubyte[])"2");
    middle.push(cast(ubyte[])"3");
    middle.push(cast(ubyte[])"4");
    assert(middle.pop == cast(ubyte[])"1");
    assert(middle.read_from == 1 + FlexibleByteRingQueue.Header.sizeof);
    assert(middle.write_to == (1+FlexibleByteRingQueue.Header.sizeof)*4);
    assert(middle.free_space() == (1+FlexibleByteRingQueue.Header.sizeof)*2);
    assert(middle.push(cast(ubyte[])"5"));
    assert(middle.push(cast(ubyte[])"6"));
    assert(middle.free_space() == 0);
}

/*******************************************************************************

    Performance test

*******************************************************************************/

version ( UnitTest )
{
    // Uncomment the next line to see UnitTest output
    // version = UnitTestVerbose;

    import tango.math.random.Random;
    import tango.time.StopWatch;
    import tango.core.Memory;
    import tango.io.FilePath;
    version (UnitTestVerbose) import ocean.io.Stdout;
}

deprecated unittest
{
     scope random = new Random();

    /***********************************************************************

        Test for empty queue

    ***********************************************************************/

    {
       auto caught = false;
       try scope queue = new FlexibleByteRingQueue(0);
       catch ( Exception e ) caught = true;
       assert (caught == true);
    }

    /***********************************************************************

        Test wrapping

    ***********************************************************************/

    version (UnitTestVerbose) Stdout.formatln("\nRunning ocean.io.device.queue.FlexibleByteRingQueue wrapping stability test");
    {
        scope queue = new FlexibleByteRingQueue((1+FlexibleByteRingQueue.Header.sizeof)*3);

        assert(queue.read_from == 0);
        assert(queue.write_to == 0);
        // [___] r=0 w=0
        assert(queue.push(cast(ubyte[])"1"));

        assert(queue.read_from == 0);
        assert(queue.write_to == 1+FlexibleByteRingQueue.Header.sizeof);
        assert(queue.items == 1);
        assert((cast(FlexibleByteRingQueue.Header*) queue.data.ptr).length == 1);

        assert(queue.data[FlexibleByteRingQueue.Header.sizeof ..
                          1+FlexibleByteRingQueue.Header.sizeof] ==
                              cast(ubyte[]) "1");

        // [#__] r=0 w=5
        assert(queue.push(cast(ubyte[])"2"));
        assert(queue.write_to == (1+FlexibleByteRingQueue.Header.sizeof)*2);

        assert((cast(FlexibleByteRingQueue.Header*)
            (queue.data.ptr + 1 + FlexibleByteRingQueue.Header.sizeof)).length == 1);

        assert(queue.data[1+FlexibleByteRingQueue.Header.sizeof*2 ..
                          1+FlexibleByteRingQueue.Header.sizeof*2+1] ==
                              cast(ubyte[]) "2");
        //assert(queue.data[queue.write_to-1-FlexibleByteRingQueue.h .. ])



        // [##_] r=0 w=10
        assert(queue.push(cast(ubyte[])"3"));
        assert(queue.write_to == (1+FlexibleByteRingQueue.Header.sizeof)*3);

        // [###] r=0 w=15
        assert(!queue.push(cast(ubyte[])"4"));
        assert(queue.write_to == (1+FlexibleByteRingQueue.Header.sizeof)*3);
        assert(queue.read_from == 0);

        assert(queue.free_space == 0);
        assert(queue.pop() == cast(ubyte[])"1");

        assert(queue.write_to == (1+FlexibleByteRingQueue.Header.sizeof)*3);
        assert(queue.read_from == 1+FlexibleByteRingQueue.Header.sizeof);

        // [_##] r=5 w=15
        assert(queue.free_space() == 1+FlexibleByteRingQueue.Header.sizeof);

        assert(queue.write_to == (1+FlexibleByteRingQueue.Header.sizeof)*3);
        assert(queue.read_from == 1+FlexibleByteRingQueue.Header.sizeof);

        assert(queue.pop() == cast(ubyte[])"2");

        // [__#] r=10 w=15
        assert(queue.free_space() == (1+FlexibleByteRingQueue.Header.sizeof)*2);
        assert(queue.write_to == queue.data.length);
        assert(queue.push(cast(ubyte[])"1"));

        // [#_#] r=10 w=5
        assert(queue.free_space() == 1+FlexibleByteRingQueue.Header.sizeof);
        assert(queue.write_to == queue.pushSize("2".length));
        assert(queue.push(cast(ubyte[])"2"));
       // Stdout.formatln("gap is {}, free is {}, write is {}", queue.gap, queue.free_space(),queue.write_to);


        // [###] r=10 w=10
        assert(queue.free_space == 0);
        assert(queue.pop() == cast(ubyte[])"3");

        // [##_] r=15/0 w=10
        assert(queue.free_space() == (1+FlexibleByteRingQueue.Header.sizeof)*1);
        assert(queue.pop() == cast(ubyte[])"1");

        // [_#_] r=5 w=10
        assert(queue.pop() == cast(ubyte[])"2");

        // [__] r=0 w=0
        assert(queue.is_empty);
        assert(queue.push(cast(ubyte[])"1"));

        // [#__] r=0 w=5
        assert(queue.push(cast(ubyte[])"2#"));

        // [#$_] r=0 w=11 ($ = 2 bytes)
        assert(queue.pop() == cast(ubyte[])"1");

        // [_$_] r=5 w=11
        assert(queue.push(cast(ubyte[])"1"));

        // [#$_] r=5 w=5
        assert(!queue.push(cast(ubyte[])"2"));
        assert(queue.pop() == cast(ubyte[])"2#");

        // [#__] r=11 w=5
        assert(queue.push(cast(ubyte[])"2")); // this needs to be wrapped now

        // [##_] r=11 w=10
        assert(queue.gap == queue.read_from);
    }

    // https://github.com/sociomantic/ocean/issues/5
    void bug5()
    {
        const Q_SIZE = 20;
        FlexibleByteRingQueue q = new FlexibleByteRingQueue(Q_SIZE);

        void push(size_t n)
        {
            for (size_t i = 0; i < n; i++)
            {
                ubyte[] push_slice = q.push(1);
                if (push_slice is null)
                    break;
                push_slice[] = cast(ubyte[]) [i];
            }
        }

        void pop(size_t n)
        {
            for (size_t i = 0; i < n; i++)
            {
                auto popped = q.pop();
                if (!popped.length)
                    break;
                assert (popped[0] != Q_SIZE+1);
                popped[0] = Q_SIZE+1;
            }
        }

        push(2);
        pop(1);
        push(2);
        pop(1);
        push(3);
        pop(4);
        pop(1);
    }
    bug5();

}

