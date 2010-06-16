/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release      

    author:         Gavin Norman

    QueueMemory implements the QueueConduit base class. It is a FIFO queue
    based on the Memory Conduit (which is a non-growing memory buffer).

	Also in this module is QueueMemoryPersist, an extension of QueueMemory which
	loads itself from a dump file upon construction, and saves itself to a file
	upon destruction. It handles the Ctrl-C terminate signal to ensure that the
	state and content of all QueueMemoryPersist instances are saved if the
	program is terminated.

*******************************************************************************/

module  ocean.io.device.QueueMemory;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.io.device.model.IConduitQueue;

private import tango.util.log.model.ILogger;

private import tango.io.device.Conduit;

private import ocean.io.device.Memory;

private import tango.io.FilePath, tango.io.device.File;

private import ocean.sys.SignalHandler;

private import tango.util.log.Trace;



/*******************************************************************************

	C memcpy

*******************************************************************************/

extern (C)
{
    protected void * memcpy (void *dst, void *src, size_t);
}


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

		Determines when the queue is ready to be remapped.

		As remapping is very cheap with a memory queue, it decides to remap when
		the space left to write into at the end of the queue is smaller than the
		space at the beginning.

    ***************************************************************************/

    public bool isDirty ( )
	{
    	return (this.limit - this.insert) < (this.first);
	}

    /***************************************************************************

		Initialises the Array conduit with the size set in the constructor.
	
	***************************************************************************/

    public void open ( char[] name )
	{
		this.log("Initializing memory queue '{}' to {} KB", this.name, this.limit / 1024);
        this.conduit = new Memory(this.limit); // non-growing array
	}

    /***************************************************************************

		Overridden remap method. Uses memcpy for greater speed.
		
		Returns:
			true if remapped, false otherwise
	
	***************************************************************************/

    override public synchronized bool remap ( )
    {
		if ( !this.isDirty() )
		{
			return false;
		}

		Trace.formatln("QueueMemory remapping");

		// Move queue contents
		void* buf_start = this.conduit.buffer.ptr;
		memcpy(buf_start, buf_start + this.first, this.insert - this.first);

		// Update seek positions
		this.insert -= super.first;
		this.first = 0;
	
	    // insert an empty record at the new insert position
		this.eof();

	    return true;
    }
}



/*******************************************************************************

	QueueMemoryPersist

*******************************************************************************/

class QueueMemoryPersist : QueueMemory
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
		this.stopIO();

		Trace.formatln("Closing {} (saving {} entries to {})",
				this.getName(), this.size(), this.getName() ~ ".dump");
		this.log(SignalHandler.getId(code) ~ " raised: terminating");
		this.dumpToFile();
	}
}



/*******************************************************************************

	Unittest

*******************************************************************************/

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
	    Trace.formatln("Running ocean.io.device.QueueMemory unittest");

	    char[] buf;


	    /***********************************************************************

			Queue test

	    ***********************************************************************/

	    const uint ITERATIONS = 50_000;

	    const uint Q_SIZE = 1024 * 1024;

	    auto q = new QueueMemory("test", Q_SIZE);

	    Trace.formatln("Queue test: Initial mem usage = {} bytes", GC.stats["poolSize"]);

	    scope random = new Random();

	    for ( uint i = 0; i < ITERATIONS; i++ )
	    {
    		MemProfiler.check("queue push", {
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
		    	
		    	if ( i % 1000 == 0 ) Trace.formatln("iteration {} / {}", i, ITERATIONS);
    		}, MemProfiler.Expect.NoChange);
	    }

	    Trace.formatln("Done unittest\n");
	}
}


