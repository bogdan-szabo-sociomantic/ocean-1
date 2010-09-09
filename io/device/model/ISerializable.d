/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release

    author:         Gavin Norman

	Serializable interface. Implementing classes can be written and read to /
	from a Conduit.

*******************************************************************************/

module io.device.model.ISerializable;



/*******************************************************************************

	Imports

*******************************************************************************/

private import tango.io.device.Conduit;



deprecated interface Serializable
{
	/***************************************************************************

	    Writes the queue's state and contents to a Conduit.
	
	***************************************************************************/
	
	synchronized void serialize ( Conduit conduit );
	
	
	/***************************************************************************
	
	    Reads the queue's state and contents from a Conduit.
	    
	***************************************************************************/
	
	synchronized void deserialize ( Conduit conduit );
}

