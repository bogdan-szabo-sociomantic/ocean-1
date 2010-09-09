/*******************************************************************************

    copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release

    author:         Kris Bell / Thomas Nicolai / Gavin Norman

	ConduitQueue implements the PersistQueue class. It implements a FIFO queue to
	push and pop a large quantity of data to a Conduit. Each item in the queue
	consists of the data itself and an automatically generated message header.

	ConduitQueue is a template class over a Conduit object as the underlying
	storage medium for the queue. In this way multiple types of queue can be
	implemented, using a variety of Conduits as storage media.
	
	It is assumed that the Conduit underlying the queue is of a fixed size.

	Usage example, tests the derived classes QueueFile:

	---
	
	private import ocean.io.device.model.IQueue;
	private import ocean.io.device.QueueMemory;
	private import ocean.io.device.QueueFile;
	
	import tango.stdc.posix.stdlib;
	private import tango.time.StopWatch;
	
	private import tango.util.log.Log, tango.util.log.AppendConsole;
	
	private import tango.net.cluster.model.IChannel;
	
	
	
	void main (char[][] args)
	{
		StopWatch w;
		auto log = Log.getLogger("queue.persist");
		auto appender = new AppendConsole;
		log.add(appender);
	
		// Initialise the queue
		auto q = new QueueFile ("test_file_queue", 256 * 1024 * 1024);
		q.attachLogger(log);
	
		// Clear the queue before we test.
		q.flush();
	
		// Time a bunch of push operations
		w.start;
		const uint tests = 500_000;
		uint i;
		for (i=tests; i--;)
		     push_stuff(q);
	
		log.info("{} push/s", tests/w.stop);
		
		// Time a bunch of pop operations
		w.start;
		i = 0;
		while (q.pop !is null) ++i;
	
		log.info ("{}, {} pop/s",i, i/w.stop);
	
		// Close the queue
		q.close();
	}
	
	void push_stuff(Queue q)
	{
		q.push ("one");
		q.push ("two");
		q.push ("three");
		q.push ("four");
		q.push ("five");
		q.push ("six");
		q.push ("seven");
		q.push ("eight");
		q.push ("nine");
		q.push ("ten");
	}
	
	---

*******************************************************************************/

module io.device.model.IConduitQueue;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.io.device.model.IPersistQueue;

private import tango.util.log.model.ILogger;

private import tango.util.log.Log;

private import swarm.queue.model.IChannel;

private import tango.io.device.Conduit;

private import tango.io.FilePath, tango.io.device.File;

private import tango.util.log.Trace;

private import Integer = tango.text.convert.Integer;

private import Float = tango.text.convert.Float;

private import tango.core.Thread;



/*******************************************************************************

	Version for checking memory usage of various operations.

*******************************************************************************/

//version = MemCheck;

version ( MemCheck )
{
	private import ocean.util.Profiler;
}



/*******************************************************************************

	ConduitQueue abstract template class.
	Implements the Queue interface.
	
	Template parameter C = Conduit type

*******************************************************************************/

deprecated abstract class ConduitQueue ( C ) : PersistQueue
{
	debug const CHECK_MAX_ITEM_SIZE = 1024 * 1024;

	/***************************************************************************
	
	    Make sure the template parameter C is a type derived from Conduit
	
	***************************************************************************/

	static assert ( is(C : Conduit), "use Conduit not '" ~ C.stringof ~ "'" );


	/***************************************************************************
	 
	    Message Header
	
	***************************************************************************/
	
	public struct Header                // 16 bytes
	{
	    uint    size,                   // size of the current chunk
	            prior;                  // size of the prior chunk
	    ushort  check;                  // simpe header checksum
	    ubyte   pad;                    // how much padding applied?
	    byte[5] unused;                 // future use
	
	
	    /***********************************************************************
	    
		    Initialises the header object, given the previous header and the
		    data which is to be written in this chunk. The header is padded out
		    to a 4 byte boundary, so all the headers in the queue are aligned.
	
		    Params:
		    	prior = the header of the previous message in the queue
		    	data = the data to be written in the message
		        
		***********************************************************************/
	
	    void init ( ref Header prior, ref void[] data )
	    {
	        // pad the output to 4 byte boundary, so that each header is aligned
	    	this.prior = prior.size;
	    	this.size  = ((data.length + 3) / 4) * 4;
	    	this.pad   = cast(ubyte) (this.size - data.length);
	    	this.calcChecksum();
	    }
	
	
	    /***********************************************************************
	    
		    Calculates the checksum for the header.
		        
		***********************************************************************/
	
	    void calcChecksum ( )
	    {
	    	this.check = checksum(*this);
	    }
	
	
	    /***********************************************************************
	    
		    Writes the header to Trace.
		    
		    Params:
		    	pre = message to print before the header
		        
		***********************************************************************/
	
	    void trace ( char[] pre )
	    {
	    	Trace.formatln("{} = [size:{}, priorsize:{}, check:{}, pad:{}]",
	    			pre, this.size, this.prior, this.check, this.pad);
	    }
	
	
	    /***********************************************************************
	    
		    Static method: Creates a checksum for a header.
		        
		***********************************************************************/
		
		static ushort checksum ( ref Header hdr )
		{
	        uint i = hdr.pad;
	        
	        i = i ^ hdr.size  ^ (hdr.size >> 16);
	        i = i ^ hdr.prior ^ (hdr.prior >> 16);
	        
	        return cast(ushort) i;
		}
	}
	
	
	/***************************************************************************
	
	    The Header struct should definitely be 16 bytes in size
	
	***************************************************************************/
	
	static assert(Header.sizeof == 16);
	
	
	/***************************************************************************
	
		The Conduit object which the queue is based on.
	
	***************************************************************************/
	
	protected C conduit;
	
	
	/***************************************************************************

	    Queue Implementation

	***************************************************************************/

	protected void[]	buffer;         // read buffer
	protected Header	current;        // top-of-stack info

	protected static const uint BUFFER_SIZE = 8 * 1024; // default read buffer size


	/***************************************************************************
	
	    Constructor
	
		Params:
	    	name = name of queue (for logging)
	    	max = max queue size (bytes)

	    Note: the name parameter may be used be derived classes to denote a file
	    name, ip address, etc.

	***************************************************************************/

	public this ( char[] name, uint max )
	{
		super(name, max);
	    this.buffer = new void [this.BUFFER_SIZE];
	}


	/***************************************************************************
	
	    Closes the queue's conduit.
	
	***************************************************************************/
	
	public void close ( )
	{
		if ( this.conduit )
		{
			this.conduit.detach();
			delete this.conduit;
			this.conduit = null;
		}
	}


	/***************************************************************************
	
	    Gets queue's conduit.
	
	***************************************************************************/
	
	public Conduit getConduit()
	{
		return this.conduit;
	}


	/***************************************************************************
	
		Pushes an item to the rear of the queue.
	
		Params:
			data = the item to be written
			
	***************************************************************************/

	protected void pushItem ( void[] data )
	{
		debug assert(data.length < CHECK_MAX_ITEM_SIZE);

	    // create a Header struct for the new data to be written
	    Header chunk = void;
	    chunk.init(this.current, data);

	    this.conduit.seek(this.write_to);
	    this.write(&chunk, Header.sizeof); // write queue message header
	    this.write(data.ptr, chunk.size); // write data
	
	    // update refs
	    this.write_to = this.write_to + Header.sizeof + chunk.size;
	    this.current = chunk;
	    ++this.items;
	
	    // insert an empty record at the new insert position
	    this.eof();
	}


	/***************************************************************************
	
		Pops an item from the front of the queue.
		If any items remain in the queue after the item is popped, the header of
		the next item in line to be read is updated to be the new front of the
		queue.
		
		Returns:
			the item retrieved from the queue, or null if the queue is empty.
	        
	***************************************************************************/

	protected void[] popItem ( )
	{
		void[] ret = null;
		Header chunk;

		if ( this.write_to )
	    {
	       if ( this.read_from < this.write_to )
	       {
	    	   // seek to front position of queue
	    	   this.conduit.seek(this.read_from);
	
	           // reading header & data of chunk (queue front)
	           this.read(&chunk, Header.sizeof);
	           ret = this.readItem(chunk);

	           debug assert(ret.length < CHECK_MAX_ITEM_SIZE);

	           --this.items;

	           if ( this.items > 0 )
	           {
	        	   // updating front seek position to next chunk
	               this.read_from += Header.sizeof + chunk.size;
	
	               // update next chunk prior size to zero
	               this.setHeaderPriorSize(this.read_from, 0);
	           }
	           else
	           {
	        	   this.reset();
	           }
	       }
	       else
	       {
	    	   this.reset();
	       }
	    }

	    return ret;
	}


	/***************************************************************************
	
	    Remaps the queue conduit. If the insert position reaches the end of the
	    conduit and the first chunk at the queue's front is not at seek position
	    0 we can potentially remap the conduit from size = [first..insert] to
	    [0..size].
	    
	    Remapping is only performed if the queue's read position is > 1/4 of the
	    way through the queue. (Otherwise the situation can arise that a full
	    queue is remapped after every read.)
	
	***************************************************************************/

	protected void cleanupQueue ( )
	{
	    uint bytes_read, bytes_written;
	    long offset;
	    this.logSeekPositions("Old seek positions");

	    auto input = this.conduit.input;
	    auto output = this.conduit.output;
	    
	    long total_bytes_read;

	    while ( (this.read_from + offset) < this.write_to && bytes_read !is conduit.Eof)
	    {
	        // seek to read position
	    	this.conduit.seek(this.read_from + offset);

	    	uint bytes_to_read = this.BUFFER_SIZE;
	    	if ( this.read_from + offset + bytes_to_read > this.write_to )
	    	{
	    		bytes_to_read = this.write_to - (this.read_from + offset);
	    	}
	    	this.buffer.length = bytes_to_read;
	    	bytes_read = input.read(this.buffer);
	        
	        if ( bytes_read !is conduit.Eof )
	        {
		    	total_bytes_read += bytes_read;

		    	// seek to write position
	        	this.conduit.seek(offset);
	        	bytes_written = output.write(this.buffer[0..bytes_read]);
	
	        	offset += bytes_read;
	        }
	    }
	    
	    this.write_to -= this.read_from;
	    this.read_from = 0;
	
	    // insert an empty record at the new insert position
	    this.eof();
	
	    this.logSeekPositions("Remapping done, new seek positions");
	}


	/***************************************************************************

		Calculates the amount of space a given data buffer would take up if
		pushed into the queue.
		
		The space requirement is equal to the length of the data, plus the
		length of its header (which is constant), plus the length of the null
		header which is written after every item to show where the end of the
		queue is.
		
		Returns:
			bytes size
	        
	***************************************************************************/
	
	protected uint pushSize ( void[] data )
	{
		return Header.sizeof + data.length + Header.sizeof;
	}
	

	/***************************************************************************
	
		Reads a chunk header at the given seek position, updates the 'prior'
		member, and rewrites it in situ.
		
		Params:
			seek_pos = position in Conduit to read and write Header struct
			prior_size = new value for Header's prior member
	
	***************************************************************************/

	protected void setHeaderPriorSize(long seek_pos, uint prior_size)
	{
		Header chunk = void;
	
		this.conduit.seek(seek_pos);
	    this.read(&chunk, Header.sizeof);
	
	    chunk.prior = 0;
	    chunk.calcChecksum();
	
	    this.conduit.seek(seek_pos);
	    this.write(&chunk, Header.sizeof);
	}


	/***************************************************************************
	
		Sets the read and write pointers to 0.
	
	***************************************************************************/
	
	override protected void reset ( )
	{
		super.reset();
	
	    // insert an empty record at the new insert position
	    this.eof();
	}


	/***************************************************************************
	        
	    Reads message content from the queue, at the conduit's current seek
	    position,  into the 'buffer' member.
	    
	    Params:
	    	hdr = header describing the message to be read
	    	pad = bytes of padding
	
	    Returns:
	    	the content that has been read
	
	***************************************************************************/
	
	protected void[] readItem ( ref Header hdr)
	{
		auto len = hdr.size - hdr.pad;
//Trace.formatln("   ConduitQueue.readItem {}bytes", len);
	
	    // make buffer big enough
	    if ( this.buffer.length < len )
	    {
	    	this.buffer.length = len;
	    }
	    this.read(this.buffer.ptr, len);
	    
	    return this.buffer[0 .. len];
	}


	/***************************************************************************
	
	    Reads data from the queue, at the conduit's current seek position, into
	    the passed data buffer.
	    
	    Params:
	    	data = buffer to read into
	    	len = number of bytes to read
	    
	    Throws:
	    	if the end of the conduit is passed while reading
	        
	***************************************************************************/

	protected void read ( void* data, uint len )
	{
		debug assert(len < CHECK_MAX_ITEM_SIZE);

		scope ( failure )
		{
			Trace.formatln("Read error, trying to read {} bytes", len);
		}

		auto input = this.conduit.input;
	
	    for ( uint i; len > 0; len -= i, data += i )
	    {
	         if ( (i = input.read(data[0..len])) is conduit.Eof )
	         {
	        	 this.conduit.error("QueueConduit.read :: Eof while reading");
	         }
	    }
	}
	
	
	/***************************************************************************

	    Writes data to the queue at the conduit's current seek position.
	    
	    Params:
	    	data = data to write
	    	len = number of bytes to write
	
		Throws:
	    	if the end of the conduit is passed while writing
	
	***************************************************************************/
	
	protected void write ( void* data, uint len )
	{
		debug assert(len < CHECK_MAX_ITEM_SIZE,"Element length > max size");

		scope ( failure )
		{
			debug Trace.formatln("Write error, trying to write {} bytes", len);
		}

		auto output = this.conduit.output;

	    for ( uint i; len > 0; len -= i, data += i )
	    {
	    	uint written = output.write(data[0..len]);
	    	i = written;
	        if ( written is conduit.Eof )
	        {
	        	this.log("QueueConduit.write :: Eof while writing: {}:\n{}", len, (cast(char*)data)[0..len]);
	        	this.conduit.error("QueueConduit.write :: Eof while writing");
	        }
	    }
	}
	
	
	/***************************************************************************
	
		Writes a blank header at the write position, to indicate Eof.
	
	    The insert position is not advanced, so new items are written over the
	    blank header.
	
	***************************************************************************/
	
	protected void eof ( )
	{
	    Header zero;
	    this.conduit.seek(this.write_to);
	    write(&zero, Header.sizeof);
	}


	/***************************************************************************
	
		Copies the contents of the queue to the passed conduit.
		
		Params:
			conduit = conduit to write to
	
	***************************************************************************/

	protected void writeToConduit ( Conduit conduit )
	{
		this.conduit.seek(0);
		conduit.copy(this.conduit);
	}


	/***************************************************************************
	
		Copies the contents of the queue from the passed conduit.
		
		Params:
			conduit = conduit to read from
	
	***************************************************************************/

	protected void readFromConduit ( Conduit conduit )
	{
		this.conduit.seek(0);
		this.conduit.copy(conduit);
	}


	/***************************************************************************

		Outputs a summary of the queue's contents to Trace. The queue is
		properly iterated through, and the number of items found is counted.
		The number of items found is compared with the queue's idea of how many
		items it contains, so errors can be detected.
		
		Params:
			message = message to be printed first
			show_contents_size = lists the size of each item (as told by its
			header) - WARNING: only send true to this argument for very small
			queues!
		
	***************************************************************************/

	synchronized public void validateContents ( bool show_summary, char[] message = "", bool show_contents_size = false )
	{
		scope ( failure )
		{
			Trace.formatln("ConduitQueue.validateContents - EXCEPTION OCCURRED");

			// Wait
			Thread.sleep(2);
		}

		if ( show_summary )
		{
			Trace.format("{}: {}: ", this.name, message);
		}
		uint count = 0;
		long seek_pos = this.read_from;
		Header header;
		do
		{
			if ( seek_pos < this.dimension )
			{
				this.conduit.seek(seek_pos);

				this.read(&header, Header.sizeof);

				if ( show_contents_size )
				{
					if ( show_summary )
					{
						Trace.format("{} ", header.size);
					}
//					auto content = this.readItem(header);
				}
				debug assert(header.size < CHECK_MAX_ITEM_SIZE);

				seek_pos += Header.sizeof + header.size;
	
				count ++;
			}
			else
			{
				Trace.format("CORRUPT: seek pos > end");
				break;
			}
		} while ( header.size > 0 );

		if ( show_summary )
		{
			bool valid = count - 1 == this.items;
			Trace.formatln("({}) - ({}) ({} bytes free){}", count - 1, this.items, this.dimension - this.write_to,
					valid ? "" : " # OF ITEMS INVALID");
		}
	}
}

