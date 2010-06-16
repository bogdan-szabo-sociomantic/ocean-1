/******************************************************************************

    Protocol writer capable of writing lists of arrays or strings

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        January 2010: Initial release

    authors:        David Eckardt

    Extends tango.io.protocol.Writer by capability of reading lists of arrays
    or strings. Such a string/array list is terminated by an empty item as
    expected by ListReader.

*******************************************************************************/

module ocean.io.protocol.ListWriter;



/******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.protocol.Writer;

private import tango.io.stream.Buffered;

//version = TRACE;

version ( TRACE )
{
	private import tango.util.log.Trace;
}



/******************************************************************************

    ListWriter class

*******************************************************************************/

class ListWriter : Writer
{
    /**************************************************************************
    
        Convenience This alias
    
     **************************************************************************/
    
    private alias typeof (this) This;

    /**************************************************************************
    
        Constructor
        
        Params:
            stream = stream to construct Reader upon 
    
     **************************************************************************/
    
    public this ( OutputStream stream )
    {
   		super(stream);
    }
    
    /***************************************************************************
    
		Constructor without an output stream.
		
		This constructor used in the case where the output stream doesn't exist
		at the point when the ListWriter is constructed. An output stream can be
		attached later using the connectBufferedOutput method, below.
	
	***************************************************************************/

    public this ( )
    {
   		super();
    }

    /***************************************************************************

		Connects a conduit to an output buffer, and attaches them to this
		ListWriter.
		
		Any content in the buffer is flushed first.
		
		Params:
			bout = output buffer
			conduit = stream to write to
	
	***************************************************************************/

    public void connectBufferedOutput ( BufferedOutput bout, IConduit conduit )
    {
    	if ( bout.output )
    	{
    		bout.flush();
    	}

    	bout.output = conduit;
    	this.attachStream(bout);
    }

    /***************************************************************************

		Disconnects the output buffer from this ListWriter.
		
		Any content in the buffer is flushed first.
		
	***************************************************************************/

    public void disconnectBufferedOutput ( )
    {
    	assert(this.output, "ASSERT: ocean.io.protocol.ListWriter - cannot disconnect output buffer, there's not one connected");
    	this.output.flush();
    	this.output = null;
    }

    /**************************************************************************
    
        Writes "items" to the current position in the order of being passed.
        Supports items of elementary type, arrays/strings and lists (arrays) of
        arrays/strings.
        
        Params:
            items = items to extract (variable argument list)
            
        Returns:
            this instance
    
     **************************************************************************/

    public This put ( T ... ) ( T items )
    {
    	assert(this.output);
    	assert(this.output.output);
    	version ( TRACE ) Trace.formatln("ListWriter.put");

    	static if (items.length)
        {
            static if (is (T[0] U == U[][]))    // check whether the current
            {                                   // item is an array of arrays
                this.putList(items[0]);
            }
            else
            {
                static if (is (T[0] EnumBase == enum))
                {
                    /* 
                     * For enums the base type must be used to avoid ambiguous
                     * matching of overloaded super.put().
                     */
                	version ( TRACE ) Trace.formatln("ListWriter.put - enum {}", EnumBase.stringof);
                    super.put(cast (EnumBase) items[0]);
                }
                else
                {
                	version ( TRACE ) Trace.formatln("ListWriter.put - single item {}", typeof(items[0]).stringof);
                    super.put(items[0]);
                }
            }
            
            this.put(items[1 .. $]);
        }
        
        return this;
    }
    
    /**************************************************************************
    
        Writes a list (array) of arrays/strings.
        
        Params:
            list = list to write
    
        Returns:
            this instance
    
     **************************************************************************/
    
    public This putList ( T ) ( T[][] items )
    {
    	version ( TRACE ) Trace.formatln("ListWriter.put - list {}[][] ({})", T.stringof, items.length);
        const T[] TERM = [];
        
        foreach (item; items)
        {
        	version ( TRACE ) Trace.formatln("  ListWriter.put - list item ({})", item.length);
            super.put(item);
        }

        version ( TRACE ) Trace.formatln("  ListWriter.put - list terminator");
        super.put(TERM);
        
        return this;
    }
}
