/*******************************************************************************

    UnitTest main 
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        Gavin Norman, David Eckardt
    				Thomas Nicolai, Lars Kirchhoff
    
 ******************************************************************************/

module ocean.test.main;

/*******************************************************************************
 	
 	Imports
 	
 ******************************************************************************/

private import 	ocean.core.Array;
private import 	ocean.core.ArrayMap;
private import 	ocean.core.ObjectThreadPool;


private import 	ocean.io.digest.Fnv1;
private import 	ocean.io.Retry;
private import 	ocean.io.device.QueueMemory;


private import 	ocean.net.http.Url;


private import 	ocean.text.entities.XmlEntityCodec;
private import 	ocean.text.utf.UtfString;
private import 	ocean.text.ling.ngram.NGramParser;
private import 	ocean.text.ling.ngram.NGramSet;



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

