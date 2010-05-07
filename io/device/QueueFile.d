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

private import ocean.io.device.model.IQueueChannel;

private import tango.util.log.model.ILogger;

private import tango.net.cluster.model.IChannel;

private import tango.io.device.Conduit;

private import  tango.io.FilePath, tango.io.device.File;



/*******************************************************************************

	QueueFile class

*******************************************************************************/

class QueueFile : ConduitQueue!(File)
{
	/***************************************************************************

	    Constructor (Channel)
	    
		Params:
			log = logger instance
	    	cluster = cluster channel
	    	max = max queue size (bytes)

	***************************************************************************/

	public this ( ILogger log, IChannel channel, uint max, uint min = 1024 * 1024 )
	{
		this.min_file_size = min;
		super(log, channel, max);
	}


	/***************************************************************************
	
	    Constructor (Name)
		Creates or opens existing persistent queue with the given name.

		Params:
			log = logger instance
	    	name = name of queue (file path)
	    	max = max queue size (bytes)

	***************************************************************************/
	
	public this ( ILogger log, char[] name, uint max, uint min = 1024 * 1024 )
	{
		this.min_file_size = min;
		super(log, name, max);
	}


	protected uint min_file_size;

	public void open ( char[] name )
	{
		this.openFile(name, this.min_file_size);
	}
	
	/***************************************************************************

		Opens a persistent queue file. The file is scanned to find the front and
		rear of the queue. After opening the queue file is remapped.

		If the file doesn't exist it is created (with the given minimum length).
		
		Params:
			name = file name
			min = minimum size of newly created queue files
    
	***************************************************************************/

	protected void openFile ( char[] name, uint min )
	{
		Header chunk;

		File file = new File(name, File.ReadWriteOpen);
		this.conduit = file;
		auto length = file.length;

		if (length is 0)
		{
			// initialize file with min length
			min = (min + this.buffer.length - 1) / this.buffer.length;

			this.log.trace ("initializing file queue '{}' to {} KB", this.name, (min * this.buffer.length) / 1024);
          
			while ( min-- > 0 )
			{
				write(this.buffer.ptr, this.buffer.length);
			}

			this.conduit.seek (0);
		}
		else
		{
			// find front and rear position of queue
			while ( this.insert < length )
			{
				// get a header
				this.read(&chunk, Header.sizeof);

				// end of queue?
				if ( chunk.size )
				{
					if ( Header.checksum(chunk) != chunk.check )
					{
						this.log.error ("Invalid header located in queue '{}': truncating after item {}",
								this.name, this.items);
						break;
					}

					if ( chunk.prior == 0 )
					{
						this.first = this.insert;
						this.items = 0;
					}

					++this.items;
                   
					this.current = chunk;
					this.insert = this.insert + chunk.size + Header.sizeof;

					this.conduit.seek(this.insert);
				}
				else
				{
					break;
				}
			}

			this.log.trace ("initializing file queue '{}' [ queue front pos = {} queue rear pos = {} items = {}]",
					this.name, this.first, this.insert, this.items);
           
			this.remap();
		}
	}
}

