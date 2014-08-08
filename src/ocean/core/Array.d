/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        Gavin Norman

    Array manipulation functions.

    It's often convenient to use these functions with D's 'function as array
    property' syntax, so:

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

private import ocean.core.Traits: ReturnAndArgumentTypesOf;

private import tango.core.Traits;

private import tango.stdc.string : memmove, memset;

private import tango.stdc.posix.sys.types : ssize_t;

private import tango.text.Util : patterns;

private import tango.stdc.math: fabs;

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

public D concat ( D, T ... ) ( ref D dest, T arrays )
{
    return concatT!("concat", D, T)(dest, arrays);
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

public D append ( D, T ... ) ( ref D dest, T arrays )
{
    size_t old_len = dest.length;

    return concatT!("append", D, T)(dest, arrays, old_len);
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

    Copies the contents of src to dest, increasing dest.length if required.
    Since dest.length will not be decreased, dest will contain tailing garbage
    if src.length < dest.length.

    Template params:
        T = type of array element

    Params:
        dest  = reference to the destination array
        array = array to copy; null has the same effect as an empty array

    Returns:
        slice to copied elements in dest

*******************************************************************************/

public T[] copyExtend ( T ) ( ref T[] dest, T[] src )
{
    if (src.length)
    {
        if (dest.length < src.length)
        {
            dest.length = src.length;
        }

        dest[0 .. src.length] = src[];
    }

    return dest[0 .. src.length];
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
        src = source array to search
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

    Removes and returns (via the 'popped' out parameter) the last element in an
    array. If the provided array is empty, the function returns false.

    Template params:
        T = type of array element

    Params:
        array = array to pop an element from
        popped = popped element (if array contains > 0 elements)

    Returns:
        true if an element was popped

*******************************************************************************/

public bool pop ( T ) ( ref T[] array, out T popped )
{
    if ( array.length )
    {
        popped = array[$-1];
        array.length = array.length - 1;
        return true;
    }

    return false;
}


/*******************************************************************************

    Removes all instances of match from source.

    Template params:
        T = type of array element

    Params:
        src = source array to search
        match = pattern to remove from source array
        result = receives array with removed patterns

    Returns:
        result

*******************************************************************************/

public T[] remove ( T ) ( T[] source, T[] match, ref T[] result )
{
    T[] replacement = null;
    return substitute(source, match, replacement, result);
}


/*******************************************************************************

    Removes an element from the middle of an array, maintaining the order of the
    remaining elements by shifting them left using memmove.

    Template params:
        T = type of array element

    Params:
        array = array to remove from
        index = position in array from which to remove element

    Returns:
        modified array

*******************************************************************************/

public T[] removeShift ( T ) ( ref T[] array, size_t index )
{
    return removeShift(array, index, 1);
}


/*******************************************************************************

    Removes elements from the middle of an array, maintaining the order of the
    remaining elements by shifting them left using memmove.

    Template params:
        T = type of array element

    Params:
        array = array to remove from
        index = position in array from which to remove elements
        remove_elems = number of elements to remove

    Returns:
        modified array

*******************************************************************************/

public T[] removeShift ( T ) ( ref T[] array, size_t index, size_t remove_elems )
in
{
    assert(index < array.length, "removeShift: index is > array length");
    assert(index + remove_elems - 1 < array.length, "removeShift: end is > array length");
}
body
{
    if ( remove_elems == 0 )
    {
        return array;
    }

    auto end = index + remove_elems - 1;
    auto shift_elems = (array.length - end) - 1;

    if ( shift_elems )
    {
        // shift after elements to the left
        void* src = &array[end + 1];
        void* dst = &array[index];
        size_t num = T.sizeof * shift_elems;

        memmove(dst, src, num);
    }

    // adjust array length
    array.length = array.length - remove_elems;

    return array;
}


/*******************************************************************************

    Inserts an element into the middle of an array, maintaining the order of the
    existing elements by shifting them right using memmove.

    Template params:
        T = type of array element

    Params:
        array = array to insert into
        index = position in array at which to insert new element

    Returns:
        modified array

*******************************************************************************/

public T[] insertShift ( T ) ( ref T[] array, size_t index )
{
    return insertShift(array, index, 1);
}


/*******************************************************************************

    Inserts elements into the middle of an array, maintaining the order of the
    existing elements by shifting them right using memmove.

    Template params:
        T = type of array element

    Params:
        array = array to insert into
        index = position in array at which to insert new elements
        insert_elems = number of elements to insert

    Returns:
        modified array

*******************************************************************************/

public T[] insertShift ( T ) ( ref T[] array, size_t index, size_t insert_elems )
in
{
    assert(index <= array.length, "insertShift: index is > array length");
}
body
{
    if ( insert_elems == 0 )
    {
        return array;
    }

    auto shift_elems = array.length - index;

    // adjust array length
    array.length = array.length + insert_elems;

    // shift required elements one place to the right
    if ( shift_elems )
    {
        void* src = &array[index];
        void* dst = &array[index + insert_elems];
        size_t num = T.sizeof * shift_elems;
        memmove(dst, src, num);
    }

    return array;
}


/*******************************************************************************

    Sorts array and removes all value duplicates.

    Template params:
        T    = type of array element
        sort = true: do array.sort first; false: array is already sorted

    Params:
        array = array to clean from duplicate values

    Returns:
        result

*******************************************************************************/

public T[] uniq ( T, bool sort = true ) ( T[] array )
{
    if (array.length)
    {
        size_t n = 0;

        static if (sort)
        {
            array.sort;
        }

        T item = array[n];

        foreach (element; array)
        {
            if (element != item)
            {
                array[++n] = element;
                item       = element;
            }
        }

        return array[0 .. n + 1];
    }
    else
    {
        return array;
    }

}

version ( UnitTest )
{
    private import ocean.core.Test;
}

/*******************************************************************************

    Check if the given array starts with the given prefix

    Template Params:
        T = The type of the array element

    Params:
        arr    = The array to be tested
        prefix = The prefix to test for

    Returns:
        True if the array starts with the prefix, false otherwise

*******************************************************************************/

bool startsWith ( T ) ( T[] arr, T[] prefix )
{
    return (arr.length >= prefix.length) && (arr[0..prefix.length] == prefix[]);
}

unittest
{
    test( startsWith!(char)("abcd", "abc"));
    test( startsWith!(char)("abcd", "abcd"));
    test(!startsWith!(char)("ab", "abc"));
    test( startsWith!(char)("ab", null));
    test(!startsWith!(char)(null, "xx"));

    test( startsWith!(uint)([1,2,3,4], [1,2,3]));
    test( startsWith!(uint)([1,2,3,4], [1,2,3,4]));
    test(!startsWith!(uint)([1,2], [1,2,3]));
    test( startsWith!(uint)([1,2], null));
    test(!startsWith!(uint)(null, [1,2]));
}

/*******************************************************************************

    Check if the given array ends with the given suffix

    Template Params:
        T = The type of the array element

    Params:
        arr    = The array to be tested
        suffix = The suffix to test for

    Returns:
        True if the array ends with the suffix, false otherwise

*******************************************************************************/

bool endsWith ( T ) ( T[] arr, T[] suffix )
{
    return (arr.length >= suffix.length) && (arr[$ - suffix.length .. $] == suffix[]);
}

unittest
{
    test( endsWith!(char)("abcd", "bcd"));
    test( endsWith!(char)("abcd", "abcd"));
    test(!endsWith!(char)("ab", "abc"));
    test( endsWith!(char)("ab", null));
    test(!endsWith!(char)(null, "xx"));

    test( endsWith!(uint)([1,2,3,4], [2,3,4]));
    test( endsWith!(uint)([1,2,3,4], [1,2,3,4]));
    test(!endsWith!(uint)([1,2], [1,2,3]));
    test( endsWith!(uint)([1,2], null));
    test(!endsWith!(uint)(null, [1,2]));
}

/*******************************************************************************

    Remove the given prefix from the given array.

    Template Params:
        T = The type of the array element

    Params:
        arr    = The array from which the prefix is to be removed
        prefix = The prefix to remove

    Returns:
        A slice without the prefix if successful, the original array otherwise

*******************************************************************************/

public T[] removePrefix ( T ) ( T[] arr, T[] prefix )
{
    return ((arr.length >= prefix.length) && (startsWith(arr, prefix))
                ? arr[prefix.length .. $]
                : arr);
}

unittest
{
    test(removePrefix!(char)("abcd", "abc") == "d");
    test(removePrefix!(char)("abcd", "abcd") == "");
    test(removePrefix!(char)("abcd", "abcde") == "abcd");
    test(removePrefix!(char)("abcd", null) == "abcd");
    test(removePrefix!(char)(null, "xx") == "");
    test("abcd".removePrefix("abc") == "d");
    test("abcd".removePrefix("abcd") == "");
    test("abcd".removePrefix("abcde") == "abcd");
    test("abcd".removePrefix("") == "abcd");
    test("".removePrefix("xx") == "");

    test(removePrefix!(uint)([1,2,3,4], [1,2,3]) == cast(uint[])[4]);
    test(removePrefix!(uint)([1,2,3,4], [1,2,3,4]) == cast(uint[])[]);
    test(removePrefix!(uint)([1,2], [1,2,3]) == cast(uint[])[1,2]);
    test(removePrefix!(uint)([1,2], null) == cast(uint[])[1,2]);
    test(removePrefix!(uint)(null, [1,2]) == cast(uint[])[]);
}

/*******************************************************************************

    Remove the given suffix from the given array.

    Template Params:
        T = The type of the array element

    Params:
        arr    = The array from which the suffix is to be removed
        suffix = The suffix to remove

    Returns:
        A slice without the suffix if successful, the original array otherwise

*******************************************************************************/

public T[] removeSuffix ( T ) ( T[] arr, T[] suffix )
{
    return ((arr.length >= suffix.length) && (endsWith(arr, suffix))
                ? arr[0 .. $-suffix.length]
                : arr);
}

unittest
{
    test(removeSuffix!(char)("abcd", "cd") == "ab");
    test(removeSuffix!(char)("abcd", "abcd") == "");
    test(removeSuffix!(char)("abcd", "abcde") == "abcd");
    test(removeSuffix!(char)("abcd", null) == "abcd");
    test(removeSuffix!(char)(null, "xx") == "");
    test("abcd".removeSuffix("cd") == "ab");
    test("abcd".removeSuffix("abcd") == "");
    test("abcd".removeSuffix("abcde") == "abcd");
    test("abcd".removeSuffix("") == "abcd");
    test("".removeSuffix("xx") == "");

    test(removeSuffix!(uint)([1,2,3,4], [2,3,4]) == cast(uint[])[1]);
    test(removeSuffix!(uint)([1,2,3,4], [1,2,3,4]) == cast(uint[])[]);
    test(removeSuffix!(uint)([1,2], [1,2,3]) == cast(uint[])[1,2]);
    test(removeSuffix!(uint)([1,2], null) == cast(uint[])[1,2]);
    test(removeSuffix!(uint)(null, [1,2]) == cast(uint[])[]);
}

/*******************************************************************************

    Moves all elements from array which match the exclusion criterum
    represented by exclude to the back of array so that the elements that do not
    match this criterium are in the front.

    array is modified in-place, the order of the elements may change.

    exclude is expected to be callable (function or delegate), accepting exactly
    one T argument and returning an integer (bool, (u)int, (u)short or (u)long).
    It is called with the element in question and should return true if that
    element should moved to the back or false if to the front.

    Params:
        array   = array to move values matching the exclusion criterum to the
                  back
        exclude = returns true if the element matches the exclusion criterium

    Returns:
        the index of the first excluded elements in array. This element and all
        following ones matched the exclusion criterum; all elements before it
        did not match.
        array.length indicates that all elements matched the exclusion criterium
        and 0 that none matched.

    Out:
        The returned index is at most array.length.

*******************************************************************************/

public size_t filterInPlace ( T, Exclude ) ( T[] array, Exclude exclude )
out (end)
{
    assert(end <= array.length, "result index out of bounds");
}
body
{
    alias ReturnAndArgumentTypesOf!(Exclude) ExcludeParams;

    static assert(ExcludeParams.length, "exclude is expected to be callable, "
                                        "not \"" ~ Exclude.stringof ~ '"');
    static assert(ExcludeParams.length == 2, "exclude is expected to accept "
                                             "one argument, which " ~
                                             Exclude.stringof ~ " doesn't'");
    static assert(is(ExcludeParams[0]: long), "the return type of exclude is "
                                              "expected to be an integer type, "
                                              "not " ~ ExcludeParams[0].stringof);
    static assert(is(ExcludeParams[1] == T), "exclude is expected to accept an "
                                             "argument of type " ~ T.stringof ~
                                             ", not " ~ ExcludeParams[1].stringof);

    return filterInPlaceCore(array.length,
                            (size_t i)
                            {
                                return !!exclude(array[i]);
                             },
                            (size_t i, size_t j)
                            {
                                typeid(T).swap(&array[i], &array[j]);
                            });
}

/*******************************************************************************

    Moves all elements in an array which match the exclusion criterum
    represented by exclude to the back of array so that the elements that do not
    match this criterium are in the front.

    array is modified in-place, the order of the elements may change.

    exclude is called with the index of the element in question and should
    return true if array[index] should moved to the back or false if to the
    front. At the time exclude is called, the order of the array elements may
    have changed so exclude should index the same array instance this function
    is working on (i.e. not a copy).

    Params:
        length  = array length
        exclude = returns true if array)[index] matches the exclusion
                  criterium
        swap    = swaps array[i] and array[j]

    Returns:
        the index of the first excluded elements in the array. This element
        and all following ones matched the exclusion criterum; all elements
        before it did not match.
        length indicates that all elements matched the exclusion criterium and
        0 that none matched.

*******************************************************************************/

public size_t filterInPlaceCore ( size_t length,
                                  bool delegate ( size_t index ) exclude,
                                  void delegate ( size_t i, size_t j ) swap )
out (end)
{
    assert(end <= length, "result length out of bounds");
}
body
{
    for (size_t i = 0; i < length; i++)
    {
        if (exclude(i))
        {
            length--;

            while (length > i)
            {
                if (exclude(length))
                {
                    length--;
                }
                else
                {
                    swap(i, length);
                    break;
                }
            }
        }
    }

    return length;
}

/******************************************************************************/

unittest
{
    uint[] array = [2, 3, 5, 8, 13, 21, 34, 55, 89, 144];
    size_t end;

    /***************************************************************************

        Returns true if array[0 .. end] contains n or false if not.

    ***************************************************************************/

    bool inIncluded ( uint n )
    {
        foreach (element; array[0 .. end])
        {
            if (element == n) return true;
        }

        return false;
    }

    /***************************************************************************

        Returns true if array[end .. $] contains n or false if not.

    ***************************************************************************/

    bool inExcluded ( uint n )
    {
        foreach (element; array[end .. $])
        {
            if (element == n) return true;
        }

        return false;
    }

    /***************************************************************************

        Returns true n is even or false if n is odd.

    ***************************************************************************/

    bool even ( uint n )
    {
        return !(n & 1);
    }

    end = .filterInPlace(array, &even);
    assert(end == 6);
    assert(inIncluded(3));
    assert(inIncluded(5));
    assert(inIncluded(13));
    assert(inIncluded(21));
    assert(inIncluded(55));
    assert(inIncluded(89));
    assert(inExcluded(2));
    assert(inExcluded(8));
    assert(inExcluded(34));
    assert(inExcluded(144));

    array    = [2, 4, 6];
    end = .filterInPlace(array, &even);
    assert(!end);
    assert(inExcluded(2));
    assert(inExcluded(4));
    assert(inExcluded(6));

    array    = [8];
    end = .filterInPlace(array, &even);
    assert(!end);
    assert(array[end] == 8);

    array    = [12345];
    end = .filterInPlace(array, &even);
    assert(end == array.length);
    assert(array[0] == 12345);

    array = [1, 2, 4, 6];
    end = .filterInPlace(array, &even);
    assert(end == 1);
    assert(array[0] == 1);
    assert(inExcluded(2));
    assert(inExcluded(4));
    assert(inExcluded(6));

    array = [1, 3, 5, 7];
    end = .filterInPlace(array, &even);
    assert(end == array.length);
    assert(inIncluded(1));
    assert(inIncluded(3));
    assert(inIncluded(5));
    assert(inIncluded(7));

    array = [1, 2, 5, 7];
    end = .filterInPlace(array, &even);
    assert(end == 3);
    assert(inIncluded(1));
    assert(inIncluded(5));
    assert(inIncluded(7));
    assert(inExcluded(2));
}

/*******************************************************************************

    Searches a sorted array for the specified element or for the insert
    position of the element. The array is assumed to be pre-sorted in ascending
    order, the search will not work properly if it is not.
    If T is a class or struct, comparison is performed using T.opCmp().
    Otherwise, elements of T are compared using ">" and ">=" or, if T is
    compatible to size_t (which includes ssize_t, the signed version of size_t),
    by calculating the difference.

    Template params:
        T = type of array element

    Params:
        array = array to search
        match = element to search for
        position = out value, value depends on whether the element was found:

            1. If found, the position at which element was found is output.

            2. If not found, the position at which the element could be inserted
               is output, as follows:

               * A value of 0 means that the element is smaller than all
                 elements in the array, and would need to be inserted at the
                 beginning of the array, and all other elements shifted to the
                 right.
               * A value of array.length means that the element is larger than
                 all elements in the array, and would need to be appended to the
                 end of the array.
               * A value of > 0 and < array.length means that the element would
                 need to be inserted at the specified position, and all elements
                 of index >= the specified position shifted to the right.

    Returns:
        true if the element was found in the array

    In:
        array.length must be at most ssize_t.max (int.max if size_t is uint or
        long.max if size_t is ulong). TODO: Remove this restriction by
        rephrasing the implementation in bsearchCustom().

*******************************************************************************/

public bool bsearch ( T ) ( T[] array, T match, out size_t position )
out (found)
{
    if (found)
    {
        assert (position < array.length);
    }
    else
    {
        assert (position <= array.length);
    }
}
body
{
    return bsearchCustom(array.length,
            delegate ssize_t ( size_t i )
            {
                static if (is (T : size_t)) // will also be true if T is ssize_t
                {
                    // If T is unsigned, check if cast (ssize_t) (0 - 1) == -1.
                    // TODO: Is this behaviour guaranteed? If so, remove the
                    // check.

                    static if (T.min == 0)
                    {
                        static assert (cast (ssize_t) (T.min - cast (T) 1) == -1,
                                       "bsearch: 0 - 1 != -1 for type " ~ T.stringof);
                    }

                    return match - array[i];
                }
                else static if (is (T == class) || is (T == struct))
                {
                    return match.opCmp(array[i]);
                }
                else
                {
                    return (match >= array[i])? (match > array[i]) : -1;
                }
            },
            position);
}


/*******************************************************************************

    Searches a sorted array for an element or an insert position for an element.
    The array is assumed to be pre-sorted according to cmp.

    Params:
        array_length = length of array to search
        cmp       = comparison callback delegate, should return
                    * a positive value if the array element at index i compares
                      greater than the element to search for,
                    * a negative value if the array element at index i compares
                      less than the element to search for,
                    * 0 if if the array element at index i compares equal to
                      the element to search for.
        position  = out value, value depends on whether the element was found:

            1. If found, the position at which element was found is output.

            2. If not found, the position at which the element could be inserted
               is output, as follows:

               * A value of 0 means that the element is smaller than all
                 elements in the array, and would need to be inserted at the
                 beginning of the array, and all other elements shifted to the
                 right.
               * A value of array.length means that the element is larger than
                 all elements in the array, and would need to be appended to the
                 end of the array.
               * A value of > 0 and < array.length means that the element would
                 need to be inserted at the specified position, and all elements
                 of index >= the specified position shifted to the right.

    Returns:
        true if the element was found in the array

    In:
        array_length must be at most ssize_t.max (int.max if size_t is uint or
        long.max if size_t is ulong). TODO: Remove this restriction by
        rephrasing the implementation so that min/max cannot be less than 0.

*******************************************************************************/

public bool bsearchCustom ( size_t array_length, ssize_t delegate ( size_t i ) cmp, out size_t position )
in
{
    assert (cast (ssize_t) array_length >= 0,
            "bsearchCustom: array_length integer overflow (maximum is " ~
            ssize_t.stringof ~ ".max = " ~ ssize_t.max.stringof ~ ')');
}
out (found)
{
    if (found)
    {
        assert (position < array_length);
    }
    else
    {
        assert (position <= array_length);
    }
}
body
{
    if ( array_length == 0 )
    {
        return false;
    }

    ssize_t min = 0;
    ssize_t max = array_length - 1;

    ssize_t c = cmp(position = (min + max) / 2);

    while ( min <= max && c )
    {
        if ( c < 0 ) // match < array[position]
        {
            max = position - 1;
        }
        else        // match > array[position]
        {
            min = position + 1;
        }

        c = cmp(position = (min + max) / 2);
    }

    position += c > 0;

    return !c;
}

/*******************************************************************************

    Creates a single element dynamic array that slices val. This will not
    allocate memory in contrast to the '[val]' expression.

    Params:
        val = value to slice

    Returns:
        single element dynamic array that slices val.

*******************************************************************************/

public T[] toArray ( T ) ( ref T val )
{
    return (&val)[0 .. 1];
}

/*******************************************************************************

    Shuffles the elements of array in-place.

    Params:
        array = array with elements to shuffle
        rand  = random number generator, will be invoked array.length - 1 times

    Returns:
        shuffled array

*******************************************************************************/

public T[] shuffle ( T ) ( T[] array, lazy double rand )
{
    return shuffle(array,
                   (size_t i) {return cast (size_t) (fabs(rand) * (i + 1));});
}

/*******************************************************************************

    Shuffles the elements of array in-place.

    Params:
        array     = array with elements to shuffle
        new_index = returns the new index for the array element whose index is
                    currently i. i is guaranteed to be in the range
                    [1 .. array.length - 1]; the returned index should be in the
                    range [0 .. i] and must be in range [0 .. array.length - 1].

    Returns:
        shuffled array

*******************************************************************************/

public T[] shuffle ( T ) ( T[] array, size_t delegate ( size_t i ) new_index )
{
    for (auto i = array.length? array.length - 1 : 0; i; i--)
    {
        auto j = new_index(i);
        auto tmp = array[i];
        array[i] = array[j];
        array[j] = tmp;
    }

    return array;
}

/******************************************************************************

    Resets each elements of array to its initial value.

    T.init must consist only of zero bytes.

    Params:
        array = array to clear elements

    Returns:
        array with cleared elements

 ******************************************************************************/

public T[] clear ( T ) ( T[] array )
in
{
    assert(isClearable!(T), T.stringof ~ ".init contains a non-zero byte so " ~
           (T[]).stringof ~ " cannot be simply cleared");
}
body
{
    memset(array.ptr, 0, array.length * array[0].sizeof);

    return array;
}


/******************************************************************************

    Checks if T.init consists only of zero bytes so that a T[] array can be
    cleared by clear().

    Returns:
        true if a T[] array can be cleared by clear() or false if not.

 ******************************************************************************/

bool isClearable ( T ) ( )
{
    const size_t n = T.sizeof;

    T init;

    ubyte[n] zero_data;

    return (cast (void*) &init)[0 .. n] == zero_data;
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
        write_slice = write_slice[array.length .. $];
    }

    assert (!write_slice.length);

    return dest;
}

/*******************************************************************************

    Assigns elements to array.

    This is a static array substitution for fixed type variadic functions
    to avoid the memory condition caused by using it.  A fixed type variadic
    function follows the pattern
    ---
        int f ( int[] list ... )
    ---
    .  A call to that function like
    ---
        f(2, 3, 5, 7);
    ---
    seems at compile-time to be rewritten to
    ---
        f([2, 3, 5, 7])
    ---
    . The "[2, 3, 5, 7]" array literal is implemented by the _d_arrayliteralTX()
    function of the run-time library which uses gc_malloc() to allocate the
    array buffer.
    @see tango.rt.compiler.dmd.rt.lifetime

    Template params:
        func = function name for static assertion messages

    Params:
        dest     = destination array, length must equal the number of elements
        elements = elements to append, each  parameter must be possible to
                   assign to an element of dest.

    Returns:
        total length of elements.

    TODO: Could be made public but must then not rely on elements to be arrays.

*******************************************************************************/

private size_t toStaticArray ( size_t n, D, char[] func = "toStaticArray", T ... ) ( D[n] dest, T elements )
in
{
    static assert (n == T.length, func ~ ": destination array length mismatch (expected" ~ T.length.stringof ~ " instead of " ~ n.stringof);
}
body
{
    size_t total_length = 0;

    foreach ( i, element; elements )
    {
        static assert (is (typeof (dest[i] = element)), func ~ ": cannot "
                           "assign element " ~ i.stringof ~ " of type " ~
                           typeof (element).stringof ~ "to  " ~ D.stringof);

        dest[i] = element;
        total_length += element.length;
    }

    return total_length;
}

/*******************************************************************************

    Copies the contents of one element of arrays to another, starting at
    dest[start], setting the length of the destination array first.
    Note that start may be greater than the initial length of dest; dest will
    then be extended appropriately.

    Template params:
        func = function name for static assertion messages

    Params:
        dest   = reference to the destination array
        arrays = arrays to copy; a null parameter has the same effect as an
                 empty array.

    Returns:
        dest

    TODO: Could be made public but must then not rely on elements to be arrays.

*******************************************************************************/

private D concatT ( char[] func, D, T ... ) ( ref D dest, T arrays, size_t start = 0 )
{
    static if (T.length == 1)                                               // single argument
    {
        static if (is (typeof (dest[] = arrays[0][])))                      // one array
        {
            dest.length = start + arrays[0].length;

            return dest[start .. $] = arrays[0][];
        }
        else                                                                // must be an array of arrays
        {
            static assert (is (typeof (dest.concat_(arrays[0]))), "cannot concatenate " ~ T[0].stringof ~ " to " ~ D.stringof);

            size_t total_len = start;

            foreach ( array; arrays[0] )
            {
                total_len += array.length;
            }

            dest.length = total_len;

            return dest.concat_(arrays[0], start);
        }
    }
    else                                                                    // multiple arguments, must be arrays
    {
        D[T.length] list;

        dest.length = start + toStaticArray(list, arrays);

        return dest.concat_(list, start);
    }
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

    char[] nothing = null;

    str.length = 0;
    assert (str.concat("Die ", "", "Katze ", "tritt ", nothing, "die ", "Treppe ", "krumm.") == "Die Katze tritt die Treppe krumm.");

    str.length = 0;
    str.append("Die Katze ");
    assert (str == "Die Katze ");
    str.append("tritt ", "die ");
    assert (str.append("Treppe ", "krumm.") == "Die Katze tritt die Treppe krumm.");

    alias bsearch!(long) bs;

    long[] arr = [1, 2, 3,  5, 8, 13, 21];

    size_t n;

    assert (bs(arr, 5, n));
}

version ( UnitTest )
{
    import ocean.util.log.Trace;

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
        version (UnitTestVerbose) Trace.formatln("\nRunning ocean.core.Array unittest");

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

        version (UnitTestVerbose) Trace.formatln("done unittest\n");
    }
}

