/******************************************************************************

    Protocol reader capable of reading lists of arrays or strings

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        January 2010: Initial release

    authors:        David Eckardt

    Extends tango.io.protocol.Reader by capability of reading enums and lists of
    arrays or strings. Such a string/array list must be terminated by an empty
    item as is done by ListWriter.

*******************************************************************************/

module core.protocol.ListReader;

/******************************************************************************

    Imports

*******************************************************************************/

private import tango.io.protocol.Reader;

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
    {
        static if (items.length)
        {
            static if (is (T[0] U == U[][]))    // check whether the current
            {                                   // item is an array of arrays
                this.getList(items[0]);
            }
            else
            {
                static if (is (T[0] EnumBase == enum))
                {                           
                    /* 
                     * For enums the base type must be used to avoid ambiguous
                     * matching of overloaded super.get().
                     */
                    EnumBase item;
                    
                    super.get(item);

                    items[0] = cast (T[0]) item;
                }
                else
                {
                    super.get(items[0]);
                }
            }
            
            this.get(items[1 .. $]);
        }
        
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
        T[] item;
        
        super.get(item);
        
        while (item.length)
        {
            list ~= item;
            
            super.get(item);
        }
        
        return this;
    }
}
