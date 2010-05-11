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

private import swarm.queue.model.IChannel;

private import tango.io.device.Conduit;

private import tango.io.FilePath, tango.io.device.File;



/*******************************************************************************

	QueueTrace version, adds extra debug trace capabilities to the queue.

*******************************************************************************/

version ( QueueTrace )
{
	private import tango.util.log.Trace;
	private import Integer = tango.text.convert.Integer;
	private import Float = tango.text.convert.Float;
}



/*******************************************************************************

	ConduitQueue abstract template class.
	Implements the Queue interface.
	
	Template parameter C = Conduit type

*******************************************************************************/

abstract class ConduitQueue ( C ) : Queue, Serializable, Loggable
{
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
	protected ILogger	logger;            // logging target
	
	
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
	    this.buffer = new void [1024 * 8];
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
	
	public void attachLogger ( ILogger logger )
	{
		this.logger = logger;
	}


	/***************************************************************************
	
	    Gets the logger object associated with the queue.
	
	***************************************************************************/

	public ILogger getLogger ( )
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
			this.logger.trace(fmt, _arguments, _argptr);
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


	/**********************************************************************
	
	    Returns queue status
	    
	    The queue is dirty if more than 50% of the front 
	    of the queue is wasted and not used.
	
	**********************************************************************/
	
	public bool isDirty ( )
	{
	    return (this.first > 0 && (this.limit / this.first) < 2);
	}


	/**********************************************************************
	
	    Returns true if queue is full (write position >= end of queue)
	
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
		if ( data.length is 0 )
	    {
			this.conduit.error("invalid zero length content");
	    }
	
	    // check if queue is full and try to remap queue
	    if ( this.insert > this.limit )
	    {
	        if ( !this.remap() )
	        {
	            this.log("queue '{}' full with {} items", this.name, this.items);
	            return false;
	        }
	    }
	
	    this.conduit.seek(this.insert);
	
	    // create a Header struct for the new data to be written
	    Header chunk = void;
	    chunk.init(this.current, data);
	
	    this.write(&chunk, Header.sizeof); // write queue message header
	    this.write(data.ptr, chunk.size); // write data
	
	    // update refs
	    this.insert = this.insert + Header.sizeof + chunk.size;
	    this.current = chunk;
	    ++this.items;
	
	    // insert an empty record at the new insert position
	    this.eof();
	
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
		Header chunk;
	
	    if ( this.insert )
	    {
	       if ( this.first < this.insert )
	       {
	           // seek to front position of queue
	    	   this.conduit.seek(this.first);
	
	           // reading header & data of chunk (queue front)
	           this.read(&chunk, Header.sizeof);
	           auto content = this.readItem(chunk, chunk.pad);
	
	           if ( this.items > 1 )
	           {
	        	   // updating front seek position to next chunk
	               this.first = this.first + Header.sizeof + chunk.size;
	
	               // update next chunk prior size to zero
	               this.setHeaderPriorSize(this.first, 0);
	           }
	           else if ( this.items == 1 )
	           {
	        	   this.reset();
	           }
	
	           this.conduit.seek(this.first);
	           --items;
	           
	           return content;
	       }
	       else
	       {
	           // no element left in queue (reset first and insert to zero)
	           insert = first = 0;
	       }
	    }
	    return null;
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
	
	public bool remap ( )
	{
	    this.log("Thinking about remapping queue '{}'", name);
	
	    uint i, pos;
		if ( this.first == 0 || this.first < this.limit / 4 )
		{
			return false;
		}
	
	    this.logSeekPositions("Old seek positions");
	            
	    auto input = this.conduit.input;
	    auto output = this.conduit.output;
	    
	    while ( (this.first + pos) < this.insert && i !is conduit.Eof)
	    {
	        // seek to read position
	    	this.conduit.seek(this.first + pos);
	        i = input.read(this.buffer);
	        
	        if ( i !is conduit.Eof )
	        {
	                // seek to write position
	        	this.conduit.seek(pos);
	        	output.write(this.buffer[0..i]);
	
	        	pos += i;
	        }
	    }
	    
	    this.insert -= first;
	    this.first = 0;
	
	    // insert an empty record at the new insert position
	    this.eof();
	
	    this.logSeekPositions("Remapping done, new seek positions");
	
	    return true;
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
	        
	    Reads message content from the queue into the 'buffer' member.
	    
	    Params:
	    	hdr = header describing the message to be read
	    	pad = bytes of padding
	
	    Returns:
	    	the content that has been read
	
	***************************************************************************/
	
	protected void[] readItem ( ref Header hdr, uint pad = 0 )
	{
		auto len = hdr.size - pad;
	
	    // make buffer big enough
	    if ( this.buffer.length < len )
	    {
	    	this.buffer.length = len;
	    }
	    this.read(this.buffer.ptr, len);
	    
	    return this.buffer[0 .. len];
	}


	/***************************************************************************
	
	    Reads data from the queue into the passed data buffer.
	    
	    Params:
	    	data = buffer to read into
	    	len = number of bytes to read
	    
	    Throws:
	    	if the end of the conduit is passed while reading
	        
	***************************************************************************/
	
	protected void read ( void* data, uint len )
	{
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
	        
	    Writes data to the queue.
	    
	    Params:
	    	data = data to write
	    	len = number of bytes to write
	
		Throws:
	    	if the end of the conduit is passed while writing
	
	***************************************************************************/
	
	protected void write ( void* data, uint len )
	{
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

		Writes the queue's state and contents to a file with the queue's name
		+ ".dump".
	
		If the file already exists it is overwritten.
	
	***************************************************************************/

	public void dumpToFile ( )
	{
		this.log("Writing to file {}", this.name ~ ".dump");
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
	
	public void readFromFile ( )
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
	
	public synchronized void serialize ( Conduit conduit )
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

	public synchronized void deserialize ( Conduit conduit )
	{
		this.readState(conduit);

		this.conduit.seek(0);
		this.conduit.copy(conduit);
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
	
		Outputs the queue's current seek positions to the log.
	
		If compiled as the QueueTrace version, also outputs a message to Trace.
	
		Params:
			str = message to prepend to seek positions output 
	
	***************************************************************************/

	version ( QueueTrace )
	{
		public void logSeekPositions ( char[] str = "" )
		{
	    	Trace.format("{} {} ", str, this.name);
	    	this.traceSeekPositions(false);
		    this.log("{} [ front = {} rear = {} ]", str, this.first, this.insert);
		}
	}
	else
	{
		public void logSeekPositions ( char[] str = "" )
		{
		    this.log("{} [ front = {} rear = {} ]", str, this.first, this.insert);
		}
	}
		

	version ( QueueTrace )
	{
		/***********************************************************************
	
			Internal character buffer, used repeatedly for string formatting
	
	    ***********************************************************************/
	
		protected char[] trace_buf;
	
		
		/***********************************************************************
	
			Prints the queue's current seek positions to Trace.
	
			Params:
				show_pcnt = show seek positions as a % o the queue's total size
				nl = output a newline after the seek positions info
	
		***********************************************************************/
	
		public void traceSeekPositions ( bool show_pcnt, bool nl = true )
		{
			this.trace_buf = "";
			this.formatSeekPositions(this.trace_buf, show_pcnt, nl);
			Trace.format(this.trace_buf).flush;
		}
		
	
		/***********************************************************************
	
			Format a string with the queue's current start and end seek
			positions.
	
			Params:
				buf = string buffer to be written into
				show_pcnt = show seek positions as a % o the queue's total size
				nl = write a newline after the seek positions info
	
		***********************************************************************/
	
		public void formatSeekPositions ( ref char[] buf, bool show_pcnt, bool nl = true )
		{
			if ( show_pcnt )
			{
				float first_pcnt = 100.0 * (cast(float) this.first / cast(float) this.limit);
				float insert_pcnt = 100.0 * (cast(float) this.insert / cast(float) this.limit);
	
				buf ~= "[" ~ Float.toString(first_pcnt) ~ "%.." ~ Float.toString(insert_pcnt) ~ "%]";
			}
			else
			{
				buf ~= "[" ~ Integer.toString(this.first) ~ ".." ~ Integer.toString(this.insert) ~ "]";
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
		}
	}
}

