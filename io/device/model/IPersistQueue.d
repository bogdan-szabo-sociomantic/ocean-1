/*******************************************************************************

    copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release

    author:         Kris Bell / Thomas Nicolai / Gavin Norman

	PersistQueue is an abstract base class for a fixed-size serializable FIFO
	queue.

	See ocean.io.device.QueueFile and ocean.io.device.QueueMemory for
	implementations of this class.
	
*******************************************************************************/

module io.device.model.IPersistQueue;


/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.io.device.model.IQueue,
				ocean.io.device.model.ISerializable,
				ocean.io.device.model.ILoggable;

private import tango.io.device.Conduit;

private import tango.util.log.model.ILogger;

private import tango.util.log.Log;

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

	Persist queue class

*******************************************************************************/

abstract class PersistQueue : Queue, Serializable, Loggable
{
	/***************************************************************************
	
	    Abstract method: Opens the queue given an identifying name. Should
	    create any data containers needed. This method is called by the
	    PersistQueue constructor.
	
	***************************************************************************/
	
	abstract public void open ( char[] name );


	/***************************************************************************

		Abstract method: Pushes a single item to the queue. This method should
		not do any kind of checking whether the item will fit, this is done
		previously by the push method (below).

	***************************************************************************/

	abstract protected void pushItem ( void[] item );


	/***************************************************************************

		Abstract method: Pops a single item from the queue. This method should
		not do any kind of checking whether there are items to pop, this is done
		previously by the pop method (below).

	***************************************************************************/

	abstract protected void[] popItem ( );


	/***************************************************************************
	
	    Abstract method: Performs any cleanup operations needed for the queue's
	    continual functioning. This method does not need to check whether the
	    cleanup is required, this is done previously by the cleanup method
	    (below).
	
	***************************************************************************/

	abstract protected void cleanupQueue ( );


	/***************************************************************************
	
	    Abstract method: Determines whether the queue is in need of cleanup.
	    Each deriving class should implement this method with a heuristic which
	    suits the data container which it is based on.
	
	***************************************************************************/
	
	abstract public bool isDirty ( );


	/***************************************************************************
	
	    Abstract method: Calculates the size (in bytes) an item would take if it
	    were pushed to the queue. This value should include any header data
	    required.

	***************************************************************************/

	abstract public uint pushSize ( void[] data );


	/***************************************************************************

		Abstract method: Writes the contents of the queue to the passed conduit.

	***************************************************************************/

	abstract protected void writeToConduit ( Conduit conduit );


	/***************************************************************************

		Abstract method: Reads the contents of the queue from the passed conduit.
	
	***************************************************************************/

	abstract protected void readFromConduit ( Conduit conduit );


	/***************************************************************************
	
	    Abstract method: Debug method to validate the queue's contents.
	
	***************************************************************************/

	debug abstract public void validateContents
		( bool show_summary, char[] message = "", bool show_contents_size = false );


	/***************************************************************************
	
	    Queue Implementation
	
	***************************************************************************/

	protected char[]	name;           // queue name (for logging)
	protected long		dimension,      // max size (bytes)
	                    write_to,       // rear insert position of queue (push)
	                    read_from,      // front position of queue (pop)
	                    items;          // number of items in the queue

	protected Logger	logger;         // logging target

	protected char[] format_buf;		// buffer used for seek position formatting


	/***************************************************************************
	
	    Constructor.
	    
	    Sets the queue's name and dimension.
	    
	    Params:
	    	name = queue's name
	    	max = dimension of queue (bytes)
	
	***************************************************************************/

	public this ( char[] name, uint max )
	{
		this.setName(name);
	    this.dimension = max;
		this.open(name);
	}


	/***************************************************************************

		Pushes an item to the queue. The item is checked for valid length (>0),
		and the queue checks if the item will fit. If there's not enough space
		available the cleanup method is called in an attempt to make more space.
		The push is then retried.
	    
	    Params:
	    	item = item to be pushed
	
		Returns:
			true if the item was pushed to the queue

		Throws:
			asserts if the data to be pushed is 0 length
			
	***************************************************************************/

	public bool push ( void[] item )
	in
	{
		assert(item.length !is 0, "PersistQueue.push - attempted to push zero length content");
	}
	body
	{
		scope ( exit )
		{
			version ( MemCheck ) MemProfiler.checkSectionUsage("push", before, MemProfiler.Expect.NoChange);
		}

		version ( MemCheck ) auto before = MemProfiler.checkUsage();

	    // check if the item will fit, and if it won't fit then cleanup and try again
		if ( !this.willFit(item) )
	    {
	        if ( !this.cleanup() || !this.willFit(item) )
	        {
	            this.log("queue '{}' full with {} items", this.name, this.items);
	            return false;
	        }
	    }

		// Store item in queue
		synchronized ( this )
		{
			this.pushItem(item);
			return true;
		}
	}


	/***************************************************************************

		Pops an item from the queue.
	    
		Returns:
			the item popped, or null if the queue is empty
	
	***************************************************************************/

	synchronized public void[] pop ( )
	{
		scope ( exit)
		{
			version ( MemCheck ) MemProfiler.checkSectionUsage("pop", before, MemProfiler.Expect.NoChange);
		}

		version ( MemCheck ) auto before = MemProfiler.checkUsage();

		if ( this.items == 0 )
		{
			return null;
		}

		synchronized ( this )
		{
			return this.popItem();
		}
	}


	/***************************************************************************
	
		Cleans up the queue, if it's dirty.
		
		Returns:
			true if cleanupQueue was called, false otherwise
	
	***************************************************************************/
	
	public bool cleanup ( )
	{
		scope ( exit )
		{
		    version ( MemCheck ) MemProfiler.checkSectionUsage("cleanup", before, MemProfiler.Expect.NoChange);
		}

		version ( MemCheck ) auto before = MemProfiler.checkUsage();

		if ( !this.isDirty() )
		{
			return false;
		}

		synchronized ( this )
		{
			this.cleanupQueue();
			return true;
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
		return this.dimension - this.write_to;
	}
	
	
	/***************************************************************************
	
		Gets the amount of data stored in the queue.
		
		Returns:
			bytes stored in queue
	        
	***************************************************************************/
	
	public uint usedSpace ( )
	{
		return this.write_to - this.read_from;
	}
	

	/**********************************************************************
	
	    Returns true if queue is full (write position >= end of queue)
	
		TODO: change to > 99% full? or < 1K free?
		
	**********************************************************************/
	
	public bool isFull ( )
	{
		return this.write_to >= this.dimension;
	}
	
	
	/**********************************************************************
	
	    Returns true if queue is empty
	
	**********************************************************************/
	
	public bool isEmpty ( )
	{
		return this.items == 0;
	}


	/***************************************************************************
	
	    Removes all entries from the queue.
	
	***************************************************************************/
	
	public void flush ( )
	{
		this.reset();
	}


	/***************************************************************************
	
	    Closes the queue's data container. Base class does nothing, but may be
	    overridden by derived classes.
	
	***************************************************************************/

	public void close ( )
	{
	}


	/***************************************************************************

		Writes the queue's state and contents to a file with the queue's name
		+ ".dump".
	
		If the file already exists it is overwritten.
	
	***************************************************************************/
	
	public void dumpToFile ( )
	{
		this.log("Writing to file " ~ this.name ~ ".dump");
		scope fp = new FilePath(this.name ~ ".dump");
		if ( fp.exists() )
		{
			this.log("(File exists, deleting)");
			fp.remove();
		}
	
		scope file = new File(this.name ~ ".dump", File.WriteCreate);

		synchronized ( this )
		{
			this.serialize(file);
		}

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
	
			synchronized ( this )
			{
				this.deserialize(file);
			}

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
		this.writeToConduit(conduit);
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
		this.readFromConduit(conduit);

		Trace.formatln("Deserialized {}: {} items, {} read, {} write, {} dimension", this.name, this.items, this.read_from, this.write_to, this.dimension);
	}


	/***************************************************************************
	
		Outputs the queue's current seek positions to the log.
	
		If compiled as the QueueTrace version, also outputs a message to Trace.
	
		Params:
			str = message to prepend to seek positions output 
	
	***************************************************************************/
	
	public void logSeekPositions ( char[] str = "" )
	{
	    this.log("{} [ front = {} rear = {} ]", str, this.read_from, this.write_to);
	}
	
	
	/***********************************************************************
	
		Format a string with the queue's current start and end seek
		positions.
	
		Params:
			buf = string buffer to be written into
			show_pcnt = show seek positions as a % of the queue's total size
			nl = write a newline after the seek positions info
	
	***********************************************************************/
	
	public void formatSeekPositions ( ref char[] buf, bool show_pcnt, bool nl = true )
	{
		version ( MemCheck ) auto before = MemProfiler.checkUsage();

		if ( show_pcnt )
		{
			double first_pcnt = 100.0 * (cast(double) this.read_from / cast(double) this.dimension);
			double insert_pcnt = 100.0 * (cast(double) this.write_to / cast(double) this.dimension);
	
			this.format_buf.length = 20;
			buf ~= "[" ~ Float.format(this.format_buf, first_pcnt) ~ "%..";
			this.format_buf.length = 20;
			buf ~= Float.format(this.format_buf, insert_pcnt) ~ "%]";
		}
		else
		{
			buf ~= "[" ~ Integer.format(this.format_buf, this.read_from) ~ ".."
				~ Integer.format(this.format_buf, this.write_to) ~ " / "~ Integer.format(this.format_buf, this.dimension) ~ "]";
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


	/***************************************************************************
	
	    Resets the queue's internal counters to 0.
	
	***************************************************************************/
	
	protected void reset ( )
	{
		this.write_to = 0;
		this.read_from = 0;
		this.items = 0;
	}


	/***************************************************************************

		Enum defining the order in which the queue's state longs are written to
		/ read from a file.
	
	***************************************************************************/
	
	protected enum StateSerializeOrder
	{
		dimension = 0,
		write_to,
		read_from,
		items,
		name_length
	}
	
	
	/***************************************************************************
	
		Writes the queue's state to a conduit. The queue's name is written,
		followed by an array of longs describing its state.
	
		Params:
			conduit = conduit to write to
		
		Returns:
			number of bytes written
	
	***************************************************************************/
	
	protected long writeState ( Conduit conduit )
	{
		long[StateSerializeOrder.max + 1] longs;
		
		// Write longs
		longs[StateSerializeOrder.dimension] = this.dimension;
		longs[StateSerializeOrder.write_to] = this.write_to;
		longs[StateSerializeOrder.read_from] = this.read_from;
		longs[StateSerializeOrder.items] = this.items;
		longs[StateSerializeOrder.name_length] = this.name.length;

		long bytes_written = conduit.write(cast(void[]) longs);

		// Write name
		bytes_written += conduit.write(cast(void[]) this.name);

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
	
	protected long readState ( Conduit conduit )
	{
		long[StateSerializeOrder.max + 1] longs;
	
		// Read longs
		long bytes_read = conduit.read(cast(void[]) longs);

		this.dimension = longs[StateSerializeOrder.dimension];
		this.write_to = longs[StateSerializeOrder.write_to];
		this.read_from = longs[StateSerializeOrder.read_from];
		this.items = longs[StateSerializeOrder.items];
		this.name.length = longs[StateSerializeOrder.name_length];
	
		// Read names
		bytes_read += conduit.read(cast(void[]) this.name);

		return bytes_read;
	}
}

