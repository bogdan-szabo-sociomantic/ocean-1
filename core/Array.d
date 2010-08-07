/*******************************************************************************

	copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
	
	version:        July 2010: Initial release
	
	authors:        Gavin Norman

	Array manipulation functions.
	
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
		concat(dest, "hello ", "world);
	---

********************************************************************************/

size_t concat ( T ) ( ref T[] dest, T[][] arrays ... )
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

	return total_len;
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

