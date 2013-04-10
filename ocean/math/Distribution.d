/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        November 2010: Initial release

    authors:        Gavin Norman

    Helper class useful for producing apache bench style output about value
    distributions. For example:

    ---

        Time distribution of 10000 requests:
         50.0% <= 234μs
         66.0% <= 413μs
         75.0% <= 498μs
         80.0% <= 575μs
         90.0% <= 754μs
         95.0% <= 787μs
         98.0% <= 943μs
         99.0% <= 1054μs
         99.5% <= 1183μs
         99.9% <= 7755μs
        100.0% <= 8807μs (longest request)

        146 requests (1.5%) took longer than 1000μs

    ---

    Performance note: the lessThanCount(), greaterThanCount() and percentValue()
    methods all sort the list of values stored in the Distribution instance. In
    general it is thus best to add all the values you're interested in, then
    call the results methods, so the list only needs to be sorted once.

    Usage example:

    ---

        import ocean.math.Distribution;

        import tango.io.Stdout;

        import tango.time.StopWatch;

        // Stopwatch instance.
        StopWatch sw;

        // Create a distribution instance initialised to contain 10_000 values.
        // (The size can be extended, but it's set initially for the sake of
        // pre-allocation.)
        const num_requests = 10_000;
        auto dist = new Distribution!(ulong)(num_requests);

        // Perform a series of imaginary requests, timing each one and adding
        // the time value to the distribution
        for ( int i; i < num_requests; i++ )
        {
            sw.start;
            doRequest();
            auto time = sw.microsec;

            dist ~= time;
        }

        // Display the times taken by 50%, 66% etc of the requests.
        // (This produces output like apache bench.)
        const percentages = [0.5, 0.66, 0.75, 0.8, 0.9, 0.95, 0.98, 0.99, 0.995, 0.999, 1];

        foreach ( i, percentage; percentages )
        {
            auto value = dist.percentValue(percentage);

            Stdout.formatln("{,5:1}% <= {}μs", percentage * 100, value);
        }

        // Display the number of requests which took longer than 1ms.
        const timeout = 1_000; // 1ms
        auto timed_out = dist.greaterThanCount(timeout);

        Stdout.formatln("{} requests ({,3:1}%) took longer than {}μs",
                timed_out,
                (cast(float)timed_out / cast(float)dist.length) * 100.0,
                timeout);

        // Clear distribution ready for next test.
        dist.clear;

    ---

*******************************************************************************/

module ocean.math.Distribution;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array : bsearch;

private import ocean.util.container.AppendBuffer;



/*******************************************************************************

    Class to report on the distribution of a series of values.

*******************************************************************************/

public class Distribution ( T )
{
    /***************************************************************************

        List of values, appended to by the opAddAssign method.

    ***************************************************************************/

    private AppendBuffer!(T) values;


    /***************************************************************************

        Indicates whether the list of values has been sorted (which is required
        by the methods: lessThanCount, greaterThanCount, percentValue).
        opAddAssign() and clear() reset the sorted flag to false.

        TODO: it might be better to always maintain the list in sorted order?

    ***************************************************************************/

    private bool sorted;


    /***************************************************************************

        Constructor.

        Params:
            num_values = initial size of list (for pre-allocation)

    ***************************************************************************/

    public this ( size_t num_values = 0 )
    {
        this.values = new AppendBuffer!(T)(num_values);
    }


    /***************************************************************************

        Adds a value to the list.

        Params:
            value = value to add

    ***************************************************************************/

    public void opCatAssign ( T value )
    {
        this.values.append(value);
        this.sorted = false;
    }


    /***************************************************************************

        Clears all values from the list.

    ***************************************************************************/

    public void clear ( )
    {
        this.values.length = 0;
        this.sorted = false;
    }


    /***************************************************************************

        Returns:
            the number of values in the list

        Note: aliased as length.

    ***************************************************************************/

    public ulong count ( )
    {
        return this.values.length;
    }

    public alias count length;


    /***************************************************************************

        Gets the count of values in the list which are less than the specified
        value.

        Params:
            max = value to count less than

        Returns:
            number of values less than max

    ***************************************************************************/

    public size_t lessThanCount ( T max )
    {
        if ( this.values.length == 0 )
        {
            return 0;
        }

        this.sort;

        size_t less;
        bsearch(this.values[], max, less);
        return less;
    }


    /***************************************************************************

        Gets the count of values in the list which are greater than the
        specified value.

        Params:
            min = value to count greater than

        Returns:
            number of values greater than min

    ***************************************************************************/

    public size_t greaterThanCount ( T min )
    {
        auto less = this.lessThanCount(min);
        return this.values.length - less;
    }


    /***************************************************************************

        Gets the value which X% of the values in the list are less than or equal
        to.

        For example, if values contains [1, 2, 3, 4, 5, 6, 7, 8], then
        percentValue(0.5) returns 4, while percentValue(0.25) returns 2, and
        percentValue(1.0) returns 8.

        Params:
            percent = percentage as a fraction

        Returns:
            value which X% of the values in the list are less than or equal to

    ***************************************************************************/

    public size_t percentValue ( float percent )
    {
        if ( this.values.length == 0 )
        {
            return 0;
        }

        this.sort;

        auto index = cast(size_t)(percent * this.values.length);
        if ( index >= this.values.length )
        {
            index = this.values.length - 1;
        }

        return this.values[index];
    }


    /***************************************************************************

        Sorts the values in the list, if they are not already sorted.

    ***************************************************************************/

    private void sort ( )
    {
        if ( !this.sorted )
        {
            this.values[].sort;
            this.sorted = true;
        }
    }
}

