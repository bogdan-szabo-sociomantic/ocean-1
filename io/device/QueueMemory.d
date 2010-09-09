/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release      

    author:         Gavin Norman

    QueueMemory implements the ConduitQueue base class, based on the Memory
    conduit (ocean.io.device.Memory). A few methods of ConduitQueue are
    overridden to take advantage of our knowledge of the underlying Conduit
    (ie that it's just a memory buffer). Thus memcpy and slicing can be used.

	Also in this module is AutoSaveQueueMemory, an extension of QueueMemory which
	loads itself from a dump file upon construction, and saves itself to a file
	upon destruction. It handles the Ctrl-C terminate signal to ensure that the
	state and content of all AutoSaveQueueMemory instances are saved if the
	program is terminated.

*******************************************************************************/

module  ocean.io.device.QueueMemory;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.io.device.model.IConduitQueue;

private import ocean.io.device.Memory;

private import tango.io.device.Conduit;

private import tango.io.FilePath, tango.io.device.File;

private import ocean.sys.SignalHandler;

private import tango.util.log.Trace;



/*******************************************************************************

    QueueMemory

*******************************************************************************/

class QueueMemory : ConduitQueue!(Memory)
{
	/***************************************************************************

	    Constructor
	
	    Params:
	    	name = name of queue (for logging)
	    	max = max queue size (bytes)
	
	***************************************************************************/

	this ( char[] name, uint max )
	{
		super(name, max);
	}

	/***************************************************************************

		Determines when the queue is ready to be cleaned up.

		As remapping is very cheap with a memory queue, it decides to remap when
		the difference between the space left to write into at the end of the
		queue and the space at the beginning is > 0.5% of the total size of the
		queue, or at least 2Kb.
	    
	***************************************************************************/

	public bool isDirty ( )
	{
    	const min_bytes = 2048;
    	auto half_percent = (this.dimension / 200);
    	auto min_diff = half_percent > min_bytes ? half_percent : min_bytes;

    	return (this.read_from) - (this.dimension - this.write_to) > min_diff;
	}


	/***************************************************************************

    	Opens the queue. Just creates the memory buffer.
	    
	    Params:
	    	name = the queue's name

	***************************************************************************/

	public void open ( char[] name )
	{
		this.log("Initializing memory queue '{}' to {} KB", this.name, this.dimension / 1024);
        this.conduit = new Memory(this.dimension); // non-growing array
	}


    ~this()
    {
        delete this.conduit;
    }
    
	/***************************************************************************

		Overridden cleanup method, making use of memcpy for gerater speed.
	    
	***************************************************************************/

	override protected void cleanupQueue ( )
    {
		// Move queue contents
		void* buf_start = this.conduit.buffer.ptr;
		memcpy(buf_start, buf_start + this.read_from, this.write_to - this.read_from);

		// Update seek positions
		this.write_to -= this.read_from;
		this.read_from = 0;
	
	    // insert an empty record at the new insert position
		this.eof();
    }


	/***************************************************************************

		Overridden readItem method, slices directly into the memory buffer, for
		greater speed.
    
	***************************************************************************/
	
	override protected void[] readItem ( ref Header hdr)
	{
	    return this.conduit.slice(hdr.size);
	}
}






/*******************************************************************************

	AutoSaveQueueMemory

*******************************************************************************/

class AutoSaveQueueMemory : QueueMemory
{
	/***************************************************************************

	    Constructor. Registers a termination handler for the class, so the
	    queue's contents can be saved if the program is terminated.
	    
	    Params:
	    	name = name of queue (for logging)
	    	max = max queue size (bytes)
	
	***************************************************************************/
	
	public this ( char[] name, uint max )
	{
		super(name, max);
		TerminationSignal.handle(&this.terminate);
		this.readFromFile();
	}


	/***************************************************************************

		Closes the queue, writing it to a file before deleting it.
	
	***************************************************************************/
	
	public synchronized override void close ( )
	{
		this.dumpToFile();
		super.close();
	}


    /***************************************************************************

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
}



/*******************************************************************************

	Unittest

*******************************************************************************/
debug = OceanUnitTest;
debug (OceanUnitTest)
{
	import tango.util.log.Trace;
	import tango.core.Memory;
	import tango.time.StopWatch;
	import tango.core.Thread;
	import tango.text.convert.Integer;
	import ocean.util.Profiler;
	
	import tango.stdc.string: memcpy;
	import tango.stdc.stdio: snprintf;
	
	import tango.math.random.Random;

	unittest
	{
        /***********************************************************************
        
            Performance and Memory Test

        ***********************************************************************/
        {
            Trace.formatln("\nRunning ocean.io.device.QueueMemory memory & performance test");
            const uint QueueSize = 1024*1024*100;
            const Iterations = 500;
            uint it = 0;
            void[] buf = new void[QueueSize];
            ulong average=0;
            ulong allBytes;

            while(it++ < Iterations)
            {
                scope random = new Random();

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

                scope q = new QueueMemory("hello",QueueSize);
                q.write_to = q.read_from = start;

                StopWatch watch;
                watch.start;
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


        Trace.formatln("Running ocean.io.device.QueueMemory unittest");

        char[] buf;


	    /***********************************************************************

			Queue test

	    ***********************************************************************/

	    const uint ITERATIONS = 0; //50_000;

	    const uint Q_SIZE = 1024 * 1024;

	    auto q = new QueueMemory("test", Q_SIZE);

	    Trace.formatln("Queue test: Initial mem usage = {}Mb", MemProfiler.checkUsageMb());

	    scope random = new Random();

    	uint total_ops;
    	auto before = MemProfiler.checkUsage();
	    for ( uint i = 0; i < ITERATIONS; i++ )
	    {
	    	// Add random length items to the queue until it's full
    		bool push_succeeded;
    		uint pushes;
	    	do
	    	{
	    		uint len;
	    		random(len);
	    		len = 1 + (len % 25_000);
	    		buf.length = len;
	    		push_succeeded = q.push(buf);
	    		if ( push_succeeded )
	    		{
	    			pushes++;
	    		}
	    	} while ( push_succeeded )

	    	// Remove items from the queue until it's empty
	    	uint pops;
	    	while ( !q.isEmpty() )
	    	{
    			auto content = q.pop();
    			pops++;
	    	}
	    	assert(pops == pushes);
	    	total_ops += pushes;

	    	if ( i % 1000 == 0 )
	    	{
	    		Trace.formatln("iteration {}, {}%, {} push/pops",
	    				i, 100.0 * (cast(float)i / cast(float)ITERATIONS), total_ops);
	    		total_ops = 0;

	    		MemProfiler.checkSectionUsage("queue", before, MemProfiler.Expect.NoChange);
	    		before = MemProfiler.checkUsage();
	    	}
	    }

	    Trace.formatln("Queue test: Final mem usage = {}Mb", MemProfiler.checkUsageMb());

	    Trace.formatln("Done unittest\n");
	}
}


