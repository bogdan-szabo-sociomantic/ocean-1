/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release      

    author:         Gavin Norman

    QueueMemory implements the PersistQueue base class. It is a FIFO queue
    based on a void[] memory buffer, using memcpy for all write operations, and
    array slicing for read operations.

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

private import ocean.io.device.model.IPersistQueue;

private import ocean.io.device.Memory;

private import tango.io.device.Conduit;

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

class QueueMemory : PersistQueue
{
	struct ItemHeader
	{
		uint size;
	}

	protected void[] data;


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

		Initialises the Array conduit with the size set in the constructor.
	
	***************************************************************************/

    public void open ( char[] name )
	{
		this.log("Initializing memory queue '{}' to {} KB", this.name, this.dimension / 1024);
		this.data = new void[this.dimension];
	}


    /***************************************************************************

		Overridden cleanup method. Uses memcpy for greater speed.
		
		Returns:
			true if remapped, false otherwise
	
	***************************************************************************/

    override public synchronized bool cleanup ( )
    {
		if ( !this.isDirty() )
		{
			return false;
		}

		Trace.formatln("QueueMemory remapping");

		// Move queue contents
		void* buf_start = this.data.ptr;
		memcpy(buf_start, buf_start + this.read_from, this.write_to - this.read_from);

		// Update seek positions
		this.write_to -= this.read_from;
		this.read_from = 0;
	
	    return true;
    }


	/***************************************************************************
	
	    Pushes an item into the queue.
	
	***************************************************************************/
	
	synchronized bool push ( void[] item )
	{
		if ( !this.willFit(item) )
		{
			return false;
		}

		// write item header
		ItemHeader hdr;
		hdr.size = item.length;
		this.writeHeader(this.write_to, hdr);
		this.write_to += ItemHeader.sizeof;
		
		// write item
		memcpy(this.data.ptr + this.write_to, item.ptr, item.length);
		this.write_to += item.length;

		// update counter
		this.items++;

		return true;
	}


	/***************************************************************************

		Calculates the amount of space a given data buffer would take up if
		pushed into the queue.
		
		The space requirement is equal to the length of the data, plus the
		length of its header (which is constant).
		
		Returns:
			bytes size
	        
	***************************************************************************/
	
	protected uint pushSize ( void[] item )
	{
		return ItemHeader.sizeof + item.length;
	}


	/***************************************************************************
	
	    Pops an item from the queue.
	
	***************************************************************************/

	synchronized void[] pop ( )
	{
		if ( !this.items )
		{
			return null;
		}

		// read item header
		ItemHeader hdr;
		this.readHeader(this.read_from, hdr);
		this.read_from += ItemHeader.sizeof;

		// get item slice
		auto item_content = this.data[this.read_from .. this.read_from + hdr.size];
		this.read_from += hdr.size;

		// update counter
		this.items--;
		if ( this.items == 0 )
		{
			this.reset();
		}
		
		return item_content;
	}


	/***************************************************************************
	
	    Removes all entries from the queue.
	
	***************************************************************************/
	
	public void flush ( )
	{
		this.reset();
	}


	debug synchronized public void validateContents ( bool show_summary, char[] message = "", bool show_contents_size = false )
	{
		long pos = this.read_from;
		uint count;
		
		do
		{
			ItemHeader hdr;
			this.readHeader(pos, hdr);
			assert(hdr.size < 1024 * 1024);
			count++;
			
			pos += ItemHeader.sizeof + hdr.size;
		} while ( pos < this.write_to )

		if ( show_summary )
		{
			Trace.formatln("{} - {} END OF QUEUE", this.getName(), count);
		}
	}

	
	/***************************************************************************
	
	    Writes a header into the queue at the specified offset.
	    
	    Params:
	    	offset = offset from beginning of queue
	    	header = header to write
	
	***************************************************************************/

	protected void writeHeader ( uint offset, ref ItemHeader header )
	in
	{
		assert(offset < dimension);
	}
	body
	{
		memcpy(this.data.ptr + offset, &header, header.sizeof);
	}


	/***************************************************************************
	
	    Reads a header from the queue at the specified offset.
	    
	    Params:
	    	offset = offset from beginning of queue
	    	header = header to read into
	
	***************************************************************************/

	protected void readHeader ( uint offset, out ItemHeader header )
	in
	{
		assert(offset < dimension);
	}
	body
	{
		memcpy(&header, this.data.ptr + offset, header.sizeof);
	}
	

	/***************************************************************************
	
		Copies the contents of the queue to the passed conduit.
		
		Params:
			conduit = conduit to write to
	
	***************************************************************************/
	
	protected void writeToConduit ( Conduit conduit )
	{
		scope this_conduit = new Memory(this.data);
		this_conduit.seek(0);
		conduit.copy(this_conduit);
	}


	/***************************************************************************
	
		Copies the contents of the queue from the passed conduit.
		
		Params:
			conduit = conduit to read from
	
	***************************************************************************/
	
	protected void readFromConduit ( Conduit conduit )
	{
		scope this_conduit = new Memory(this.data);
		this_conduit.seek(0);
		this_conduit.copy(conduit);
	}
}



private import ocean.io.device.model.IConduitQueue;

class OldQueueMemory : ConduitQueue!(Memory)
{
	this ( char[] name, uint max )
	{
		super(name, max);
	}

	public bool isDirty ( )
	{
    	const min_bytes = 2048;
    	auto half_percent = (this.dimension / 200);
    	auto min_diff = half_percent > min_bytes ? half_percent : min_bytes;

    	return (this.read_from) - (this.dimension - this.write_to) > min_diff;
	}

    public void open ( char[] name )
	{
		this.log("Initializing memory queue '{}' to {} KB", this.name, this.dimension / 1024);
        this.conduit = new Memory(this.dimension); // non-growing array
	}

    override public synchronized bool cleanup ( )
    {
		if ( !this.isDirty() )
		{
			return false;
		}

		Trace.formatln("QueueMemory remapping");

		// Move queue contents
		void* buf_start = this.conduit.buffer.ptr;
		memcpy(buf_start, buf_start + this.read_from, this.write_to - this.read_from);

		// Update seek positions
		this.write_to -= this.read_from;
		this.read_from = 0;
	
	    // insert an empty record at the new insert position
		this.eof();

	    return true;
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


