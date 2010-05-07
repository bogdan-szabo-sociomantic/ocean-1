/*******************************************************************************

    copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release

    author:         Kris Bell / Thomas Nicolai / Gavin Norman

	QueueChannel defines an interface to a single channel of a queue cluster.
	It defines an interface to a FIFO queue to push and pop a large quantity of
	data. Each item in the queue consists of the data itself and an
	automatically generated message header.

	The ConduitQueue template class implements QueueChannel using a Conduit
	object as the underlying storage medium for the queue. In this way multiple
	types of queue can be implemented, using a variety of storage media.

	The QueueChannel interface is defined so that different versions of the
	ConduitQueue class can be used abstractly via the interface.

    What follows is an example on how to use this queue implementation. The
    example uses QueueFile, which is derived from QueueConduit, but other
    derived classes should have the same interface.
    
    ---
	    import tango.util.log.Log, 
	           tango.util.log.AppendConsole;
		import ocean.io.device.model.IQueueChannel;
		import ocean.io.device.QueueFile;


	    auto log = Log.getLogger("queue.persist");
	    auto appender = new AppendConsole;
	    
	    log.add(appender);
	    
	    auto queue = new QueueFile (log, "foo.bar", 1024);
	    
	    // insert some data, and retrieve it again
	    auto text = "this is a test";
	    
	    queue.push (text);
	    auto item = queue.pop ();
	    
	    assert (item == text);
	    queue.close;
    
    ---

*******************************************************************************/

module io.device.model.IQueueConduit;



/*******************************************************************************

	Imports

*******************************************************************************/

private import tango.util.log.model.ILogger;

private import tango.net.cluster.model.IChannel;

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

	QueueChannel interface

*******************************************************************************/

interface QueueChannel
{
	/***************************************************************************

	    Sets the queue's cluster channel.
	
	***************************************************************************/

	void setChannel ( IChannel channel );

	
	/***************************************************************************

	    Sets the queue's name.
	
	***************************************************************************/
	
	void setName ( char[] name );
	

	/***************************************************************************

	    Returns the number of items in the queue.
	
	***************************************************************************/

	uint size ( );

	
	/***************************************************************************

	    Returns the queue's channel.
	
	***************************************************************************/

	IChannel channel ( );

	
	/***************************************************************************

	    Is the front of the queue being wasted? (the queue's read position is >
	    half way through the conduit.)
	
	***************************************************************************/

	bool isDirty ( );

	
	/***************************************************************************

	    Is the queue full?
	
	***************************************************************************/

	bool isFull ( );

	
	/***************************************************************************

	    Pushes an item into the queue.
	
	***************************************************************************/

	synchronized bool push ( void[] data );


	/***************************************************************************

	    Pops an item from the queue.
	
	***************************************************************************/

	synchronized void[] pop ( );


	/***************************************************************************

	    Writes the queue's content to a file.
	
	***************************************************************************/

	void dumpToFile();


	/***************************************************************************

	    Reads the queue's content from a file.
	
	***************************************************************************/
	
	void readFromFile();
}



/*******************************************************************************

	ConduitQueue abstract template class.
	Implements the QueueChannel interface.

	Template parameter C = Conduit type

*******************************************************************************/

abstract class ConduitQueue ( C ) : QueueChannel
{
	/***************************************************************************
	
	    Make sure the template parameter C is a type derived from Conduit
	
	***************************************************************************/

	static assert ( is(C : Conduit), "use conduit not '" ~ C.stringof ~ "'" );


	/***************************************************************************

	    Abstract method: Opens the queue given an identifying name.
	
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
    protected IChannel	channel_;       // the channel we're using
    protected ILogger	log;            // logging target


	/***************************************************************************
	
	    Constructor (Name)
	
		Params:
			log = logger instance
	    	name = name of queue (for logging)
	    	max = max queue size (bytes)
	
	    Note: the name parameter may be used be derived classes to denote a file
	    name, ip address, etc.
	
	***************************************************************************/

    public this ( ILogger log, char[] name, uint max )
    {
    	this.log = log;
    	this.setName(name);
        this.limit = max;
        this.buffer = new void [1024 * 8];
        this.open(name);
    }


    /***************************************************************************

	    Constructor (Channel)
	    
	    Params:
	    	log = logger instance
	    	channel = queue cluster channel
	    	max = max queue size (bytes)

	***************************************************************************/

    public this ( ILogger log, IChannel channel, uint max )
    {
    	this(log, channel.name, max);
        this.setChannel(channel);
        this.open(channel.name);
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

	    Gets the logger object associated with the queue.
	
	***************************************************************************/

	ILogger logger ( )
	{
		return this.log;
	}

	/***************************************************************************

	    Closes the queue's conduit.
	
	***************************************************************************/

	protected Conduit getConduit()
	{
		return this.conduit;
	}

	/***************************************************************************

		Sets the queue's channel.

    ***************************************************************************/

    public void setChannel ( IChannel channel )
    {
    	this.channel_ = channel;
    }


	/***************************************************************************

	    Sets the queue's name.
	
	***************************************************************************/
	
	public void setName ( char[] name )
	{
		this.name = name;
	}


	/**********************************************************************

        Returns number of items in the queue

    **********************************************************************/

    public uint size ( )
    {
    	return this.items;
    }
    
    /**********************************************************************

        Returns cluster channel

    **********************************************************************/

    public IChannel channel ( )
    {
        return this.channel_;
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

		Frees wasted blocks at the queue front.

    **********************************************************************/

	public synchronized void flush ( )
    {
    	remap();
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
                this.log.trace ("queue '{}' full with {} items", this.name, this.items);
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
		Header chunk = void;

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
    
	protected void setHeaderPriorSize(long seek_pos, uint prior_size)
	{
		Header chunk = void;

		this.conduit.seek(seek_pos);

        this.read(&chunk, Header.sizeof);

        chunk.prior = 0;
        chunk.calcChecksum();

        this.conduit.seek(seek_pos);

        this.write(&chunk, Header.sizeof); // update message header
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
            
        Reads message content from the queue.
        
        Params:
        	hdr = header of the message to be read
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

        Reads data from the queue.
        
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
            	this.log.trace("QueueConduit.write :: Eof while writing: {}:\n{}", len, (cast(char*)data)[0..len]);
            	this.conduit.error("QueueConduit.write :: Eof while writing");
            }
        }
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
    
    protected bool remap ( )
    {
        this.log.trace("Thinking about remapping queue '{}'", name);

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

		Writes the queue's contents to a file with the queue's name + ".dump".
		If the file already exists it is deleted.
	
	***************************************************************************/
    
	public void dumpToFile ( )
	{
		this.log.trace("Writing to file");
		scope fp = new FilePath(this.name ~ ".dump");
		if ( fp.exists() )
		{
			this.log.trace("File exists, deleting");
			fp.remove();
		}
			
		scope file = new File(this.name ~ ".dump", File.WriteCreate);
		this.conduit.seek(0);
		file.copy(this.conduit);
		file.close();
	}


	/***************************************************************************

	    Reads the queue's content from a file.
	
	***************************************************************************/
	
	public void readFromFile ( )
	{
		this.log.trace("Loading from file");
		scope fp = new FilePath(this.name ~ ".dump");
		if ( fp.exists() )
		{
			this.log.trace("File exists");
			scope file = new File(this.name ~ ".dump", File.ReadExisting);
			assert ( file.length <= this.limit );

			this.conduit.copy(file);

			file.close();
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
        version ( QueueTrace )
        {
        	Trace.format("{} {} ", str, this.name);
        	this.traceSeekPositions(false);
        }

        this.log.trace ("{} [ front = {} rear = {} ]", str, this.first, this.insert);
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



/*******************************************************************************

	QueueConduit test - tests the QueueMemory and QueueFile classes, derived
	from QueueConduit.
	
	Copy this code into a main.d somewhere and compile it.

*******************************************************************************/

version ( QueueConduitTest )
{
	private import ocean.io.device.model.IQueueChannel;
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
//		auto q = new QueueFile (log, "test_file_queue", 256 * 1024 * 1024);
		auto q = new QueueMemoryPersist (log, "test_memory_queue", 256 * 1024 * 1024);
		
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

		q.logger().info ("{}, {} pop/s",i, i/w.stop);

		// Close the queue
		q.close();
	}

	void push_stuff(QueueChannel q)
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
}