/*******************************************************************************

    copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

    license:        BSD style: $(LICENSE)
    
    version:        May 2010: Initial release      
                    
    author:         Thomas Nicolai / Gavin Norman

    QueueMemory implements the QueueConduit base class. It is a FIFO queue
    based on the Memory Conduit (which is a non-growing memory buffer).

	Also in this file is QueueMemoryPersist, an extension of QueueMemory which
	loads itself from a dump file upon construction, and saves itself to a file
	upon destruction. It handles the Ctrl-C terminate signal to ensure that its
	state is saved if the program is interrupted.

*******************************************************************************/

module  ocean.io.device.QueueMemory;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.io.device.model.IQueueChannel;

private import tango.util.log.model.ILogger;

private import tango.net.cluster.model.IChannel;

private import tango.io.device.Conduit;

private import ocean.io.device.Memory;

private import tango.io.FilePath, tango.io.device.File;

private import Csignal = tango.stdc.signal: signal, raise, SIGTERM, SIGINT, SIG_DFL;

private import ocean.sys.SignalHandler;



/*******************************************************************************

    QueueMemory

*******************************************************************************/

class QueueMemory : ConduitQueue!(Memory)
{
	/***************************************************************************

	    Constructor (Channel)
	    
	    Params:
	    	log = logger instance
	    	name = name of queue (for logging)
	    	max = max queue size (bytes)
	
	***************************************************************************/

    this ( ILogger log, char[] name, uint max )
    {
    	super(log, name, max);
    }


	/***************************************************************************

	    Constructor (Channel)
	    
	    Params:
	    	log = logger instance
	    	channel = cluster channel
	    	max = max queue size (bytes)
	
	***************************************************************************/
	
	this ( ILogger log, IChannel channel, uint max )
	{
		super(log, channel, max);
	}


	public void open ( char[] name )
	{
		this.initMemory();
	}
	
	/***************************************************************************

		Initialises the Array conduit with the size set in the constructor.

	***************************************************************************/

	protected void initMemory ( )
	{
		this.log.trace ("initializing memory queue '{}' to {} KB", this.name, this.limit / 1024);
        this.conduit = new Memory(this.limit); // non-growing array
	}
}



/*******************************************************************************

	QueueMemoryPersist

*******************************************************************************/

class QueueMemoryPersist : QueueMemory
{
	/***************************************************************************

	    Constructor (Channel)
	    
	    Params:
	    	log = logger instance
	    	name = name of queue (for logging)
	    	max = max queue size (bytes)
	
	***************************************************************************/
	
	this ( ILogger log, char[] name, uint max )
	{
		super(log, name, max);
		this.instances ~= this;
		this.readFromFile();
	}
	
	
	/***************************************************************************
	
	    Constructor (Channel)
	    
	    Params:
	    	log = logger instance
	    	channel = cluster channel
	    	max = max queue size (bytes)
	
	***************************************************************************/
	
	this ( ILogger log, IChannel channel, uint max )
	{
		super(log, channel, max);
		this.instances ~= this;
		this.readFromFile();
	}


	/***************************************************************************

		Closes the queue, writing it to a file before deleting it.
	
	***************************************************************************/
	
	public void close ( )
	{
		this.dumpToFile();
		super.close();
	}


	/***************************************************************************
	
	    Static constructor.
	    Redirects the terminate signal (Ctrl-C) to the static terminate method
	    below.

	***************************************************************************/
	
	static this ( )
	{
	    Csignal.signal(Csignal.SIGTERM, &terminate);
	    Csignal.signal(Csignal.SIGINT,  &terminate);
	}


    /***************************************************************************

	    Static signal handler. Saves each instance of this class to a file
	    before termination.
	    
	    Params:
	        code = signal code
	    
	***************************************************************************/
	
	extern (C) static protected void terminate ( int code )
	{
		char[] msg = SignalHandler.getId(code) ~ " raised: terminating";
	
		foreach ( instance; instances )
		{
			instance.log.trace(msg);
			instance.dumpToFile();
		}
	
	    Csignal.signal(code, SIG_DFL);
	    Csignal.raise(code);
	}
	
	
	/***************************************************************************
	
	    Static list of instances of this class
	    
	***************************************************************************/
	
	static protected QueueMemoryPersist[] instances;
}

