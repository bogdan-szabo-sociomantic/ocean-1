/******************************************************************************

    Protocol writer capable of writing lists of arrays or strings

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        January 2010: Initial release

    authors:        David Eckardt

    Extends tango.io.protocol.Writer by capability of reading lists of arrays
    or strings. Such a string/array list is terminated by an empty item as
    expected by ListReader.

 ******************************************************************************/

module core.protocol.ListWriter;

private import tango.io.protocol.Writer;

/******************************************************************************

    ListWriter class

 ******************************************************************************/


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
                    
                    super.put(cast (EnumBase) items[0]);
                }
                else
                {
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
        const T[] TERM = [];
        
        foreach (item; items)
        {
            super.put(item);
        }
        
        super.put(TERM);
        
        return this;
    }
}
