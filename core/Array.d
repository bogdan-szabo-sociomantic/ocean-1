/*******************************************************************************

	copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
	
	version:        July 2010: Initial release
	
	authors:        Gavin Norman

	Array manipulation functions.

	It's often convenient to use these functions with D's 'function as array
    property' sytnax, so:
    
    ---
        char[] dest;
        concat(dest, "hello ", "world");
    ---
    
    could also be written as:

    ---
        char[] dest;
        dest.concat("hello ", "world");
    ---

    TODO: Extend unittest to test all functions in this module.
    
*******************************************************************************/

module ocean.core.Array;



/*******************************************************************************
    
    Imports
    
*******************************************************************************/

private import tango.text.Util : patterns;



/*******************************************************************************

	Concatenates a list of arrays into a destination array. The function results
	in at most a single memory allocation, if the destination array is too small
	to contain the concatenation results.
	
	The destination array is passed as a reference, so its length can be
	modified in-place as required. This avoids any per-element memory
	allocation, which the normal ~ operator suffers from.

    Template params:
        T = type of array element

	Params:
		dest = reference to the destination array
		arrays = variadic list of arrays to concatenate

    Returns:
        dest

	Usage:
	---
		char[] dest;
		concat(dest, "hello ", "world");
	---

********************************************************************************/

public T[] concat ( T ) ( ref T[] dest, T[][] arrays ... )
{
    dest.length = totalLength(arrays);
    
    return dest.concat_(arrays);
}

/*******************************************************************************

	Appends a list of arrays to a destination array. The function results
	in at most a single memory allocation, as the destination array needs to be
	expanded to contain the concatenated list of arrays.
	
	The destination array is passed as a reference, so its length can be
	modified in-place as required. This avoids any per-element memory
	allocation, which the normal ~ operator suffers from.
	
    Template params:
        T = type of array element

	Params:
		dest = reference to the destination array
		arrays = variadic list of arrays to append
	
    Returns:
        dest

	Usage:
	---
		char[] dest = "hello";
		append(dest, " world", ", what a beautiful day!");
	---

*******************************************************************************/

public T[] append ( T ) ( ref T[] dest, T[][] arrays ... )
{
    size_t old_len = dest.length;
    
    dest.length = old_len + totalLength(arrays);
    
    return dest.concat_(arrays, old_len);
}


/*******************************************************************************

    Copies the contents of one array to another, setting the length of the
    destination array first.

    This function is provided as a shorthand for this common operation.

    Template params:
        T = type of array element

    Params:
        dest = reference to the destination array
        array = array to copy; null has the same effect as an empty array

    Returns:
        dest

    Usage:
    ---
        char[] dest;
        char[] src = "hello";
        copy(dest, src);
    ---

*******************************************************************************/

public T[] copy ( T ) ( ref T[] dest, T[] src )
{
    dest.length = src.length;
    
    if (src.length)
    {
        dest[] = src[];
    }
    
    return dest;
}


/*******************************************************************************

    Appends an element to a list of arrays, and copies the contents of the
    passed source array into the new element, setting the length of the
    destination array first.

    This function is provided as a shorthand for this common operation.

    Template params:
        T = type of array element

    Params:
        dest = reference to the destination array list
        array = array to copy

    Returns:
        dest

    Usage:
    ---
        char[][] dest;
        char[] src = "hello";
        copy(dest, src);
    ---

*******************************************************************************/

public T[][] appendCopy ( T ) ( ref T[][] dest, T[] src )
{
    dest.length = dest.length + 1;
    dest[$ - 1].copy(src);
    
    return dest;
}


/*******************************************************************************

    Split the provided array wherever a pattern instance is found, and return
    the resultant segments. The pattern is excluded from each of the segments.
    
    Note that the src content is not duplicated by this function, but is sliced
    instead.

    (Adapted from tango.text.Util : split, which isn't memory safe.)
    
    Template params:
        T = type of array element
    
    Params:
        src = source array to split
        pattern = pattern to split array by
        result = receives split array segments (slices into src)
    
    Returns:
        result

*******************************************************************************/

public T[][] split ( T ) ( T[] src, T[] pattern, ref T[][] result )
{
    result.length = 0;
    
    foreach ( segment; patterns(src, pattern) )
    {
        result ~= segment;
    }

    return result;
}


/*******************************************************************************

    Substitute all instances of match from source. Set replacement to null in
    order to remove instead of replace (or use the remove() function, below).
    
    (Adapted from tango.text.Util : substitute, which isn't memory safe.)
    
    Template params:
        T = type of array element
    
    Params:
        src = source array to split
        match = pattern to match in source array
        replacement = pattern to replace matched sub-arrays
        result = receives array with replaced patterns
    
    Returns:
        result

*******************************************************************************/

public T[] substitute ( T ) ( T[] source, T[] match, T[] replacement, ref T[] result )
{
    result.length = 0;
    
    foreach ( s; patterns(source, match, replacement) )
    {
        result ~= s;
    }
    
    return result;
}


/*******************************************************************************

    Removes all instances of match from source.
    
    Template params:
        T = type of array element
    
    Params:
        src = source array to split
        match = pattern to remove from source array
        result = receives array with removed patterns
    
    Returns:
        result

*******************************************************************************/

public T[] remove ( T ) ( T[] source, T[] match, ref T[] result )
{
    char[] replacement = null;
    return substitute(source, match, replacement, result);
}

/*******************************************************************************

    Sorts array and removes all value duplicates.
    
    Template params:
        T = type of array element
    
    Params:
        array = array to clean from duplicate values
    
    Returns:
        result

*******************************************************************************/

public T[] uniq ( T ) ( ref T[] array )
{
    if (array.length)
    {
        size_t n = 0;
        
        T item = array.sort[n];
        
        foreach (element; array)
        {
            if (element != item)
            {
                array[++n] = element;
                item       = element;
            }
        }
        
        array.length = n + 1;
    }
    
    return array;
}

/*******************************************************************************

    Calculates the sum of the lengths of arrays
    
    Params:
        arrays = arrays to add lengths
        
    Returns:
        sum of the lengths of arrays

*******************************************************************************/

public size_t totalLength ( T ) ( T[][] arrays ... )
{
    size_t total_len = 0;
    
    foreach ( array; arrays )
    {
        total_len += array.length;
    }
    
    return total_len;
}

/*******************************************************************************

    Concatenates arrays, using dest[start .. $] as destination array.
    dest[start .. $].length must equal the sum of the lengths of arrays.
    
    Params:
        dest   = destination array
        arrays = arrays to concatenate
        start  = start index on dest
        
    Returns:
        dest

*******************************************************************************/

private T[] concat_ ( T ) ( T[] dest, T[][] arrays, size_t start = 0 )
{
    T[] write_slice = dest[start .. $];
    
    foreach ( array; arrays )
    {
        if (array)
        {
            write_slice[0 .. array.length] = array[];
        }
        write_slice                        = write_slice[array.length .. $];
    }
    
    assert (!write_slice.length);
    
    return dest;
}



/*******************************************************************************

    Unittest

*******************************************************************************/

unittest
{
    char[] str;
    assert (str.copy("Die Katze tritt die Treppe krumm.") == "Die Katze tritt die Treppe krumm.");
    
    str.length = 0;
    assert (str.concat("Die ", "Katze ", "tritt ", "die ", "Treppe ", "krumm.") == "Die Katze tritt die Treppe krumm.");
    
    str.length = 0;
    str.append("Die Katze ");
    assert (str == "Die Katze ");
    str.append("tritt ", "die ");
    assert (str.append("Treppe ", "krumm.") == "Die Katze tritt die Treppe krumm.");
}

debug ( OceanUnitTest )
{
	import tango.util.log.Trace;

	// Tests string concatenation function against results of the normal ~ operator
	bool concat_test ( char[][] strings ... )
	{
		char[] dest;
		concat(dest, strings);
		
		char[] concat_result;
		foreach ( str; strings )
		{
			concat_result ~= str;
		}
		return dest == concat_result ;
	}

	unittest
	{
		Trace.formatln("\nRunning ocean.core.Array unittest");

		char[] dest;
		char[] str1 = "hello";
		char[] str2 = "world";
		char[] str3 = "something";

		// Check dynamic array concatenation
		assert(concat_test(dest, str1, str2, str3), "Concatenation test failed");

		// Check that modifying one of the concatenated strings doesn't modify the result
		char[] result = dest.dup;
		str1 = "goodbye";
		assert(dest == result, "Modified concatenation test failed");

		// Check null concatenation
		assert(concat_test(dest), "Null concatenation test 1 failed");
		assert(concat_test(dest, "", ""), "Null concatenation test 2 failed");

		// Check static array concatenation
		char[3] staticstr1 = "hi ";
		char[5] staticstr2 = "there";
		assert(concat_test(dest, staticstr1, staticstr2), "Static array concatenation test failed");

		// Check const array concatenation
		const char[] conststr1 = "hi ";
		const char[] conststr2 = "there";
		assert(concat_test(dest, conststr1, conststr2), "Const array concatenation test failed");

		Trace.formatln("done unittest\n");
	}
}

