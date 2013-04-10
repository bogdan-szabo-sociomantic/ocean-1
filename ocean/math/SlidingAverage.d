/*******************************************************************************

    Sliding Average Module

    copyright:      Copyright (c) 2009-2011 sociomantic labs.
                    All rights reserved

    version:        September 2011: initial release

    authors:        Mathias L. Baumann

*******************************************************************************/

module ocean.math.SlidingAverage;

/*******************************************************************************

    Sliding Average Class

    Used to calculate the average of an amount of values.

*******************************************************************************/

class SlidingAverage ( T )
{
    /***************************************************************************

        Sliding window, containing the values of the recent slices

    ***************************************************************************/

    protected T window[];

    /***************************************************************************

        Current average value of the whole window

    ***************************************************************************/

    protected real _average;

    /***************************************************************************

        Index of the value that was updated most recently

    ***************************************************************************/

    protected size_t index;

    /***************************************************************************

        Constructor

        Params:
            window_size = size of the sliding window

    ***************************************************************************/

    public this ( size_t window_size )
    {
        this.window = new T[window_size];
    }

    /***************************************************************************

        Pushes another value to the sliding window, overwriting the oldest one.
        Calculates the new average and returns it

        Returns:
            new average

    ***************************************************************************/

    public real push ( T value )
    {
        if ( ++this.index >= this.window.length )
        {
            this.index = 0;
        }

        this.window[this.index] = value;

        this._average = 0.0;

        foreach ( val; this.window )
        {
            this._average += val;
        }

        return this._average /= this.window.length;
    }

    /***************************************************************************

        Returns the last value pushed

        Returns:
            the last value

    ***************************************************************************/

    public T last ( )
    {
        return this.window[this.index];
    }

    /***************************************************************************

        Returns the current average

        Returns:
            average

    ***************************************************************************/

    public real average ( )
    {
        return this._average;
    }

    /***************************************************************************

        Resets the average counter to its initial state.

    ***************************************************************************/

    public void clear ( )
    {
        this.index = 0;
        this._average = 0;

        foreach ( ref val; this.window )
        {
            val = 0;
        }
    }
}

/*******************************************************************************

    Sliding Average Time Class

*******************************************************************************/

class SlidingAverageTime ( T ) : SlidingAverage!(T)
{
    /***************************************************************************

        Contains the value that is being counted for the current slice

    ***************************************************************************/

    public T current;

    /***************************************************************************

        Resolution that the output needs to be multiplied with

    ***************************************************************************/

    protected real resolution;

    /***************************************************************************

        Constructor

        Params:
            window_size       = size of the sliding window
            resolution        = size of a time slice in milliseconds
            output_resolution = desired resolution for output in milliseconds

    ***************************************************************************/

    public this ( size_t window_size, size_t resolution,
                  size_t output_resolution = 1000 )
    {
        super(window_size);

        this.resolution = cast(real) output_resolution / cast(real) resolution;
    }

    /***************************************************************************

        Adds current value to the time window history.
        Calculates the new average and returns it

        Note: This should be called by a timer periodically according to the
              resolution given in the constructor

        Returns:
            new average

    ***************************************************************************/

    public real push ( )
    {
        super._average = super.push(this.current) * this.resolution;

        this.current = 0;

        return super._average;
    }

    /***************************************************************************

        Returns the last finished value

        Returns:
            the last finished slice

    ***************************************************************************/

    public T last ( )
    {
        return this.window[this.index] * cast(T) this.resolution;
    }

    /***************************************************************************

        Sets the current value to val

        Params:
            val = value to set current value to

        Returns:
            new current value

    ***************************************************************************/

    public T opAssign ( T val )
    {
        return this.current = val;
    }

    /***************************************************************************

        Increments the current value by one

        Returns:
            new current value

    ***************************************************************************/

    public T opPostInc ( )
    {
        return this.current++;
    }

    /***************************************************************************

        Adds the given value to the current value

        Params:
            val = value to add to the current value

        Returns:
            new current value

    ***************************************************************************/

    public T opAddAssign ( T val )
    {
        return this.current += val;
    }
}