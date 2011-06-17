/*******************************************************************************

    Fixed size memory-based ring queue.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        June 2011: Initial release

    authors:        Mathias Baumann, Gavin Norman

*******************************************************************************/

module ocean.io.device.queue.SimpleRingQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

debug private import ocean.util.log.Trace;



/*******************************************************************************

    Simple ubyte-based ring queue.

    TODO: usage example

*******************************************************************************/

class ByteRingQueue
{
    /***************************************************************************

        Data array -- the actual queue where the items are stored.

    ***************************************************************************/

    private ubyte[] data;


    /***************************************************************************

        Read & write opositions (indices into the data array.

    ***************************************************************************/

    private size_t write_to;


    private size_t read_from;


    /***************************************************************************

        Number of items in the queue.

    ***************************************************************************/

    private size_t items;


    /***************************************************************************

        Location of the gap at the rear end of the data array where the unused
        space starts.

    ***************************************************************************/        

    private size_t gap;


    /***************************************************************************

        The current seek position.

        TODO: the class could no doubt be rephrased to not need a seek position,
        this is purely a legacy from the old version of the RingQueue.

    ***************************************************************************/

    private size_t position;


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

    invariant
    {
        debug scope ( failure ) Trace.formatln(typeof(this).stringof ~ ".invariant failed with items = {}, read_from = {}, write_to = {}",
                this.items, this.read_from, this.write_to);

        assert (this.items || !(this.read_from || this.write_to),
                typeof(this).stringof ~ ".invariant failed");
    }


    /***************************************************************************

        Constructor.
        
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
        this.data.length = dimension;
    }


    /***************************************************************************
    
        Pushes an item into the queue.
    
        Params:
            item = data item to push
    
        Returns:
            true if the item was pushed successfully, false if it didn't fit

    ***************************************************************************/
    
    public bool push ( ubyte[] item )
    in
    {
        assert(item.length != 0, "PersistQueue.push - attempted to push zero length content");
    }
    body
    {
        if ( item.length > 0 )
        {
            auto will_fit = this.willFit(item.length);
            if ( will_fit )
            {
                this.push_(item);
            }
    
            return will_fit;
        }
        else
        {
            return false;
        }
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

        Returns:
            the number of items in the queue

    ***************************************************************************/
    
    public uint length ( )
    {
        return this.items;
    }


    /***************************************************************************

        Returns:
            number of bytes stored in queue

    ***************************************************************************/

    public ulong usedSpace ( )
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

        Returns:
            number of bytes free in queue

    ***************************************************************************/

    public ulong freeSpace ( )
    {
        return this.data.length - this.usedSpace; 
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

        Removes all items from the queue.

    ***************************************************************************/

    public void clear ( )
    {
        this.write_to = 0;
        this.read_from = 0;
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

        if (this.items)
        {
            if (this.needsWrapping(bytes))
            {
                return push_size <= this.read_from;
            }
            else
            {
                long d = this.read_from - this.write_to;

                return push_size <= d || d < 0; 
            }
        }
        else
        {
            assert(this.write_to == 0, typeof(this).stringof ~ ".willFit: queue should be in the zeroed state");
            return push_size <= this.data.length;                                // Queue is empty and item at most
        }                                                                // as long as the whole queue
    }


    /***************************************************************************

        Pushes an item into the queue.

        Params:
            item = data item to push

    ***************************************************************************/

    private void push_ ( ubyte[] item )
    in
    {
        assert(this.willFit(item.length), typeof(this).stringof ~ ".push_: item will not fit");
    }
    body
    {
        ubyte[] header = (cast(ubyte*)&Header(item.length))[0 .. Header.sizeof];

        if (this.needsWrapping(item.length))
        {
            this.gap = this.write_to;
            this.write_to = 0;            
        }

        this.seek(this.write_to);
        
        auto written = this.write(header);
        assert(written == header.length, typeof (this).stringof ~ ": write(header) length mismatch");
        
        this.seek(this.write_to + header.length);
        
        written = this.write(item);
        assert(written == item.length, typeof (this).stringof ~ ": write(item) length mismatch");

        this.write_to += this.pushSize(item.length);
        this.items++;
    }

    
    /***************************************************************************

        Pops an item from the queue.

        Returns:
            item popped from queue

    ***************************************************************************/

    private ubyte[] pop_ ( )
    in
    {
        assert(this.items > 0, typeof(this).stringof ~ ".pop_: no items in the queue");
    }
    body
    {
        if (this.read_from >= this.gap)                                  // check whether there is an item at this offset
        {
            this.read_from = 0;                                          // if no, set it to the beginning (wrapping around)
            this.gap = this.data.length;
        }

        this.seek(this.read_from);

        Header* header = cast(Header*)this.read(Header.sizeof).ptr;

        this.seek(this.read_from + header.sizeof);

        this.items--;

        if (!this.items)
        {
            this.read_from = 0;
            this.write_to  = 0;
        }
        else
        {
            this.read_from += pushSize(header.length);
            
            if (this.read_from >= this.data.length)
            {
                this.read_from = 0;
            }
        }

        return this.read(header.length);
    }


    /***************************************************************************
    
        Writes an item to the data array.

        Params:
            item = item to write

        Returns:
            amount of bytes written
            
    ***************************************************************************/

    private size_t write ( ubyte[] item )
    {
        if (item.length <= this.data.length - this.position)
        {
            this.data[this.position .. this.position + item.length] = item;

            return item.length;
        }

        this.data[this.position .. $] = item[0 .. this.data.length - this.position];

        return this.data.length - this.position;
    }


    /***************************************************************************
        
        Reads data from the data array.

        Params:
            bytes = the amount of bytes to read

        Returns:
            the requested data

    ***************************************************************************/

    private ubyte[] read ( size_t bytes )
    {
        if (bytes > this.data.length - this.position)
        {
            return this.data[this.position .. $];
        }

        return this.data[this.position..this.position + bytes];    
    }


    /***************************************************************************

        Sets the seek position in the data array.

        Params:
            offset = the requested read/write position

        Returns:
            the new read/write position

        TODO: could no doubt be rephrased to not need a seek method

    ***************************************************************************/

    private size_t seek ( size_t offset )
    {
        if (offset > this.data.length)
        {
            this.position = this.data.length;
        }
        else
        {
            this.position = offset;
        }
        
        return this.position; 
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
        return pushSize(bytes) + this.write_to > this.data.length;           
    }
}



/*******************************************************************************

    Typed ring queue class template -- implements a queue which pushes and pops
    values of a certain type.

    Template params:
        T = type of items to store in queue

    TODO: usage example

*******************************************************************************/

class RingQueue ( T ) : ByteRingQueue
{
    /***************************************************************************

        Constructor.
        
        Params:
            max_items = maximum number of items of type T that will fit in the
                queue

    ***************************************************************************/

    public this ( size_t max_items )
    {
        super(max_items * T.sizeof);
    }


    /***************************************************************************

        Pops an item from the queue.

        Params:
            item = output value to receive popped item

        Returns:
            true if item was popped, false if queue is empty

    ***************************************************************************/

    public bool popItem ( ref T item )
    {
        auto popped = super.pop();
        if ( popped is null )
        {
            return false;
        }
        else
        {
            item = *(cast(T*)popped.ptr); // TODO: could probably be reworked to not need this copy
            return true;
        }
    }


    /***************************************************************************

        Pushes an item to the queue.

        Params:
            item = value to push

        Returns:
            true if item was pushed, false if there was not enough space

    ***************************************************************************/

    public bool pushItem ( ref T item )
    {
        return super.push((cast(ubyte*)&item)[0 .. T.sizeof]);
    }


    /***************************************************************************

        Overridden base class methods as private to prevent use.

    ***************************************************************************/

    private ubyte[] pop ( )
    {
        return null;
    }

    private bool push ( ubyte[] )
    {
        return false;
    }
}



/*******************************************************************************

    UnitTest

*******************************************************************************/

debug ( OceanUnitTest )
{
    import tango.math.random.Random;
    import tango.time.StopWatch;
    import tango.core.Memory;
    import tango.io.FilePath; 
    import ocean.util.log.Trace; 

    unittest
    {
         scope random = new Random();

        /***********************************************************************

            Test for empty queue

        ***********************************************************************/

        {
            scope queue = new ByteRingQueue(0);
            assert(queue.isEmpty());
            assert(!queue.push(cast(ubyte[])"stuff"));
        }


        /***********************************************************************
            
            Test wrapping
        
        ***********************************************************************/        

        Trace.formatln("\nRunning ocean.io.device.queue.RingQueue wrapping stability test");
        {
            scope queue = new ByteRingQueue((1+ByteRingQueue.Header.sizeof)*3);
    
            // [___] r=0 w=0
            assert(queue.push(cast(ubyte[])"1"));
    
            // [#__] r=0 w=5
            assert(queue.push(cast(ubyte[])"2"));
            
            // [##_] r=0 w=10
            assert(queue.push(cast(ubyte[])"3"));
            
            // [###] r=0 w=15
            assert(!queue.push(cast(ubyte[])"4"));
            assert(queue.freeSpace == 0);
            assert(queue.pop() == cast(ubyte[])"1");
    
            // [_##] r=5 w=15
            assert(queue.freeSpace() == 1+ByteRingQueue.Header.sizeof);
            assert(queue.pop() == cast(ubyte[])"2");
            
            // [__#] r=10 w=15
            assert(queue.freeSpace() == (1+ByteRingQueue.Header.sizeof)*2);
            assert(queue.write_to == queue.data.length);
            assert(queue.push(cast(ubyte[])"1"));
            
            // [#_#] r=10 w=5
            assert(queue.freeSpace() == 1+ByteRingQueue.Header.sizeof);
            assert(queue.write_to == queue.pushSize("2".length));
            assert(queue.push(cast(ubyte[])"2"));
           // Trace.formatln("gap is {}, free is {}, write is {}", queue.gap, queue.freeSpace(),queue.write_to);
           
            
            // [###] r=10 w=10
            assert(queue.freeSpace == 0);
            assert(queue.pop() == cast(ubyte[])"3");
      
            // [##_] r=15/0 w=10
            assert(queue.freeSpace() == (1+ByteRingQueue.Header.sizeof)*1);
            assert(queue.pop() == cast(ubyte[])"1");         
    
            // [_#_] r=5 w=10
            assert(queue.pop() == cast(ubyte[])"2");
    
            // [__] r=0 w=0
            assert(queue.isEmpty);
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
        
        /***********************************************************************
        
            Various random tests
    
        ***********************************************************************/
                
        scope queue = new ByteRingQueue((9+ByteRingQueue.Header.sizeof)*10);
        assert(!queue.freeSpace == 0);
        assert(queue.isEmpty);
        
        assert(queue.push(cast(ubyte[])"Element 1"));
        assert(queue.pop() == cast(ubyte[])"Element 1");
        assert(queue.items == 0);
        assert(!queue.freeSpace == 0);
        assert(queue.isEmpty);
        assert(queue.usedSpace() == 0);
        
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
        assert(queue.freeSpace == 0);
        assert(!queue.isEmpty);
        
        assert(!queue.push(cast(ubyte[])"more"));
        assert(queue.length == 10);

        scope middle = new ByteRingQueue(5*5);        
        middle.push(cast(ubyte[])"1");        
        middle.push(cast(ubyte[])"2");
        middle.push(cast(ubyte[])"3");
        middle.push(cast(ubyte[])"4");
        assert(middle.pop == cast(ubyte[])"1");        
        assert(middle.read_from == 5);
        assert(middle.write_to == 5*4);
        assert(middle.freeSpace() == 5*2);
        assert(middle.push(cast(ubyte[])"5"));
        assert(middle.push(cast(ubyte[])"6"));
        assert(middle.freeSpace() == 0);
    }    
}
