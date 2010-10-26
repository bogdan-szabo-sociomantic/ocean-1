/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release

    author:         Gavin Norman

	Serializable interface. Implementing classes can be written and read to /
	from a Conduit.

*******************************************************************************/

module io.device.queue.model.ISerializable;



/*******************************************************************************

	Imports

*******************************************************************************/

private import tango.io.model.IConduit: InputStream, OutputStream;



interface Serializable
{
	/***************************************************************************

	    Writes the queue's state and contents to a Conduit.
	
	***************************************************************************/
	
	synchronized size_t serialize ( OutputStream output );
	
	
	/***************************************************************************
	
	    Reads the queue's state and contents from a Conduit.
	    
	***************************************************************************/
	
	synchronized size_t deserialize ( InputStream input );
}

