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

private     import  tango.stdc.stdlib: free;
private     import  tango.stdc.string: strlen;

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

class TokyoCabinetB
{

}
