module ocean.test.main;



import ocean.core.Array;
import ocean.core.ArrayMap;
import ocean.core.ObjectThreadPool;

import ocean.io.digest.Fnv1;

import ocean.io.Retry;
import ocean.io.device.QueueMemory;

import ocean.net.http.Url;

import ocean.text.entities.XmlEntityCodec;

import ocean.text.utf.UtfString;

import ocean.text.ling.ngram.NGramParser;
import ocean.text.ling.ngram.NGramSet;



void main ()
{
	// 200 million bytes of memory is allocated to ensure that any performance
	// checks in unittests are operating under a normal / stressed condition.
	scope dummy = new char[200_000_000]; 
}

