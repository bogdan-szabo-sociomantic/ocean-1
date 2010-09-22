/*******************************************************************************

	copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
	
	version:        July 2010: Initial release
	
	authors:        Gavin Norman
	
	Class to contain and compare sets of ngrams from analyses of texts.

    TODO: usage example

    Note: the ngrams in the set are stored as *slices* into the original text.
    So make sure the original text is still in memory, otherwise the slices will
    be invalid.

*******************************************************************************/

module text.ling.ngram.NGramSet;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.core.ArrayMap;

private	import tango.core.BitArray;

private	import tango.io.model.IConduit;

private import tango.math.Math : abs;

private import ocean.io.digest.Fnv1;

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

    public alias ArrayMap!(uint, dchar[], ThreadSafe) NGramCountArray;
    public alias ArrayMap!(float, dchar[], ThreadSafe) NGramRelFreqArray;


	/***************************************************************************

		The array mapping from ngram -> count / frequency.

	***************************************************************************/

    private NGramCountArray ngrams;
    private NGramRelFreqArray ngrams_rel_freq;

    
    /***************************************************************************

        Flag which is set to true when the relative frequencies array is out of
        date.

    ***************************************************************************/

    private bool rel_freq_invalid;
    

	/***************************************************************************
	
		A list of ngrams, sorted in descending order of frequency (that is,
		highest first).
		
		This list is maintained as the associative array (this.ngrams) cannot be
		sorted itself. The strings in this.sorted_ngrams are just slices into
		the keys of this.ngrams.
	
	***************************************************************************/
	
	private dchar[][] sorted_ngrams;


    /***************************************************************************

        List of ngrams to be removed - used internally by keepHighestCount().
    
    ***************************************************************************/

    private dchar[][] remove_list;

	
    /***************************************************************************

        Constructor. Initialises the internal array map.
    
    ***************************************************************************/
    
    public this ( )
    {
        this.ngrams = new NGramCountArray(1000);
        this.ngrams_rel_freq = new NGramRelFreqArray(1000);
    }


	/***************************************************************************
	
		Clears all ngrams from this set.
	
	***************************************************************************/
	
	public void clear ( )
	{
        this.ngrams.clear();
        this.ngrams_rel_freq.clear();

        this.rel_freq_invalid = false;
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
        this.rel_freq_invalid = true;
	}
	
	
	/***************************************************************************
	
		Increases the frequency for an ngram by one.
	
		Params:
			ngram = ngram string to increment
	
	***************************************************************************/

    public void addOccurrence ( dchar[] ngram, uint occurrences = 1 )
	{
		if ( ngram in this.ngrams )
		{
			auto freq = this.ngrams[ngram];
			this.ngrams[ngram] = freq + occurrences;
		}
		else
		{
			this.ngrams[ngram] = occurrences;
		}
        this.rel_freq_invalid = true;
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
		foreach ( ngram, count; this.ngrams )
		{
			total += count;
		}
	
		return total;
	}


	/***************************************************************************
	
		foreach iterator over all the ngrams in the set.
	
	***************************************************************************/

    public int opApply ( int delegate ( ref dchar[], ref uint ) dg )
    {
        int result;
        foreach ( ngram, count; this.ngrams )
        {
            result = dg(ngram, count);
            if ( result )
            {
                break;
            }
        }
    
        return result;
    }


    /***************************************************************************
	
		Generates the sorted list of ngrams, by count (highest first).
	
	***************************************************************************/
	
	public void sortByCount ( )
	{
        this.sort_(this.ngrams.length, this.ngrams);
	}

	
	/***************************************************************************

		Generates the sorted list of ngrams, by count (highest first).

		Params:
			max_ngrams = maximum number of ngrams to include in the sorted array

	***************************************************************************/

	public void sortByCount ( uint max_ngrams )
	{
        this.sort_(max_ngrams, this.ngrams);
	}


    /***************************************************************************
    
        Generates the sorted list of ngrams, by relative frequency (highest
        first).
    
    ***************************************************************************/

    public void sortByRelFreq ( )
    {
        this.updateRelFreqs();
        this.sort_(this.ngrams.length, this.ngrams_rel_freq);
    }


    /***************************************************************************

        Generates the sorted list of ngrams, by relative frequency (highest
        first).
    
        Params:
            max_ngrams = maximum number of ngrams to include in the sorted array
    
    ***************************************************************************/

    public void sortByRelFreq ( uint max_ngrams )
    {
        this.updateRelFreqs();
        this.sort_(max_ngrams, this.ngrams_rel_freq);
    }


    /***************************************************************************
    
        Returns:
            the list of sorted ngrams

        Throws:
            asserts that the list of sorted ngrams list has been generated
    
    ***************************************************************************/
    
    public dchar[][] getSorted ( )
    in
    {
        assert(this.sorted_ngrams.length, typeof(this).stringof ~ ".sorted - ngram set has not been sorted");
    }
    body
    {
        return this.sorted_ngrams;
    }


	/***************************************************************************
	
		Reduces the size of the ngram set to just the highest count n.
		
		Params:
			num = maximum number of ngrams to keep
	
	***************************************************************************/

    public void keepHighestCount ( uint num )
    {
        this.ensureWithinRange(num);

        BitArray keep;
        this.findHighestCount(num, keep);

        size_t index;
        this.remove_list.length = 0;
        foreach ( ngram, count; this.ngrams )
        {
            if ( !keep[index] )
            {
                this.remove_list.length = this.remove_list.length + 1;
                this.remove_list[$ - 1] = ngram;
            }
            index++;
        }

        foreach ( ngram; this.remove_list )
        {
            this.ngrams.remove(ngram);
        }
        this.remove_list.length = 0;

        this.sorted_ngrams.length = 0;

        this.rel_freq_invalid = true;
    }


    /***************************************************************************
    
        Reduces the size of the ngram set by the provided filtering delegate.
        The delegate is passed each ngram and its count in turn, and should
        return true if the ngram should be filtered (removed from the set).
        
        Params:
            filter_dg = filtering delegate
    
    ***************************************************************************/

    public void filter ( bool delegate ( dchar[], uint ) filter_dg )
    {
    	this.remove_list.length = 0;

    	foreach ( ngram, count; this.ngrams )
        {
            if ( filter_dg(ngram, count) )
            {
                this.remove_list.length = this.remove_list.length + 1;
                this.remove_list[$ - 1] = ngram;
            }
        }

        foreach ( ngram; this.remove_list )
        {
            this.ngrams.remove(ngram);
        }
        this.remove_list.length = 0;

        this.rel_freq_invalid = true;
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

        float total_distance = 0;

        foreach ( ngram, count; compare )
        {
            if ( !(ngram in this.ngrams) )
            {
                total_distance += 1;
                continue;
            }

            float ngram_distance = abs(compare.getRelFreq(ngram) - this.getRelFreq(ngram));

            total_distance += ngram_distance;

//            debug Trace.format("'{}' ({}% / {}%): {}%,  ", ngram, this.getRelFreq(ngram) * 100, compare.getRelFreq(ngram) * 100, ngram_distance * 100);
        }

        return total_distance / cast(float) compare.length;
    }

    // TODO
    public float distance ( This compare, dchar[][] ngrams )
    {
        if ( ngrams.length == 0 )
        {
            return 1.0;
        }

        float total_distance = 0;

        foreach ( ngram; ngrams )
        {
            if ( !(ngram in this.ngrams) )
            {
                total_distance += 1;
                continue;
            }

            float ngram_distance = abs(compare.getRelFreq(ngram) - this.getRelFreq(ngram));

            total_distance += ngram_distance;

//            debug Trace.format("'{}' ({}% / {}%): {}%,  ", ngram, this.getRelFreq(ngram) * 100, compare.getRelFreq(ngram) * 100, ngram_distance * 100);
        }

        return total_distance / cast(float) ngrams.length;
    }


    /***************************************************************************
    
        Tells if the given ngram is in this set.
        
        Params:
            ngram = ngram to test
            
        Returns:
            true if the ngram is in this set
    
    ***************************************************************************/

    public bool opIn_r ( dchar[] ngram )
    {
        return !!(ngram in this.ngrams);
    }
    
    
    /***************************************************************************
    
        Gets the number of times an ngram has occurred.
        
        Params:
            ngram = ngram string to check
        
        Returns:
            frequency of occurrence
    
    ***************************************************************************/

    public uint getCount ( dchar[] ngram )
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
    
        Gets the relative frequency of an ngram. The relative frequencies are
        updated if they're out of date.
        
        Params:
            ngram = ngram to test
            
        Returns:
            the ngram's relative frequency
    
    ***************************************************************************/
    
    public float getRelFreq ( dchar[] ngram )
    {
        this.updateRelFreqs();
    
        if ( ngram in this.ngrams_rel_freq )
        {
            return this.ngrams_rel_freq[ngram];
        }
        else
        {
            return 0.0;
        }
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

            // TODO: pretty sure this needs a dup here?
            // It's a shame, when an ngram set is parsed straight from a source
            // text, all the ngrams are just slices into that text.
            // But when a set is deserialized like this, they're all individual
            // strings, which doesn't take advantage of their overlapping.
			this.add(ngram, freq);
		}
	}


	debug
    {
        /***********************************************************************

            Prints the ngram set to Trace.
        
        ***********************************************************************/

        public void traceDump ( )
    	{
            foreach ( ngram, count; this.ngrams )
    		{
    			Trace.format("'{}': {},  ", ngram, count);
    		}
            Trace.formatln("");
    	}

        /***********************************************************************

            Prints the sorted ngram set to Trace.
        
        ***********************************************************************/
    
        public void traceDumpSorted ( )
        {
            this.ensureSorted(this.ngrams.length);

            foreach ( ngram; this.sorted_ngrams )
            {
                Trace.format("'{}': {},  ", ngram, this.ngrams[ngram]);
            }
            Trace.formatln("");
        }
    }


    /***************************************************************************

        Generates the sorted list of ngrams, by relative frequency (highest
        first).
    
        Params:
            max_ngrams = maximum number of ngrams to include in the sorted array
    
    ***************************************************************************/

    private void sort_ ( N ) ( uint max_ngrams, N ngrams )
    {
        this.sorted_ngrams.length = 0;
    
        if ( max_ngrams > this.ngrams.length )
        {
            max_ngrams = this.ngrams.length;
        }

        BitArray ngram_copied;
        ngram_copied.length = ngrams.length;
    
        uint count;
        while ( count < max_ngrams )
        {
            size_t highest_index;
            N.ValueType highest_value;
            dchar[] highest_ngram;
            size_t index;
            foreach ( ngram, value; ngrams )
            {
                if ( value > highest_value && !ngram_copied[index] )
                {
                    highest_ngram = ngram;
                    highest_value = value;
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
	
		Checks whether the sorted array has been generated for at leats the
		number of items desired, and if it hasn't then calls the sort method.
		
		Params:
			max_items = maximum number of items to sort
		
	***************************************************************************/

    private void ensureSorted ( uint max_items )
	{
		if ( this.ngrams.length && this.sorted_ngrams.length < max_items )
		{
			this.sortByCount(max_items);
		}
	}


	/***************************************************************************
	
		Checks whether the passed integer is within the range of the number of
		ngrams in the set, and limits it if it's greater.
		
		Params:
			num = ngram index
		
	***************************************************************************/

    private void ensureWithinRange ( ref uint num )
	{
		if ( num > this.ngrams.length )
		{
			num = this.ngrams.length;
		}
	}


    /***************************************************************************
    
        Computes the relative frequencies of the ngrams in the set, if the
        currently computed relative frequencies are out of date.
        
    ***************************************************************************/

    private void updateRelFreqs ( )
    {
        if ( this.rel_freq_invalid )
        {
            auto total_ngrams = this.countOccurrences();

            foreach ( ngram, count; this.ngrams )
            {
                float rel_freq = cast(float) count / cast(float) total_ngrams;
                this.ngrams_rel_freq[ngram] = rel_freq;
            }

            this.rel_freq_invalid = false;
        }
    }


    /***************************************************************************

        Finds the n ngrams with the highest occurrence count.
        
        Params:
            max_ngrams = number to find
            already_included = bit array, where the value of bit[i] represents
                whether this.ngrams[i] is included in the highest number.

    ***************************************************************************/

    private void findHighestCount ( uint max_ngrams, ref BitArray already_included )
    {
        already_included.length = this.ngrams.length;

        uint count;
        while ( count < max_ngrams )
        {
            auto highest_index = findHighestCount(already_included);
            already_included[highest_index] = true;
            count++;
        }
    }


    /***************************************************************************

        Finds the next highest count ngram.
        
        Params:
            already_included = bit array, where the value of bit[i] represents
                whether this.ngrams[i] is included in the highest number.

        Returns:
            highest ngram (string)

    ***************************************************************************/

    private size_t findHighestCount ( ref BitArray already_included )
    {
        size_t highest_index;
        uint highest_value;
        size_t index;
        foreach ( ngram, value; this.ngrams )
        {
            if ( value > highest_value && !already_included[index] )
            {
                highest_value = value;
                highest_index = index;
            }

            index++;
        }

        return highest_index;
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

    private void write ( T ) ( T data, OutputStream output )
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

    private void writeData ( void* data, size_t bytes, OutputStream output )
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

    private void read ( T ) ( out T data, InputStream input )
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

    private void readData ( void* data, size_t bytes, InputStream input)
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

