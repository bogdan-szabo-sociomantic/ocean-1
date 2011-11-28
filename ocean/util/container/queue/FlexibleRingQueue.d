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

private import ocean.util.container.queue.model.IRingQueue;

private import tango.io.model.IConduit: InputStream, OutputStream;

private import ocean.io.serialize.SimpleSerializer;

debug private import ocean.util.log.Trace;



/*******************************************************************************

    Simple ubyte-based ring queue.

    TODO: usage example

*******************************************************************************/

class FlexibleByteRingQueue : IRingQueue
{
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
                super.items, super.read_from, super.write_to);

        assert (super.items || !(super.read_from || super.write_to),
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
        super(dimension);
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
    
        Reserves space for an item of <size> bytes on the queue but doesn't
        fill the content. The caller is expected to fill in the content using
        the returned slice. 
    
        Params:
            size = size of the space of the item that should be reserved
    
        Returns:
            slice to the reserved space if it was successfully reserved, 
            else null

    ***************************************************************************/
    
    public ubyte[] push ( size_t size )
    in
    {
        assert(size != 0, typeof(this).stringof ~ ".push - attempted to push zero length content");
    }
    body
    {
        if ( size > 0 && this.willFit(size) )
        {
            return this.push_(size);
        }
        
        return null;
    }
    
    /***************************************************************************

        Pops an item from the queue.
    
        Returns:
            item popped from queue, may be null if queue is empty

    ***************************************************************************/

    public ubyte[] pop ( )
    {
        return super.items ? this.pop_() : null;
    }


    /***************************************************************************

        Returns:
            number of bytes stored in queue

    ***************************************************************************/

    public ulong usedSpace ( )
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

    protected override void clear_ ( )
    {
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

        if (super.items)
        {
            if (this.needsWrapping(bytes))
            {
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
            return push_size <= super.data.length;                               // Queue is empty and item at most
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

        Pushes an item into the queue.

        Params:
            item = data item to push

    ***************************************************************************/

    private ubyte[] push_ ( size_t size )
    in
    {
        assert(this.willFit(size), typeof(this).stringof ~ ".push_: item will not fit");
    }
    body
    {
        ubyte[] header = (cast(ubyte*)&Header(size))[0 .. Header.sizeof];

        if (this.needsWrapping(size))
        {
            this.gap = super.write_to;
            super.write_to = 0;            
        }

		super.data[super.write_to .. super.write_to + header.length] = header[];
        this.seek(super.write_to + header.length);
      
        super.write_to += this.pushSize(size);
        super.items++;
                
        return super.data[this.position .. this.position + size];
    }
    
    
    /***************************************************************************

        Pops an item from the queue.

        Returns:
            item popped from queue

    ***************************************************************************/

    private ubyte[] pop_ ( )
    in
    {
        assert(super.items > 0, typeof(this).stringof ~ ".pop_: no items in the queue");
    }
    body
    {
        if (super.read_from >= this.gap)                                  // check whether there is an item at this offset
        {
            super.read_from = 0;                                          // if no, set it to the beginning (wrapping around)
            this.gap = super.data.length;
        }

        this.seek(super.read_from);

        Header* header = cast(Header*)this.read(Header.sizeof).ptr;

        this.seek(super.read_from + header.sizeof);

        super.items--;

        if (!super.items)
        {
            super.read_from = 0;
            super.write_to  = 0;
        }
        else
        {
            super.read_from += pushSize(header.length);
            
            if (super.read_from >= super.data.length)
            {
                super.read_from = 0;
            }
        }

        return this.read(header.length);
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
        if (bytes > super.data.length - this.position)
        {
            return super.data[this.position .. $];
        }

        return super.data[this.position..this.position + bytes];    
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
        if (offset > super.data.length)
        {
            this.position = super.data.length;
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
        return pushSize(bytes) + super.write_to > super.data.length;           
    }
}

/*******************************************************************************

    UnitTest

*******************************************************************************/

unittest
{
    scope queue = new FlexibleByteRingQueue((9+FlexibleByteRingQueue.Header.sizeof)*10);
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
    
    scope middle = new FlexibleByteRingQueue(5*5);        
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

/*******************************************************************************

    Performance test

*******************************************************************************/

debug ( OceanUnitTest )
{
    // Uncomment the next line to see UnitTest output
    // debug = Verbose;
    
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
           auto caught = false;
           try scope queue = new FlexibleByteRingQueue(0); 
           catch ( Exception e ) caught = true;
           assert (caught == true);
        }

        /***********************************************************************
            
            Test wrapping
        
        ***********************************************************************/        

        debug (Verbose)  Trace.formatln("\nRunning ocean.io.device.queue.FlexibleByteRingQueue wrapping stability test");
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
            assert(queue.freeSpace == 0);
            assert(queue.pop() == cast(ubyte[])"1");
    
            // [_##] r=5 w=15
            assert(queue.freeSpace() == 1+FlexibleByteRingQueue.Header.sizeof);
            assert(queue.pop() == cast(ubyte[])"2");
            
            // [__#] r=10 w=15
            assert(queue.freeSpace() == (1+FlexibleByteRingQueue.Header.sizeof)*2);
            assert(queue.write_to == queue.data.length);
            assert(queue.push(cast(ubyte[])"1"));
            
            // [#_#] r=10 w=5
            assert(queue.freeSpace() == 1+FlexibleByteRingQueue.Header.sizeof);
            assert(queue.write_to == queue.pushSize("2".length));
            assert(queue.push(cast(ubyte[])"2"));
           // Trace.formatln("gap is {}, free is {}, write is {}", queue.gap, queue.freeSpace(),queue.write_to);
           
            
            // [###] r=10 w=10
            assert(queue.freeSpace == 0);
            assert(queue.pop() == cast(ubyte[])"3");
      
            // [##_] r=15/0 w=10
            assert(queue.freeSpace() == (1+FlexibleByteRingQueue.Header.sizeof)*1);
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
    }
}
