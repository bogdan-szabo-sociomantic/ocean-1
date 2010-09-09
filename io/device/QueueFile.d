/*******************************************************************************

    copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release      

    author:         Kris Bell / Thomas Nicolai / Gavin Norman

    QueueFile implements the ConduitQueue base class. It is a FIFO queue
    based on a persistent file.
    
    Be aware that opening a large queue file might take some time to find the
    front and rear of the queue. Moreover, the remapping (flushing) needs some
    time too.

    Note: No file locking needs to be done as this is already done by File.

    TODO        truncate method to reduce file size
                after remaping (if we have to much
                free space wasted at the queues rear)
                
                check the rear of the queue in the
                isDirty method too not only the front

                Using FileMap/mmap in the future
                instead of seeks

*******************************************************************************/

module  ocean.io.device.QueueFile;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.io.device.model.IConduitQueue;

private import tango.util.log.model.ILogger;

private import tango.io.device.Conduit;

private import  tango.io.FilePath, tango.io.device.File;



/*******************************************************************************

	QueueFile class

*******************************************************************************/

deprecated class QueueFile : ConduitQueue!(File)
{
	/***************************************************************************
	
		The queue file's minimum size (in bytes).
		If a new queue is constructed, the file will be initialised to this
		size.
	
	***************************************************************************/

	protected uint min_file_size;


	/***************************************************************************
	
	    Constructor
		Creates or opens existing queue file with the given name.

		Params:
	    	name = name of queue (file path)
	    	max = max queue size (bytes)
	    	min = minimum queue file size (bytes)

	***************************************************************************/

	public this ( char[] name, uint max  )
	{
		super(name, max);
	}
    
    /***************************************************************************
        
         Determines whether the queue is in need of cleanup.
         
         Returns:
             true if the queue is in the need of a clean up.
    
    ***************************************************************************/

	public bool isDirty ( )
	{
		return this.read_from > this.dimension / 4;
	}

	/***************************************************************************

		Opens a persistent queue file. The file is scanned to find the front and
		rear of the queue. After opening the queue file is remapped.

		If the file doesn't exist it is created (with the given minimum length).
		
		Params:
			name = file name
			min = minimum size of newly created queue files
    
	***************************************************************************/

	protected void open ( char[] name )
	{
		Header chunk;

		File file = new File(name, File.ReadWriteOpen);
		this.conduit = file;
		auto length = file.length;

		if (length is 0)
		{
			// initialize file with max length
			uint buffers_to_write = (this.dimension + this.buffer.length - 1) / this.buffer.length;

			this.log("initializing file queue '{}' to {} KB", this.name,
					(buffers_to_write * this.buffer.length) / 1024);
          
			while ( buffers_to_write-- > 0 )
			{
				write(this.buffer.ptr, this.buffer.length);
			}

			this.conduit.seek (0);
		}
		else
		{
			// find front and rear position of queue
			while ( this.write_to < length )
			{
				// get a header
				this.read(&chunk, Header.sizeof);

				// end of queue?
				if ( chunk.size )
				{
					if ( Header.checksum(chunk) != chunk.check )
					{
						if ( this.logger )
						{
							this.logger.error ("Invalid header located in queue '{}': truncating after item {}",
								this.name, this.items);
						}
						break;
					}

					if ( chunk.prior == 0 )
					{
						this.read_from = this.write_to;
						this.items = 0;
					}

					++this.items;
                   
					this.current = chunk;
					this.write_to = this.write_to + chunk.size + Header.sizeof;

					this.conduit.seek(this.write_to);
				}
				else
				{
					break;
				}
			}

			this.log("initializing file queue '{}' [ queue front pos = {} queue rear pos = {} items = {}]",
					this.name, this.read_from, this.write_to, this.items);
           
			this.cleanup();
		}
	}
}

