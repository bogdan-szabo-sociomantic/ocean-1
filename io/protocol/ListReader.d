/******************************************************************************

    Protocol reader capable of reading lists of arrays or strings

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        January 2010: Initial release

    authors:        David Eckardt

    Extends tango.io.protocol.Reader by capability of reading enums and lists of
    arrays or strings. Such a string/array list must be terminated by an empty
    item as is done by ListWriter.

*******************************************************************************/

module ocean.io.protocol.ListReader;



/******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.protocol.Reader;

private import tango.io.stream.Buffered;

//version = TRACE;

version ( TRACE )
{
	private import tango.util.log.Trace;
}



/******************************************************************************

    ListReader class
    
*******************************************************************************/

class ListReader : Reader
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
    
    public this ( InputStream stream )
    {
   		super(stream);
    }

    /***************************************************************************
    
		Constructor without an input stream.
		
		This constructor used in the case where the input stream doesn't exist
		at the point when the ListReader is constructed. An input stream can be
		attached later using the connectBufferedInput method, below.

    ***************************************************************************/

    public this ( )
    {
   		super();
    }


    /***************************************************************************

    	Connects a conduit to an input buffer, and attaches them to this
    	ListReader.
    	
    	Any content in the buffer is flushed first.
    	
    	Params:
    		bin = input buffer
    		conduit = stream to read from
	
	***************************************************************************/

    public void connectBufferedInput ( BufferedInput bin, IConduit conduit )
    {
    	if ( bin.input )
    	{
    		bin.flush();
    	}

    	bin.input = conduit;
    	this.attachStream(bin);
    }

    /***************************************************************************

		Disconnects the input buffer from this ListReader.
		
		Any content in the buffer is flushed first.
		
	***************************************************************************/

    public void disconnectBufferedInput ( )
    in
    {
        assert(this.input, "ASSERT: ocean.io.protocol.ListReader - cannot disconnect input buffer, there's not one connected");
    }
    body
    {
    	this.input.flush();
    	this.input = null;
    }

    /**************************************************************************
    
        Extracts "items" from the current position in the order of being passed.
        Supports items of elementary type, arrays/strings and lists (arrays) of
        arrays/strings.
        
        Params:
            items = items to extract (variable argument list)
            
        Returns:
            this instance
    
     **************************************************************************/

    public This get ( T ... ) ( out T items )
    in
    {
        assert(this.input);
        assert(this.input.input);
    }
    body
    {
    	static if (items.length)
        {
        	version ( TRACE ) Trace.formatln("ListReader.get - {}", T[0].stringof);

        	static if (is (T[0] U == U[][]))    // check whether the current
            {                                   // item is an array of arrays
                this.getList(items[0]);
            }
            else
            {
                static if (is (T[0] EnumBase == enum))
                {                           
                	version ( TRACE ) Trace.formatln("ListReader.get - enum {}", EnumBase.stringof);
                    /* 
                     * For enums the base type must be used to avoid ambiguous
                     * matching of overloaded super.get().
                     */
                    EnumBase item;
                    
                    super.get(item);

                	items[0] = cast (T[0]) item;

                	version ( TRACE ) Trace.formatln("  GOT {}", items[0]);
                }
                else
                {
                	static if ( is(typeof(items[0]) U == U[]) )
                	{
                		version ( TRACE ) Trace.formatln("ListReader.get - single array item {} ({})", typeof(items[0]).stringof, items[0].length);
                	}
                	else
                	{
                		version ( TRACE ) Trace.formatln("ListReader.get - single item {}", typeof(items[0]).stringof);
                	}
                    super.get(items[0]);
                	version ( TRACE ) Trace.formatln("  GOT {}", items[0]);
                }
            }

        	static if ( items.length > 1)
        	{
        		this.get(items[1 .. $]);
        	}
        }
    	else
    	{
        	version ( TRACE ) Trace.formatln("ListReader.get - empty");
    	}

    	version ( TRACE ) Trace.formatln("ListReader.get - DONE");
        return this;
    }
    
    /**************************************************************************
    
        Extracts one item of type "T".
        
        Returns:
            extracted item 
    
     **************************************************************************/
    
    public T getValue ( T ) ( )
    {
        static if (is (T EnumBase == enum)) 
        {                                  
            /* 
             * For enums the base type must be used to avoid ambiguous matching
             * of overloaded super.get().
             */
            EnumBase value;
            
            super.get(value);
            
            return cast (T) value;
        }
        else
        {
            T value;
            
            super.get(value);
            
            return value;
        }
    }
    
    /**************************************************************************
    
        Extracts one item of "size_t" which is the data type of the .length
        property of arrays.
        
        Returns:
            extracted item 
    
     **************************************************************************/
    
    public alias getValue!(size_t) getLength;
    
    /**************************************************************************
    
        Extracts a list (array) of arrays/strings.
        
        Params:
            list = list to extract
            
        Returns:
            this instance
    
     **************************************************************************/
    
    public This getList ( T ) ( out T[][] list )
    {
    	version ( TRACE ) Trace.formatln("ListReader.get - list {}[][]", T.stringof);
        T[] item;
        
        super.get(item);
        
        while (item.length)
        {
            version ( TRACE ) Trace.formatln("    GOT {} ({})", item, item.length);
            list ~= item;
            
        	version ( TRACE ) Trace.formatln("  ListReader.get - list item");
            super.get(item);
        }
        version ( TRACE ) Trace.formatln("  ListReader.get - list terminator");
        
        return this;
    }
}
