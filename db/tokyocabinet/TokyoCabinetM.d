/*******************************************************************************

        Tokyo Cabinet On-Memory Hash Database

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        June 2010: Initial release
                        
        author:         Thomas Nicolai, Lars Kirchhoff, David Eckardt
        
        Description:

        Very fast and lightweight database with 10K to 200K inserts per second.
        
        ---
        
            import ocean.db.tokyocabinet.TokyoCabinetM;
            
            scope db = new TokyoCabinetM;
            
            db.put("foo", "bar");
            
            db.close();
        
        ---
        
 ******************************************************************************/

module ocean.db.tokyocabinet.TokyoCabinetM;


/*******************************************************************************

    Imports

 ******************************************************************************/

private     import  ocean.db.tokyocabinet.model.ITokyoCabinet: TokyoCabinetIterator;

private     import  ocean.db.tokyocabinet.c.tcmdb:
                        TCMDB,
                        tcmdbnew,   tcmdbdel,
                        tcmdbput,   tcmdbputkeep,  tcmdbputcat,
                        tcmdbget,   tcmdbforeach,
                        tcmdbout,   tcmdbrnum,     tcmdbvsiz;
                        
private     import  ocean.text.util.StringC;

/*******************************************************************************

    TokyoCabinetH class

*******************************************************************************/

class TokyoCabinetM
{
    private alias TokyoCabinetIterator!(TCMDB, tcmdbforeach) TcIterator;
    
    /**************************************************************************
    
        Destructor check if called twice

     **************************************************************************/
    
    private bool            deleted         = false;
    
    private TCMDB*          db;
    
    /**************************************************************************
        
        Constructor    
                             
     **************************************************************************/
    
    public this ( ) 
    {
        this.db = tcmdbnew();
    }
    
    
    
    /**************************************************************************
    
        Destructor    
        
        FIXME: destructor called twice: why?
                             
     **************************************************************************/

    private ~this ( )
    {
        if (!this.deleted)
        {
            tcmdbdel(this.db);
        }
        
        this.deleted = true;
    }
    
    
    
    /**************************************************************************
        
        Invariant: called every time a public class method is called
                             
     **************************************************************************/
    
    invariant ( )
    {
        assert (this.db, typeof (this).stringof ~ ": invalid TokyoCabinet Hash core object");
    }
    
    
    
    /**************************************************************************
     
        Puts a record to database; overwrites an existing record
       
        Params:
            key   = record key
            value = record value
            
    ***************************************************************************/
    
    public void put ( char[] key, char[] value )
    {
        tcmdbput(this.db, key.ptr, key.length, value.ptr, value.length);
    }
    
    
    /**************************************************************************
    
        Puts a record to database; does not ooverwrite an existing record
       
        Params:
            key   = record key
            value = record value
            
    ***************************************************************************/
    
    public void putkeep ( char[] key, char[] value )
    {
        tcmdbputkeep(this.db, key.ptr, key.length, value.ptr, value.length);
    }
    
    
    
    /**************************************************************************
        
        Attaches/Concenates value to database record; creates a record if not
        existing
        
        Params:
            key   = record key
            value = value to concenate to record
            
    ***************************************************************************/
    
    public void putcat ( char[] key, char[] value )
    {
        tcmdbputcat(this.db, key.ptr, key.length, value.ptr, value.length);
    }
    
    /**************************************************************************
    
        Get record value without intermediate value buffer
    
        Params:
            key   = record key
            value = record value output
    
        Returns
            true on success or false if record not existing
            
    ***************************************************************************/

    public bool get ( char[] key, out char[] value )
    {
        int len;
        
        void* value_ = cast (void*) tcmdbget(this.db, key.ptr, key.length, &len); 
        
        bool found = !!value;
        
        if (found)
        {
            value = (cast (char*) value)[0 .. len];
        }
        
        return found;
    }
    
    
    
    /**************************************************************************
    
        Tells whether a record exists
        
         Params:
            key = record key
        
        Returns:
             true if record exists or false otherwise
    
    ***************************************************************************/

    public bool exists ( char[] key )
    {
        return (tcmdbvsiz(this.db, key.ptr, key.length) >= 0);
    }
    
    /**************************************************************************
    
        Remove record
        
        Params:
            key = key of record to remove
        
        Returns:
            true on success or false otherwise
        
    ***************************************************************************/

    public bool remove ( char[] key )
    {
        return tcmdbout(this.db, key.ptr, key.length);
    }
    
    
    /**************************************************************************
        
        Returns number of records
        
        Returns: 
            number of records, or zero if none
        
     ***************************************************************************/
    
    public ulong numRecords ()
    {
        return tcmdbrnum(this.db);
    }
    
    /**************************************************************************
    
        "foreach" iterator over key/value pairs of records in database. The
        "key" and "val" parameters of the delegate correspond to the iteration
        variables.
        
     ***************************************************************************/
    
    public int opApply ( TcIterator.KeyValIterDg delg )
    {
        int result;
        
        TcIterator.tcdbopapply(this.db, delg, result);
        
        return result;
    }
    
    
    /**************************************************************************
    
        "foreach" iterator over keys of records in database. The "key"
        parameter of the delegate corresponds to the iteration variable.
        
     ***************************************************************************/
    
    public int opApply ( TcIterator.KeyIterDg delg )
    {
        int result;
        
        TcIterator.tcdbopapply(this.db, delg, result);
        
        return result;
    }
}
