/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        4/18/2012: Initial release

    authors:        Hatem Oraby

    Calculates the average using an accumulative technique (i.e, not all the
    values are provided at once).
    The struct doesn't store any previous values.

*******************************************************************************/

module ocean.math.IncrementalAverage;


/*******************************************************************************

    Calculates the average using an accumulative technique (i.e, not all the
    values are provided at once).
    The struct doesn't store any previous values.

*******************************************************************************/

public struct IncrementalAverage
{
    /***************************************************************************

        Counts the number of averages that has been previously performed.
        This helps in giving the correct weight to a new number being added
        to the average in comparison to the previous numbers.

    ***************************************************************************/

    private ulong count_ = 0;


    /***************************************************************************

        Holds the average value calculated so far.

    ***************************************************************************/

    private double average_ = 0;


    /***************************************************************************

        Adds a new number (giving it an appropriate weight) to the average.

        Note that if too many numbers were added (more than ulong.max) then the
        the internal counter will overflow (and as a result the average value
        would be corrupt).

        Params:
            value = the new value to add to the current average.
            count = if that value represent in itself the average of other
                numbers, then this param should define the number of elements
                that this average stands for. A count = 0 has no effect on the
                average and gets discarded.

    ***************************************************************************/

    public void addToAverage (T)(T value, ulong count = 1)
    {
        if (count == 0)
            return;

        this.average_ =
             (this.average_*cast(double)this.count_ + value*cast(double)count) /
                          /*______________divided_by______________*/
                                    (this.count_ + count);
        this.count_ += count;
    }


    /***************************************************************************

        Returns:
            the average calculated so far.

    ***************************************************************************/

    public double average ()
    {
        return this.average_;
    }


    /***************************************************************************

        Returns:
            the count of elements added.

    ***************************************************************************/

    public ulong count ()
    {
        return this.count_;
    }


    /***************************************************************************

        Resets the average incremental instance.

    ***************************************************************************/

    public void clear ()
    {
        this.average_ = 0;
        this.count_ = 0;
    }
}


version (UnitTest)
{
    import ocean.core.Test : NamedTest;

    import tango.math.IEEE;

    // Bit count to avoid deliberate loss of precision.
    // Ensures only 8 bits of precision could be lost.
    const PRECISION = double.mant_dig - 8;
}

unittest
{
    auto t = new NamedTest("Incremental Average - basic unit tests");

	IncrementalAverage inc_avg;

    t.test!("==")(inc_avg.count, 0);
    t.test!(">=")(feqrel(inc_avg.average(), 0.0), PRECISION);

	inc_avg.addToAverage(1);
    t.test!(">=")(feqrel(inc_avg.average(), 1.0), PRECISION);

	inc_avg.clear();
	t.test!("==")(inc_avg.count, 0);
    t.test!(">=")(feqrel(inc_avg.average(), 0.0), PRECISION);

	inc_avg.addToAverage(10);
	inc_avg.addToAverage(20);
    t.test!("==")(inc_avg.count, 2);
    t.test!(">=")(feqrel(inc_avg.average(), 15.0), PRECISION);

	inc_avg.clear();
	inc_avg.addToAverage(-10);
    t.test!(">=")(feqrel(inc_avg.average(), -10.0), PRECISION);
	inc_avg.addToAverage(-20);
    t.test!(">=")(feqrel(inc_avg.average(), -15.0), PRECISION);

	inc_avg.clear();
	inc_avg.addToAverage(-10, uint.max);
	inc_avg.addToAverage(10, uint.max);
    t.test!("==")(inc_avg.count, 2UL * uint.max);
    t.test!(">=")(feqrel(inc_avg.average(), 0.0), PRECISION);

	inc_avg.clear();
	inc_avg.addToAverage(long.max);
    t.test!(">=")(feqrel(inc_avg.average(), cast(double)long.max), PRECISION);
	inc_avg.addToAverage(cast(ulong)long.max + 10);
    t.test!(">=")(feqrel(inc_avg.average(), cast(double)long.max) + 5,
                  PRECISION);

	inc_avg.clear();
	inc_avg.addToAverage(long.max / 2.0);
	inc_avg.addToAverage(long.max * 1.25);
    // (0.5 + 1.25) / 2 = 0.875
    t.test!(">=")(feqrel(inc_avg.average(), long.max * 0.875), PRECISION);

	inc_avg.clear();
	inc_avg.addToAverage(long.min);
    t.test!(">=")(feqrel(inc_avg.average(), cast(double)long.min), PRECISION);
	inc_avg.addToAverage(cast(double)long.min - 10);
    t.test!(">=")(feqrel(inc_avg.average(), cast(double)long.min - 5),
                  PRECISION);

	inc_avg.clear();
	const ADD = ulong.max/1_000_000;
	for (ulong i = 0; i < ulong.max; i += (ADD < ulong.max - i ? ADD : 1))
		inc_avg.addToAverage(i%2); // 1 or 0
	inc_avg.addToAverage(1); // One more add is missing
    t.test!(">=")(feqrel(inc_avg.average(), 0.5), PRECISION);
}
