/*******************************************************************************

    Sliding Average Module

    copyright:      Copyright (c) 2009-2011 sociomantic labs.
                    All rights reserved

    version:        September 2011: initial release
                    July 2013: reworked documentation

    authors:        Mathias L. Baumann

    This module contains two classes to calculate the average of a fixed amount
    of values. Once the fixed amount of values has been added, each time a new
    value is added, the oldest is forgotten

    SlidingAverage is very simple. You can add values to the list and you can
    query the average at any time.

    SlidingAverageTime offers a few more functions. It is for the use case when
    you don't want to add one value at once, but instead add on top of the last
    value until push() is called, which should be done periodically. The class
    is aware of that period and adjusts the added values accordingly. You tell
    it how much time a single completed value corresponds to and what time
    output resultion you desire.

*******************************************************************************/

module ocean.math.SlidingAverage;



/*******************************************************************************

    Sliding Average Class

    SlidingAverage is very simple. You can add values to the list and you can
    query the average at any time.

*******************************************************************************/

public class SlidingAverage ( T )
{
    /***************************************************************************

        Sliding window, containing the values of the recent additions

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

        The number of values the sliding window currently contains

    ***************************************************************************/

    protected size_t current_size;


    /***************************************************************************

        Constructor

        Params:
            window_size = size of the sliding window

    ***************************************************************************/

    public this ( size_t window_size )
    in
    {
        assert(window_size > 1, "SlidingAverage, window_size parameter must be > 1");
    }
    body
    {
        this.window = new T[window_size];
    }


    /***************************************************************************

        Pushes another value to the sliding window, overwriting the oldest one
        if the sliding window has reached its maximum size.
        Calculates the new average, stores it, and returns it.

        Params:
            value = The value to into the sliding window

        Returns:
            new average

    ***************************************************************************/

    public real push ( T value )
    {
        // overwrite oldest value if max slider size has been reached
        if ( this.index >= this.window.length )
        {
            this.index = 0;
        }

        this.window[this.index] = value;

        this.index++;

        // only the filled indexes in the slider should be calculated
        if ( this.current_size < this.window.length )
        {
            this.current_size++;
        }

        this._average = 0.0;

        foreach ( val; this.window[0 .. this.current_size] )
        {
            this._average += val;
        }

        this._average /= this.current_size;

        return this._average;
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
        this.current_size = 0;
        this.window[] = 0;
    }
}


/*******************************************************************************

    Sliding Average Time Class

    SlidingAverageTime offers a few more functions. It is for the use case when
    you don't want to add one value at once, but instead add on top of the last
    value until push() is called, which should be done periodically. The class
    is aware of that period and adjusts the added values accordingly. You tell
    it how much time a single completed value corresponds to and what time
    output resultion you desire.

    Usage Example
    ------------

    import ocean.math.SlidingAverage;
    import ocean.io.select.EpollSelectDispatcher;
    import ocean.io.select.event.TimerEvent;

    import tango.io.Stdout;

    void main ()
    {
        // One stat output for the amount of records
        auto avg_stats = new SlidingAverageTime!(size_t)(100, 50, 1000);
        // one stat output for the amount of bytes
        auto avg_byte_stats = new SlidingAverageTime!(size_t)(100, 50, 1000);

        // Called by the udpate_timer
        bool update ( )
        {
            // Push accumulated data to the list of values used for caluclation
            // of average
            avg_stats.push();
            return true;
        }

        // called by the display timer
        bool display_stats ( )
        {
            Stdout.formatln("Processed {} (avg {}) records,\n"
                            "          {} bytes, (avg {} bytes)",
                            avg_stats.last(), avg_stats.average(),
                            avg_byte_stats.last, avg_byte_stats.average());
        }

        auto epoll = new EpollSelectDispatcher;
        auto update_timer = new TimerEvent(&update);
        auto display_timer = new TimerEvent(&display_stats);

        // Fire timer every 50ms
        update_timer.set(0, 0, 0, 50);

        // Fire timer every 1000ms
        display_timer.set(0, 0, 1, 0);

        epoll.register(update_timer);
        epoll.register(display_stats);

        // Assume that some epoll triggered handler calls this method every time
        // the program has to process incoming data
        void process_record ( ubyte[] data )
        {
            do_important_stuff();
            avg_stats++;  // one new record
            avg_byte_stats += data.length; // that much new data was handled
        }

        epoll.eventLoop();
    }
    -----

*******************************************************************************/

public class SlidingAverageTime ( T ) : SlidingAverage!(T)
{
    /***************************************************************************

        Contains the latest value to which new values are currently being added

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
            resolution        = how much milli seconds one completed value
                                corresponds to.  Push needs to be called every
                                <resolution> ms
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

        This pushes the data accumulated using opPostInc, opAddAssign and
        opAssign to the list of values used to calculate the average.

        Note: This should be called by a timer periodically according to the
              resolution given in the constructor

              The parents class' push() method is not required or planned to be
              called when this class is used, none the less there might be rare
              usecases where it could be desired.

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
            the latest complete value

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
