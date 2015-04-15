/*******************************************************************************

    Fixed size memory-based ring queue for elements of flexible size.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        June 2011: Initial release

    authors:        Mathias Baumann, Gavin Norman, David Eckardt

*******************************************************************************/

module ocean.util.container.queue.FlexibleRingQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.queue.model.IRingQueue;

import ocean.util.container.queue.model.IByteQueue;

import ocean.util.container.mem.MemManager;

import tango.io.model.IConduit: InputStream, OutputStream;

import ocean.io.serialize.SimpleSerializer;

import ocean.text.util.ClassName;

debug import ocean.io.Stdout;



/*******************************************************************************

    Simple ubyte-based ring queue.

    TODO: usage example

*******************************************************************************/

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

    invariant ( )
    {
        debug scope ( failure ) Stderr.formatln
        (
            "{} invariant failed with items = {}, read_from = {}, " ~
            "write_to = {}, gap = {}, data.length = {}",
            classname(this), this.items, this.read_from, this.write_to,
            this.gap, this.data.length
        );

        if (this.items)
        {
            assert(this.gap       <= this.data.length, "gap out of range");
            assert(this.read_from <= this.data.length, "read_from out of range");
            assert(this.write_to  <= this.data.length, "write_to out of range");
            assert(this.write_to,                      "write_to 0 with non-empty queue");
            assert(this.read_from < this.gap,          "read_from within gap");
            assert((this.gap == this.write_to) ||
                   !(this.read_from < this.write_to),
                   "read_from < write_to but gap not write position");
        }
        else
        {
            assert(!this.gap, "gap expected to be 0 for empty queue");
            assert(!this.read_from, "read_from expected to be 0 for empty queue");
            assert(!this.write_to, "write_to expected to be 0 for empty queue");
        }
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

        item.length = 0 is allowed.

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

        Reserves space for an item of <size> bytes on the queue but doesn't
        fill the content. The caller is expected to fill in the content using
        the returned slice.

        size = 0 is allowed.

        Params:
            size = size of the space of the item that should be reserved

        Returns:
            slice to the reserved space if it was successfully reserved, else
            null. Returns non-null empty string if size = 0 and the item was
            successfully pushed.

        Out:
            The length of the returned array slice is size unless the slice is
            null.

    ***************************************************************************/

    public ubyte[] push ( size_t size )
    out (slice)
    {
        assert(slice is null || slice.length == size,
               classname(this) ~ "push: length of returned buffer not as requested");
    }
    body
    {
        return this.willFit(size) ? this.push_(size) : null;
    }


    /***************************************************************************

        Pops an item from the queue.

        Returns:
            item popped from queue, may be null if queue is empty

    ***************************************************************************/

    public ubyte[] pop ( )
    {
        return this.items ? this.pop_() : null;
    }


    /***************************************************************************

        Peeks at the item that would be popped next.

        Returns:
            item that would be popped from queue,
            may be null if queue is empty

    ***************************************************************************/

    public ubyte[] peek ( )
    {
        if (this.items)
        {
            auto h = this.read_from;
            auto d = h + Header.sizeof;
            auto header = cast(Header*) this.data[h .. d].ptr;
            return this.data[d .. d + header.length];
        }
        else
        {
            return null;
        }
    }


    /***************************************************************************

        Returns:
            number of bytes stored in queue

    ***************************************************************************/

    public override ulong used_space ( )
    {
        if (this.items == 0)
        {
            return 0;
        }

        if (this.write_to > this.read_from)
        {
            return this.write_to - this.read_from;
        }

        return this.gap - this.read_from + this.write_to;
    }


    /***************************************************************************

        Removes all items from the queue.

    ***************************************************************************/

    protected override void clear_ ( )
    out
    {
        assert(this); // invariant
    }
    body
    {
        this.items = 0;
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

    bool willFit ( ubyte[] item )
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

        if (this.read_from < this.write_to)
        {
            /*
             *  Free space at either
             *  - data[write_to .. $], the end, or
             *  - data[0 .. read_from], the beginning, wrapping around.
             */
            return ((this.data.length - this.write_to) >= push_size) // Fits at the end.
                   || (this.read_from >= push_size); // Fits at the start wrapping around.

        }
        else if (this.items)
        {
            // Free space at data[write_to .. read_from].
            return (this.read_from - this.write_to) >= push_size;
        }
        else
        {
            // Queue empty: data is the free space.
            return push_size <= this.data.length;
        }
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
        bytes += SimpleSerializer.write(stream, this.write_to);
        bytes += SimpleSerializer.write(stream, this.read_from);
        bytes += SimpleSerializer.write(stream, this.items);
        bytes += SimpleSerializer.write(stream, this.data);

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
        bytes += SimpleSerializer.read(stream, this.write_to);
        bytes += SimpleSerializer.read(stream, this.read_from);
        bytes += SimpleSerializer.read(stream, this.items);
        bytes += SimpleSerializer.read(stream, this.data);

        return bytes;
    }

    /***************************************************************************

        Pushes an item into the queue.

        Params:
            item = data item to push

    ***************************************************************************/

    private ubyte[] push_ ( size_t size )
    in
    {
        assert(this); // invariant
        assert(this.willFit(size), classname(this) ~ ".push_: item will not fit");
    }
    out (slice)
    {
        assert(slice !is null,
               classname(this) ~ "push_: returned a null slice");
        assert(slice.length == size,
               classname(this) ~ "push_: length of returned slice not as requested");
        assert(this); // invariant
    }
    body
    {
        auto push_size = this.pushSize(size);

        /*
         * read_from and write_to can have three different relationships:
         *
         * 1. write_to == read_from: The queue is empty, both are 0, the
         *    record goes to data[write_to .. $].
         *
         * 2. write_to < read_from: The record goes in
         *    data[write_to .. read_from].
         *
         * 3. read_from < write_to: The record goes either in
         *   a) data[write_to .. $] if there is enough space or
         *   b) data[0 .. read_from], wrapping around by setting
         *      write_to = 0.
         *
         * The destination slice of data in case 3a is equivalent to case 1
         * and in case 3b to case 2.
         */

        if (this.read_from < this.write_to)
        {
            assert(this.gap == this.write_to);

            // Case 3: Check if the record fits in data[write_to .. $] ...
            if (this.data.length - this.write_to < push_size)
            {
                /*
                 * ... no, we have to wrap around. The precondition claims
                 * the record does fit so there must be enough space in
                 * data[0 .. read_from].
                 */
                assert(push_size <= this.read_from);
                this.write_to = 0;
            }
        }

        auto start = this.write_to;
        this.write_to += push_size;

        if (this.write_to > this.read_from) // Case 1 or 3a.
        {
            this.gap = this.write_to;
        }

        this.items++;

        void[] dst = this.data[start .. this.write_to];
        *cast(Header*)dst[0 .. Header.sizeof].ptr = Header(size);
        return cast(ubyte[])dst[Header.sizeof .. $];
    }


    /***************************************************************************

        Pops an item from the queue.

        Returns:
            item popped from queue

    ***************************************************************************/

    private ubyte[] pop_ ( )
    in
    {
        assert(this); // invariant
        assert(this.items, classname(this) ~ ".pop_: no items in the queue");
    }
    out (buffer)
    {
        assert(buffer, classname(this) ~ ".pop_: returned a null buffer");
        assert(this); // invariant
    }
    body
    {

        auto position = this.read_from;
        this.read_from += Header.sizeof;

        // TODO: Error if this.data.length < this.read_from.

        auto header = cast(Header*)this.data[position .. this.read_from].ptr;

        // TODO: Error if this.data.length - this.read_from < header.length

        position = this.read_from;
        this.read_from += header.length;
        assert(this.read_from <= this.gap); // The invariant ensures that
                                            // this.gap is not 0.

        this.items--; // The precondition prevents decrementing 0.

        scope (exit)
        {
            if (this.items)
            {
                if (this.read_from == this.gap)
                {
                    /*
                     *  End of data, wrap around:
                     *  1. Set the read position to the start of this.data.
                     */
                    this.read_from = 0;
                    /*
                     *  2. The write position is now the end of the data.
                     *     If the queue is now empty, i.e. this.items == 0,
                     *     write_to must be 0.
                     */

                    assert(this.items || !this.write_to);
                    this.gap = this.write_to;
                }
            }
            else // Popped the last record.
            {
                assert(this.read_from == this.write_to);
                this.read_from = 0;
                this.write_to  = 0;
                this.gap       = 0;
            }

        }

        return this.data[position .. this.read_from];
    }
}

/*******************************************************************************

    UnitTest

*******************************************************************************/

unittest
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
}

unittest
{
     scope random = new Random();

    /***********************************************************************

        Test wrapping

    ***********************************************************************/

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

        // [##_] r=0 w=10
        assert(queue.push(cast(ubyte[])"3"));

        // [###] r=0 w=15
        assert(!queue.push(cast(ubyte[])"4"));
        assert(queue.free_space == 0);
        assert(queue.pop() == cast(ubyte[])"1");

        // [_##] r=5 w=15
        assert(queue.free_space() == 1+FlexibleByteRingQueue.Header.sizeof);
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
    }
}

