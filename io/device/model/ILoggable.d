/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        May 2010: Initial release

    author:         Gavin Norman

	Loggable interface. Implementing classes can have an ILogger object attached.

*******************************************************************************/

module io.device.model.ILoggable;



/*******************************************************************************

Imports

*******************************************************************************/

private import tango.util.log.Log;



deprecated interface Loggable
{
	/***************************************************************************

	    Attaches a logger to the queue, for log output.
	
	***************************************************************************/

	void attachLogger ( Logger logger );


	/***************************************************************************

    	Attaches a logger to the queue, for log output.

	***************************************************************************/

	Logger getLogger ( );


	/***************************************************************************

		Sends a message to the logger.
	
	***************************************************************************/

	void log ( char[] fmt, ... );
}

