/******************************************************************************

    Provides a ring buffer implementation of a persistent queue

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        Sep 2010: Initial release

    authors:        Mathias Baumann

*******************************************************************************/

module io.device.queue.RingQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.device.model.IPersistQueue;

private import ocean.io.device.queue.storage.model.IStorageEngine;

private import ocean.io.device.queue.storage.Memory;

private import tango.io.device.Conduit;

private import ocean.sys.SignalHandler;

private import tango.util.log.Trace;



class RingQueue : PersistQueue
{
    private IStorageEngine storageEngine;
    
    /***************************************************************************
    
        Location of the gap at the rear end of the buffer
        where the unused space starts

    ***************************************************************************/        
    
    private size_t gap;
  
    /***************************************************************************
     
        Flag enumeration for comfortable selection of the storage engine

    ***************************************************************************/    
    
    public enum EngineFlag
    {
        Memory,File
    };
        
    
    struct Header
    {
        static Header header ( size_t length )
        {
            Header h; h.length = length; 
            return h;
        }
        
        size_t length;
    };  
    
    
    
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
        TerminationSignal.handle(&this.terminate);
        super(name,storage.size);
        this.gap = storage.size;
    }
    
    
    /***************************************************************************
    
        Constructor
    
        Params:
            name = name of queue (for logging)
            max = max queue size (bytes)
            flag = flag to choose the storage engine
    
        Note: the name parameter may be used be derived classes to denote a file
        name, ip address, etc.

    ***************************************************************************/
        
    public this ( char[] name, uint max,EngineFlag flag=EngineFlag.Memory )
    {
        assert(flag == EngineFlag.Memory,"Only memory implemented so far");
        this.storageEngine = new Memory(max); 
        TerminationSignal.handle(&this.terminate);
        super(name,max);    
        this.gap = max;    
        
    }
    

    /***************************************************************************
    
        Calculates the size (in bytes) an item would take if it
        were pushed to the queue. 
        
        Params:
            data = data of which the queue-size should be returned
            
        Returns:
            bytes that data will claim in the queue

    ***************************************************************************/

    public uint pushSize ( void[] data )
    {        
        return Header.sizeof+data.length;
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

        Pushes a single item to the queue. 
        
        Params:
            item = item that will be pushed on the queue

    ***************************************************************************/

    protected void pushItem ( void[] item )
    {        
       
        if(this.needsWrapping(item))
        {   // writing to the beginning of our storage
            // the calling function made sure it will fit.
            this.gap = super.write_to;
            super.write_to = 0;
            

        }
        
        with(this.storageEngine)
        {
            seek(super.write_to);
            write((cast(void*)&Header.header(item.length))[0..Header.sizeof]);
            seek(super.write_to+Header.sizeof);
            write(item);
        }
        
        this.write_to+=this.pushSize(item);
        ++super.items;         
        

    }
    
    /***************************************************************************
    
        Gets the amount of data stored in the queue.
        
        Returns:
            bytes stored in queue
            
    ***************************************************************************/
        
    public uint usedSpace ( )
    {
        if(items == 0)
        {
            return 0;
        }
        
        if(super.write_to > super.read_from)
        {
            return super.usedSpace();
        }
        
        return this.gap-super.read_from + super.write_to;
        
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
        
    public uint freeSpace ( )
    {
        return super.dimension - this.usedSpace; 
    }
    
    /***************************************************************************

        Pops a single item from the queue. 
        
        Returns:
            the popped item
    
    ***************************************************************************/

    protected void[] popItem ( )
    {
        this.storageEngine.seek(super.read_from);
        Header* header=cast(Header*)this.storageEngine.read(Header.sizeof);
        
        this.storageEngine.seek(super.read_from+header.sizeof);
        void[] data = this.storageEngine.read(header.length);
        
        super.read_from += header.sizeof + header.length;
        
        // check whether there is an item at this offset
        if(super.read_from >= this.gap)
        {   // if no, set it to the beginning (wrapping around)
            super.read_from = 0;
            this.gap = this.dimension;
        }
        else if(super.read_from >= super.dimension)
        {
            super.read_from = 0;
        }
        
        --super.items;
        
        return data;
    }
    
    /***************************************************************************

        Finds out whether the provided data needs to be wrapped 
        
        Params:
            data = the data that should be checked
            
        Returns:
            true if the data needs wrapping, else false

    ***************************************************************************/

    private bool needsWrapping ( void[] data )
    {
        return this.pushSize(data)+super.write_to > super.dimension;           
    }
    
    /***************************************************************************

        Finds out whether the provided data will fit in the queue. 
        Also considers the need of wrapping. 
        
        Params:
            data = data to check 
            
        Returns:
            true when the data fits, else false

    ***************************************************************************/
    
    public bool willFit ( void[] data )
    {
      //  debug Stdout("called willfit").newline;

        // check if the dimension is big enough when it's empty
        if(super.items == 0 && super.dimension >= this.pushSize(data))
        {         
            return true;
        }
        
        if(this.needsWrapping(data))
        {
          
            // check if there is enough space at the beginning
            return super.read_from >= this.pushSize(data);
        }
        if(super.read_from < super.write_to)
        {
        
            return super.dimension-super.write_to >= this.pushSize(data);
        }
        
        // check if there is enough space between the new and old data
        if(super.read_from > super.write_to)
        {
         
            return super.read_from-super.write_to >= this.pushSize(data);
        }
        
        if(super.read_from == super.write_to && super.items != 0)
        {
            return false;
        }
        
                
        assert(false,"Not considered case happened");                
    }


    /**************************************************************************

        Terminate signal handler. Saves this instance of the class to a file
        before termination.

        Params:
            code = signal code

    ***************************************************************************/

    protected void terminate ( int code )
    {
        Trace.formatln("Closing {} (saving {} entries to {})",
                this.getName(), this.size(), this.getName() ~ ".dump");
        this.log(SignalHandler.getId(code) ~ " raised: terminating");
        this.dumpToFile();
    } 

    /***************************************************************************
    
        Opens the queue given an identifying name. Should
        create any data containers needed. This method is called by the
        PersistQueue constructor.
            
        Params:
            name = name of the queue to open

    ***************************************************************************/

    public void open ( char[] name )
    {
        super.setName=name;
        super.readFromFile();
    }
    
    /***************************************************************************
    
        this method is not needed.
    
    ***************************************************************************/
    
    public void cleanupQueue ( )
    {
        return;
    }
        
    /***************************************************************************
    
        This method is not needed.
    
    ***************************************************************************/

    public bool isDirty ( ) 
    { 
        return false; 
    }
    
    
    /***************************************************************************
    
        Copies the contents of the queue from the passed conduit.
    
        Params:
            conduit = conduit to read from

    ***************************************************************************/
    
    protected void readFromConduit ( Conduit conduit )
    {           
       
        this.storageEngine.init(this.dimension);
        this.storageEngine.readFromConduit(conduit);
    }
    /***************************************************************************
    
        Dumps the data in an linear way to the conduit
    
        Params:
            conduit = conduit to write to
    
    ***************************************************************************/

    protected void writeToConduit ( Conduit conduit )
    {
     /*   if(super.items > 0)
        {
            if(super.read_from > super.write_to)
            {   // [###__###]
            
                // read from read_from till the end of data
                this.storageEngine.seek(super.read_from);
                auto part1 = this.storageEngine.read(this.gap - super.read_from);
                // read from 0 to write_to
                this.storageEngine.seek(0);
                auto part2 = this.storageEngine.read(super.write_to);

                for(size_t bytes=0; (bytes=conduit.write(part1[bytes..$])) > 0;) {}
                for(size_t bytes=0; (bytes=conduit.write(part2[bytes..$])) > 0;) {}
            }
            else if(super.read_from < super.write_to)
            {   // [__###__]
            */
                this.storageEngine.seek(0);
                auto part = this.storageEngine.read(super.dimension);

                for(size_t bytes=0; (bytes=conduit.write(part[bytes..$])) > 0;) {}
/*            }

        }*/
    }


    debug public void validateContents
      (bool show_summary, char[] message = "", bool show_contents_size = false )
    {
        
    }
                                   

    
    
}


debug(OceanUnitTest)
{
    import tango.math.random.Random;
    import tango.time.StopWatch;
    import tango.core.Memory;
    import ocean.util.Profiler;
    import tango.io.FilePath; 
    
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
            assert(queue.write_to == queue.dimension);
            assert(queue.push("1"));
            
            // [#_#] r=10 w=5
            assert(queue.freeSpace() == 1+RingQueue.Header.sizeof);
            assert(queue.write_to == queue.pushSize("2"));
            assert(queue.push("2"));
           // Trace.formatln("gap is {}, free is {}, write is {}", queue.gap, queue.freeSpace(),queue.write_to);
           
            
            // [###] r=10 w=10
            assert(queue.isFull);
            assert(queue.pop() == "3");
                        
            // [##_] r=15 w=10
            assert(queue.freeSpace() == (1+RingQueue.Header.sizeof)*1);
            assert(queue.pop() == "1");         
            
            // [_#_] r=5 w=10
            assert(queue.pop() == "2");
            
            // [__] r=10 w=10
            assert(queue.isEmpty);
            assert(queue.push("1"));
            
            // [__#] r=10 w=15
            assert(queue.push("2#"));            
            
            // [$_#] r=10 w=6 ($ = 2 bytes)
            assert(queue.pop() == "1");           
            
            // [$__] r=15 w=6
            assert(queue.push("1"));             
            
            // [$#_] r=15 w=11
            assert(!queue.push("2"));
            assert(queue.pop() == "2#");
            
            // [_#_] r=6 w=11
            assert(queue.push("2")); // this needs to be wrapped now
            
            // [##_] r=6 w=5            
            assert(queue.gap == RingQueue.Header.sizeof + queue.read_from + 1);
          
            
            
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
            auto itemsBefore = fq.items;

            fq.dumpToFile();

            delete fq;
            
            fq = new RingQueue("fileQueue",QueueSize);
            rmFile();

            assert(fq.usedSpace ==sizeBefore);
            assert(itemsBefore == fq.items);
        }

        /***********************************************************************
        
            Performance and Memory Test
    
        ***********************************************************************/
        {
            Trace.formatln("\nRunning ocean.io.device.queue.RingQueue memory & performance test");
            const uint QueueSize = 1024*1024*100;
            const Iterations = 500;
            uint it = 0;
            void[] buf = new void[QueueSize];
            ulong average,allBytes;


            while(it++ < Iterations)
            {

                // Pre-generate the values //

                int[] elements;

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
                        break;
                    }
                    elements~= el;
                    bytesLeft -= el;
                }
                uint start=void; random(start);
                start %= QueueSize;
                // set it to start reading from .. anywhere.

                uint pos=0;            


                auto before = MemProfiler.checkUsageMb();                         

                scope q = new RingQueue("hello",QueueSize);
                q.write_to = q.read_from = start; StopWatch watch; watch.start;
                uint i;

                foreach(el ; elements)
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
                Trace.formatln("Iteration {}: Started at byte {}\t{} Items and\t{} MB in\t{} ms. Memory: Before\t{} MB, after:\t{}MB, Diff:\t{}",it,start,i,pos/1024.0/1024,watch.microsec(),before,MemProfiler.checkUsageMb,(MemProfiler.checkUsageMb-before));
                allBytes+=pos;
                average+=watch.microsec();

            }
            Trace.formatln("Average time for 100mb: {}",QueueSize*average/allBytes);

        }
        
        
        
        
        
        scope queue = new RingQueue("test1",(9+RingQueue.Header.sizeof)*10);
        assert(!queue.isFull);
        assert(queue.isEmpty);
        
        assert(queue.push("Element 1"));                
        assert(queue.pop() == "Element 1");
        assert(queue.items == 0);
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
        
        assert(queue.size() == 10);        
        assert(queue.isFull);
        assert(!queue.isEmpty);
        
        assert(!queue.push("more"));
        assert(queue.size() == 10);
        
        

        
        scope middle = new RingQueue("test2",5*5);        
        middle.push("1");        
        middle.push("2");
        middle.push("3");
        middle.push("4");
        assert(middle.pop == "1");        
        assert(middle.read_from == 5);
        assert(middle.write_to == 5*4);
        assert(middle.freeSpace() == 5*2);
        assert(middle.push("5"));
        assert(middle.push("6"));
        assert(middle.freeSpace() == 0);
    }
    


    /*******************************************************************************

        Unittest

    ****************************************************************************

    import tango.util.log.Trace;
    import tango.core.Memory;
    import tango.time.StopWatch;
    import tango.core.Thread;
    import tango.text.convert.Integer;
    import ocean.util.Profiler;
    
    import tango.stdc.string: memcpy;
    import tango.stdc.stdio: snprintf;
    
    import tango.math.random.Random;


***/

    
    
}
