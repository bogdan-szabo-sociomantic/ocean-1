/******************************************************************************

    Tokyo Cabinet List

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)
    
    version:        Mar 2010: Initial release
                    
    author:         David Eckardt
    
    Description:
    
        The TokyoCabinetList class encapsulates TCLIST and provides a list
        object used by Tokyo Cabinet in several contexts, for example, when
        requesting a range of records from a B+ tree database.
        TokyoCabinetList class instances are created in and returned from
        TokyoCabinetH/TokyoCabinetB class methods.
    
 ******************************************************************************/

module    ocean.db.tokyocabinet.util.TokyoCabinetList;

/*******************************************************************************

    Imports

 ******************************************************************************/

private   import ocean.db.tokyocabinet.c.tcutil:
                                TCLIST,        ListCmp,
                                tclistnew,     tclistnew2,      tclistload,
                                tclistdup,     tclistdump,
                                tclistclear,   tclistdel,
                                tclistval,     tclistnum, 
                                tclistpush,    tclistpop,
                                tclistshift,   tclistunshift,
                                tclistinsert,  tclistover,      tclistremove,
                                tclistlsearch, tclistbsearch,
                                tclistsort,    tclistsortex,    tclistinvert;

private   import tango.stdc.stdlib: free;

/*******************************************************************************

    TokyoCabinetList class

 ******************************************************************************/

class TokyoCabinetList
{
    /**************************************************************************
    
        This alias for chainable methods
     
     **************************************************************************/

    private alias typeof (this) This;
    
    /**************************************************************************
    
        Tokyo Cabinet list object
     
     **************************************************************************/

    private TCLIST* list;
    
    /**************************************************************************
     
        Constructor
     
     **************************************************************************/
    
    this ( )
    {
        this(tclistnew());
    }
    
    /**************************************************************************
    
        Constructor
         
        Params:
            n = initial list length
         
     **************************************************************************/

    this ( int n )
    {
        this(tclistnew2(n));
    }
    
    /**************************************************************************
    
        Constructor
        
        Uses an existing TCLIST object rather than creating one.
        
        Params:
            list = TCLIST object for this instance
         
     **************************************************************************/
    
    this ( TCLIST* list )
    {
        this.list = list;
    }
    
    /**************************************************************************
    
        Constructor
        
        Restores an instance from output data of a previous call to dump().
        
        Params:
            data = data of a dumped TCLIST object
         
     **************************************************************************/

    this ( ubyte[] data )
    {
        this.list = tclistload(data.ptr, data.length);
    }
    
    /**************************************************************************
    
        Duplicates this instance
        
        Returns:
            new instance (duplicate of this instance)
         
     **************************************************************************/
    
    public This dup ( )
    {
        return new This(tclistdup(this.list));
    }

    /**************************************************************************
    
        Returns the list length
        
        Returns:
            list length
         
     **************************************************************************/

    public int getLength ( )
    {
        return tclistnum(this.list);
    }
    
    
    /**************************************************************************
    
        Returns list item of index. index must be at least 0 and may not exceed
        the list length.
        
        Returns:
            list item
         
     **************************************************************************/

    public char[] get ( int index )
    in
    {
        assert (index >= 0, This.stringof ~ ".get: negative index");
    }
    out (r)                                                                     // tclistval returns null when index out of range 
    {
        assert (r, This.stringof ~ ".get: index out of range");
    }
    body
    {
        return this.getT!(tclistval, int)(index);
    }
    
    public alias get opIndex;
    
    
    /**************************************************************************
    
        'foreach' iteration over list
         
     **************************************************************************/

    public int opApply ( int delegate ( ref char[] item ) dg )
    {
        int result = 0;
        
        for (int i = 0; i < this.getLength(); i++)
        {
            char[] item = this[i];
            
            result = dg(item);
            
            if (result) break;
        }
        
        return result;
    }
    
    
    /**************************************************************************
    
        Appends item to list
        
        Params:
            item = item to append
            
        Returns:
            this instance
         
     **************************************************************************/

    public This append ( char[] item )
    {
        tclistpush(this.list, item.ptr, item.length);
        
        return this;
    }
    
    public alias append opCatAssign;
    
    /**************************************************************************
    
        Prepends item to list
        
        Params:
            item = item to prepend
            
        Returns:
            this instance
         
     **************************************************************************/

    public This prepend ( char[] item )
    {
        tclistunshift(this.list, item.ptr, item.length);
        
        return this;
    }
    
    /**************************************************************************
    
        Inserts item into list so that index is the index of the inserted item. 
        If index is equal to or more than the number of elements, this function
        has no effect.
        
        TODO: 'in' contract checking index?
        
        Params:
            item  = item to append
            index = index of item to insert
            
        Returns:
            this instance
         
     **************************************************************************/

    public This insert ( char[] item, int index )
    {
        tclistinsert(this.list, index, item.ptr, item.length);
        
        return this;
    }
    
    /**************************************************************************
    
        Replaces list item.
        If index is equal to or more than the number of elements, this function
        has no effect.
        
        TODO: 'in' contract checking index?
        
        Params:
            item  = new item
            index = index of item to replace
            
        Returns:
            this instance
         
     **************************************************************************/

    public This replace ( char[] item, int index )
    {
        tclistover(this.list, index, item.ptr, item.length);
        
        return this;
    }
    
    public alias replace opIndexAssign;
    
    /**************************************************************************
    
        Removes the last list item
        
        Returns:
            removed list item
         
     **************************************************************************/

    public char[] removeLast ( )
    {
        return this.getFreeT!(tclistpop)();
    }
    
    /**************************************************************************
    
        Removes the last list item
        
        Returns:
            removed list item
         
     **************************************************************************/

    public char[] removeFirst ( )
    {
        return this.getFreeT!(tclistshift)();
    }
    
    /**************************************************************************
    
        Removes item
        
        TODO: Throw exception via 'out' contract for out of range index
        
        Params:
            index = index of item to remove
            
        Returns:
            removed list item or null if index exceeded list length
         
     **************************************************************************/

    public char[] remove ( int index )
    in
    {
        assert (index >= 0, This.stringof ~ ".remove: negative index");
    }
    out (r)                                                                     // tclistremove returns null when index out of range 
    {
        assert (r, This.stringof ~ ".remove: index out of range");
    }
    body
    {
        return this.getFreeT!(tclistremove, int)(index);
    }
    
    /**************************************************************************
    
        Looks up item using liner search
        
        Params:
            item to lookup
        
        Returns:
            item if found or null otherwise
         
     **************************************************************************/

    public char[] search ( char[] item )
    {
        int index = tclistlsearch(this.list, item.ptr, item.length);
        
        return (index >= 0)? this[index] : null;
    }
    
    public alias search opIndex;
    
    /**************************************************************************
    
        Looks up item using binary search
        
        Params:
            item to lookup
        
        Returns:
            item if found or null otherwise
         
     **************************************************************************/

    public char[] binSearch ( char[] item )
    {
        int index = tclistbsearch(this.list, item.ptr, item.length);
        
        return (index >= 0)? this[index] : null;
    }
    
    /**************************************************************************
    
        Sorts the list
        
        Returns:
            this instance
         
     **************************************************************************/

    public This sort ( )
    {
        tclistsort(this.list);
        
        return this;
    }
    
    /**************************************************************************
    
        Sorts the list
        
        Params:
            cmp = comparison function
        
        Returns:
            this instance
         
     **************************************************************************/

    public This sort ( ListCmp cmp )
    {
        tclistsortex(this.list, cmp);
        
        return this;
    }
    
    /**************************************************************************
    
        Inverts the list
        
        Returns:
            this instance
         
     **************************************************************************/

    public This invert ( )
    {
        tclistinvert(this.list);
        
        return this;
    }
    
    /**************************************************************************
    
        Resets (clears) the list
        
        Returns:
            this instance
         
     **************************************************************************/
    
    public This reset ( )
    {
        tclistclear(this.list);
        
        return this;
    }
    
    /**************************************************************************
    
        Serializes the list object so that a the list may be later restored from
        the data.
        
        Returns:
            this instance
         
     **************************************************************************/

    public ubyte[] dump ( )
    {
        return cast (ubyte[]) this.getFreeT!(tclistdump)();
    }

    /**************************************************************************
    
        Invokes fn with args and propagates the returned string. fn must be of
        type
            ---
                char* function ( TCLIST* list, Args args, int* len )
            ---
            Params:
                list = TCHLIST object
                args = additional arguments (Args may be 'void' if no argument)
                len  = output length of returned string
                
            Returns:
                a string
        .
        
        Params:
            args = additional fn arguments (Args may be 'void' if no argument)
        
        Returns:
            String returned by fn, or null if fn returned null
        
     **************************************************************************/

    private char[] getT ( alias func, Args ... ) ( Args args )
    {
        int len;
        
        char* str = cast (char*) func(this.list, args, &len);
        
        return str? str[0 .. len] : null;
    }
    
    /**************************************************************************
    
        Invokes func with args, propagates a duplicate of the returned string
        and frees the string returned by func. func must be of type
            ---
                char* ( TCLIST* list, Args args, int* len )
            ---
            Params:
                list = TCHLIST object
                args = additional arguments (Args may be 'void' if no argument)
                len  = output length of returned string
                
            Returns:
                a string
        .
        
        Params:
            args = additional func arguments (Args may be 'void' if no argument)
        
        Returns:
            Duplicate of string returned by func, or null if func returned null
        
     **************************************************************************/

    private char[] getFreeT ( alias func, Args ... ) ( Args args )
    {
        char[] str = this.getT!(func, Args)(args);
        
        scope (exit) if (str) free(str.ptr);
        
        return str.dup;
    }
    
    
    /**************************************************************************
    
        Destructor
    
     **************************************************************************/
    
    private ~this ( )
    {
        tclistdel(this.list);
    }
    
    
    
    /**************************************************************************
    
        QuickIterator structure
        
        Holds a TCLIST object as returned e.g. by tcbdbrange(). The following
        operations can be done with this object:
        
            - creating a persistent TokyoCabinetList instance,
            - iterating over a temporary  TcList instance with 'foreach'.
            
         After one of these operations has been finished, the internal TCLIST
         object is exhausted and the QuickIterator object may no more be used.
         
     **************************************************************************/

    static struct QuickIterator
    {
        /**********************************************************************
        
            TCLIST object
             
         **********************************************************************/

        private TCLIST* list_;
        
        /**********************************************************************
        
            Creates a persistent TcList instance from the internal TCLIST
            object.
            
            Returns:
                new TcList
             
         **********************************************************************/

        TokyoCabinetList getPersistent ( )
        in
        {
            assert (this.list_, "TokyoCabinetList exhausted");
        }
        body
        {
            scope (exit) this.list_ = null;
            
            return new TokyoCabinetList(this.list_);
        }
        
        /**********************************************************************
        
            'foreach' iteration over the list. After iteration has been
            finished, the list is deleted.
             
         **********************************************************************/

        int opApply ( int delegate ( ref char[] item ) dg )
        {
            scope list = this.getPersistent();
            
            int result;
            
            foreach (ref item; list)
            {
                result = dg(item);
                
                if (result) break;
            }
            
            return result;
        }
    } // QuickIterator structure
}


