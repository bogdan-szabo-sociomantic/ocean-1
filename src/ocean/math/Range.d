/*******************************************************************************

    Copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    Simple integer range struct with various comparison functions.

    Note that the range template currently only supports unsigned integer types.
    It would be possible to extend it to also work with signed and/or floating
    point types.

*******************************************************************************/

module ocean.math.Range;



/*******************************************************************************

    Imports

*******************************************************************************/

import tango.core.Traits : isUnsignedIntegerType;

version ( UnitTest )
{
    import ocean.core.Test;
}



/*******************************************************************************

    Range struct template

*******************************************************************************/

public struct Range ( T )
{
    static assert(isUnsignedIntegerType!(T),
        "Range only works with unsigned integer types");


    /***************************************************************************

        Min & max values when range is empty (magic values).

    ***************************************************************************/

    private const T null_min = T.max;
    private const T null_max = T.min;


    /***************************************************************************

        Min & max values, default to the empty range.

    ***************************************************************************/

    private T min_ = null_min;
    private T max_ = null_max;


    /***************************************************************************

        Checks whether the specified range is empty.

        Params:
            min = minimum value
            max = maximum value

        Returns:
            true if the range is empty (null)

    ***************************************************************************/

    static public bool isEmpty ( T min, T max )
    {
        return min == null_min && max == null_max;
    }

    unittest
    {
        assert(isEmpty(null_min, null_max));
        assert(!isEmpty(null_max, null_min));
        assert(!isEmpty(1, null_max));
        assert(!isEmpty(null_min, 1));
        assert(!isEmpty(1, 1));
        assert(!isEmpty(1, 2));
        assert(!isEmpty(2, 1));
    }


    /***************************************************************************

        Checks whether the specified range is valid.

        Params:
            min = minimum value
            max = maximum value

        Returns:
            true if the range is valid (min <= max or empty)

    ***************************************************************************/

    static public bool isValid ( T min, T max )
    {
        return min <= max || isEmpty(min, max);
    }

    unittest
    {
        assert(isValid(null_min, null_max));
        assert(isValid(0, 0));
        assert(isValid(0, 1));
        assert(isValid(T.max, T.max));
        assert(!isValid(1, 0));
    }


    /***************************************************************************

        The range must always be valid.

    ***************************************************************************/

    invariant()
    {
        assert(isValid(this.min_, this.max_));
    }

    version ( UnitTest )
    {
        import tango.util.Convert;

        public istring toString()
        {
            return this.is_empty ? "()"
                   : "(" ~ to!(istring)(this.min_) ~ ", " ~ to!(istring)(this.max_) ~ ")";
        }
    }


    /***************************************************************************

        Static opCall. Disables the default "constructor", with the advantage
        that the invariant is run after calling this method, making it
        impossible to construct invalid instances.

        Params:
            min = minimum value of range
            max = maximum value of range

        Returns:
            new Range instance

    ***************************************************************************/

    public static Range opCall ( T min, T max )
    {
        Range r;
        r.min_ = min;
        r.max_ = max;
        return r;
    }


    /***************************************************************************

        Returns:
            the minimum value of the range

    ***************************************************************************/

    public T min ( )
    {
        return this.min_;
    }


    /***************************************************************************

        Returns:
            the maximum value of the range

    ***************************************************************************/

    public T max ( )
    {
        return this.max_;
    }


    /***************************************************************************

        Sets the minimum value of the range.

        Params:
            min = new minimum value

    ***************************************************************************/

    public void min ( T min )
    {
        return this.min_ = min;
    }


    /***************************************************************************

        Sets the maximum value of the range.

        Params:
            max = new maximum value

    ***************************************************************************/

    public void max ( T max )
    {
        return this.max_ = max;
    }


    /***************************************************************************

        Returns:
            true if the range is empty (null)

    ***************************************************************************/

    public bool is_empty ( )
    {
        return isEmpty(this.min, this.max);
    }


    /***************************************************************************

        Note that in non-release builds, the struct invariant ensures that
        instances are always valid. This method can be called by user code to
        explicitly check the validity of a range, for example when creating a
        range from run-time data.

        Returns:
            true if the range is valid (min < max, or empty)

    ***************************************************************************/

    public bool is_valid ( )
    {
        return isValid(this.min, this.max);
    }


    /***************************************************************************

        Returns:
            the number of values in the range

    ***************************************************************************/

    public size_t length ( )
    {
        if ( this.is_empty ) return 0;

        return (this.max - this.min) + 1;
    }

    unittest
    {
        assert(Range.init.length == 0);
        assert(Range(0, 0).length == 1);
        assert(Range(5, 5).length == 1);
        assert(Range(0, 1).length == 2);
        assert(Range(5, 10).length == 6);
    }


    /***************************************************************************

        Checks whether the specified range is exactly identical to this range.

        Params:
            other = instance to compare this with

        Returns:
            true if both ranges are identical

    ***************************************************************************/

    public bool opEquals ( Range other )
    {
        return this.min == other.min && this.max == other.max;
    }

    unittest
    {
        // empty == empty
        assert(Range.init == Range.init);

        // empty != a
        assert(Range.init != Range(0, 1));

        // a != empty
        assert(Range(0, 1) != Range.init);

        // a == b
        assert(Range(0, 1) == Range(0, 1));

        // a != b
        assert(Range(0, 1) != Range(1, 2));
    }


    /***************************************************************************

        Checks whether the union of the specified ranges covers exactly the same
        range as this instance, with no gaps.

        Note that the passed list of ranges is sorted by this method. Empty
        ranges in the list are ignored.

        Params:
            sub_ranges = list of ranges to union and compare against this
                instance

        Returns:
            true if the union of sub_ranges covers exactly the same range as
            this instance

    ***************************************************************************/

    public bool opEquals ( Range[] sub_ranges )
    {
        if ( sub_ranges.length == 0 ) return false;

        sub_ranges.sort;

        // sort() moves empty ranges to the start of the list. Slice them off.
        while ( sub_ranges[0].is_empty )
        {
            sub_ranges = sub_ranges[1..$];
        }

        if ( sub_ranges[0].min != this.min ) return false;
        if ( sub_ranges[$-1].max != this.max ) return false;

        for ( size_t i = 1; i < sub_ranges.length; i++ )
        {
            if ( sub_ranges[i].min != sub_ranges[i - 1].max + 1 ) return false;
        }

        return true;
    }

    unittest
    {
        // minimal case: one hash range, test covers and not-covers
        assert(Range(0, 0) == [Range(0, 0)]);
        assert(Range(0, 0) != [Range(1, 1)]);

        // complete
        assert(Range(0, 10) ==
            [Range(0, 1), Range(2, 5), Range(6, 10)]);

        // missing start
        assert(Range(0, 10) !=
            [Range(1, 1), Range(2, 5), Range(6, 10)]);

        // missing middle
        assert(Range(0, 10) !=
            [Range(0, 1), Range(3, 5), Range(6, 10)]);

        // missing end
        assert(Range(0, 10) !=
            [Range(0, 1), Range(2, 5), Range(6, 9)]);

        // unsorted, complete
        assert(Range(0, 10) ==
            [Range(6, 10), Range(2, 5), Range(0, 1)]);

        // complete, empty ranges skipped
        Range empty;
        assert(Range(0, 10) ==
            [Range(6, 10), Range(2, 5), Range(0, 1), empty, empty]);

        // unsorted, missing start
        assert(Range(0, 10) !=
            [Range(6, 10), Range(2, 5), Range(1, 1)]);

        // unsorted, missing middle
        assert(Range(0, 10) !=
            [Range(6, 10), Range(3, 5), Range(0, 1)]);

        // unsorted, missing end
        assert(Range(0, 10) !=
            [Range(6, 9), Range(2, 5), Range(0, 1)]);
    }


    /***************************************************************************

        Compares this instance with other. An empty range is considered to be <
        all non-empty ranges. Otherwise, the comparison always considers the
        range's minimum value before comparing the maximum value.

        Params:
            other = instance to compare with this

        Returns:
            a value less than 0 if this < other,
            a value greater than 0 if this > other
            or 0 if this == other.

    ***************************************************************************/

    public int opCmp ( Range other )
    {
        if ( this.is_empty )  return other.is_empty ? 0 : -1;
        if ( other.is_empty ) return 1;

        if ( this.min < other.min ) return -1;
        if ( other.min < this.min ) return 1;
        assert(this.min == other.min);
        if ( this.max < other.max ) return -1;
        if ( other.max < this.max ) return 1;
        return 0;
    }

    unittest
    {
        // empty < smallest range
        assert(Range.init < Range(0, 0));

        // smallest range > empty
        assert(Range(0, 0) > Range.init);

        // a < b
        assert(Range(0, 1) < Range(2, 3));

        // a > b
        assert(Range(2, 3) > Range(0, 1));

        // a < b (overlapping)
        assert(Range(0, 1) < Range(1, 2));

        // a > b (overlapping)
        assert(Range(1, 2) > Range(0, 1));
    }


    /***************************************************************************

        Determines whether this instance is non-empty subset of the specified
        range. All values in this range must be within the other range.

        Note: For practical reasons, this isn't conforming strictly to
        the mathematical definition, where an empty set is considered to be
        a subset of any set. However, two equal ranges will be considered
        to be subsets of one another.

        Params:
            other = instance to compare with this

        Returns:
            true if this range is a subset of the other range

    ***************************************************************************/

    public bool isSubsetOf ( Range other )
    {
        if ( this.is_empty || other.is_empty )
            return false;

        return this.min >= other.min && this.max <= other.max;
    }

    unittest
    {
        // empty
        test(!Range.init.isSubsetOf(Range(0, 10)), "Empty range doesn't count as subset");
        test(!Range(0, 10).isSubsetOf(Range.init), "Empty range can't be superset");

        // very proper subset
        test(Range(1, 9).isSubsetOf(Range(0, 10)));

        // equal
        test(Range(0, 10).isSubsetOf(Range(0, 10)), "Equal range is a subset too");

        // ends touch, inside
        test(Range(0, 9).isSubsetOf(Range(0, 10)));
        test(Range(1, 10).isSubsetOf(Range(0, 10)));

        // ends touch, outside
        test(!Range(0, 5).isSubsetOf(Range(5, 10)));
        test(!Range(10, 15).isSubsetOf(Range(5, 10)));

        // very proper superset
        test(!Range(0, 10).isSubsetOf(Range(1, 9)), "Proper superset can't be subset");

        // overlap
        test(!Range(0, 10).isSubsetOf(Range(5, 15)));

        // no overlap
        test(!Range(5, 10).isSubsetOf(Range(15, 20)));
    }


    /***************************************************************************
        Determines whether this instance is a proper subset of the specified
        range. All values in this range must be within the other range and not
        extend to either the start or end of this range.

        Params:
            other = instance to compare with this

        Returns:
            true if this range is a subset of the other range

    ***************************************************************************/

    public bool subsetOf ( Range other )
    {
        if ( this.is_empty || other.is_empty ) return false;

        return this.min > other.min && this.max < other.max;
    }

    unittest
    {
        // empty
        assert(!Range.init.subsetOf(Range(0, 10)));
        assert(!Range(0, 10).subsetOf(Range.init));

        // subset
        assert(Range(1, 9).subsetOf(Range(0, 10)));

        // equal
        assert(!Range(0, 10).subsetOf(Range(0, 10)));

        // ends touch, inside
        assert(!Range(0, 9).subsetOf(Range(0, 10)));
        assert(!Range(1, 10).subsetOf(Range(0, 10)));

        // ends touch, outside
        assert(!Range(0, 5).subsetOf(Range(5, 10)));
        assert(!Range(10, 15).subsetOf(Range(5, 10)));

        // superset
        assert(!Range(0, 10).subsetOf(Range(1, 9)));

        // no overlap
        assert(!Range(5, 10).subsetOf(Range(15, 20)));
    }


    /***************************************************************************

        Determines whether this instance is a proper superset of the specified
        range. All values in the other range must be within this range and not
        extend to either the start or end of this range.

        Params:
            other = instance to compare with this

        Returns:
            true if this range is a superset of the other range

    ***************************************************************************/

    public bool supersetOf ( Range other )
    {
        if ( this.is_empty || other.is_empty ) return false;

        return other.min > this.min && other.max < this.max;
    }

    unittest
    {
        // empty
        assert(!Range.init.supersetOf(Range(0, 10)));
        assert(!Range(0, 10).supersetOf(Range.init));

        // superset
        assert(Range(0, 10).supersetOf(Range(1, 9)));

        // equal
        assert(!Range(0, 10).supersetOf(Range(0, 10)));

        // ends touch, inside
        assert(!Range(0, 10).supersetOf(Range(0, 9)));
        assert(!Range(0, 10).supersetOf(Range(1, 10)));

        // ends touch, outside
        assert(!Range(5, 10).supersetOf(Range(0, 5)));
        assert(!Range(5, 10).supersetOf(Range(10, 15)));

        // subset
        assert(!Range(1, 9).supersetOf(Range(0, 10)));

        // no overlap
        assert(!Range(5, 10).supersetOf(Range(15, 20)));
    }


    /***************************************************************************

        Predicate that checks whether the provided array of ranges exactly
        tessellates this range.  The term "tessellation" means that this
        range is a union of the given ranges and that the given ranges form
        a contiguous chain without gap or overlap.

        It is assumed that the array is already sorted.

        This method can be used as a replacement for the now-deprecated
        opEquals ( Range[] )

        Params:
            ranges = a sorted array of Range!T

        Returns:
            true if this instance is tessellated by the given array
            of ranges, false otherwise

    ***************************************************************************/

    public bool isTessellatedBy ( Range[] ranges )
    {
        return (*this == extent(ranges)) && isContiguous(ranges);
    }

    unittest
    {
        // minimal case: one range, test covers and not-covers
        test(Range(0, 0).isTessellatedBy([Range(0, 0)]));
        test(!Range(0, 0).isTessellatedBy([Range(1, 1)]));

        // tessellation by itself
        test(Range(3, 12).isTessellatedBy([Range(3, 12)]), "Any range should tessellate itself");

        // proper subset or proper superset can't be tessellation
        test(!Range(3, 12).isTessellatedBy([Range(4, 11)]), "Proper superset can't be tessellation");
        test(!Range(3, 12).isTessellatedBy([Range(3, 11)]), "Proper superset can't be tessellation");
        test(!Range(3, 12).isTessellatedBy([Range(4, 12)]), "Proper superset can't be tessellation");
        test(!Range(3, 12).isTessellatedBy([Range(2, 13)]), "Proper subset can't be tessellation");
        test(!Range(3, 12).isTessellatedBy([Range(3, 13)]), "Proper subset can't be tessellation");
        test(!Range(3, 12).isTessellatedBy([Range(2, 12)]), "Proper subset can't be tessellation");

        // complete
        test(Range(0, 10).isTessellatedBy([Range(0, 1),
                                           Range(2, 5),
                                           Range(6, 10)]));

        // missing start
        test(!Range(0, 10).isTessellatedBy([Range(1, 1),
                                            Range(2, 5),
                                            Range(6, 10)]));

        // missing middle
        test(!Range(0, 10).isTessellatedBy([Range(0, 1),
                                                  Range(3, 5),
                                                  Range(6, 10)]));

        // missing end
        test(!Range(0, 10).isTessellatedBy([Range(0, 1),
                                            Range(2, 5),
                                            Range(6, 9)]));

        // overlapped ranges in list
        test(!Range(0, 10).isTessellatedBy([Range(0, 2),
                                            Range(2, 5),
                                            Range(6, 10)]));

        // empty ranges skipped
        Range empty;
        test(Range(0, 10).isTessellatedBy([empty,
                                           empty,
                                           Range(0, 1),
                                           Range(2, 5),
                                           Range(6, 10)]));

        // union of empty ranges and empty list
        test(!Range(0, 10).isTessellatedBy([empty,
                                            empty,
                                            empty]));
        test(!Range(0, 10).isTessellatedBy([empty]));
        test(!Range(0, 10).isTessellatedBy([]));
        test(!Range(0, 10).isTessellatedBy(null));
    }


    /***************************************************************************

        Calculates the number of values shared by this range and the other range
        specified.

        Params:
            other = instance to compare with this

        Returns:
            the number of values shared by the two ranges

    ***************************************************************************/

    public size_t overlapAmount ( Range other )
    {
        if ( this.is_empty || other.is_empty ) return 0;

        if ( *this == other || other.supersetOf(*this) ) return this.length;

        if ( other.subsetOf(*this) ) return other.length;

        if ( other.min < this.min ) // starts before this
        {
            assert(other.max <= this.max); // also ends within this, otherwise superset

            if ( other.max < this.min ) return 0;   // ends before this
            return (other.max - this.min) + 1;      // ends within this
        }
        else if ( other.min <= this.max ) // starts within this
        {
            if ( other.max <= this.max ) return other.length; // ends within this
            return (this.max - other.min) + 1;                // ends outside this
        }
        else // starts after this
        {
            return 0;
        }
    }

    unittest
    {
        // empty
        assert(Range.init.overlapAmount(Range.init) == 0);
        assert(Range.init.overlapAmount(Range(0, 10)) == 0);
        assert(Range(0, 10).overlapAmount(Range.init) == 0);

        // equal
        assert(Range(0, 10).overlapAmount(Range(0, 10)) == 11);

        // proper subset
        assert(Range(0, 10).overlapAmount(Range(1, 9)) == 9);

        // proper superset
        assert(Range(1, 9).overlapAmount(Range(0, 10)) == 9);

        // ends touch
        assert(Range(0, 10).overlapAmount(Range(10, 20)) == 1);
        assert(Range(10, 20).overlapAmount(Range(0, 10)) == 1);

        // subset + ends touch
        assert(Range(0, 10).overlapAmount(Range(0, 9)) == 10);
        assert(Range(0, 10).overlapAmount(Range(1, 10)) == 10);

        // superset + ends touch
        assert(Range(0, 9).overlapAmount(Range(0, 10)) == 10);
        assert(Range(1, 10).overlapAmount(Range(0, 10)) == 10);

        // overlaps
        assert(Range(0, 10).overlapAmount(Range(9, 20)) == 2);
        assert(Range(10, 20).overlapAmount(Range(0, 11)) == 2);

        // no overlap
        assert(Range(0, 10).overlapAmount(Range(11, 20)) == 0);
        assert(Range(10, 20).overlapAmount(Range(0, 9)) == 0);
    }


    /***************************************************************************

        Checks whether this range shares any values with the other range
        specified.

        Params:
            other = instance to compare with this

        Returns:
            true if the two ranges share any values

    ***************************************************************************/

    public bool overlaps ( Range other )
    {
        if ( this.is_empty || other.is_empty ) return false;

        return !(other.max < this.min || other.min > this.max);
    }

    unittest
    {
        // empty
        assert(!Range.init.overlaps(Range.init));
        assert(!Range.init.overlaps(Range(0, 10)));
        assert(!Range(0, 10).overlaps(Range.init));

        // equal
        assert(Range(0, 10).overlaps(Range(0, 10)));

        // proper subset
        assert(Range(0, 10).overlaps(Range(1, 9)));

        // proper superset
        assert(Range(1, 9).overlaps(Range(0, 10)));

        // ends touch
        assert(Range(0, 10).overlaps(Range(10, 20)));
        assert(Range(10, 20).overlaps(Range(0, 10)));

        // subset + ends touch
        assert(Range(0, 10).overlaps(Range(0, 9)));
        assert(Range(0, 10).overlaps(Range(1, 10)));

        // superset + ends touch
        assert(Range(0, 9).overlaps(Range(0, 10)));
        assert(Range(1, 10).overlaps(Range(0, 10)));

        // overlaps
        assert(Range(0, 10).overlaps(Range(9, 20)));
        assert(Range(10, 20).overlaps(Range(0, 11)));

        // no overlap
        assert(!Range(0, 10).overlaps(Range(11, 20)));
        assert(!Range(10, 20).overlaps(Range(0, 9)));
    }


    /***************************************************************************

        Subtracts the specified range from this range, returning the remaining
        range(s) via the out parameters. Two separate ranges can result from a
        subtraction if the range being subtracted bisects the range being
        subtracted from, like:

            subtract        ------
            from        --------------
            remainder   ----      ----

        Params:
            other = range to subtract from this
            lower = lower output range. If only a single range results from the
                subtraction, it will be returned via this parameter
            upper = upper output range. Only set when the subtraction results in
                two ranges

    ***************************************************************************/

    public void subtract ( Range other, out Range lower, out Range upper )
    {
        // this empty -- empty result
        if ( this.is_empty ) return;

        // other empty -- no change
        if ( other.is_empty )
        {
            lower = *this;
            return;
        }

        // equal -- empty result
        if ( *this == other ) return;

        // other is proper superset of this -- empty result
        if ( other.supersetOf(*this) ) return;

        // ranges do not overlap -- no change
        if ( !this.overlaps(other) )
        {
            lower = *this;
            return;
        }

        // other is proper subset of this -- two ranges result
        if ( other.subsetOf(*this) )
        {
            lower = Range(this.min, other.min - 1);
            upper = Range(other.max + 1, this.max);
            return;
        }

        // ranges overlap (but not proper superset or subset)
        assert(this.overlaps(other));

        if ( other.min <= this.min )
        {
            assert(other.max < this.max);
            lower = Range(other.max + 1, this.max);
            return;
        }
        else
        {
            assert(other.min > this.min);
            assert(other.max >= this.max);
            lower = Range(this.min, other.min - 1);
            return;
        }

        assert(false);
    }

    unittest
    {
        bool test ( Range r1, Range r2,
            Range l_expected, Range u_expected = Range.init )
        {
            Range l, u;
            r1.subtract(r2, l, u);
            return l == l_expected && u == u_expected;
        }

        // empty
        assert(test(Range.init, Range.init, Range.init));
        assert(test(Range.init, Range(0, 0), Range.init));
        assert(test(Range(0, 0), Range.init, Range(0, 0)));

        // equal
        assert(test(Range(0, 0), Range(0, 0), Range.init));
        assert(test(Range(0, 10), Range(0, 10), Range.init));

        // superset
        assert(test(Range(1, 9), Range(0, 10), Range.init));

        // subset
        assert(test(Range(0, 10), Range(1, 9), Range(0, 0), Range(10, 10)));
        assert(test(Range(0, 10), Range(5, 5), Range(0, 4), Range(6, 10)));

        // no overlap
        assert(test(Range(0, 10), Range (11, 20), Range(0, 10)));
        assert(test(Range(11, 20), Range (0, 10), Range(11, 20)));

        // ends touch
        assert(test(Range(10, 20), Range(0, 10), Range(11, 20)));
        assert(test(Range(10, 20), Range(20, 30), Range(10, 19)));

        // overlap
        assert(test(Range(5, 15), Range(0, 10), Range(11, 15)));
        assert(test(Range(5, 15), Range(5, 10), Range(11, 15)));
        assert(test(Range(5, 15), Range(10, 20), Range(5, 9)));
        assert(test(Range(5, 15), Range(10, 15), Range(5, 9)));
    }
}



/*******************************************************************************

    Unittest to instantiate the Range template with all supported types, in turn
    running the unittests for each of them.

*******************************************************************************/

unittest
{
    Range!(ubyte) br;
    Range!(ushort) sr;
    Range!(ulong) lr;
}


/*******************************************************************************

    Predicate that checks for the existence of one or more gaps
    in an array of Range!T.

    It is assumed that the array is already sorted. All empty ranges are ignored.

    Params:
        ranges = a sorted array of Range!T to be checked

    Returns:
        true if at least one gap exists in the array

*******************************************************************************/

public bool hasGap ( T ) ( Range!(T)[] ranges )
{
    trimEmptyRanges(ranges);

    if (ranges.length > 0)
    {
        auto current_threshold = ranges[0].max;

        for (size_t i = 1; i < ranges.length; ++i)
        {
            if (ranges[i].min > current_threshold + 1)
                return true;

            if (ranges[i].max > current_threshold)
                current_threshold = ranges[i].max;
        }
    }

    return false;
}

unittest
{
    // contiguous
    test(!hasGap([Range!(uint)(1, 5),
                  Range!(uint)(6, 12),
                  Range!(uint)(13, 15)]), "Contiguous ranges can't have gap");

    // overlap, but no gaps 
    test(!hasGap([Range!(uint)(1, 5),
                  Range!(uint)(3, 14),
                  Range!(uint)(13, 15)]));
    test(!hasGap([Range!(uint)(1, 12),
                  Range!(uint)(4, 7),
                  Range!(uint)(13, 15)]));
    test(!hasGap([Range!(uint)(1, 13),
                  Range!(uint)(4, 7),
                  Range!(uint)(13, 15)]));
    test(!hasGap([Range!(uint)(1, 14),
                  Range!(uint)(4, 7),
                  Range!(uint)(13, 15)]));

    // gap
    test(hasGap([Range!(uint)(1, 11),
                 Range!(uint)(4, 7),
                 Range!(uint)(13, 15)]));

    // two equal range
    test(!hasGap([Range!(uint)(3, 17),
                  Range!(uint)(3, 17)]));

    // any count of empty ranges has no effect
    test(!hasGap([Range!(uint).init,
                  Range!(uint)(1, 13),
                  Range!(uint)(4, 7),
                  Range!(uint)(13, 15)]));
    test(!hasGap([Range!(uint).init,
                  Range!(uint)(1, 14),
                  Range!(uint)(4, 7),
                  Range!(uint)(13, 15)]));
    test(hasGap([Range!(uint).init,
                 Range!(uint)(1, 11),
                 Range!(uint)(4, 7),
                 Range!(uint)(13, 15)]));
    test(!hasGap([Range!(uint).init,
                  Range!(uint).init,
                  Range!(uint)(1, 14),
                  Range!(uint)(4, 7),
                  Range!(uint)(13, 15)]));
    test(hasGap([Range!(uint).init,
                 Range!(uint).init,
                 Range!(uint)(1, 11),
                 Range!(uint)(4, 7),
                 Range!(uint)(13, 15)]));

    // any combination of empty sets has no gaps
    test(!hasGap!(uint)(null));
    test(!hasGap!(uint)([]));
    test(!hasGap([Range!(uint).init]));
    test(!hasGap([Range!(uint).init,
                  Range!(uint).init]));
    test(!hasGap([Range!(uint).init,
                  Range!(uint).init,
                  Range!(uint).init]));
}


/*******************************************************************************

    Predicate that checks for the existence of overlaps in array of Range!T.

    It is assumed that the array is already sorted. All empty ranges are ignored.

    Params:
        ranges = a sorted array of Range!T to be checked

    Returns:
        true if at least one overlap exists in the array

*******************************************************************************/

public bool hasOverlap ( T ) ( Range!(T)[] ranges )
{
    trimEmptyRanges(ranges);

    if (ranges.length > 0)
    {
        auto current_threshold = ranges[0].max;

        for (size_t i = 1; i < ranges.length; ++i)
        {
            if (ranges[i].min <= current_threshold)
                return true;

            if (ranges[i].max > current_threshold)
                current_threshold = ranges[i].max;
        }
    }

    return false;
}

unittest
{
    // contiguous
    test(!hasOverlap([Range!(uint)(1, 5),
                      Range!(uint)(6, 12),
                      Range!(uint)(13, 15)]), "Contiguous ranges can't overlap");

    // one common point
    test(hasOverlap([Range!(uint)(1, 5),
                     Range!(uint)(5, 12),
                     Range!(uint)(13, 15)]));
    test(hasOverlap([Range!(uint)(1, 5),
                     Range!(uint)(6, 13),
                     Range!(uint)(13, 15)]));

    // overlap range
    test(hasOverlap([Range!(uint)(1, 5),
                     Range!(uint)(3, 14),
                     Range!(uint)(13, 15)]));

    // has gap
    test(!hasOverlap([Range!(uint)(1, 4),
                      Range!(uint)(6, 12),
                      Range!(uint)(13, 15)]));
    test(hasOverlap([Range!(uint)(1, 4),
                     Range!(uint)(6, 13),
                     Range!(uint)(13, 15)]));
    test(hasOverlap([Range!(uint)(1, 4),
                     Range!(uint)(6, 14),
                     Range!(uint)(13, 15)]));

    // the first range mask the second
    test(hasOverlap([Range!(uint)(1, 12),
                     Range!(uint)(6, 8),
                     Range!(uint)(13, 15)]));
    // the second range mask the first
    test(hasOverlap([Range!(uint)(3, 8),
                     Range!(uint)(3, 12),
                     Range!(uint)(13, 15)]));

    // equal
    test(hasOverlap([Range!(uint)(3, 17),
                     Range!(uint)(3, 17)]));

    // any count of empty ranges has no effect
    test(!hasOverlap([Range!(uint).init,
                      Range!(uint)(1, 5),
                      Range!(uint)(6, 12),
                      Range!(uint)(13, 15)]));
    test(hasOverlap([Range!(uint).init,
                     Range!(uint)(1, 5),
                     Range!(uint)(5, 12),
                     Range!(uint)(13, 15)]));
    test(!hasOverlap([Range!(uint).init,
                      Range!(uint).init,
                      Range!(uint)(1, 5),
                      Range!(uint)(6, 12),
                      Range!(uint)(13, 15)]));
    test(hasOverlap([Range!(uint).init,
                     Range!(uint).init,
                     Range!(uint)(1, 5),
                     Range!(uint)(5, 12),
                     Range!(uint)(13, 15)]));

    // any combination of empty sets has no overlaps
    test(!hasOverlap!(uint)(null));
    test(!hasOverlap!(uint)([]));
    test(!hasOverlap([Range!(uint).init]));
    test(!hasOverlap([Range!(uint).init,
                      Range!(uint).init]));
    test(!hasOverlap([Range!(uint).init,
                      Range!(uint).init,
                      Range!(uint).init]));
}

/*******************************************************************************

    Predicate that checks contiguity of the array of Range!T.

    This function's result is equivalent to !hasGap && !hasOverlap. There is
    a special unittest which asserts this (see below). It has been implemented
    as a separate function because a more efficient implementation is possible.

    It is assumed that the array is already sorted in lexicographical
    order: first check left boundaries of ranges if equal then right boundaries
    will be checked (that is current status quo of opCmp). All empty ranges
    are ignored.

    Params:
        ranges = a sorted array of Range!T to be checked

    Returns:
        true if collection is contiguous

*******************************************************************************/

public bool isContiguous ( T ) ( Range!(T)[] ranges )
{
    trimEmptyRanges(ranges);

    for (size_t i = 1; i < ranges.length; ++i)
    {
        if (ranges[i].min != ranges[i - 1].max + 1)
            return false;
    }

    return true;
}

unittest
{
    // contiguous
    test(isContiguous([Range!(uint)(1, 5),
                       Range!(uint)(6, 12),
                       Range!(uint)(13, 15)]));

    // one common point
    test(!isContiguous([Range!(uint)(1, 5),
                        Range!(uint)(5, 12),
                        Range!(uint)(13, 15)]));
    test(!isContiguous([Range!(uint)(1, 5),
                        Range!(uint)(6, 13),
                        Range!(uint)(13, 15)]));

    // gap
    test(!isContiguous([Range!(uint)(1, 4),
                        Range!(uint)(6, 12),
                        Range!(uint)(13, 15)]));
    test(!isContiguous([Range!(uint)(1, 5),
                        Range!(uint)(6, 11),
                        Range!(uint)(13, 15)]));

    // gap and common point
    test(!isContiguous([Range!(uint)(1, 4),
                        Range!(uint)(6, 13),
                        Range!(uint)(13, 15)]));

    // two equal range
    test(!isContiguous([Range!(uint)(6, 13),
                        Range!(uint)(6, 13)]));

    // any count of empty ranges has no effect
    test(isContiguous([Range!(uint).init,
                       Range!(uint)(1, 5),
                       Range!(uint)(6, 12),
                       Range!(uint)(13, 15)]));
    test(!isContiguous([Range!(uint).init,
                        Range!(uint)(1, 5),
                        Range!(uint)(6, 13),
                        Range!(uint)(13, 15)]));
    test(!isContiguous([Range!(uint).init,
                        Range!(uint)(1, 4),
                        Range!(uint)(6, 12),
                        Range!(uint)(13, 15)]));
    test(!isContiguous([Range!(uint).init,
                        Range!(uint)(1, 4),
                        Range!(uint)(6, 13),
                        Range!(uint)(13, 15)]));
    test(isContiguous([Range!(uint).init,
                       Range!(uint).init,
                       Range!(uint)(1, 5),
                       Range!(uint)(6, 12),
                       Range!(uint)(13, 15)]));

    // any combination of empty sets is contiguous
    test(isContiguous!(uint)(null));
    test(isContiguous!(uint)([]));
    test(isContiguous([Range!(uint).init]));
    test(isContiguous([Range!(uint).init,
                       Range!(uint).init]));
    test(isContiguous([Range!(uint).init,
                       Range!(uint).init,
                       Range!(uint).init]));
}


/*******************************************************************************

    Special unittest which checks that:
    isContiguous <=> !hasGap && !hasOverlap

*******************************************************************************/

unittest
{
    Range!(uint)[] ranges;

    // ranges is null
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));

    // contiguous ranges
    ranges ~= [Range!(uint)(1, 5), Range!(uint)(6, 12), Range!(uint)(13, 15)];
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
    ranges.length = 0;
    enableStomping(ranges);

    // overlap
    ranges ~= [Range!(uint)(1, 5), Range!(uint)(6, 13), Range!(uint)(13, 15)];
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
    ranges.length = 0;
    enableStomping(ranges);

    // gap
    ranges ~= [Range!(uint)(1, 4), Range!(uint)(6, 12), Range!(uint)(13, 15)];
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
    ranges.length = 0;
    enableStomping(ranges);

    // gap and overlap
    ranges ~= [Range!(uint)(1, 4), Range!(uint)(6, 13), Range!(uint)(13, 15)];
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
    ranges.length = 0;
    enableStomping(ranges);

    // range.length == 0
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));

    // only empty ranges
    ranges ~= Range!(uint).init;
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
    ranges ~= Range!(uint).init;
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
    ranges ~= Range!(uint).init;
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
}


/*******************************************************************************

    Generate a single Range!T that covers the entire set of values found
    in an array of Range!T, i.e. whose min, max values reflect the smallest
    and largest min and max found in the array.

    It is assumed that the array is sorted already in lexicographical order:
    first compare the left boundaries of the range, if they are equal then
    the right boundaries will be compared (that is current status quo of opCmp).
    All empty ranges are ignored.

    Note: Although this method assumes sorted input, it would be possible
    to provide another implementation without this assumption.
    However, such an implementation would be more expensive, with
    an asymptotic complexity of O(n), whereas this version is O(1).

    Params:
        ranges = a sorted array of Range!T

    Returns:
        resulting minimal covering range, or an empty range
        if the input array is empty

*******************************************************************************/

public Range!(T) extent (T) ( Range!(T)[] ranges )
{
    trimEmptyRanges(ranges);

    return ranges.length == 0 ? Range!(T).init : Range!(T)(ranges[0].min, ranges[$ - 1].max);
}

unittest
{
    // one range
    test!("==")(extent([Range!(uint)(3, 5)]), Range!(uint)(3, 5));

    // two equal ranges
    test!("==")(extent([Range!(uint)(3, 5),
                        Range!(uint)(3, 5)]), Range!(uint)(3, 5));

    // overlap 
    test!("==")(extent([Range!(uint)(3, 5),
                        Range!(uint)(4, 8)]), Range!(uint)(3, 8));

    // gap
    test!("==")(extent([Range!(uint)(3, 5),
                        Range!(uint)(7, 9)]), Range!(uint)(3, 9));

    // gap and overlap
    test!("==")(extent([Range!(uint)(3, 5),
                        Range!(uint)(7, 12),
                        Range!(uint)(12, 15)]), Range!(uint)(3, 15));

    // the first has the same min as the second
    test!("==")(extent([Range!(uint)(3, 5),
                        Range!(uint)(3, 7)]), Range!(uint)(3, 7));

    // any count of empty ranges has no effect
    test!("==")(extent([Range!(uint).init,
                        Range!(uint)(3, 5)]), Range!(uint)(3, 5));
    test!("==")(extent([Range!(uint).init,
                        Range!(uint)(3, 5),
                        Range!(uint)(7, 100)]), Range!(uint)(3, 100));
    test!("==")(extent([Range!(uint).init,
                        Range!(uint).init,
                        Range!(uint)(3, 5),
                        Range!(uint)(7, 100)]), Range!(uint)(3, 100));

    // any combination of empty sets has emty extent
    test!("==")(extent!(uint)(null), Range!(uint).init);
    test!("==")(extent!(uint)([]), Range!(uint).init);
    test!("==")(extent([Range!(uint).init]), Range!(uint).init);
    test!("==")(extent([Range!(uint).init,
                        Range!(uint).init]), Range!(uint).init);
}


/*******************************************************************************

    Trims any empty ranges from the start of a sorted array of Range!T.

    It is assumed that the array is already sorted, which means all empty ranges
    will be at the beginning of the array.

    Params:
        ranges = sorted array of Range!T from which empties drop out

*******************************************************************************/

private void trimEmptyRanges ( T ) ( ref Range!(T)[] ranges )
{
    while (ranges.length > 0 && ranges[0].is_empty)
    {
        ranges = ranges[1 .. $];
    }
}

unittest
{
    // empty and non-empty ranges
    {
        Range!(uint)[] a = [Range!(uint).init, Range!(uint).init,
                            Range!(uint)(2, 9), Range!(uint)(12, 19)];
        trimEmptyRanges(a);
        test!("==")(a, [Range!(uint)(2, 9), Range!(uint)(12, 19)]);
    }

    // only non-empty ranges
    {
        Range!(uint)[] a = [Range!(uint)(2, 9), Range!(uint)(12, 19)];
        trimEmptyRanges(a);
        test!("==")(a, [Range!(uint)(2, 9), Range!(uint)(12, 19)]);
    }

    // array of empty ranges
    {
        Range!(uint)[] a = [Range!(uint).init, Range!(uint).init];
        trimEmptyRanges(a);
        test!("==")(a.length, 0);
    }

    // empty array
    {
        Range!(uint)[] a;
        trimEmptyRanges(a);
        test!("==")(a.length, 0);
    }
}
