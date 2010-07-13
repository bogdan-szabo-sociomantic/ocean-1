/*******************************************************************************

	copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
	
	version:        July 2010: Initial release
	
	authors:        Gavin Norman
	
	Class to contain and compare sets of ngrams from analyses of texts.

*******************************************************************************/

module text.ling.ngram.NGramSet;



/*******************************************************************************

	Imports

*******************************************************************************/

private	import tango.core.Array;
private	import tango.core.BitArray;

private	import tango.io.device.Conduit;

debug
{
	private import tango.util.log.Trace;
}



/*******************************************************************************

	NGramSet class

*******************************************************************************/

class NGramSet ( Char )
{
	/***************************************************************************

		Check that the template parameter is a character type.

	***************************************************************************/

	static assert ( is(Char == dchar) || is(Char == wchar) || is(Char == char),
		"NGramSet: template paramater Char must be one of: {char, wchar, dchar}" );


	/***************************************************************************

		Alias for the associative array used to store the ngram -> frequency
		mapping.

	***************************************************************************/

	public alias uint[Char[]] NGramArray;


	/***************************************************************************

		Alias for the ngram iterator.
	
	***************************************************************************/

	public alias NGramSetIterator!(Char) Iterator;


	/***************************************************************************

		The array mapping from ngram -> frequency.

	***************************************************************************/

	protected NGramArray ngrams;


	/***************************************************************************
	
		A list of ngrams, sorted in descending order of frequency (that is,
		highest first).
		
		This list is maintained as the associative array (this.ngrams) cannot be
		sorted itself. The strings in this.sorted_ngrams are just slices into
		the keys of this.ngrams.
	
	***************************************************************************/
	
	protected Char[][] sorted_ngrams;
	
	
	/***************************************************************************
	
		Clears all ngrams from this set.
	
	***************************************************************************/
	
	public void clear ( )
	{
		this.ngrams = this.ngrams.init;
		this.sorted_ngrams.length = 0;
	}
	
	
	/***************************************************************************
	
		Adds an ngram to this set with its frequency.
	
		Params:
			ngram = ngram string to add
			freq = frequency of ngram
	
	***************************************************************************/
	
	public void add ( Char[] ngram, uint freq )
	{
		this.ngrams[ngram] = freq;
	}
	
	
	/***************************************************************************
	
		Increases the frequency for an ngram by one.
	
		Params:
			ngram = ngram string to increment
	
	***************************************************************************/
	
	public void incrementCount ( Char[] ngram )
	{
		this.ngrams[ngram]++;
	}
	
	
	/***************************************************************************
	
		Gets the number of unique ngrams which are in this set.
	
		Returns:
			number of ngrams
	
	***************************************************************************/
	
	public size_t length ( )
	{
		return this.ngrams.length;
	}
	
	
	/***************************************************************************
	
		Calculates the total number of ngrams in this set. This is simply
		the sum of the frequencies of all ngrams in the map.
	
		Returns:
			total number of ngrams
	
	***************************************************************************/
	
	public uint nGramOccurrences ( )
	{
		uint total;
		foreach ( ngram, freq; this.ngrams )
		{
			total += freq;
		}
	
		return total;
	}
	
	
	/***************************************************************************
	
		foreach iterator over all the ngrams in the set. The iterator loops over
		the *sorted* list of ngrams, returning them in order of descending
		frequency.
	
	***************************************************************************/
	
	public int opApply ( int delegate ( ref Char[], ref uint ) dg )
	{
		this.ensureSorted(this.ngrams.length);
	
		int result;
		foreach ( ngram; this.sorted_ngrams )
		{
			auto freq = this.ngrams[ngram];
			result = dg(ngram, freq);
			if ( result )
			{
				break;
			}
		}
	
		return result;
	}
	
	
	/***************************************************************************
	
		Generates the sorted list of ngrams, by frequency (highest first).
	
	***************************************************************************/
	
	public void sort ( )
	{
		this.sort(this.ngrams.length);
	}
	
	
	/***************************************************************************

		Generates the sorted list of ngrams, by frequency (highest first).

		Params:
			max_ngrams = maximum number of ngrams to include in the sorted array

	***************************************************************************/

	public void sort ( uint max_ngrams )
	{
		this.sorted_ngrams.length = 0;

		BitArray ngram_copied;
		ngram_copied.length = this.ngrams.length;
		
		uint count;
		while ( count < max_ngrams )
		{
	    	uint highest_freq, highest_index;
	    	Char[] highest_ngram;
	    	uint index;
	    	foreach ( ngram, freq; this.ngrams )
	    	{
	    		if ( freq > highest_freq && !ngram_copied[index] )
	    		{
	    			highest_ngram = ngram;
	    			highest_freq = freq;
	    			highest_index = index;
	    		}

	    		index++;
	    	}

	    	this.sorted_ngrams ~= highest_ngram;
	    	ngram_copied[highest_index] = true;
	    	count++;
		}
	}


	/***************************************************************************
	
		Copies the highest frequency ngrams in the set into another set.
		
		Params:
			copy_to = set to copy into
			num = maximum number of ngrams to copy
	
	***************************************************************************/
	
	public void copyHighest ( NGramSet copy_to, uint num )
	{
		this.ensureWithinRange(num);
		this.ensureSorted(num);
	
		for ( uint i; i < num; i++ )
		{
			auto ngram = this.sorted_ngrams[i];
			auto freq = this.ngrams[ngram];
			copy_to.ngrams[ngram.dup] = freq;
		}
	}
	
	
	/***************************************************************************
	
		Copies the highest frequency ngrams in the set into an associative
		array.
		
		Params:
			copy_to = array to copy into
			num = maximum number of ngrams to copy
	
	***************************************************************************/
	
	public void copyHighest ( out NGramArray copy_to, uint num )
	{
		this.ensureWithinRange(num);
		this.ensureSorted(num);
	
		for ( uint i; i < num; i++ )
		{
			auto ngram = this.sorted_ngrams[i];
			auto freq = this.ngrams[ngram];
			copy_to[ngram.dup] = freq;
		}
	}


	/***************************************************************************
	
		Reduces the size of the ngram set to just the highest frequency n.
		
		Params:
			num = maximum number of ngrams to keep
	
	***************************************************************************/

	public void cropToHighest ( uint num )
	{
		this.ensureWithinRange(num);
		this.ensureSorted(this.ngrams.length);

		foreach ( ngram; this.sorted_ngrams[num..$] )
		{
			this.ngrams.remove(ngram);
		}

		this.sorted_ngrams.length = num;
	}

	
	/***************************************************************************
	
		Returns an iterator over the highest frequency n ngrams in the set.
		
		Params:
			num = maximum number of ngrams to iterator over

		Returns:
			an iterator over the ngrams in the range specified
	
	***************************************************************************/

	public Iterator getHighest ( uint num )
	{
		Iterator it;
		it.num = num;
		it.ngrams = this;

		return it;
	}


	
	/***************************************************************************
	
		Gets the number of times an ngram has occurred.
		
		Params:
			ngram = ngram string to check
		
		Returns:
			frequency of occurrence
	
	***************************************************************************/
	
	public uint nGramFreq ( Char[] ngram )
	{
		return this.ngrams[ngram];
	}
	
	
	/***************************************************************************
	
		Compares another ngram set to this one, and works out the distance
		between them.
		
		The distance is computed by accumulating the difference in the relative
		frequency of each ngram in both sets, then dividing by the number of
		ngrams compared.

		Params:
			compare = set to compare against
	
		Returns:
			distance between sets:
				0.0 = totally similar
				1.0 = totally different
	
	***************************************************************************/
	
	public float distance ( NGramSet compare )
	{
		auto total_ngrams = this.nGramOccurrences();
		auto comp_total_ngrams = compare.nGramOccurrences();
	
		float total_distance = 0;
		foreach ( comp_ngram, comp_freq; compare )
		{
			if ( !(comp_ngram in this.ngrams) )
			{
				total_distance += 1;
				continue;
			}
	
			float comp_rel_freq = cast(float) comp_freq / cast(float) comp_total_ngrams;
			float rel_freq = cast(float) this.nGramFreq(comp_ngram) / cast(float) total_ngrams;
			float ngram_distance = comp_rel_freq - rel_freq;

			if ( ngram_distance < 0 )
			{
				ngram_distance = -ngram_distance;
			}
	
			total_distance += ngram_distance;
		}
	
		return total_distance / cast(float) compare.length;
	}


	/***************************************************************************
	
		Gets an ngram referenced by its index in the sorted list.
		
		Params:
			i = index
			
		Returns:
			the ngram string at the given index

		Throws:
			asserts that the index is within range
	
	***************************************************************************/

	public Char[] opIndex ( size_t i )
	in
	{
		assert(i < this.ngrams.length, "TODO");
	}
	body
	{
		this.ensureSorted(i);
		return this.sorted_ngrams[i];
	}


	// TODO
	public void serialize ( Conduit c )
	{
	}


	// TODO
	public void deserialize ( Conduit c )
	{
	}


	/***************************************************************************
	
		Prints the ngram set to Trace.
	
	***************************************************************************/

	debug public void traceDump ( uint num )
	{
		foreach ( ngram, freq; this.getHighest(num) )
		{
			Trace.formatln("{}: {}", ngram, freq);
		}
	}
	
	
	/***************************************************************************
	
		Checks whether the sorted array has been generated for at leats the
		number of items desired, and if it hasn't then calls the sort method.
		
		Params:
			max_items = maximum number of items to sort
		
	***************************************************************************/

	protected void ensureSorted ( uint max_items )
	{
		if ( this.ngrams.length && this.sorted_ngrams.length < max_items )
		{
			this.sort();
		}
	}

	/***************************************************************************
	
		Checks whether the passed integer is within the range of the number of
		ngrams in the set, and limits it if it's greater.
		
		Params:
			num = ngram index
		
	***************************************************************************/

	protected void ensureWithinRange ( ref uint num )
	{
		if ( num > this.ngrams.length )
		{
			num = this.ngrams.length;
		}
	}
}



/*******************************************************************************

	NGramSetIterator struct.

*******************************************************************************/

struct NGramSetIterator ( Char )
{
	/***************************************************************************

		Check that the template parameter is a character type.
	
	***************************************************************************/
	
	static assert ( is(Char == dchar) || is(Char == wchar) || is(Char == char),
		"NGramSetIterator: template paramater Char must be one of: {char, wchar, dchar}" );


	/***************************************************************************

		Number of ngramsto iterate over (the n highest frequency).
	
	***************************************************************************/

	public uint num;


	/***************************************************************************

		A reference to the NGramSet object to iteratoe over.
	
	***************************************************************************/

	public NGramSet!(Char) ngrams;
	

	/***************************************************************************

		foreach iterator over the given ngram set.
	
	***************************************************************************/

	public int opApply ( int delegate ( ref Char[] ngram, ref uint freq ) dg )
	{
		this.ngrams.ensureWithinRange(this.num);
		this.ngrams.ensureSorted(this.num);
		
		int result;
		foreach ( ngram; this.ngrams.sorted_ngrams[0..this.num] )
		{
			auto freq = this.ngrams.nGramFreq(ngram);
			result = dg(ngram, freq);
			if ( result )
			{
				break;
			}
		}
	
		return result;
	}
}


