/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        Gavin Norman

    Array manipulation functions.

    It's often convenient to use these functions with D's 'function as array
    property' syntax, so:

    ---
        mstring dest;
        concat(dest, "hello ", "world");
    ---

    could also be written as:

    ---
        mstring dest;
        dest.concat("hello ", "world");
    ---

    TODO: Extend unittest to test all functions in this module.

*******************************************************************************/

module ocean.core.Array;


/*******************************************************************************

    Imports

*******************************************************************************/

import tango.transition;

import ocean.core.Traits: ReturnAndArgumentTypesOf;

import tango.core.Traits;

import tango.stdc.string : memmove, memset;

import tango.stdc.posix.sys.types : ssize_t;

import tango.text.Util : patterns;

import tango.stdc.math: fabs;

version ( UnitTest )
{
    import ocean.core.Test;
}

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

********************************************************************************/

public D concat ( D, T ... ) ( ref D dest, T arrays )
{
    return concatT!("concat", D, T)(dest, arrays);
}

///
unittest
{
    mstring dest;
    concat(dest, "hello ", "world");
    test!("==")(dest, "hello world");
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

*******************************************************************************/

public D append ( D, T ... ) ( ref D dest, T arrays )
{
    size_t old_len = dest.length;

    return concatT!("append", D, T)(dest, arrays, old_len);
}

///
unittest
{
    mstring dest = "hello".dup;
    append(dest, " world", ", what a beautiful day!");
    test!("==")(dest, "hello world, what a beautiful day!");
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

*******************************************************************************/

public T[] copy ( T, TC ) ( ref T[] dest, TC[] src )
{
    dest.length = src.length;

    if (src.length)
    {
        dest[] = src[];
    }

    return dest;
}

///
unittest
{
    mstring dest;
    cstring src = "hello";
    copy(dest, src);
    test!("==")(dest, "hello");
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

public T[] copyExtend ( T, TC ) ( ref T[] dest, TC[] src )
{
    static assert (is(Unqual!(T) == Unqual!(TC)));

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

///
unittest
{
    auto dst = "aaaaa".dup;
    auto str = copyExtend(dst, "bbb");
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

*******************************************************************************/

public T[][] appendCopy ( T, TC ) ( ref T[][] dest, TC[] src )
{
    static assert (is(Unqual!(T) == Unqual!(TC)));

    dest.length = dest.length + 1;
    dest[$ - 1].copy(src);

    return dest;
}

///
unittest
{
    mstring[] dest;
    cstring src = "hello";
    appendCopy(dest, src);
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

public T[][] split ( T, TC ) ( T[] src, TC[] pattern, ref T[][] result )
{
    static assert (is(Unqual!(T) == Unqual!(TC)));

    result.length = 0;

    foreach ( segment; patterns(src, pattern) )
    {
        result ~= segment;
    }

    return result;
}

///
unittest
{
    istring[] result;
    split("aaa..bbb..ccc", "..", result);
    test!("==")(result, [ "aaa", "bbb", "ccc" ]);
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

public T[] substitute ( T, TC1, TC2, TC3 ) ( TC1[] source, TC2[] match,
    TC3[] replacement, ref T[] result )
{
    static assert (is(Unqual!(T) == Unqual!(TC1)));
    static assert (is(Unqual!(T) == Unqual!(TC2)));
    static assert (is(Unqual!(T) == Unqual!(TC3)));

    result.length = 0;

    foreach ( s; patterns(source, match, replacement) )
    {
        result ~= s;
    }

    return result;
}

///
unittest
{
    mstring result;
    substitute("some string", "ring", "oops", result);
    test!("==")(result, "some stoops");
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

///
unittest
{
    mstring arr = "something".dup;
    char elem;
    test(pop(arr, elem));
    test!("==")(arr, "somethin");
    test!("==")(elem, 'g');
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

public T[] remove ( T, TC1, TC2 ) ( TC1[] source, TC2[] match, ref T[] result )
{
    static assert (is(Unqual!(T) == Unqual!(TC1)));
    static assert (is(Unqual!(T) == Unqual!(TC2)));

    T[] replacement = null;
    return substitute(source, match, replacement, result);
}

///
unittest
{
    mstring result;    
    remove("aaabbbaaa", "bbb", result);
    test!("==")(result, "aaaaaa");
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

///
unittest
{
    auto array = "something".dup;
    removeShift(array, 4);
    test!("==")(array, "somehing");
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

///
unittest
{
    mstring arr = "something".dup;
    removeShift(arr, 3, 4);
    test!("==")(arr, "somng");
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

///
unittest
{
    mstring arr = "something".dup;
    insertShift(arr, 2);
    test!("==")(arr, "sommething");
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

///
unittest
{
    mstring arr = "something".dup;
    insertShift(arr, 2, 2);
    test!("==")(arr, "somemething");
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

///
unittest
{
    int[] arr = [ 42, 43, 43, 42, 2 ];
    arr = uniq(arr);
    test!("==")(arr, [ 2, 42, 43 ]);
}

/*******************************************************************************

    Sorts array and checks if it contains at least one duplicate.

    Template params:
        T    = type of array element
        sort = true: do array.sort first; false: array is already sorted

    Params:
        array = array to clean from duplicate values

    Returns:
        true if array contains a duplicate or false if not. Returns false if
        array is empty.

*******************************************************************************/

public bool containsDuplicate ( T, bool sort = true ) ( T[] array )
{
    return !!findDuplicates!(T, sort)(
        array,
        delegate int(ref size_t index, ref T element) {return true;}
    );
}

/*******************************************************************************

    Sorts array and iterates over each array element that compares equal to the
    previous element.

    To just check for the existence of duplicates it's recommended to make
    found() return true (or some other value different from 0) to stop the
    iteration after the first duplicate.

    To assert array has no duplicates or throw an exception if it has, put the
    `assert(false)` or `throw ...` in `found()`:
    ---
        int[] array;

        findDuplicates(array,
                       (ref size_t index, ref int element)
                       {
                           throw new Exception("array contains duplicates");
                           return 0; // pacify the compiler
                       });
    ---

    Template params:
        T    = type of array element
        sort = true: do array.sort first; false: array is already sorted

    Params:
        array = array to clean from duplicate values
        found = `foreach`/`opApply()` style delegate, called with the index and
                the value of each array element that is equal to the previous
                element, returns 0 to continue or a value different from 0 to
                stop iteration.

    Returns:
        - 0 if no duplicates were found so `found()` was not called or
        - 0 if `found()` returned 0 on each call or
        - the non-zero value returned by `found()` on the last call.

*******************************************************************************/

public int findDuplicates ( T, bool sort = true )
                          ( T[] array, int delegate ( ref size_t index, ref T element ) found )
{
    if (array.length)
    {
        static if (sort)
        {
            array.sort;
        }

        foreach (i, ref element; array[1 .. $])
        {
            if (element == array[i])
            {
                auto j = i + 1;
                if (int x = found(j, element))
                {
                    return x;
                }
            }
        }
    }

    return 0;
}

unittest
{
    uint n_iterations, n_duplicates;

    struct Found
    {
        int    value;
        size_t index;
    }

    Found[8] found;
    int[8] array;
    alias findDuplicates!(typeof(array[0]), false) fd;

    int found_cb ( ref size_t index, ref int element )
    in
    {
        assert(n_iterations);
    }
    body
    {
        test(index);
        test(index < array.length);
        test(array[index] == array[index - 1]);
        found[n_duplicates++] = Found(element, index);
        return !--n_iterations;
    }

    array[] = 2;

    test(containsDuplicate(array));

    for (uint i = 1; i < array.length; i++)
    {
        n_iterations = i;
        n_duplicates = 0;
        int ret = fd(array, &found_cb);
        test(ret);
        test(n_duplicates == i);
    }

    n_iterations = array.length;
    n_duplicates = 0;
    {
        int ret = fd(array, &found_cb);
        test(!ret);
    }
    test(n_duplicates == array.length - 1);

    array[] = [2, 3, 5, 7, 11, 13, 17, 19];

    test(!containsDuplicate(array));

    n_duplicates = 0;

    for (uint i = 1; i <= array.length; i++)
    {
        n_iterations = i;
        int ret = fd(array, &found_cb);
        test(!ret);
        test(!n_duplicates);
    }

    n_iterations = array.length;
    array[] = 2;
    {
        n_duplicates = 0;
        int ret = fd(array[0 .. 0], &found_cb);
        test(!ret);
        test(!n_duplicates);
        ret = fd(array[0 .. 1], &found_cb);
        test(!ret);
        test(!n_duplicates);
        ret = fd(array[0 .. 2], &found_cb);
        test(!ret);
        test(n_duplicates == 1);
    }
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

bool startsWith ( TC1, TC2 ) ( TC1[] arr, TC2[] prefix )
{
    return (arr.length >= prefix.length) && (arr[0..prefix.length] == prefix[]);
}

unittest
{
    test( startsWith("abcd", "abc"));
    test( startsWith("abcd", "abcd"));
    test(!startsWith("ab", "abc"));
    test( startsWith("ab", ""));
    test(!startsWith("", "xx"));

    test( startsWith([1,2,3,4], [1,2,3]));
    test( startsWith([1,2,3,4], [1,2,3,4]));
    test(!startsWith([1,2], [1,2,3]));
    test( startsWith([1,2], [ ]));
    test(!startsWith([ ], [1,2]));
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

bool endsWith ( TC1, TC2 ) ( TC1[] arr, TC2[] suffix )
{
    return (arr.length >= suffix.length) && (arr[$ - suffix.length .. $] == suffix[]);
}

unittest
{
    test( endsWith("abcd", "bcd"));
    test( endsWith("abcd", "abcd"));
    test(!endsWith("ab", "abc"));
    test( endsWith("ab", ""));
    test(!endsWith("", "xx"));

    test( endsWith([1,2,3,4], [2,3,4]));
    test( endsWith([1,2,3,4], [1,2,3,4]));
    test(!endsWith([1,2], [1,2,3]));
    test( endsWith([1,2], [ ]));
    test(!endsWith([ ], [1,2]));
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

public TC1[] removePrefix ( TC1, TC2 ) ( TC1[] arr, TC2[] prefix )
{
    return ((arr.length >= prefix.length) && (startsWith(arr, prefix))
                ? arr[prefix.length .. $]
                : arr);
}

unittest
{
    test(removePrefix("abcd", "abc") == "d");
    test(removePrefix("abcd", "abcd") == "");
    test(removePrefix("abcd", "abcde") == "abcd");
    test(removePrefix("abcd", "") == "abcd");
    test(removePrefix("", "xx") == "");
    test("abcd".removePrefix("abc") == "d");
    test("abcd".removePrefix("abcd") == "");
    test("abcd".removePrefix("abcde") == "abcd");
    test("abcd".removePrefix("") == "abcd");
    test("".removePrefix("xx") == "");

    test(removePrefix([1,2,3,4], [1,2,3]) == [ 4 ]);
    test(removePrefix([1,2,3,4], [1,2,3,4]) == cast(int[]) null);
    test(removePrefix([1,2], [1,2,3]) == [ 1, 2 ]);
    test(removePrefix([1,2], [ ]) == [ 1, 2 ]);
    test(removePrefix([ ], [1,2]) == cast(int[]) null);
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

public TC1[] removeSuffix ( TC1, TC2 ) ( TC1[] arr, TC2[] suffix )
{
    return ((arr.length >= suffix.length) && (endsWith(arr, suffix))
                ? arr[0 .. $-suffix.length]
                : arr);
}

unittest
{
    test(removeSuffix("abcd", "cd") == "ab");
    test(removeSuffix("abcd", "abcd") == "");
    test(removeSuffix("abcd", "abcde") == "abcd");
    test(removeSuffix("abcd", "") == "abcd");
    test(removeSuffix("", "xx") == "");
    test("abcd".removeSuffix("cd") == "ab");
    test("abcd".removeSuffix("abcd") == "");
    test("abcd".removeSuffix("abcde") == "abcd");
    test("abcd".removeSuffix("") == "abcd");
    test("".removeSuffix("xx") == "");

    test(removeSuffix([1,2,3,4], [2,3,4]) == [ 1 ]);
    test(removeSuffix([1,2,3,4], [1,2,3,4]) == cast(int[]) null);
    test(removeSuffix([1,2], [1,2,3]) == [ 1, 2 ]);
    test(removeSuffix([1,2], [ ]) == [ 1, 2 ]);
    test(removeSuffix([ ], [1,2]) == cast(int[]) null);
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

unittest
{
    auto arr = "something".dup;
    filterInPlace(arr, (char c) { return c / 2; });
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

unittest
{
    auto arr = [ 1, 2, 4, 6, 20, 100, 240 ];
    size_t pos;
    bool found = bsearch(arr, 6, pos);
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

///
unittest
{
    int x;
    int[] arr = toArray(x);
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

///
unittest
{
    int[] arr = [ 1, 2, 3, 4 ];
    auto random_generator = () { return 0.42; }; // not proven by the dice roll
    shuffle(arr, random_generator());
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

unittest
{
    auto arr = [ 1, 2, 3 ];
    clear(arr);
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

unittest
{
    auto x = isClearable!(double);
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

private T[] concat_ ( T, TC ) ( T[] dest, TC[][] arrays, size_t start = 0 )
{
    static assert (is(Unqual!(T) == Unqual!(TC)));

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

private size_t toStaticArray ( D, istring func = "toStaticArray",
    T ... ) ( D[] dest, T elements )
in
{
    assert (
        dest.length == T.length,
        func ~ ": destination array length mismatch (expected"
            ~ T.length.stringof ~ ")"
    );
}
body
{
    size_t total_length = 0;

    foreach ( i, element; elements )
    {
        static assert (
            is(typeof(dest[i] = element)),
            func ~ ": cannot assign element " ~ i.stringof ~ " of type " ~
                typeof (element).stringof ~ " to  " ~ D.stringof
        );

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

private D concatT ( istring func, D, T ... ) ( ref D dest, T arrays, size_t start = 0 )
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
        static if (is(D U : U[]))
        {
            alias Const!(U)[] _D;
            _D[T.length] list;
        }
        else
        {
            static assert ("Expected array, got " ~ D.stringof);
        }

        dest.length = start + toStaticArray(list, arrays);

        return dest.concat_(list, start);
    }
}



/*******************************************************************************

    Unittest

*******************************************************************************/

unittest
{
    mstring str;
    assert (str.copy("Die Katze tritt die Treppe krumm.") == "Die Katze tritt die Treppe krumm.");

    str.length = 0;
    assert (str.concat("Die ", "Katze ", "tritt ", "die ", "Treppe ", "krumm.") == "Die Katze tritt die Treppe krumm.");

    mstring nothing = null;

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

    // Tests string concatenation function against results of the normal ~ operator
    bool concat_test ( cstring[] strings ... )
    {
        mstring dest;
        concat(dest, strings);

        mstring concat_result;
        foreach ( str; strings )
        {
            concat_result ~= str;
        }
        return dest == concat_result ;
    }
}

unittest
{
    mstring dest;
    istring str1 = "hello";
    istring str2 = "world";
    istring str3 = "something";

    // Check dynamic array concatenation
    test(concat_test(dest, str1, str2, str3), "Concatenation test failed");

    // Check that modifying one of the concatenated strings doesn't modify the result
    mstring result = dest.dup;
    str1 = "goodbye";
    test!("==")(dest, result);

    // Check null concatenation
    test(concat_test(dest), "Null concatenation test 1 failed");
    test(concat_test(dest, "", ""), "Null concatenation test 2 failed");

    // Check static array concatenation
    char[3] staticstr1 = "hi ";
    char[5] staticstr2 = "there";
    test(concat_test(dest, staticstr1, staticstr2), "Static array concatenation test failed");

    // Check manifest constant array concatenation
    const conststr1 = "hi ";
    const conststr2 = "there";
    test(concat_test(dest, conststr1, conststr2), "Const array concatenation test failed");
}

