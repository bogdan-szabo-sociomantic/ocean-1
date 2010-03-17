/*******************************************************************************

        copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        Mar 2010: Initial release
                        
        author:         Thomas Nicolai, Lars Kirchhoff, David Eckardt

 ******************************************************************************/

module ocean.db.tokyocabinet.TokyoCabinetB;



/*******************************************************************************

    Imports

 ******************************************************************************/


public      import 	ocean.core.Exception: TokyoCabinetException;

private     import  ocean.db.tokyocabinet.c.tcbdb;
private     import  ocean.db.tokyocabinet.model.ITokyoCabinet;

private     import  tango.util.log.Trace;



/*******************************************************************************

	Tokyo Cabinet B+ Tree Database
	
	Very fast and lightweight database with 10K to 200K inserts per second
	based on the storage engine used.
	
	---
	
	import ocean.db.tokyocabinet.TokyoCabinetB;
	
	auto db = new TokyoCabinetB();
	db.setTuneOpts(TokyoCabinetB.TuneOpts.HDBTLARGE);
	db.setTuneBnum(20_000_000);
	db.enableAsync();
	db.open("db.tch");
	
	db.add("foo", "bar");
	
	db.close;
	
	---


*******************************************************************************/

class TokyoCabinetB : ITokyoCabinet
{
	
	
	
	 /**************************************************************************
    
	    Definitions
	
	 **************************************************************************/ 
	
	private         TCBDB*          db;                             			// tokyocabinet instance

	
	/***************************************************************************
    
	    Tuning parameter for hash database tcbdbtune
	
	 **************************************************************************/ 
	
	private			int 			tune_lmemb;									// lmemb specifies the number of members in each leaf page. The default value is 128.	 
	private			int 			tune_nmemb;									// nmemb specifies the number of members in each non-leaf page. The default value is 256.
	private         long            tune_bnum; 									//  = 30_000_000;       
	private         byte            tune_apow; 									//   = 2;
	private         byte            tune_fpow; 									//   = 3;
	private         TuneOpts        tune_opts;         
	
	
	
	 /**************************************************************************
    
	    constants for tcbdbtune options
	
	    Large:      size of the database can be larger than 2GB 
	    Deflate:    each recordis compressed with deflate encoding
	    Bzip:       each record is compressed with BZIP2 encoding
	    Tcbs:       each record is compressed with TCBS encoding
	
	 **************************************************************************/
	
	enum                            TuneOpts : BDBOPT
	                                {
	                                    Large   = BDBOPT.BDBTLARGE, 
	                                    Deflate = BDBOPT.BDBTDEFLATE,
	                                    Bzip    = BDBOPT.BDBTBZIP,
	                                    Tcbs    = BDBOPT.BDBTTCBS,
	                                    
	                                    None    = cast (BDBOPT) 0
	                                }
	
	enum                            OpenStyle : BDBOMODE
	                                {
	                                    Read             = BDBOMODE.BDBOREADER, // open as a reader 
	                                    Write            = BDBOMODE.BDBOWRITER, // open as a writer 
	                                    Create           = BDBOMODE.BDBOCREAT,  // writer creating 
	                                    Truncate         = BDBOMODE.BDBOTRUNC,  // writer truncating 
	                                    DontLock         = BDBOMODE.BDBONOLCK,  // open without locking 
	                                    LockNonBlocking  = BDBOMODE.BDBOLCKNB,  // lock without blocking 
	                                    SyncAlways       = BDBOMODE.BDBOTSYNC,  // synchronize every transaction
	                                    
	                                    WriteCreate      = Write | Create,
	                                    ReadOnly         = Read  | DontLock,
	                                }
	
	
	/**************************************************************************
    
	    Destructor check if called twice
	
	 **************************************************************************/
	
	bool            deleted         = false;
	
	
	
	/**************************************************************************
	    
	    Constructor    
	    
	    Params:
	        dbfile = path to database file (e.g. /tmp/store.tcb)
	                         
	 **************************************************************************/
	
	public this ( ) 
	{
	    // Trace.formatln(typeof (this).stringof ~ " created").flush();	    
	    this.db = tcbdbnew();
	}
    
	
	
	/**************************************************************************
    
	    Destructor    
	    
	    FIXME: destructor called twice: why?
	    
	    tcbdbdel() will close the database object if it is still open.
	                         
	 **************************************************************************/
	
	private ~this ( )
	{
	    if (!this.deleted)
	    {
	        tcbdbdel(this.db);
	        // Trace.formatln(typeof (this).stringof ~ " deleted").flush();
	    }
	    
	    this.deleted = true;
	}

	
	
	/**************************************************************************
    
	    Invariant: called every time a public class method is called
	                         
	 **************************************************************************/
	
	invariant ( )
	{
	    assert (this.db, typeof (this).stringof ~ ": invalid TokyoCabinet B+ Tree core object");
	}
	
	
	
	/***************************************************************************
    
	    Open Database for reading/writing, create if necessary
	
	    dbfile = specifies the database  file name
	
	 **************************************************************************/    
	
	public void open ( char[] dbfile )
	{   
	    tcbdbtune(	this.db, this.tune_lmemb, this.tune_nmemb, this.tune_bnum, 
	    			this.tune_apow, this.tune_fpow, this.tune_opts);
	    
	    return this.openNonBlocking(dbfile, OpenStyle.WriteCreate);
	}
	
	public void openNonBlocking ( char[] dbfile, OpenStyle style )
	{
	    return this.open(dbfile, style | OpenStyle.LockNonBlocking);
	}
	
	public void open ( char[] dbfile, OpenStyle style )
	{
	    this.tokyoAssert(tcbdbopen(this.db, StringC.toCstring(dbfile), style), "Open error");
	}
	
	
	
	
	
	
	/**************************************************************************
    
	    Retrieves the current Tokyo Cabinet error message string.
	    
	    Returns:
	        current Tokyo Cabinet error message string
	    
	***************************************************************************/
	
	private char[] getTokyoErrMsg ( )
	{
	    return this.getTokyoErrMsg(tcbdbecode(this.db));
	}
	
	
	
	/**************************************************************************
	
	    Retrieves the Tokyo Cabinet error message string for errcode.
	    
	    Params:
	        errcode = Tokyo Cabinet error code
	        
	    Returns:
	        Tokyo Cabinet error message string for errcode
	    
	***************************************************************************/
	
	private char[] getTokyoErrMsg ( TCHERRCODE errcode )
	{
	    return StringC.toDString(tcbdberrmsg(errcode));
	}
	
	
	
	/**************************************************************************
	
	    If ok == false, retrieves the current Tokyo Cabinet error code and
	    throws an exception if the error code is different from  all error codes
	    in ignore_codes (even if it equals TCESUCCESS).
	    
	    Params:
	        ok           = assert condition
	        ignore_codes = do not throw an exception on these codes
	        context      = error context description string for message
	    
	***************************************************************************/
	
	private void tokyoAssertStrict ( bool ok, TCHERRCODE[] ignore_codes, char[] context = "Error" )
	{
	    if (!ok)
	    {
	        TCHERRCODE errcode = tcbdbecode(this.db);
	        
	        foreach (ignore_core; ignore_codes)
	        {
	            if (errcode == ignore_core) return; 
	        }
	        
	        TokyoCabinetException(typeof (this).stringof ~ ": " ~
	                              context ~ ": " ~ this.getTokyoErrMsg(errcode));
	    }
	}
}
