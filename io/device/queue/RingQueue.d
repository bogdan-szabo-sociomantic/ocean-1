/******************************************************************************

    Provides a ring buffer implementation of a persistent queue

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        Sep 2010: Initial release

    authors:        Mathias Baumann

*******************************************************************************/

module ocean.io.device.queue.RingQueue;

/*******************************************************************************

    Imports

*******************************************************************************/

private import  ocean.io.device.queue.model.IPersistQueue,
                ocean.io.device.queue.storage.model.IStorageEngine,
                ocean.io.device.queue.storage.Memory;

private import ocean.io.serialize.SimpleSerializer;

private import tango.io.model.IConduit: InputStream, OutputStream;

private import ocean.sys.SignalHandler;

debug private import tango.util.log.Trace;


/*******************************************************************************

    Implements a simple FIFO data container.  
    Internally it is using a ring buffer concept, so it automatically wrapps
    around the end when needed.   
    
    Usage Example
    
    ---
    
    import ocean.io.device.queue.RingQueue;
    
    
    // create a new Ring queue with enough size 
    scope queue = new RingQueue("test",(1+RingQueue.Header.sizeof)*3);
    
    // r is read position, w is write position.
    
    // [___] r=0 w=0
    queue.push("1");
    
    // [#__] r=0 w=5
    queue.push("2");
    
    // [##_] r=0 w=10
    queue.push("3");
    
    // fails and returns false
    queue.push("4"); 
    
    // outputs 1
    Trace.formatln(queue.pop()); 
    
    // outputs 2
    Trace.formatln(queue.pop()); 
    
    // outputs 3
    Trace.formatln(queue.pop()); 
        
    ---

*******************************************************************************/

class RingQueue : PersistQueue
{    
    /***************************************************************************
    
        The storage Engine

    ***************************************************************************/    

    private IStorageEngine storageEngine;
    
    
    /***************************************************************************
    
        Location of the gap at the rear end of the buffer where the unused space
        starts

    ***************************************************************************/        
    
    private size_t gap;
  
    
    /***************************************************************************
     
        Flag enumeration for comfortable selection of the storage engine

    ***************************************************************************/    
    
    public enum EngineFlag
    {
        Memory,
        File
    }
        
    
    /***************************************************************************
    
        Header for queue items

    ***************************************************************************/    

    struct Header
    {
        size_t length;
    }
    
    
    /***************************************************************************
    
        Constructor
    
        Params:
            name = name of queue (for logging)
            storage = storage engine to use 
    
        Note: the name parameter may be used be derived classes to denote a file
        name, ip address, etc.

    ***************************************************************************/
        
    public this ( char[] name, IStorageEngine storage )
    {
        this.storageEngine = storage;
        
        SignalHandler.register([SIGTERM,SIGINT],&this.terminate);
        
        super(name,storage.size);
        
        this.gap = storage.size;
    }
    
    
    /***************************************************************************
    
        Constructor
    
        Params:
            name = name of queue (for logging)
            max = max queue size (bytes)
            flag = flag to choose the storage engine
    
        Note: the name parameter may be used by derived classes to denote a file
        name, ip address, etc.

    ***************************************************************************/
        
    public this ( char[] name, uint max, EngineFlag flag = EngineFlag.Memory )
    in
    {
        assert (flag == EngineFlag.Memory, "Only memory implemented so far");
    }
    body
    {
        this.storageEngine = new Memory(max); 
        
        super(name,max); 
        
        this.gap = max;           
    }
    
    /***************************************************************************
    
        Registers dumping to file on application termination
    
        Returns:
            this instance
    
    ***************************************************************************/

    public typeof (this) registerTerminate ( )
    {
        SignalHandler.register(SignalHandler.AppTermination, &this.terminate);
        
        return this;
    }
    
    /***************************************************************************
    
        Unregisters dumping to file on application termination
    
        Returns:
            this instance
    
    ***************************************************************************/

    public typeof (this) unregisterTerminate ( )
    {
        SignalHandler.unregister(SignalHandler.AppTermination, &this.terminate);
        
        return this;
    }
    
    /***************************************************************************
    
        Calculates the size (in bytes) an item would take if it
        were pushed to the queue. 
        
        Params:
            data = data of which the queue-size should be returned
            
        Returns:
            bytes that data will claim in the queue

    ***************************************************************************/

    public static size_t pushSize ( size_t len )
    {        
        return Header.sizeof + len;
    }


    /***************************************************************************

        Destructor. Deletes the storageEngine 
        so that the memory is available again       
        
    ***************************************************************************/

    public ~this()
    {
        delete this.storageEngine;
    }
    
    
    /***************************************************************************
    
        Invariant to assert queue position consistency: When the queue is empty,
        read_from and write_to must both be 0.
    
    ***************************************************************************/
    
    invariant
    {
        debug scope (failure) Trace.formatln(typeof (this).stringof ~ ".invariant failed with items = {}, read_from = {}, write_to = {}",
                super.state.items, super.state.read_from, super.state.write_to);
        
        assert (super.state.items || !(super.state.read_from || super.state.write_to),
                typeof (this).stringof ~ ".invariant failed");
    }


    /***************************************************************************

        Pushes a single item to the queue.
        
        The callee has to make sure it will fit. 
        
        Params:
            item = item that will be pushed on the queue

    ***************************************************************************/

    protected void pushItem ( void[] item )
    in
    {
    	// This is checked by the super class, but just for the sake of safety
        assert(this.willFit(item.length), typeof(this).stringof ~ ".pushItem - item will not fit");
    }
    body
    {    
        void[] header = (cast(void*)&Header(item.length))[0 .. Header.sizeof];
        
        if (this.needsWrapping(item.length))
        {
            this.gap = super.state.write_to;
            super.state.write_to = 0;            
        }
        
        with (this.storageEngine)
        {
            seek(super.state.write_to);
            
            auto written = write(header);
            assert(written == header.length, typeof (this).stringof ~ ": write(header) length mismatch");
            
            seek(super.state.write_to + header.length);
            
            written = write(item);
            assert(written == item.length, typeof (this).stringof ~ ": write(item) length mismatch");
        }
        
        super.state.write_to += pushSize(item.length);
        ++super.state.items;
    }
    
    /***************************************************************************

        Pops a single item from the queue. 
        
        Returns:
            the popped item
    
    ***************************************************************************/
    
    protected void[] popItem ( )
    in
    {
    	// This is checked by the super class, but just for the sake of safety
        assert(super.state.items > 0, typeof(this).stringof ~ ".popItem - no items in the queue");
    }
    body
    {
        if (super.state.read_from >= this.gap)                                  // check whether there is an item at this offset
        {
            super.state.read_from = 0;                                          // if no, set it to the beginning (wrapping around)
            this.gap = super.state.dimension;
        }
        
        this.storageEngine.seek(super.state.read_from);
        
        Header* header = cast(Header*) this.storageEngine.read(Header.sizeof).ptr;
        
        this.storageEngine.seek(super.state.read_from + header.sizeof);
        
        --super.state.items;
        
        if (!super.state.items)
        {
            super.state.read_from = 0;
            super.state.write_to  = 0;
        }
        else
        {
            super.state.read_from += pushSize(header.length);
            
            if (super.state.read_from >= super.state.dimension)
            {
                super.state.read_from = 0;
            }
        }
        
        return this.storageEngine.read(header.length);
    }


    /***************************************************************************
    
        Gets the amount of data stored in the queue.
        
        Returns:
            bytes stored in queue
            
    ***************************************************************************/
        
    public ulong usedSpace ( )
    {
        if (super.state.items == 0)
        {
            return 0;
        }
        
        if (super.state.write_to > super.state.read_from)
        {
            return super.state.write_to - super.state.read_from;
        }
        
        return this.gap - super.state.read_from + super.state.write_to;
    }
    
    
    /**************************************************************************
        
        Returns true if queue is full (write position >= end of queue)
    
        TODO: change to > 99% full? or < 1K free?
        
        Returns:
            true when there is no free space left
        
    ***************************************************************************/

    public bool isFull ( )
    {
        return this.freeSpace() == 0;
    }
    
    
    /***************************************************************************
    
        Gets the amount of free space at the end of the queue.
        
        Returns:
            bytes free in queue
            
    ***************************************************************************/
        
    public ulong freeSpace ( )
    {
        return super.state.dimension - this.usedSpace; 
    }
    
    /***************************************************************************

        Finds out whether the provided data needs to be wrapped 
        
        Params:
            data = the data that should be checked
            
        Returns:
            true if the data needs wrapping, else false

    ***************************************************************************/

    private bool needsWrapping ( size_t len )
    {
        return pushSize(len) + super.state.write_to > super.state.dimension;           
    }
    
    
    /***************************************************************************

        Finds out whether the provided data will fit in the queue. 
        Also considers the need of wrapping. 
        
        Params:
            data = data to check 
            
        Returns:
            true when the data fits, else false

    ***************************************************************************/
    
    public bool willFit ( size_t elen )
    {   
        size_t len = pushSize(elen);

        if (super.state.items)
        {
            if (this.needsWrapping(elen))
            {
                return len <= super.state.read_from;
            }
            else
            {
                long d = super.state.read_from - super.state.write_to;
                
                return len <= d || d < 0; 
            }
        }
        else
        {
            assert(super.state.write_to == 0, typeof(this).stringof ~ "willFit: queue should be in the zeroed state");
            return len <= super.state.dimension;                                // Queue is empty and item at most
        }                                                                       // as long as the whole queue
    }


    /**************************************************************************

        Terminate signal handler. Saves this instance of the class to a file
        before termination.

        Params:
            code = signal code

    ***************************************************************************/

    protected bool terminate ( int code )
    {
        debug Trace.formatln("Closing {} (saving {} entries to {}.dump)",
                             super.name, super.state.items, super.name);
        this.log(SignalHandler.getId(code) ~ " raised: terminating .. at least trying to");
        
        this.dumpToFile();
        
        return true;
    } 

    
    /***************************************************************************
    
        Copies the contents of the queue from the passed conduit.
    
        Params:
            conduit = conduit to read from
        
        Returns:
            number of bytes read
        
        Throws:
            IOException on End Of Flow condition

    ***************************************************************************/
    
    protected size_t readFromConduit ( InputStream input )
    {   
        this.storageEngine.init(super.state.dimension);
        
        return this.storageEngine.readFromConduit(input);
    }
    
    
    /***************************************************************************
    
        Dumps the data in an linear way to the conduit
    
        Params:
            conduit = conduit to write to
        
        Returns:
            number of bytes written
        
        Throws:
            IOException on End Of Flow condition
    
    ***************************************************************************/

    protected size_t writeToConduit ( OutputStream output )
    {
        this.storageEngine.seek(0);
        
        return this.storageEngine.writeToConduit(output);
    }

    /***************************************************************************
    
        Writes the queue's state to a conduit. The gap member is written,
        followed by the super class' state.

        Params:
            conduit = conduit to write to
        
        Returns:
            number of bytes written
        
        Throws:
            IOException on End Of Flow condition
    
    ***************************************************************************/
    
    override protected size_t writeState ( OutputStream output )
    {
        size_t bytes_written = SimpleSerializer.write(output, this.gap);

        // Write super class' state
        bytes_written += super.writeState(output);
        
        return bytes_written;
    }


    /***************************************************************************
    
        Reads the queue's state from a conduit. The queue's gap member is read,
        followed by the super class' state.
        
        Params:
            conduit = conduit to read from
        
        Returns:
            number of bytes read
        
        Throws:
            IOException on End Of Flow condition
    
    ***************************************************************************/
    
    override protected size_t readState ( InputStream input )
    {
        size_t bytes_read = SimpleSerializer.read(input, this.gap);

        // Read super class' state
        bytes_read += super.readState(input);
        
        return bytes_read;
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
    import tango.core.internal.gcInterface: gc_disable, gc_enable;
    import ocean.util.Profiler;
    import tango.io.FilePath; 
    import tango.util.log.Trace; 
    
    unittest
    {

         scope random = new Random();

        /***********************************************************************
            
            Test for empty queue
        
        ***********************************************************************/
         
        {
            scope queue = new RingQueue("test",0);
            assert(queue.isFull());
            assert(queue.isEmpty());
            assert(!queue.push("stuff"));
        }
        
        
        /***********************************************************************
            
            Test wrapping
        
        ***********************************************************************/        
        
        Trace.formatln("\nRunning ocean.io.device.queue.RingQueue wrapping stability test");
        {
            scope queue = new RingQueue("test",(1+RingQueue.Header.sizeof)*3);

            // [___] r=0 w=0
            assert(queue.push("1"));

            // [#__] r=0 w=5
            assert(queue.push("2"));
            
            // [##_] r=0 w=10
            assert(queue.push("3"));
            
            // [###] r=0 w=15
            assert(!queue.push("4"));
            assert(queue.isFull);
            assert(queue.pop() == "1");
  
            // [_##] r=5 w=15
            assert(queue.freeSpace() == 1+RingQueue.Header.sizeof);
            assert(queue.pop() == "2");
            
            // [__#] r=10 w=15
            assert(queue.freeSpace() == (1+RingQueue.Header.sizeof)*2);
            assert(queue.state.write_to == queue.state.dimension);
            assert(queue.push("1"));
            
            // [#_#] r=10 w=5
            assert(queue.freeSpace() == 1+RingQueue.Header.sizeof);
            assert(queue.state.write_to == queue.pushSize("2".length));
            assert(queue.push("2"));
           // Trace.formatln("gap is {}, free is {}, write is {}", queue.gap, queue.freeSpace(),queue.write_to);
           
            
            // [###] r=10 w=10
            assert(queue.isFull);
            assert(queue.pop() == "3");
      
            // [##_] r=15/0 w=10
            assert(queue.freeSpace() == (1+RingQueue.Header.sizeof)*1);
            assert(queue.pop() == "1");         

            // [_#_] r=5 w=10
            assert(queue.pop() == "2");
  
            // [__] r=0 w=0
            assert(queue.isEmpty);
            assert(queue.push("1"));

            // [#__] r=0 w=5
            assert(queue.push("2#"));            
            
            // [#$_] r=0 w=11 ($ = 2 bytes)
            assert(queue.pop() == "1");           
            
            // [_$_] r=5 w=11
            assert(queue.push("1"));             
            
            // [#$_] r=5 w=5
            assert(!queue.push("2"));
            assert(queue.pop() == "2#");
   
            // [#__] r=11 w=5
            assert(queue.push("2")); // this needs to be wrapped now

            // [##_] r=11 w=10            
            assert(queue.gap == queue.state.read_from);
        }
         
        /***********************************************************************
        
            Read/Write from/to File Test
    
        ***********************************************************************/
        
        Trace.formatln("\nRunning ocean.io.device.queue.RingQueue file reading/writing test");
        {
            const QueueSize = 1024*1024*10; // 10 MB
            const Iterations = 50;

            void[] buffer = new void[1024*1024];
           
            void rmFile()
            { 
                scope file = new FilePath("fileQueue.dump");
                if(file.exists())
                {
                    file.remove();
                }
            }

            rmFile();
            auto fq = new RingQueue("fileQueue",QueueSize);



            int pushlen;
            do
            {
                random(pushlen);
                pushlen %= buffer.length;                
            }
            while(fq.push(buffer[0..pushlen]));

            auto sizeBefore = fq.usedSpace;
            auto itemsBefore = fq.state.items;

            fq.dumpToFile();

            delete fq;
            
            fq = new RingQueue("fileQueue",QueueSize);
            
            fq.readFromFile();
            
            rmFile();

            assert(fq.usedSpace == sizeBefore);
            assert(itemsBefore == fq.state.items);
        }

        
        /***********************************************************************
        
            Performance and Memory Test
    
        ***********************************************************************/
        
        {
            Trace.formatln("\nRunning ocean.io.device.queue.RingQueue memory & performance test");
            const uint QueueSize = 1024*1024*100;
            const Iterations = 500;
            uint it = 0;
            scope buf = new void[QueueSize];
            ulong average,allBytes;
            scope elements = new int[0];

            gc_disable();
            
            scope (exit) gc_enable();
            
            while(it++ < Iterations)
            {

                // Pre-generate the values //

                elements.length = 0;
                
                long bytesLeft=QueueSize;
                // fill 'elements' with random lengths.
                while(bytesLeft > 0)
                {
                    uint el;
                    random(el);
                    el%=1024*1024; //el+=1;
                    if(bytesLeft-el <= 0)
                    {
                        elements~=bytesLeft;
//                        elements[n++] = bytesLeft;
                        break;
                    }
                    elements~= el;
//                    elements[n++] = el;
                    bytesLeft -= el;
                }
                
                uint pos=0;            

                auto before = MemProfiler.checkUsageMb();                         

                scope q = new RingQueue("hello",QueueSize);
                
                StopWatch watch; watch.start;
                
                uint i;

                foreach(el ; elements[0 .. $])
                {
                    if(!q.push(buf[pos..pos+el]))
                    {
                        //   Trace.formatln("Failed to push data of length {}", el);                    
                        break;
                    }
                    pos+=el;
                    ++i;
                }

                while(q.pop) {}

                if(it%(Iterations*.1) == 0)
                Trace.formatln("Iteration {}: {} Items and\t{} MB in\t{} ms. Memory: Before\t{} MB, after:\t{}MB, Diff:\t{}",it,i,pos/1024.0/1024,watch.microsec(),before,MemProfiler.checkUsageMb,(MemProfiler.checkUsageMb-before));
                allBytes+=pos;
                average+=watch.microsec();

            }
            Trace.formatln("Average time for 100mb: {}",QueueSize*average/allBytes);

        }
                
        /***********************************************************************
        
            Various random tests

        ***********************************************************************/
                
        scope queue = new RingQueue("test1",(9+RingQueue.Header.sizeof)*10);
        assert(!queue.isFull);
        assert(queue.isEmpty);
        
        assert(queue.push("Element 1"));                
        assert(queue.pop() == "Element 1");
        assert(queue.state.items == 0);
        assert(!queue.isFull);
        assert(queue.isEmpty);
        assert(queue.usedSpace() == 0);
        
        assert(queue.push("Element 1"));        
        assert(queue.push("Element 2"));
        assert(queue.push("Element 3"));
        assert(queue.push("Element 4"));
        assert(queue.push("Element 5"));
        assert(queue.push("Element 6"));
        assert(queue.push("Element 7"));
        assert(queue.push("Element 8"));
        assert(queue.push("Element 9"));
        assert(queue.push("Element10"));
        
//        assert(queue.size() == 10); // FIXME: queue.size is deprecated        
        assert(queue.isFull);
        assert(!queue.isEmpty);
        
        assert(!queue.push("more"));
//        assert(queue.size() == 10);  // FIXME: queue.size is deprecated
        
        scope middle = new RingQueue("test2",5*5);        
        middle.push("1");        
        middle.push("2");
        middle.push("3");
        middle.push("4");
        assert(middle.pop == "1");        
        assert(middle.state.read_from == 5);
        assert(middle.state.write_to == 5*4);
        assert(middle.freeSpace() == 5*2);
        assert(middle.push("5"));
        assert(middle.push("6"));
        assert(middle.freeSpace() == 0);
    }    
}
