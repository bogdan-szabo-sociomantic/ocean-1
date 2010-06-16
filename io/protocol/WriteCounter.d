/*******************************************************************************

        copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Jun 2010: Initial release      
        
        author:         Gavin Norman

*******************************************************************************/

module ocean.io.protocol.WriteCounter;



/*******************************************************************************

	Imports

*******************************************************************************/

private import tango.io.model.IConduit;

private import ocean.io.protocol.Writer;



/*******************************************************************************

	Dummy output buffer class - just counts how many bytes are written to it,
	does not actually store anything.

*******************************************************************************/

class DummyOutputBuffer : OutputBuffer
{
	/***************************************************************************

		The number of bytes written to the dummy buffer

	***************************************************************************/

	protected size_t count;


	/***************************************************************************

		Adds the length of an item to the count of bytes written.
	
	***************************************************************************/

	OutputBuffer append (void[] item)
    {
    	this.count += item.length;
    	return this;
    }


	/***************************************************************************

		Gets the number of bytes written to the dummy buffer.

	***************************************************************************/

	size_t written ()
    {
    	return this.count;
    }


	/***************************************************************************

		Resets the bytes written count.

	***************************************************************************/

	IOStream flush()
    {
    	this.count = 0;
    	return this;
    }


	/***************************************************************************

		Other (empty) methods simply for compatibility with OutputBuffer and
		OutputStream interfaces.

	***************************************************************************/

	void[] slice ()
    {
    	return [];
    }
    
    size_t writer (size_t delegate(void[]) producer)
    in
    {
    	assert (false, "Dummy writer won't write anything");
    }
    body
    {
    	return 0;
    }
    
    size_t write (void[] src)
    in
    {
    	assert (false, "Dummy writer won't write anything");
    }
    body
    {
    	return 0;
    }

    OutputStream copy (InputStream src, size_t max = -1)
    {
    	return this;
    }

    OutputStream output ()
    {
    	return this;
    }


    long seek (long offset, Anchor anchor = Anchor.Begin)
    in
    {
    	assert (false, "Dummy writer cannot seek");
    }
    body
    {
    	return -1;
    }

    IConduit conduit ()
    in
    {
    	assert (false, "Dummy writer doesn't have a Conduit");
    }
    body
    {
    	return null;
    }
                      
    void close ()
    {
    	this.flush();
    }
}



/*******************************************************************************

	Write counter class - doesn't really write anything, just counts how many
	bytes are sent to it.

*******************************************************************************/

class WriteCounter : Writer
{
	/***************************************************************************

		Dummy output buffer

	***************************************************************************/

	DummyOutputBuffer dummy;


	/***************************************************************************

		Constructor.

		Creates a dummy output buffer, sets up the superclass to 'write' to it.

	***************************************************************************/

	this ( )
	{
		this.dummy = new DummyOutputBuffer();

		super.output = this.dummy;
		super.arrays = &super.writeArray;
		super.elements = &super.writeElement;

		super();
	}

	/***************************************************************************

		Gets the number of bytes written

	***************************************************************************/

	size_t written ( )
	{
		return dummy.written;
	}
}


