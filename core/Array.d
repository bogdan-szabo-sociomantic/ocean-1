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
    
	Note: the functions in this file aren't inside a class / struct, so it's
	normally best to import the module with a name:
	
		import Array = ocean.core.Array;

*******************************************************************************/

module ocean.core.Array;

/*******************************************************************************

	Concatenates a list of arrays into a destination array. The function results
	in at most a single memory allocation, if the destination array is too small
	to contain the concatenation results.
	
	The destination array is passed as a reference, so its length can be
	modified in-place as required. This avoids any per-element memory
	allocation, which the normal ~ operator suffers from.

	Params:
		dest = reference to the destination array
		arrays = variadic list of arrays to concatenate

	Returns:
		the length of the concatenated arrays

	Usage:
	---
		char[] dest;
		concat(dest, "hello ", "world");
	---

********************************************************************************/

T[] concat ( T ) ( ref T[] dest, T[][] arrays ... )
{
	size_t total_len;
	foreach ( array; arrays )
	{
		total_len += array.length;
	}

	dest.length = total_len;

	auto write_slice = dest;
	foreach ( array; arrays )
	{
		write_slice[0..array.length] = array;
		write_slice = write_slice[array.length .. $];
	}

	return dest;
}


/*******************************************************************************

	Appends a list of arrays to a destination array. The function results
	in at most a single memory allocation, as the destination array needs to be
	expanded to contain the concatenated list of arrays.
	
	The destination array is passed as a reference, so its length can be
	modified in-place as required. This avoids any per-element memory
	allocation, which the normal ~ operator suffers from.
	
	Params:
		dest = reference to the destination array
		arrays = variadic list of arrays to append
	
	Returns:
		the new length of the destination array
	
	Usage:
	---
		char[] dest = "hello";
		append(dest, " world", ", what a beautiful day!");
	---

*******************************************************************************/

T[] append ( T ) ( ref T[] dest, T[][] arrays ... )
{
	size_t total_len;
	foreach ( array; arrays )
	{
		total_len += array.length;
	}

	auto old_len = dest.length;
	dest.length = old_len + total_len;

	auto write_slice = dest[old_len..$];
	foreach ( array; arrays )
	{
		write_slice[0..array.length] = array;
		write_slice = write_slice[array.length .. $];
	}

	return old_len + total_len;
}


/*******************************************************************************

    Copies the contents of one array to another, setting the length of the
    destination array first.
    
    This function is provided as a shorthand for this common operation.
    
    Params:
        dest = reference to the destination array
        array = array to copy
    
    Usage:
    ---
        char[] dest;
        char[] src = "hello";
        copy(dest, src);
    ---

*******************************************************************************/

T[] copy ( T ) ( ref T[] dest, T[] src )
{
    dest.length = src.length;
    dest[] = src[];
    
    return dst;
}


/*******************************************************************************

    Appends an element to a list of arrays, and copies the contents of the
    passed source array into the new element, setting the length of the
    destination array first.
    
    This function is provided as a shorthand for this common operation.
    
    Params:
        dest = reference to the destination array list
        array = array to copy
    
    Usage:
    ---
        char[][] dest;
        char[] src = "hello";
        copy(dest, src);
    ---

*******************************************************************************/

T[] appendCopy ( T ) ( ref T[][] dest, T[] src )
{
    dest.length = dest.length + 1;
    dest[$ - 1].copy(src);
    
    return dst;
}



/*******************************************************************************

    Unittest
    
********************************************************************************/

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

