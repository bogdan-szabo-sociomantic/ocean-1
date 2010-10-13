/*******************************************************************************

    UnitTest main 
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        Gavin Norman, David Eckardt
    				Thomas Nicolai, Lars Kirchhoff, 
                    Mathias Baumann
    
 ******************************************************************************/

module ocean.test.main;

/*******************************************************************************
 	
 	Imports
 	
 ******************************************************************************/

private import ocean.core.Array,
               ocean.core.ArrayMap,
               ocean.core.ObjectThreadPool,
               ocean.core.UniStruct;

private import ocean.io.Retry;

private import ocean.io.compress.Lzo;
private import ocean.io.compress.lzo.LzoChunk,
               ocean.io.compress.lzo.LzoHeader;

private import ocean.io.digest.Fnv1;

private import ocean.io.device.queue.RingQueue;

private import ocean.io.serialize.SimpleSerializer,
               ocean.io.serialize.StructSerializer;

private import ocean.net.http.Url;

private import ocean.text.entities.XmlEntityCodec;
private import ocean.text.utf.UtfString;
private import ocean.text.ling.ngram.NGramParser,
               ocean.text.ling.ngram.NGramSet;



/*******************************************************************************
	
	Default memory buffer allocation
	
	This memory buffer is set to simulate a high memory usage within a 
	program. It is needed to identify Garbage Collector activity which 
	degrades performance.
	The allocation needs to be done in the unittest scope because main 
	is executed after all unitests have been executed successfully.
	
 ******************************************************************************/

unittest 
{
	// 200 million bytes of memory is allocated to ensure that any performance
	// checks in unittests are operating under a normal / stressed condition.
	static char[] dummy;
	dummy.length = 200_000_000;
}


void main () {}

