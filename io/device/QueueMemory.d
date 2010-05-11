/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release      

    author:         Gavin Norman

    QueueMemory implements the QueueConduit base class. It is a FIFO queue
    based on the Memory Conduit (which is a non-growing memory buffer).

	Also in this module is QueueMemoryPersist, an extension of QueueMemory which
	loads itself from a dump file upon construction, and saves itself to a file
	upon destruction. It handles the Ctrl-C terminate signal to ensure that the
	state and content of all QueueMemoryPersist instances are saved if the
	program is terminated.

*******************************************************************************/

module  ocean.io.device.QueueMemory;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.io.device.model.IConduitQueue;

private import tango.util.log.model.ILogger;

private import tango.io.device.Conduit;

private import ocean.io.device.Memory;

private import tango.io.FilePath, tango.io.device.File;

private import Csignal = tango.stdc.signal: signal, raise, SIGTERM, SIGINT, SIG_DFL;

private import ocean.sys.SignalHandler;

private import tango.util.log.Trace;



/*******************************************************************************

    QueueMemory

*******************************************************************************/

class QueueMemory : ConduitQueue!(Memory)
{
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

		Initialises the Array conduit with the size set in the constructor.
	
	***************************************************************************/

    public void open ( char[] name )
	{
		this.log("Initializing memory queue '{}' to {} KB", this.name, this.limit / 1024);
        this.conduit = new Memory(this.limit); // non-growing array
	}
}



/*******************************************************************************

	QueueMemoryPersist

*******************************************************************************/

class QueueMemoryPersist : QueueMemory
{
	/***************************************************************************

	    Constructor
	    
	    Params:
	    	name = name of queue (for logging)
	    	max = max queue size (bytes)
	
	***************************************************************************/
	
	public this ( char[] name, uint max )
	{
		super(name, max);
		this.registerInstance();
		this.readFromFile();
	}


	/***************************************************************************

    	Registers this instance of this class with the static instances list.
	
	***************************************************************************/

	protected void registerInstance ( )
	{
		registerInstance(this);
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
	
	extern (C) static protected synchronized void terminate ( int code )
	{
		char[] msg = SignalHandler.getId(code) ~ " raised: terminating";
		Trace.formatln(msg);

		foreach ( instance; instances )
		{
			Trace.formatln("Closing {} (saving {} entries to {})",
					instance.getName(), instance.size(), instance.getName() ~ ".dump");
			instance.log(msg);
			instance.dumpToFile();
		}

	    Csignal.signal(code, SIG_DFL);
	    Csignal.raise(code);
	}
	
	
	/***************************************************************************
	
	    Static list of instances of this class
	    
	***************************************************************************/
	
	static protected QueueMemoryPersist[] instances;


	/***************************************************************************
	
    	Registers an instance of this class with the static instances list.
    	
    	Params:
    		instance = instance to register
    
	***************************************************************************/

	static protected void registerInstance ( QueueMemoryPersist instance )
	{
		Trace.formatln("Adding {} to memory persist queue instances list", instance.getName());
		instances ~= instance;
	}
}

