/*******************************************************************************

    copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release

    author:         Kris Bell / Thomas Nicolai / Gavin Norman

	ConduitQueue implements the Queue interface. It implements a FIFO queue to
	push and pop a large quantity of data to a Conduit. Each item in the queue
	consists of the data itself and an automatically generated message header.

	ConduitQueue is a template class over a Conduit object as the underlying
	storage medium for the queue. In this way multiple types of queue can be
	implemented, using a variety of Conduits as storage media.
	
	It is assumed that the Conduit underlying the queue is of a fixed size.

	Usage example, tests the derived classes QueueFile and QueueMemory:

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
	//	auto q = new QueueFile ("test_file_queue", 256 * 1024 * 1024);
		auto q = new QueueMemory ("test_memory_queue", 256 * 1024 * 1024);
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

private import ocean.io.device.model.IQueue,
	ocean.io.device.model.ISerializable,
	ocean.io.device.model.ILoggable;

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

abstract class ConduitQueue ( C ) : Queue, Serializable, Loggable
{
	debug const CHECK_MAX_ITEM_SIZE = 1024 * 1024;
	
	/***************************************************************************
	
	    Make sure the template parameter C is a type derived from Conduit
	
	***************************************************************************/

	static assert ( is(C : Conduit), "use Conduit not '" ~ C.stringof ~ "'" );

	
	/***************************************************************************
	
	    Abstract method: Opens the queue given an identifying name. Should
	    create the conduit member. This method is called by the ConduitQueue
	    constructor.
	
	***************************************************************************/
	
	abstract public void open ( char[] name );

	
	/***************************************************************************

	    Abstract method: Determines whether the queue is ready to be remapped.
	    Each deriving class should implement this method with a heuristic which
	    suits the Conduit which it is based in.
    
	***************************************************************************/

	abstract public bool isDirty ( );


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
	
	protected char[]	name;           // queue name (for logging)
	protected long		limit,          // max size (bytes)
	                    insert,         // rear insert position of queue (push)
	                    first,          // front position of queue (pop)
	                    items;          // number of items in the queue
	protected void[]	buffer;         // read buffer
	protected Header	current;        // top-of-stack info
	protected Logger	logger;            // logging target

	protected static const uint BUFFER_SIZE = 8 * 1024; // default read buffer size

	protected bool allow_push_pop = true; // enable / disable push & pop operations 


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
		this.setName(name);
	    this.limit = max;
	    this.buffer = new void [this.BUFFER_SIZE];
	    this.open(name);
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

		Sets the logger output object.
	
	    Params:
	    	logger = logger instance
	
	***************************************************************************/
	
	public void attachLogger ( Logger logger )
	{
		this.logger = logger;
	}


	/***************************************************************************
	
	    Gets the logger object associated with the queue.
	
	***************************************************************************/

	public Logger getLogger ( )
	{
		return this.logger;
	}


	/***************************************************************************

		Sends a message to the queue's logger.
	
	    Params:
	    	fmt = format string
	    	... = 

	***************************************************************************/

	public void log ( char[] fmt, ... )
	{
		if ( this.logger )
		{
			this.logger.format(ILogger.Level.Trace, fmt, _arguments, _argptr);
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
	
	    Sets the queue's name.
	
	***************************************************************************/
	
	public void setName ( char[] name )
	{
		this.name = name;
	}


	/***************************************************************************
	
	    Gets the queue's name.
	
	***************************************************************************/
	
	public char[] getName ( )
	{
		return this.name;
	}
	
	
	/**********************************************************************
	
	    Returns number of items in the queue
	
	**********************************************************************/
	
	public uint size ( )
	{
		return this.items;
	}


	/***************************************************************************

		Determines whether a given data buffer will fit if pushed onto the
		queue at the insert position.
		
		Returns:
			true if item will fit
	        
	***************************************************************************/
	
	public bool willFit ( void[] data )
	{
		return this.pushSize(data) < this.freeSpace();
	}
	
	
	/***************************************************************************
	
		Gets the amount of free space at the end of the queue.
		
		Returns:
			bytes free in queue
	        
	***************************************************************************/
	
	public uint freeSpace ( )
	{
		return this.limit - this.insert;
	}
	

	/**********************************************************************
	
	    Returns true if queue is full (write position >= end of queue)

		TODO: change to > 99% full? or < 1K free?
		
	**********************************************************************/
	
	public bool isFull ( )
	{
		return this.insert >= this.limit;
	}


	/**********************************************************************
	
	    Returns true if queue is empty
	
	**********************************************************************/
	
	public bool isEmpty ( )
	{
		return this.items == 0;
	}


	/***************************************************************************
	
		Pushes an item to the rear of the queue.
	
		Params:
			data = the item to be written
			
		Returns:
			true if the item was pushed successfully, false otherwise
		
		Throws:
			if the data to be pushed is 0 length
	
	***************************************************************************/

	public synchronized bool push ( void[] data )
	{
		debug assert(data.length < CHECK_MAX_ITEM_SIZE);

		version ( MemCheck ) auto before = MemProfiler.checkUsage();

		if(!this.allow_push_pop) return false;

		if ( data.length is 0 )
	    {
			this.conduit.error("invalid zero length content");
	    }

	    // check if queue is full and try to remap queue
		if ( !this.willFit(data) )
	    {
	        if ( !this.remap() )
	        {
	            this.log("queue '{}' full with {} items", this.name, this.items);
	            return false;
	        }
	    }

		if ( this.willFit(data) )
	    {
		    // create a Header struct for the new data to be written
		    Header chunk = void;
		    chunk.init(this.current, data);

		    this.conduit.seek(this.insert);
		    this.write(&chunk, Header.sizeof); // write queue message header
		    this.write(data.ptr, chunk.size); // write data
		
		    // update refs
		    this.insert = this.insert + Header.sizeof + chunk.size;
		    this.current = chunk;
		    ++this.items;
		
		    // insert an empty record at the new insert position
		    this.eof();
	    }

		version ( MemCheck ) MemProfiler.checkSectionUsage("push", before, MemProfiler.Expect.NoChange);

		return true;
	}

	/***************************************************************************
	
		Pops an item from the front of the queue.
		If any items remain in the queue after the item is popped, the header of
		the next item in line to be read is updated to be the new front of the
		queue.
		
		Returns:
			the item retrieved from the queue, or null if the queue is empty.
	        
	***************************************************************************/

	public synchronized void[] pop ( )
	{
		if(!this.allow_push_pop) return null;

		version ( MemCheck ) auto before = MemProfiler.checkUsage();

		Header chunk;
	    if ( this.insert )
	    {
	       if ( this.first < this.insert )
	       {
	    	   // seek to front position of queue
	    	   this.conduit.seek(this.first);
	
	           // reading header & data of chunk (queue front)
	           this.read(&chunk, Header.sizeof);
	           auto content = this.readItem(chunk);

	           debug assert(content.length < CHECK_MAX_ITEM_SIZE);

	           if ( this.items > 1 )
	           {
	        	   // updating front seek position to next chunk
	               this.first += Header.sizeof + chunk.size;
	
	               // update next chunk prior size to zero
	               this.setHeaderPriorSize(this.first, 0);
	           }
	           else if ( this.items == 1 )
	           {
	        	   this.reset();
	           }
	
	           --items;

	           return content;
	       }
	       else
	       {
	    	   this.reset();
	       }
	    }

	    version ( MemCheck ) MemProfiler.checkSectionUsage("pop", before, MemProfiler.Expect.NoChange);

	    return cast(void[])"";
	}


	/***************************************************************************

	    Removes all entries from the queue.
	
	***************************************************************************/

	public void flush ( )
	{
		this.insert = 0;
		this.first = 0;
		this.items = 0;
		this.eof();
	}


	/***************************************************************************
	
	    Remaps the queue conduit. If the insert position reaches the end of the
	    conduit and the first chunk at the queue's front is not at seek position
	    0 we can potentially remap the conduit from size = [first..insert] to
	    [0..size].
	    
	    Remapping is only performed if the queue's read position is > 1/4 of the
	    way through the queue. (Otherwise the situation can arise that a full
	    queue is remapped after every read.)
	
	    Returns:
	    	true if remap could free some file space.
	        
	***************************************************************************/

	synchronized public bool remap ( )
	{
		version ( MemCheck ) auto before = MemProfiler.checkUsage();

		this.log("Thinking about remapping queue '" ~ name ~ "'");

	    uint bytes_read, bytes_written;
	    long offset;
		if ( !this.isDirty() )
		{
			return false;
		}
	    this.logSeekPositions("Old seek positions");
	            
	    auto input = this.conduit.input;
	    auto output = this.conduit.output;
	    
	    long total_bytes_read;

	    while ( (this.first + offset) < this.insert && bytes_read !is conduit.Eof)
	    {
	        // seek to read position
	    	this.conduit.seek(this.first + offset);

	    	uint bytes_to_read = this.BUFFER_SIZE;
	    	if ( this.first + offset + bytes_to_read > this.insert )
	    	{
	    		bytes_to_read = this.insert - (this.first + offset);
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
	    
	    this.insert -= this.first;
	    this.first = 0;
	
	    // insert an empty record at the new insert position
	    this.eof();
	
	    this.logSeekPositions("Remapping done, new seek positions");

	    version ( MemCheck ) MemProfiler.checkSectionUsage("remap", before, MemProfiler.Expect.NoChange);

		return true;
	}


	/***************************************************************************

		Sets the allow_push_pop flag to false, which will deactivate any push
		or pop operations which happen from now on.
		
		This function can be used if you want to shut down the queue at a
		certain point and be sure that no other threads will subsequently read
		from or write to the queue.

	***************************************************************************/

	public synchronized void stopIO ( )
	{
		this.allow_push_pop = false;
	}


	/***************************************************************************

		Writes the queue's state and contents to a file with the queue's name
		+ ".dump".
	
		If the file already exists it is overwritten.
	
	***************************************************************************/

	public synchronized void dumpToFile ( )
	{
		this.log("Writing to file " ~ this.name ~ ".dump");
		scope fp = new FilePath(this.name ~ ".dump");
		if ( fp.exists() )
		{
			this.log("(File exists, deleting)");
			fp.remove();
		}
	
		scope file = new File(this.name ~ ".dump", File.WriteCreate);
		this.serialize(file);
		file.close();
	}


	/***************************************************************************
	
	    Reads the queue's state and contents from a file.
	
	***************************************************************************/
	
	public synchronized void readFromFile ( )
	{
		this.log("Loading from file {}", this.name ~ ".dump");
		scope fp = new FilePath(this.name ~ ".dump");
		if ( fp.exists() )
		{
			this.log("(File exists, loading)");
			scope file = new File(this.name ~ ".dump", File.ReadExisting);
	
			this.deserialize(file);
			file.close();
		}
		else
		{
			this.log("(File doesn't exist)");
		}
	}
	
	
	/***************************************************************************
	
		Writes the queue's state and contents to the given conduit.
		
		Params:
			conduit = conduit to write to
	
	***************************************************************************/
	
	public void serialize ( Conduit conduit )
	{
		this.writeState(conduit);
		this.conduit.seek(0);
		conduit.copy(this.conduit);
	}
	
	
	/***************************************************************************
	
	    Reads the queue's state and contents from the given conduit.
	    For compatibility with any sort of Conduit, does not check that the size
	    of the data in the conduit will actually fit in the queue. The conduit
	    copy method will assert if it doesn't though.
	
		Params:
			conduit = conduit to read from
	
	***************************************************************************/
	
	public void deserialize ( Conduit conduit )
	{
		this.readState(conduit);
		this.conduit.seek(0);
		this.conduit.copy(conduit);
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
	
	protected void reset ( )
	{
		this.first = 0;
		this.insert = 0;
	
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
		debug assert(len < CHECK_MAX_ITEM_SIZE);

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
	    this.conduit.seek(this.insert);
	    write(&zero, Header.sizeof);
	}


	/***************************************************************************
	
		Enum defining the order in which the queue's state longs are written to
		/ read from a file.
	
	***************************************************************************/
	
	protected enum StateSerializeOrder
	{
		limit = 0,
		insert,
		first,
		items
	}
	
	
	/***************************************************************************
	
		Writes the queue's state to a conduit. The queue's name is written,
		followed by an array of longs describing its state.
	
		Params:
			conduit = conduit to write to
		
		Returns:
			number of bytes written
	
	***************************************************************************/
	
	protected synchronized long writeState ( Conduit conduit )
	{
		long[StateSerializeOrder.max + 1] longs;
		
		longs[StateSerializeOrder.limit] = this.limit;
		longs[StateSerializeOrder.insert] = this.insert;
		longs[StateSerializeOrder.first] = this.first;
		longs[StateSerializeOrder.items] = this.items;
	
		long bytes_written = conduit.write(cast(void[]) this.name);
		bytes_written += conduit.write(cast(void[]) longs);
		return bytes_written;
	}
	
	
	/***************************************************************************
	
		Reads the queue's state from a conduit. The queue's name is read,
		followed by an array of longs describing its state.
		
		Params:
			conduit = conduit to read from
		
		Returns:
			number of bytes read
	
	***************************************************************************/
	
	protected synchronized long readState ( Conduit conduit )
	{
		long[StateSerializeOrder.max + 1] longs;
	
		long bytes_read = conduit.read(cast(void[]) this.name);
		bytes_read += conduit.read(cast(void[]) longs);
		
		this.limit = longs[StateSerializeOrder.limit];
		this.insert = longs[StateSerializeOrder.insert];
		this.first = longs[StateSerializeOrder.first];
		this.items = longs[StateSerializeOrder.items];
	
		return bytes_read;
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

	synchronized public void traceContents ( char[] message = "", bool show_contents_size = false )
	{
		this.validateContents(true, message, show_contents_size);
	}


	synchronized public void validateContents ( bool show_summary, char[] message = "", bool show_contents_size = false )
	{
		scope ( failure )
		{
			Trace.formatln("EXCEPTION OCCURRED");

			// Wait
			Thread.sleep(2);
		}

		if ( show_summary )
		{
			Trace.format("{}: {}: ", this.name, message);
		}
		uint count = 0;
		long seek_pos = this.first;
		Header header;
		do
		{
			if ( seek_pos < this.limit )
			{
				this.conduit.seek(seek_pos);

				this.read(&header, Header.sizeof);

				debug assert(header.size < CHECK_MAX_ITEM_SIZE);
				if ( show_contents_size )
				{
					if ( show_summary )
					{
						Trace.format("{} ", header.size);
					}
//					auto content = this.readItem(header);
				}

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
			Trace.formatln("({}) - ({}) ({} bytes free){}", count - 1, this.items, this.limit - this.insert,
					valid ? "" : " # OF ITEMS INVALID");
		}
	}

	
	/***************************************************************************
	
		Outputs the queue's current seek positions to the log.
	
		If compiled as the QueueTrace version, also outputs a message to Trace.
	
		Params:
			str = message to prepend to seek positions output 
	
	***************************************************************************/

	public void logSeekPositions ( char[] str = "" )
	{
	    this.log("{} [ front = {} rear = {} ]", str, this.first, this.insert);
	}


	/***********************************************************************

		Format a string with the queue's current start and end seek
		positions.

		Params:
			buf = string buffer to be written into
			show_pcnt = show seek positions as a % o the queue's total size
			nl = write a newline after the seek positions info

	***********************************************************************/

	protected char[] format_buf;

	public void formatSeekPositions ( ref char[] buf, bool show_pcnt, bool nl = true )
	{
		version ( MemCheck ) auto before = MemProfiler.checkUsage();

		if ( show_pcnt )
		{
			double first_pcnt = 100.0 * (cast(double) this.first / cast(double) this.limit);
			double insert_pcnt = 100.0 * (cast(double) this.insert / cast(double) this.limit);

			this.format_buf.length = 20;
			buf ~= "[" ~ Float.format(this.format_buf, first_pcnt) ~ "%..";
			this.format_buf.length = 20;
			buf ~= Float.format(this.format_buf, insert_pcnt) ~ "%]";
		}
		else
		{
			buf ~= "[" ~ Integer.format(this.format_buf, this.first) ~ ".."
				~ Integer.format(this.format_buf, this.insert) ~ " / "~ Integer.format(this.format_buf, this.limit) ~ "]";
		}

		if ( this.isFull() )
		{
			buf ~= "F";
		}

		if ( this.isDirty() )
		{
			buf ~= "D";
		}

		if ( nl )
		{
			buf ~= "\n";
		}

		version ( MemCheck ) MemProfiler.checkSectionUsage("format", before, MemProfiler.Expect.NoChange);
	}
}

