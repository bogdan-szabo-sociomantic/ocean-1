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

private import ocean.io.serialize.SimpleSerializer;

private	import tango.core.BitArray;

private	import tango.io.model.IConduit;

private import tango.math.Math : abs;

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
	
		List of sorted ngrams resulting from one of the sort methods.
		
		This list is maintained as the associative array (this.ngrams) cannot be
		sorted itself. The strings in this.sorted_ngrams are just slices into
		the keys of this.ngrams.
	
	***************************************************************************/
	
	private dchar[][] sorted_ngrams;


    /***************************************************************************

        List of pre-calculated ngram hashes, corresponding to the order of the
        ngrams in this.ngrams. The hashes are precalculated to speed up distance
        calculations, which are often repeated over and over.
    
    ***************************************************************************/

    private hash_t[] ngrams_hashes;


    /***************************************************************************

        List of ngrams to be removed - used internally by keepHighestCount() and
		filter().
    
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

        this.recalcNeeded();
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
        this.recalcNeeded();
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

        this.recalcNeeded();
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

    public int opApply ( int delegate ( ref dchar[] ) dg )
    {
        int result;
        foreach ( ngram, count; this.ngrams )
        {
            result = dg(ngram);
            if ( result )
            {
                break;
            }
        }
    
        return result;
    }


    /***************************************************************************
    
        foreach iterator over all the ngrams in the set and their count.
    
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
    
        foreach iterator over all the ngrams in the set and their relative
        frequency.
    
    ***************************************************************************/

    public int opApply ( int delegate ( ref dchar[], ref float ) dg )
    {
        this.updateRelFreqs();

        int result;
        foreach ( ngram, freq; this.ngrams_rel_freq )
        {
            result = dg(ngram, freq);
            if ( result )
            {
                break;
            }
        }
    
        return result;
    }


    /***************************************************************************
    
        foreach iterator over all the ngrams in the set, their count and their
        hashes.
    
    ***************************************************************************/

    public int opApply ( int delegate ( ref dchar[], ref uint, ref hash_t ) dg )
    {
        this.updateHashes();

        int result;
        size_t i;
        foreach ( ngram, count; this.ngrams )
        {
            result = dg(ngram, count, this.ngrams_hashes[i]);
            if ( result )
            {
                break;
            }

            i++;
        }
    
        return result;
    }


    /***************************************************************************
    
        foreach iterator over all the ngrams in the set, their relative
        frequency and their hashes.
    
    ***************************************************************************/

    public int opApply ( int delegate ( ref dchar[], ref float, ref hash_t ) dg )
    {
        this.updateRelFreqs();
        this.updateHashes();

        int result;
        size_t i;
        foreach ( ngram, freq; this.ngrams_rel_freq )
        {
            result = dg(ngram, freq, this.ngrams_hashes[i]);
            if ( result )
            {
                break;
            }

            i++;
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
        if ( num >= this.ngrams.length )
        {
            return;
        }

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

        this.recalcNeeded();
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

        this.recalcNeeded();
    }


	/***************************************************************************
	
		Compares another ngram set to this one, and works out the distance
		between them.
		
		The distance is computed by accumulating the difference in the relative
		frequency of each ngram in both sets, then dividing by the number of
		ngrams compared.

        Note: To speed up repeated comparisons with the same ngram set, the
        hashes of the compared ngrams are precalculated, to avoid having to
        calculate them on every call to this.ngrams.exists().

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
        size_t i;
        foreach ( dchar[] compare_ngram, float compare_freq, hash_t compare_hash; compare )
        {
            if ( !this.ngrams.exists(compare_ngram, compare_hash) )
            {
                total_distance += 1;
            }
            else
            {
                float ngram_distance = abs(compare_freq - this.getRelFreq(compare_ngram, compare_hash));
                total_distance += ngram_distance;

//                debug Trace.format("'{}' ({}% / {}%): {}%,  ", compare_ngram, this.getRelFreq(compare_ngram, compare_hash) * 100, compare_freq * 100, ngram_distance * 100);
            }

            i++;
        }

        return total_distance / cast(float) compare.length;
    }


    /***************************************************************************
    
        Compares a list of ngram sets to this one, works out the distance
        between them, and returns the index of the closest match.
        
        Params:
            compare = list of ngram sets to compare against
            dg = (optional) delegate to call when comparing each ngram set
    
        Returns:
            index of the closest match in the compare array, or -1 (size_t.max)
            if no match was found
    
    ***************************************************************************/

    public size_t findClosest ( This[] compare, void delegate ( size_t, This, float ) dg = null )
    {
        size_t best_index = size_t.max;
        const NO_MATCH = 2.0;
        float best_distance = NO_MATCH;

        foreach ( i, ngram_set; compare )
        {
            if ( ngram_set.length )
            {
                auto distance = ngram_set.distance(this);
                if ( distance < best_distance )
                {
                    best_distance = distance;
                    best_index = i;
                }

                if ( dg )
                {
                    dg(i, ngram_set, distance);
                }
            }
        }

        return best_index;
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
		SimpleSerializer.write(output, this.ngrams.length);

		foreach ( ngram, freq; this.ngrams )
		{
            SimpleSerializer.write(output, ngram);
            SimpleSerializer.write(output, freq);
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
        SimpleSerializer.read(input, length);

		for ( uint i; i < length; i++ )
		{
			dchar[] ngram;
            SimpleSerializer.read(input, ngram);

			uint freq;
            SimpleSerializer.read(input, freq);

            // TODO: pretty sure this needs a dup here? - maybe not, cos the read method declares it as 'out'
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
    
        Invalidates the internal arrays for:
            * ngram relative frequencies
            * ngram hashes
            * sorted ngrams

        This method needs to be called any time this.ngrams is modified, as the
        derived arrays will need to be recalculated.

    ***************************************************************************/

    private void recalcNeeded ( )
    {
        this.ngrams_rel_freq.clear();
        this.sorted_ngrams.length = 0;
        this.ngrams_hashes.length = 0;
    }


    /***************************************************************************
    
        Computes the relative frequencies of the ngrams in the set, if the
        currently computed relative frequencies are out of date.
        
    ***************************************************************************/

    private void updateRelFreqs ( )
    {
        if ( this.ngrams_rel_freq.length != this.ngrams.length )
        {
            auto total_ngrams = this.countOccurrences();

            foreach ( ngram, count; this.ngrams )
            {
                float rel_freq = cast(float) count / cast(float) total_ngrams;
                this.ngrams_rel_freq[ngram] = rel_freq;
            }
        }
    }


    /***************************************************************************
    
        Computes the hashes of the ngrams in the set, if the currently computed
        hashes are out of date.
        
    ***************************************************************************/

    private void updateHashes ( )
    {
        if ( this.ngrams_hashes.length != this.ngrams.length )
        {
            this.ngrams_hashes.length = this.ngrams.length;

            size_t i;
            foreach ( ngram; this )
            {
                this.ngrams_hashes[i++] = NGramCountArray.toHash(ngram);
            }
        }
    }


    /***************************************************************************

        Gets the relative frequency of an ngram, given the ngram's hash. The
		relative frequencies are updated if they're out of date.
        
        Params:
            ngram = ngram to test
			hash = hash of ngram
            
        Returns:
            the ngram's relative frequency
    
    ***************************************************************************/
    
    private float getRelFreq ( dchar[] ngram, hash_t hash )
    {
        this.updateRelFreqs();
    
        if ( this.ngrams_rel_freq.exists(ngram, hash) )
        {
            return this.ngrams_rel_freq.get(ngram, hash);
        }
        else
        {
            return 0.0;
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
		foreach ( dchar[] ngram, uint freq; ngramset2 )
		{
			assert(ngramset.getCount(ngram) == freq, "ocean.text.ling.ngram.NGramSet unittest - ngram in file read has wrong frequency");
		}

		Trace.formatln("\nDone unittest\n");
	}
}

