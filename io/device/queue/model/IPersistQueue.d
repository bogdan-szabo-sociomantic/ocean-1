/*******************************************************************************

    copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release

    author:         Kris Bell / Thomas Nicolai / Gavin Norman

	PersistQueue is an abstract base class for a fixed-size serializable FIFO
	queue, implementing the Queue, Loggable and Serializable interfaces.

	See ocean.io.device.QueueFile and ocean.io.device.QueueMemory for
	implementations of this class.
	
    TODO: strip out the logging support and the formatSeekPositions method -
    this should go in the application, not the library.
    
    TODO: perhaps also remove the capability of dumping / loading from a file
    and move that to the application level as well.

*******************************************************************************/

module io.device.model.queue.IPersistQueue;


/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.io.device.queue.model.IQueue,
               ocean.io.device.queue.model.ISerializable,
               ocean.io.device.queue.model.ILoggable;

private import ocean.io.serialize.SimpleSerializer;

private import tango.io.model.IConduit: InputStream, OutputStream;

private import tango.util.log.model.ILogger;

private import tango.util.log.Log;

private import tango.io.FilePath, tango.io.device.File;

private import Integer = tango.text.convert.Integer;

private import Float = tango.text.convert.Float;

debug private import tango.util.log.Trace;



/*******************************************************************************

	Persist queue class

*******************************************************************************/

abstract class PersistQueue : Queue, Serializable, Loggable
{

	/***************************************************************************

		Abstract method: Pushes a single item to the queue. This method should
		not do any kind of checking whether the item will fit, this is done
		previously by the push method (below).
		
		Note that this method MUST update the item count and the write pointer.

	***************************************************************************/

	abstract protected void pushItem ( void[] item );


	/***************************************************************************

		Abstract method: Pops a single item from the queue. This method should
		not do any kind of checking whether there are items to pop, this is done
		previously by the pop method (below).

		Note that this method MUST update the item count and the read pointer.

	***************************************************************************/

	abstract protected void[] popItem ( );


	/***************************************************************************
	
	    Abstract method: Calculates the size (in bytes) an item would take if it
	    were pushed to the queue. This value should include any header data
	    required.

	***************************************************************************/

	abstract public size_t pushSize ( size_t len );


	/***************************************************************************

		Abstract method: Writes the contents of the queue to the passed conduit.

	***************************************************************************/

	abstract protected size_t readFromConduit ( InputStream input );


	/***************************************************************************

		Abstract method: Reads the contents of the queue from the passed conduit.
	
	***************************************************************************/

	abstract protected size_t writeToConduit ( OutputStream output );
	
	/***************************************************************************
	
	    Struct containing status variables
	
	***************************************************************************/

    struct State
    {
        long dimension,
             write_to,
             read_from,
             items;
    }
    
    /***************************************************************************
    
        Queue state
    
    ***************************************************************************/

    protected State state;
    
    /***************************************************************************
    
        Queue name
    
    ***************************************************************************/
    
    protected char[]    name;

    /***************************************************************************
    
        Logging target
    
    ***************************************************************************/

	protected Logger	logger;

    /***************************************************************************
    
        Buffer used for seek position formatting
    
    ***************************************************************************/

	protected char[] format_buf; 


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
	    this.state.dimension = max;
	}


	/***************************************************************************

		Pushes an item to the queue. The item is checked for valid length (>0),
		and the queue checks if the item will fit.
	    
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
        auto will_fit = this.willFit(item.length);
		if ( will_fit )
	    {
            this.pushItem(item);
	    }
        else
        {
            this.log("queue '{}' full with {} items", this.name, this.state.items);
        }

		return will_fit;
	}


	/***************************************************************************

		Pops an item from the queue.
	    
		Returns:
			the item popped, or null if the queue is empty
	
	***************************************************************************/

	public void[] pop ( )
	{
        return this.state.items ? this.popItem() : null;
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
		this.name.length = name.length;
        this.name[0..$] = name[0..$];
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
	
	deprecated public uint size ( )
	{
		return this.state.items;
	}
	
    /**********************************************************************
    
        Returns the state
    
    **********************************************************************/

    public State getState ()
    {
        return this.state;
    }
	
	/***************************************************************************
	
		Determines whether a given data buffer will fit if pushed onto the
		queue at the insert position.
		
		Returns:
			true if item will fit
	        
	***************************************************************************/
	
	abstract bool willFit ( size_t len );

	/***************************************************************************
	
		Gets the amount of free space at the end of the queue.
		
		Returns:
			bytes free in queue
	        
	***************************************************************************/
	
    abstract ulong freeSpace ( ) ;
	
	/***************************************************************************
	
		Gets the amount of data stored in the queue.
		
		Returns:
			bytes stored in queue
	        
	***************************************************************************/
	
    abstract ulong usedSpace ( ) ;

	/**********************************************************************
	
	    Returns true if queue is full (write position >= end of queue)
        
		TODO: change to > 99% full? or < 1K free?
		
	**********************************************************************/
	
    abstract bool isFull ( ) ;
	
	/**********************************************************************
	
	    Returns true if queue is empty
	
	**********************************************************************/
	
	public bool isEmpty ( )
	{
		return this.state.items == 0;
	}

	/***************************************************************************
	
	    Removes all entries from the queue.
	
	***************************************************************************/
	
	public void flush ( )
	{
		this.reset();
	}


	/***************************************************************************

		Writes the queue's state and contents to a file with the queue's name
		+ ".dump".
	
		If the file already exists it is overwritten.
	
	***************************************************************************/
	
	public void dumpToFile ( )
    {
        this.dumpToFile(this.name ~ ".dump");
    }
    
    /***************************************************************************

        Writes the queue's state and contents to a file.
    
        If the file already exists it is overwritten.
    
        Params:
            filename = name of file to write to
    
    ***************************************************************************/

	public void dumpToFile ( char[] filename )
	{
	    this.log("Writing to file {}", filename);
		debug Trace.formatln("Writing to file {}", filename);
        
		scope fp = new FilePath(filename);
		if ( fp.exists() )
		{
			this.log("(File exists, overwriting)");
            debug Trace.formatln("Writing to file {}", filename);
		}
	
		scope file = new File(fp.toString(), File.WriteCreate);

        scope (exit) file.close();
        
        this.serialize(file);
	}
	
	/***************************************************************************
    
        Reads the queue's state and contents from a file with the queue's name
        + ".dump".
    
	 ***************************************************************************/
	
	public void readFromFile (  )
	{
	    this.readFromFile(this.name ~ ".dump");
	}
	
	/***************************************************************************
	
	    Reads the queue's state and contents from a file.
	    
        Params:
            filename = name of file to read from
        
	***************************************************************************/
	
	public void readFromFile ( char[] filename )
	{
	    this.log("Loading from file {}", filename);
		debug Trace.formatln("Loading from file {}", filename);
        
        scope fp = new FilePath(filename);
        
		if ( fp.exists() )
		{
			this.log("(File exists, loading)");
			scope file = new File(fp.toString(), File.ReadExisting);
	
            scope (exit) file.close();
            
            this.deserialize(file);
		}
		else
		{
			this.log("(File doesn't exist)");
		}
	}
	
	/***************************************************************************

		Writes the queue's state and contents to the given conduit.
		
		Params:
			output = output to write to
	    
        Returns:
            number of bytes written
        
        Throws:
            IOException on End Of Flow condition
        
	***************************************************************************/
	
	public size_t serialize ( OutputStream output )
	{
        size_t bytes_written = 0;
        
        bytes_written += this.writeState(output);
        bytes_written += this.writeToConduit(output);
        
        debug Trace.formatln("Serialized {} ({} bytes): {} items, {} read, {} write, {} dimension",
                             this.name, bytes_written, this.state.items, this.state.read_from, this.state.write_to, this.state.dimension);
        
        return bytes_written;
	}

	
	/***************************************************************************
	
	    Reads the queue's state and contents from the given conduit.
	    For compatibility with any sort of Conduit, does not check that the size
	    of the data in the conduit will actually fit in the queue. The conduit
	    copy method will assert if it doesn't though.
	
		Params:
			input = input to read from
	    
        Returns:
            number of bytes read
        
        Throws:
            IOException on End Of Flow condition
        
	***************************************************************************/
	
	public size_t deserialize ( InputStream input )
	{
        size_t bytes_read = 0;
        
        bytes_read += this.readState(input);
        bytes_read += this.readFromConduit(input);

        debug Trace.formatln("Deserialized {} ({} bytes): {} items, {} read, {} write, {} dimension",
                             this.name, bytes_read, this.state.items, this.state.read_from, this.state.write_to, this.state.dimension);
        
        return bytes_read; 
	}


	/***************************************************************************
	
		Outputs the queue's current seek positions to the log.
	
		If compiled as the QueueTrace version, also outputs a message to Trace.
	
		Params:
			str = message to prepend to seek positions output 
	
	***************************************************************************/
	
	public void logSeekPositions ( char[] str = "" )
	{
	    this.log("{} [ front = {} rear = {} ]", str, this.state.read_from, this.state.write_to);
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
		if ( show_pcnt )
		{
			double first_pcnt = 100.0 * (cast(double) this.state.read_from / cast(double) this.state.dimension);
			double insert_pcnt = 100.0 * (cast(double) this.state.write_to / cast(double) this.state.dimension);
	
			this.format_buf.length = 20;
			buf ~= "[" ~ Float.format(this.format_buf, first_pcnt) ~ "%..";
			this.format_buf.length = 20;
			buf ~= Float.format(this.format_buf, insert_pcnt) ~ "%]";
		}
		else
		{
			buf ~= "[" ~ Integer.format(this.format_buf, this.state.read_from) ~ ".."
				~ Integer.format(this.format_buf, this.state.write_to) ~ " / "~ Integer.format(this.format_buf, this.state.dimension) ~ "]";
		}
	
		if ( this.isFull() )
		{
			buf ~= "F";
		}
		
		if ( nl )
		{
			buf ~= "\n";
		}
	}


	/***************************************************************************
	
	    Resets the queue's internal counters to 0.
	
	***************************************************************************/
	
	protected void reset ( )
	{
		this.state.write_to = 0;
		this.state.read_from = 0;
		this.state.items = 0;
	}


	/***************************************************************************
	
		Writes the queue's state to a conduit. The queue's name is written,
		followed by an array of longs describing its state.
	
		Params:
			conduit = conduit to write to
		
		Returns:
			number of bytes written
        
        Throws:
            IOException on End Of Flow condition
	
	***************************************************************************/
	
	protected size_t writeState ( OutputStream output )
	{
        size_t bytes_written = SimpleSerializer.write(output, &this.state);

		// Write name
		bytes_written += SimpleSerializer.write(output, this.name);
        
		return bytes_written;
	}
	
	
	/***************************************************************************
	
		Reads the queue's state from a conduit. The queue's name is read,
		followed by an array of longs describing its state.
		
		Params:
			conduit = conduit to read from
		
		Returns:
			number of bytes read
        
        Throws:
            IOException on End Of Flow condition
	
	***************************************************************************/
    
	protected size_t readState ( InputStream input )
	{
        size_t bytes_read = SimpleSerializer.read(input, this.state);
        
        bytes_read += SimpleSerializer.read(input, this.name);
        
        if (!this.state.items)                                                  // reset read/write positions
        {                                                                       // to prevent invariant to fail
            this.state.read_from = 0;
            this.state.write_to  = 0;
        }
        
        return bytes_read;
	}
}
