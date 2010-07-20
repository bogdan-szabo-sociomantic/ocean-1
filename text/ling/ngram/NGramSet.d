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

private	import ocean.core.ArrayMap;

private	import tango.core.BitArray;

private	import tango.io.model.IConduit;

debug
{
	private import tango.util.log.Trace;
	private import Utf = tango.text.convert.Utf;
}



/*******************************************************************************

	Convenience aliases for the NGramSet template class.
	
*******************************************************************************/

public alias NGramSet_!(false) NGramSet;
public alias NGramSet_!(true) ThreadSafeNGramSet;



/*******************************************************************************

	NGramSet class template
	
	Template params:
		ThreadSafe = sets up the internal ArrayMap to be thread safe. Set this
			parameter to true if you need to access a single NGramSet from
			multiple threads.

*******************************************************************************/

class NGramSet_ ( bool ThreadSafe = false )
{
	/***************************************************************************

		This alias.

	***************************************************************************/

	public alias typeof(this) This;


	/***************************************************************************

		Alias for the associative array used to store the ngram -> frequency
		mapping.

	***************************************************************************/

	public alias ArrayMapKV!(uint, dchar[], ThreadSafe) NGramArray;


	/***************************************************************************

		Alias for the ngram set iterator.

	***************************************************************************/

	public alias NGramSetIterator_!(ThreadSafe) Iterator;


	/***************************************************************************

		The array mapping from ngram -> frequency.

	***************************************************************************/

	protected NGramArray ngrams;


	/***************************************************************************

		Constructor. Initialises the internal array map.
	
	***************************************************************************/

	public this ( )
	{
		this.ngrams = new NGramArray(1000);
	}


	/***************************************************************************
	
		A list of ngrams, sorted in descending order of frequency (that is,
		highest first).
		
		This list is maintained as the associative array (this.ngrams) cannot be
		sorted itself. The strings in this.sorted_ngrams are just slices into
		the keys of this.ngrams.
	
	***************************************************************************/
	
	protected dchar[][] sorted_ngrams;
	
	
	/***************************************************************************
	
		Clears all ngrams from this set.
	
	***************************************************************************/
	
	public void clear ( )
	{
		this.ngrams.clear();
		this.sorted_ngrams.length = 0;
	}
	
	
	/***************************************************************************
	
		Adds an ngram to this set with its frequency.
	
		Params:
			ngram = ngram string to add
			freq = frequency of ngram
	
	***************************************************************************/
	
	public void add ( dchar[] ngram, uint freq )
	{
		this.ngrams[ngram] = freq;
	}
	
	
	/***************************************************************************
	
		Increases the frequency for an ngram by one.
	
		Params:
			ngram = ngram string to increment
	
	***************************************************************************/
	
	public void addOccurrence ( dchar[] ngram )
	{
		if ( ngram in this.ngrams )
		{
			auto freq = this.ngrams[ngram];
			this.ngrams[ngram] = freq + 1;
		}
		else
		{
			this.ngrams[ngram] = 1;
		}
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
	
	public uint countOccurrences ( )
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
	
	public int opApply ( int delegate ( ref dchar[], ref uint ) dg )
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
	    	dchar[] highest_ngram;
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
	
	public void copyHighest ( This copy_to, uint num )
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
	
	public uint nGramFreq ( dchar[] ngram )
	{
		if ( ngram in this.ngrams )
		{
			return this.ngrams[ngram];
		}
		else
		{
			return 0;
		}
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
	
	public float distance ( This compare )
	{
		if ( compare.length == 0 )
		{
			return 1.0;
		}

		auto total_ngrams = this.countOccurrences();
		auto comp_total_ngrams = compare.countOccurrences();
	
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

	public dchar[] opIndex ( size_t i )
	in
	{
		assert(i < this.ngrams.length, typeof(this).stringof ~ "opIndex - index out of bounds");
	}
	body
	{
		this.ensureSorted(i);
		return this.sorted_ngrams[i];
	}


	/***************************************************************************
	
		Writes this ngram set to the provided output stream.
		
		Params:
			output = stream to write to
			
	***************************************************************************/

	public void serialize ( OutputStream output )
	{
		this.write(this.ngrams.length, output);

		foreach ( ngram, freq; this.ngrams )
		{
			this.write(ngram, output);
			this.write(freq, output);
		}
	}


	/***************************************************************************
	
		Reads this ngram set from the provided input stream.
		
		Params:
			input = stream to read from
			
	***************************************************************************/

	public void deserialize ( InputStream input )
	{
		this.clear();

		size_t length;
		this.read(length, input);

		for ( uint i; i < length; i++ )
		{
			dchar[] ngram;
			this.read(ngram, input);

			uint freq;
			this.read(freq, input);

			this.add(ngram, freq);
		}
	}


	/***************************************************************************
	
		Prints the ngram set to Trace.
	
	***************************************************************************/

	debug public void traceDump ( )
	{
		this.traceDump(this.length);
	}

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


	/***************************************************************************

		Writes something to an output stream. Single elements are written
		straight to the output stream, while array types have their length
		written, followed by each element.

		Template params:
			T = type of data to write

		Params:
			data = data to write
			output = output stream to write to
		
	***************************************************************************/

	protected void write ( T ) ( T data, OutputStream output )
	{
		static if ( is ( T A == A[] ) )
		{
			this.write(data.length, output);

			foreach ( d; data )
			{
				this.write(d, output);
			}
		}
		else
		{
			this.writeData(&data, T.sizeof, output);
		}
	}


	/***************************************************************************

		Writes data to an output stream.
	
		Params:
			data = pointer to data to write
			bytes = length of data in bytes
			output = output stream to write to
		
	***************************************************************************/

	protected void writeData ( void* data, size_t bytes, OutputStream output )
	{
		do
		{
			auto ret = output.write(data[0..bytes]);
			data += ret;
			bytes -= ret;
		} while ( bytes > 0 );
	}


	/***************************************************************************

		Reads something from an input stream. Single elements are read straight
		from the input stream, while array types have their length read,
		followed by each element.
	
		Template params:
			T = type of data to read
	
		Params:
			data = data to read
			input = input stream to read from
		
	***************************************************************************/

	protected void read ( T ) ( out T data, InputStream input )
	{
		static if ( is ( T A == A[] ) )
		{
			size_t length;
			this.read(length, input);
			for ( uint i; i < length; i++ )
			{
				A d;
				this.read(d, input);
				data ~= d;
			}
		}
		else
		{
			this.readData(&data, data.sizeof, input);
		}
	}


	/***************************************************************************

		Reads data from an input stream.
	
		Params:
			data = pointer to data to read
			bytes = length of data in bytes
			input = input stream to read from
		
	***************************************************************************/

	protected void readData ( void* data, size_t bytes, InputStream input)
	{
		size_t ret;
		do
		{
			ret = input.read(data[0..bytes]);
			data += ret;
			bytes -= ret;
		} while ( bytes > 0 && ret != IOStream.Eof );
	}
}



/*******************************************************************************

	NGramSetIterator struct.

*******************************************************************************/

struct NGramSetIterator_ ( bool ThreadSafe = false )
{
	/***************************************************************************

		Number of ngrams to iterate over (the n highest frequency).
	
	***************************************************************************/

	public uint num;


	/***************************************************************************

		A reference to the NGramSet object to iterate over.
	
	***************************************************************************/

	public NGramSet_!(ThreadSafe) ngrams;
	

	/***************************************************************************

		foreach iterator over the given ngram set.
	
	***************************************************************************/

	public int opApply ( int delegate ( ref dchar[] ngram, ref uint freq ) dg )
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



debug ( OceanUnitTest )
{
	import tango.util.log.Trace;
	import tango.io.device.File;
	
	unittest
	{
        Trace.formatln("Running ocean.text.ling.ngram.NGramSet unittest");

        // Create an ngram set
		scope ngramset = new NGramSet;

		dchar[][] ngrams = ["hel", "ell", "llo", "hel"];
		foreach ( n; ngrams )
		{
			ngramset.addOccurrence(n);
		}
		assert(ngramset.countOccurrences() == ngrams.length);
		Trace.formatln("NGrams:");
		ngramset.traceDump();

		// Write the ngram set to a file
		scope file = new File("test_file", File.WriteCreate);
		scope ( exit ) file.close();

		ngramset.serialize(file);
		file.close;
		
		// Load the file into a new ngram set
		scope ngramset2 = new NGramSet;
		scope file2 = new File("test_file", File.ReadExisting);
		scope ( exit ) file2.close();
		ngramset2.deserialize(file2);

		Trace.formatln("NGrams read from file:");
		ngramset2.traceDump();

		// Check that the file has been serialized correctly
		assert(ngramset.length == ngramset2.length, "ocean.text.ling.ngram.NGramSet unittest - file read has wrong number of ngrams");
		foreach ( ngram, freq; ngramset2 )
		{
			assert(ngramset.nGramFreq(ngram) == freq, "ocean.text.ling.ngram.NGramSet unittest - ngram in file read has wrong frequency");
		}

		Trace.formatln("\nDone unittest\n");
	}
}

