/*******************************************************************************

    Serializable data structure that maps Range!(hash_t) keys
    to corresponding values

    This has been designed to work with the (de)serialization functionality
    in ocean.util.serialize.contiguous

    copyright:      Copyright (c) 2015 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.container.HashRangeMap;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.math.Range;

import tango.transition;

version ( UnitTest )
{
    import ocean.core.Test;
}


/*******************************************************************************

    Helper alias for range of hash_t

*******************************************************************************/

public alias Range!(hash_t) HashRange;


/*******************************************************************************

    Provides a mapping from HashRange to the specified type

    Note: Unittests for `put`, `remove` and `opIn_r` are not placed directly
    in this struct as they depend on the assumption that type `Value`
    (the template argument) has a meaningful equality operator (opEquals).
    Instead, private external functions exist to test these methods. These are
    then called on HashRangeMaps with various different types of Value,
    in a unittest block outside the struct.

    Template params:
        Value = type to store in values of map

*******************************************************************************/

public struct HashRangeMap ( Value )
{
    import ocean.core.Array;


    /***************************************************************************

        Array of HashRange that should be sorted in ascending order
        at all times.

        It always has the same length as values (see below),
        also to each ranges[i] corresponds to values[i]

        Note: the design with two separate arrays (ranges and values) was
        chosen in order to allow easy use of methods from ocean.math.Range
        (e.g. `hasGap`).

    ***************************************************************************/

    private HashRange[] ranges;


    /***************************************************************************

        Array of Value that should corresponds to range (see above)

    ***************************************************************************/

    private Value[] values;


    invariant()
    {
        assert(this.ranges.length == this.values.length,
               "HashRangeMap: length mismatch between ranges and values");
    }


    /***************************************************************************

        Looks up the mapping for range or adds one if not found

        Params:
            range = HashRange to look up or add mapping for
            added = set to true if the mapping did not exist but was added

        Returns:
            the pointer to value mapped to by the specified range. If output
            value `added` is true, the value is unspecified and the caller
            should set the value as desired.

        Out:
            The returned pointer is never null.

    ***************************************************************************/

    public Value* put ( HashRange range, out bool added )
    out (result)
    {
        assert(result !is null);
    }
    body
    {
        size_t insert_place;
        added = !bsearch(this.ranges, range, insert_place);

        if (added)
        {
            insertShift(this.ranges, insert_place);
            this.ranges[insert_place] = range;
            insertShift(this.values, insert_place);
        }

        return &this.values[insert_place];
    }


    /***************************************************************************

        Removes the mapping for the specified range

        Params:
            range = HashRange to remove mapping for

        Returns:
            true if range was found in the map or false if not

    ***************************************************************************/

    public bool remove ( HashRange range )
    {
        size_t remove_place;
        bool result = bsearch(this.ranges, range, remove_place);

        if (result)
        {
            removeShift(this.ranges, remove_place);
            removeShift(this.values, remove_place);
        }

        return result;
    }


    /***************************************************************************

        Clear entirely the HashRangeMap

    ***************************************************************************/

    public void clear ()
    {
        this.ranges.length = 0;
        enableStomping(this.ranges);

        this.values.length = 0;
        enableStomping(this.values);
    }

    unittest
    {
        // In order to make notation shorter
        alias HashRange R;

        HashRangeMap hrm;
        hrm.ranges = [R(1, 2), R(3, 15), R(10, 12)];
        hrm.values = [Value.init, Value.init, Value.init];

        hrm.clear();
        test!("==")(hrm.ranges.length, 0);
        test!("==")(hrm.values.length, 0);
    }


    /***************************************************************************

        'in' operator: looks up the value mapped by a given HashRange

        Params:
            range = hash range to check

        Returns:
            pointer to the value mapped by range, or null if range is
            not in the HashRangeMap

    ***************************************************************************/

    public Value* opIn_r ( HashRange range )
    {
        size_t insert_place;
        if (!bsearch(this.ranges, range, insert_place))
            return null;

        return &this.values[insert_place];
    }


    /***************************************************************************

        Check if the hash ranges in the map have neither gaps nor overlaps and
        cover the whole space of hash_t values.

        Returns:
            true if  there are no gaps and overlaps, and the whole hash_t values
            are covered with the ranges in map,
            false otherwise

    ***************************************************************************/

    public bool isTessellated ()
    {
        return HashRange(hash_t.min, hash_t.max).isTessellatedBy(this.ranges);
    }

    unittest
    {
        alias HashRange.makeRange makeRange;

        // tesselation
        {
            HashRangeMap hrm;
            hrm.ranges = [makeRange!("[)")(0, 300),
                          makeRange!("[)")(300, 7773),
                          makeRange!("[)")(7773, 169144),
                          makeRange!("[]")(169144, hash_t.max)];
            hrm.values = [Value.init, Value.init, Value.init, Value.init];
            test(hrm.isTessellated(),
                 "tessellation of hash_t should form tessellated HashRangeMap");
        }

        // overlap
        {
            HashRangeMap hrm;
            hrm.ranges = [makeRange!("[)")(0, 300),
                          makeRange!("[]")(300, 7773),
                          makeRange!("[)")(7773, 169144),
                          makeRange!("[]")(169144, hash_t.max)];
            hrm.values = [Value.init, Value.init, Value.init, Value.init];
            test(!hrm.isTessellated(),
                 "HashRangeMap with overlap in ranges haven't tessellation");
        }

        // gap
        {
            HashRangeMap hrm;
            hrm.ranges = [makeRange!("[)")(0, 300),
                          makeRange!("[)")(300, 7773),
                          makeRange!("()")(7773, 169144),
                          makeRange!("[]")(169144, hash_t.max)];
            hrm.values = [Value.init, Value.init, Value.init, Value.init];
            test(!hrm.isTessellated(),
                 "HashRangeMap with gap in ranges haven't tessellation");
        }

        // no coverage
        {
            HashRangeMap hrm;
            hrm.ranges = [makeRange!("[)")(20, 300),
                          makeRange!("[)")(300, 7773),
                          makeRange!("[)")(7773, 169144),
                          makeRange!("[]")(169144, hash_t.max)];
            hrm.values = [Value.init, Value.init, Value.init, Value.init];
            test(!hrm.isTessellated(),
                 "HashRangeMap without coverage the whole hash_t haven't tessellation");
        }

        {
            HashRangeMap hrm;
            hrm.ranges = [makeRange!("[)")(0, 300),
                          makeRange!("[)")(300, 7773),
                          makeRange!("[)")(7773, 169144),
                          makeRange!("[]")(169144, hash_t.max - 34)];
            hrm.values = [Value.init, Value.init, Value.init, Value.init];
            test(!hrm.isTessellated(),
                 "HashRangeMap without coverage the whole hash_t haven't tessellation");
        }
    }


    /***************************************************************************

        Check if the hash ranges in the map have any gaps between them or
        boundaries of hash_t type.

        Returns:
            true if any gaps exist between the ranges in the map,
            false otherwise

    ***************************************************************************/

    public bool hasGap ()
    {
        return extent(this.ranges) != HashRange(hash_t.min, hash_t.max)
               || ocean.math.Range.hasGap(this.ranges);
    }

    unittest
    {
        // In order to make notation shorter
        alias HashRange R;

        // gap
        {
            HashRangeMap hrm;
            hrm.ranges = [R(hash_t.min, 2), R(3, 15), R(20, hash_t.max)];
            hrm.values = [Value.init, Value.init, Value.init];
            test(hrm.hasGap(), "This HashRangeMap has gap");
        }

        // no coverage
        {
            HashRangeMap hrm;
            hrm.ranges = [R(1, 2), R(3, 10), R(11, hash_t.max)];
            hrm.values = [Value.init, Value.init, Value.init];
            test(hrm.hasGap(), "This HashRangeMap has gap");
        }

        // no coverage
        {
            HashRangeMap hrm;
            hrm.ranges = [R(hash_t.min, 2), R(3, 10), R(11, 40)];
            hrm.values = [Value.init, Value.init, Value.init];
            test(hrm.hasGap(), "This HashRangeMap has gap");
        }

        // overlap
        {
            HashRangeMap hrm;
            hrm.ranges = [R(hash_t.min, 2), R(3, 15), R(10, hash_t.max)];
            hrm.values = [Value.init, Value.init, Value.init];
            test(!hrm.hasGap(), "This HashRangeMap shouldn't have gaps");
        }

        // contiguous
        {
            HashRangeMap hrm;
            hrm.ranges = [R(hash_t.min, 2), R(3, 15), R(16, hash_t.max)];
            hrm.values = [Value.init, Value.init, Value.init];
            test(!hrm.hasGap(), "This HashRangeMap shouldn't have gaps");
        }
    }


    /***************************************************************************

        Check if there is any overlap between the hash ranges in the map

        Returns:
            true if at least one pair of ranges in the map overlap,
            false otherwise

    ***************************************************************************/

    public bool hasOverlap ()
    {
        return ocean.math.Range.hasOverlap(this.ranges);
    }

    unittest
    {
        // In order to make notation shorter
        alias HashRange R;

        // gap
        {
            HashRangeMap hrm;
            hrm.ranges = [R(1, 2), R(3, 15), R(20, 27)];
            hrm.values = [Value.init, Value.init, Value.init];
            test(!hrm.hasOverlap(), "This HashRangeMap shouldn't have overlaps");
        }

        // overlap
        {
            HashRangeMap hrm;
            hrm.ranges = [R(1, 2), R(3, 15), R(10, 12)];
            hrm.values = [Value.init, Value.init, Value.init];
            test(hrm.hasOverlap(), "This HashRangeMap has overlap");
        }

        // contiguous
        {
            HashRangeMap hrm;
            hrm.ranges = [R(1, 2), R(3, 15), R(16, 21)];
            hrm.values = [Value.init, Value.init, Value.init];
            test(!hrm.hasOverlap(), "This HashRangeMap shouldn't have overlaps");
        }
    }
}


/*******************************************************************************

    test instantiation with int

*******************************************************************************/

unittest
{
    HashRangeMap!(int) ihrm;

    testPut([1, 2, 3, 4, 5, 6, 7, 8]);
    testRemove([1, 2, 3, 4, 5]);
    testOpInR([1, 2, 3, 4, 5]);
}


/*******************************************************************************

    test instantiation with ulong

*******************************************************************************/

unittest
{
    HashRangeMap!(ulong) uhrm;

    testPut([1UL, 2UL, 3UL, 4UL, 5UL, 6UL, 7UL, 8UL]);
    testRemove([1UL, 2UL, 3UL, 4UL, 5UL]);
    testOpInR([1UL, 2UL, 3UL, 4UL, 5UL]);
}


/*******************************************************************************

    test instantiation with float

*******************************************************************************/

unittest
{
    HashRangeMap!(float) fhrm;

    testPut([1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f]);
    testRemove([1.0f, 2.0f, 3.0f, 4.0f, 5.0f]);
    testOpInR([1.0f, 2.0f, 3.0f, 4.0f, 5.0f]);
}


/*******************************************************************************

    test instantiation with pointer

*******************************************************************************/

unittest
{
    int v1, v2, v3, v4, v5, v6, v7, v8;
    HashRangeMap!(int*) phrm;

    testPut([&v1, &v2, &v3, &v4, &v5, &v6, &v7, &v8]);
    testRemove([&v1, &v2, &v3, &v4, &v5]);
    testOpInR([&v1, &v2, &v3, &v4, &v5]);
}


/*******************************************************************************

    test instantiation with arbitrary struct that supports `opEquals`

*******************************************************************************/

unittest
{
    struct S
    {
        import tango.util.Convert;

        int x;

        static S opCall(int x)
        {
            S s;
            s.x = x;
            return s;
        }

        bool opEquals(S other)
        {
            return this.x == other.x;
        }

        istring toString()
        {
            return "S(" ~ to!(istring)(this.x) ~ ")";
        }
    }

    HashRangeMap!(S) shrm;

    testPut([S(1), S(2), S(3), S(4), S(5), S(6), S(7), S(8)]);
    testRemove([S(1), S(2), S(3), S(4), S(5)]);
    testOpInR([S(1), S(2), S(3), S(4), S(5)]);
}


/*******************************************************************************

    test instantiation with array

*******************************************************************************/

unittest
{
    HashRangeMap!(int[]) arhrm;

    testPut([[1], [2, 1], [3, 1, 2], [4], [5], [6], [7], [8]]);
    testRemove([[1], [2, 1], [3, 1, 2], [4], [5]]);
    testOpInR([[1], [2, 1], [3, 1, 2], [4], [5]]);
}


version ( UnitTest )
{
    import tango.core.Traits;

    private template hasAtomicEquality ( T )
    {
        static if (is(T == struct) || is(T == class) || is(T == interface))
        {
            const hasAtomicEquality = is(typeof(T.opEquals));
        }
        else
        {
            const hasAtomicEquality = isAtomicType!(T) || isPointerType!(T);
        }
    }


    private template hasEquality ( T )
    {
        static if (isArrayType!(T))
        {
            const hasEquality = hasAtomicEquality!(BaseTypeOfArrays!(T));
        }
        else
        {
            const hasEquality = hasAtomicEquality!(T);
        }
    }


    // Unittest function for put().
    private void testPut (Value) ( Value[] v )
    in
    {
        assert(v.length == 8, "You should provide an array of 8 different values");
    }
    body
    {
        static assert(hasEquality!(Value),
                      "Value has to support equality check to run this test function");
        // In order to make notation shorter
        alias HashRange R;

        HashRangeMap!(Value) hrm;
        bool added;
        Value* ret;

        // first addition
        *(ret = hrm.put(R(3, 15), added)) = v[0];
        test!("==")(*ret, v[0]);
        test(added, "This case should rise added flag");
        test!("==")(hrm.ranges,
        [R(3, 15)]);
        test!("==")(hrm.values, [v[0]]);

        // addition to the end
        *(ret = hrm.put(R(19, 25), added)) = v[1];
        test!("==")(*ret, v[1]);
        test(added, "This case should rise added flag");
        test!("==")(hrm.ranges,
        [R(3, 15), R(19, 25)]);
        test!("==")(hrm.values, [v[0], v[1]]);

        // addition to the middle
        *(ret = hrm.put(R(16, 18), added)) = v[2];
        test!("==")(*ret, v[2]);
        test(added, "This case should rise added flag");
        test!("==")(hrm.ranges,
        [R(3, 15), R(16, 18), R(19, 25)]);
        test!("==")(hrm.values, [v[0], v[2], v[1]]);

        // addition to the middle; min of new HashRange is within existing range
        *(ret = hrm.put(R(10, 20), added)) = v[3];
        test!("==")(*ret, v[3]);
        test(added, "This case should rise added flag");
        test!("==")(hrm.ranges,
        [R(3, 15), R(10, 20), R(16, 18), R(19, 25)]);
        test!("==")(hrm.values, [v[0], v[3], v[2], v[1]]);

        // addition to the middle; min of new HashRange is the same with one
        // of the range
        *(ret = hrm.put(R(10, 12), added)) = v[4];
        test!("==")(*ret, v[4]);
        test(added, "This case should rise added flag");
        test!("==")(hrm.ranges,
        [R(3, 15), R(10, 12), R(10, 20), R(16, 18), R(19, 25)]);
        test!("==")(hrm.values, [v[0], v[4], v[3], v[2], v[1]]);

        // added existing range
        *(ret = hrm.put(R(10, 12), added)) = v[5];
        test!("==")(*ret, v[5]);
        test(!added, "In this case a range already exists");
        test!("==")(hrm.ranges,
        [R(3, 15), R(10, 12), R(10, 20), R(16, 18), R(19, 25)]);
        test!("==")(hrm.values, [v[0], v[5], v[3], v[2], v[1]]);

        // addition to the begin
        *(ret = hrm.put(R(1, 2), added)) = v[6];
        test!("==")(*ret, v[6]);
        test(added, "This case should rise added flag");
        test!("==")(hrm.ranges,
        [R(1, 2), R(3, 15), R(10, 12), R(10, 20), R(16, 18), R(19, 25)]);
        test!("==")(hrm.values, [v[6], v[0], v[5], v[3], v[2], v[1]]);

        // addition to the end with gap
        *(ret = hrm.put(R(30, 33), added)) = v[7];
        test!("==")(*ret, v[7]);
        test(added, "This case should rise added flag");
        test!("==")(hrm.ranges,
        [R(1, 2), R(3, 15), R(10, 12), R(10, 20), R(16, 18), R(19, 25), R(30, 33)]);
        test!("==")(hrm.values, [v[6], v[0], v[5], v[3], v[2], v[1], v[7]]);
    }


    // Unittest function for remove().
    private void testRemove ( Value ) ( Value[] v)
    in
    {
        assert(v.length == 5, "You should provide an array of 5 different values");
    }
    body
    {
        static assert(hasEquality!(Value),
                      "Value has to support equality check to run this test function");

        // In order to make notation shorter
        alias HashRange R;

        HashRangeMap!(Value) hrm;
        hrm.ranges = [R(1, 2), R(3, 15), R(10, 12), R(10, 20), R(16, 18)];
        hrm.values = v.dup;

        // remove existent key
        test(hrm.remove(HashRange(10, 12)), "This range should exist");
        test!("==")(hrm.ranges,
                    [R(1, 2), R(3, 15), R(10, 20), R(16, 18)]);
        test!("==")(hrm.values, [v[0], v[1], v[3], v[4]]);

        // remove nonexistent key
        test(!hrm.remove(HashRange(10, 12)), "This range should be deleted already");
        test!("==")(hrm.ranges,
                    [R(1, 2), R(3, 15), R(10, 20), R(16, 18)]);
        test!("==")(hrm.values, [v[0], v[1], v[3], v[4]]);
    }

    // Unittest function for opIn_r().
    private void testOpInR ( Value ) ( Value[] v )
    in
    {
        assert(v.length == 5, "You should provide an array of 5 different values");
    }
    body
    {
        static assert(hasEquality!(Value),
                      "Value has to support equality check to run this test function");

        // In order to make notation shorter
        alias HashRange R;

        HashRangeMap!(Value) hrm;
        hrm.ranges = [R(1, 2), R(3, 15), R(10, 12), R(10, 20), R(16, 18)];
        hrm.values = v.dup;

        // not existent range
        test!("==")(R(3, 12) in hrm, null);

        // existent range
        for(size_t i = 0; i < hrm.ranges.length; ++i)
            test!("==")(*(hrm.ranges[i] in hrm), v[i]);
    }
}