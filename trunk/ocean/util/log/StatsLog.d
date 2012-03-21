/*******************************************************************************

    Automatic console / log file stats counter.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        June 2011: Initial release

    authors:        Gavin Norman

    Outputs to the console once every second, and to a log file at a settable
    interval. The console output displays a per-hour count, whereas the log file
    tracks a per-interval count.

    The log can track the following types of values:
        1. Integer counters, have a simple increment method.
        2. Integer quantities, have a simple set method.

    Usage example:

    ---

        import ocean.util.log.StatsLog;
        import ocean.io.select.event.IntervalClock;
        import ocean.io.select.EpollSelectDispatcher;

        alias StatsLog!("my_app",
                        Counter("record", "records processed"),
                        Counter("error", "errors in records"),
                        Quantity("cache", "cached records")) Stats;

        auto epoll = new EpollSelectDispatcher;

        auto clock = new IntervalClock;

        // Write to the log file every 5 seconds
        auto stats = new Stats("stats.log", 5, epoll);

        // Start everything going (the clock and stats update timer are *not*
        // automatically registered with epoll, this must be done manually).
        epoll.register(clock);
        epoll.register(stats.log_timer_select_client);
        epoll.eventLoop;

        void someEpollCallback ( )
        {
            // Example use of a quantity.
            stats.cache = 10_000;
    
            foreach ( record; records ) // Imaginary records iterator
            {
                if ( record.error )
                {
                    stats.error; // Increments the error counter.
                }
                else
                {
                    stats.record; // Increments the record counter.
                }
            }
        }

    ---

*******************************************************************************/

module ocean.util.log.StatsLog;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Traits;

private import ocean.util.log.StaticTrace;
private import ocean.util.log.Trace;
private import ocean.util.log.MessageLogger;

private import ocean.io.select.event.TimerEvent;
private import ocean.io.select.event.IntervalClock;
private import ocean.io.select.model.ISelectClient;

private import ocean.text.util.DigitGrouping;

private import ocean.text.convert.Layout;

private import tango.time.Clock;
private import tango.time.Time;



// TODO: remove all output code, just add delegates (or abstract methods?) to do console / log output



/*******************************************************************************

    Helper function to create a StatsValue struct representing a counter.

    Params:
        name = name of value

    Returns:
        StatsValue to be used in StatsLog template

*******************************************************************************/

public StatsValue Counter ( char[] name )
{
    return Counter(name, name);
}


/*******************************************************************************

    Helper function to create a StatsValue struct representing a counter.
    
    Params:
        name = name of value
        text = log text for value
    
    Returns:
        StatsValue to be used in StatsLog template

*******************************************************************************/

public StatsValue Counter ( char[] name, char[] text )
{
    return StatsValue(name, text, StatsValue.Type.Counter);
}


/*******************************************************************************

    Helper function to create a StatsValue struct representing a quantity.

    Params:
        name = name of value

    Returns:
        StatsValue to be used in StatsLog template

*******************************************************************************/

public StatsValue Quantity ( char[] name )
{
    return Quantity(name, name);
}


/*******************************************************************************

    Helper function to create a StatsValue struct representing a quantity.

    Params:
        name = name of value
        text = log text for value

    Returns:
        StatsValue to be used in StatsLog template

*******************************************************************************/

public StatsValue Quantity ( char[] name, char[] text )
{
    return StatsValue(name, text, StatsValue.Type.Quantity);
}


/*******************************************************************************

    Helper function to create a StatsValue struct representing a floating point
    quantity.

    Params:
        name = name of value

    Returns:
        StatsValue to be used in StatsLog template

*******************************************************************************/

public StatsValue FloatQuantity ( char[] name )
{
    return Quantity(name, name);
}


/*******************************************************************************

    Helper function to create a StatsValue struct representing a floating point
    quantity.

    Params:
        name = name of value
        text = log text for value

    Returns:
        StatsValue to be used in StatsLog template

*******************************************************************************/

public StatsValue FloatQuantity ( char[] name, char[] text )
{
    return StatsValue(name, text, StatsValue.Type.FloatQuantity);
}


/*******************************************************************************

    Struct describing a single tracked value.

*******************************************************************************/

private struct StatsValue
{
    /***************************************************************************

        Name of value, used for the internal variable for the value. Must be a
        D identifier.

    ***************************************************************************/

    public char[] name;

    
    /***************************************************************************

        Log text for value, printed to the console and stats log file.

    ***************************************************************************/

    public char[] text;


    /***************************************************************************

        Type of value
    
    ***************************************************************************/
    
    public enum Type
    {
        Counter,
        Quantity,
        FloatQuantity
    }

    public Type type;
}



/*******************************************************************************

    Stats log template.

    Template params:
        AppName = name of application which is being logged (used for message
            formatting)
        T = value tuple of StatsValue structs defining the values being logged

*******************************************************************************/

public class StatsLog ( char[] AppName, T ... )
{
    /***************************************************************************

        Template to mixin one private integer member per StatsValue struct in T.

    ***************************************************************************/

    private template DeclareValue ( char[] name, StatsValue.Type type )
    {
        static if ( type == StatsValue.Type.Quantity )
        {
            const char[] DeclareValue = "ulong " ~ name ~ ";";
        }
        else static if ( type == StatsValue.Type.FloatQuantity )
        {
            const char[] DeclareValue = "float " ~ name ~ ";";
        }
        else static if ( type == StatsValue.Type.Counter )
        {
            const char[] DeclareValue = "ulong " ~ name ~ ";";
        }
    }

    private template DeclareValues ( T ... )
    {
        static if ( T.length == 1 )
        {
            const char[] DeclareValues = DeclareValue!(T[0].name, T[0].type);
        }
        else
        {
            const char[] DeclareValues = DeclareValues!(T[0]) ~ DeclareValues!(T[1..$]);
        }
    }


    /***************************************************************************

        Template to mixin one private string buffer member per StatsValue struct
        in T.

    ***************************************************************************/

    private template DeclareStringBuffer ( char[] name )
    {
        const char[] DeclareStringBuffer = "private char[] " ~ name ~ "_buf;";
    }

    private template DeclareStringBuffers ( T ... )
    {
        static if ( T.length == 1 )
        {
            const char[] DeclareStringBuffers = DeclareStringBuffer!(T[0].name);
        }
        else
        {
            const char[] DeclareStringBuffers = DeclareStringBuffer!(T[0].name) ~ DeclareStringBuffers!(T[1..$]);
        }
    }


    /***************************************************************************

        Template to mixin a comma-seperated list of all the value string
        buffers.

    ***************************************************************************/

    private template ListValue ( char[] name )
    {
        const char[] ListValue = "this." ~ name ~ "_buf";
    }

    private template ListValues ( T ... )
    {
        static if ( T.length == 1 )
        {
            const char[] ListValues = ListValue!(T[0].name);
        }
        else
        {
            const char[] ListValues = ListValue!(T[0].name) ~ "," ~ ListValues!(T[1..$]);
        }
    }


    /***************************************************************************

        Template to mixin code to format the digit-grouped string
        represenatations of each of the tracked values into the corresponding
        string buffers.

    ***************************************************************************/

    private template UpdateStringBuffer ( char[] struct_name, char[] name, StatsValue.Type type )
    {
        static if ( type == StatsValue.Type.FloatQuantity )
        {
            const char[] UpdateStringBuffer =
                "this." ~ name ~ "_buf.length=0;"
                ~ "Layout!(char).print(this." ~ name ~ `_buf,"{}",this.` ~ struct_name ~ "." ~ name ~ ");";
        }
        else
        {
            const char[] UpdateStringBuffer = "DigitGrouping.format(this." ~
                struct_name ~ "." ~ name ~ ",this." ~ name ~ "_buf);";
        }
    }

    private template UpdateStringBuffers ( char[] struct_name, T ... )
    {
        static if ( T.length == 1 )
        {
            const char[] UpdateStringBuffers = UpdateStringBuffer!(struct_name, T[0].name, T[0].type);
        }
        else
        {
            const char[] UpdateStringBuffers = UpdateStringBuffers!(struct_name, T[0]) ~ UpdateStringBuffers!(struct_name, T[1..$]);
        }
    }


    /***************************************************************************

        Template to mixin code to reset all the values in a Values struct.

    ***************************************************************************/

    private template ResetCounter ( char[] struct_name, char[] name, StatsValue.Type type )
    {
        static if ( type == StatsValue.Type.Quantity )
        {
            const char[] ResetCounter = "";
        }
        else static if ( type == StatsValue.Type.FloatQuantity )
        {
            const char[] ResetCounter = "this." ~ struct_name ~ "." ~ name ~ "=0.0;";
        }
        else static if ( type == StatsValue.Type.Counter )
        {
            const char[] ResetCounter = "this." ~ struct_name ~ "." ~ name ~ "=0;";
        }
    }

    private template ResetCounters ( char[] struct_name, T ... )
    {
        static if ( T.length == 1 )
        {
            const char[] ResetCounters = ResetCounter!(struct_name, T[0].name, T[0].type);
        }
        else
        {
            const char[] ResetCounters = ResetCounter!(struct_name, T[0].name, T[0].type) ~ ResetCounters!(struct_name, T[1..$]);
        }
    }


    /***************************************************************************

        Template to mixin one public member function per StatsValue struct in T.

    ***************************************************************************/

    private template ValueMethod ( char[] name, StatsValue.Type type )
    {
        static if ( type == StatsValue.Type.Quantity )
        {
            const char[] ValueMethod = "public void " ~ name ~ "(ulong v){this.values." ~ name ~ "=v;this.stats_values." ~ name ~ "=v;this.update(false);}";
        }
        else static if ( type == StatsValue.Type.FloatQuantity )
        {
            const char[] ValueMethod = "public void " ~ name ~ "(float v){this.values." ~ name ~ "=v;this.stats_values." ~ name ~ "=v;this.update(false);}";
        }
        else static if ( type == StatsValue.Type.Counter )
        {
            const char[] ValueMethod = "public void " ~ name ~ "(){this.values." ~ name ~ "++;this.stats_values." ~ name ~ "++;this.update(false);}";
        }
    }

    private template ValueMethods ( T ... )
    {
        static if ( T.length == 1 )
        {
            const char[] ValueMethods = ValueMethod!(T[0].name, T[0].type);
        }
        else
        {
            const char[] ValueMethods = ValueMethod!(T[0].name, T[0].type) ~ ValueMethods!(T[1..$]);
        }
    }


    /***************************************************************************

        Template to mixin a format string suitable for use with Stdout, which
        lists the output values and text of all counters.

    ***************************************************************************/

    private template CounterText ( char[] text )
    {
        const CounterText = "{} " ~ text;
    }

    private template FormatString ( T ... )
    {
        static if ( T.length == 1 )
        {
            const char[] FormatString = CounterText!(T[0].text);
        }
        else
        {
            const char[] FormatString = CounterText!(T[0].text) ~ ", " ~ FormatString!(T[1..$]);
        }
    }


    /***************************************************************************

        Template to mixin code to output to StaticTrace.

    ***************************************************************************/

    private template ConsoleOutput ( T ... )
    {
        const char[] ConsoleOutput = UpdateStringBuffers!("values", T) ~ `StaticTrace.format("  ` ~ AppName
            ~ " [Time {}:00:00 .. {:d2}:{:d2}:{:d2}] "
            ~ FormatString!(T) ~ `", this.last_time.hours,time.hours,time.minutes,time.seconds,` ~ ListValues!(T) ~ `).flush;`;
    }


    /***************************************************************************

        Template to mixin code to output to the log file.

    ***************************************************************************/

    private template StatsOutput ( T ... )
    {
        const char[] StatsOutput = UpdateStringBuffers!("stats_values", T) ~ `this.log.write("` ~ AppName ~ ": "
            ~ FormatString!(T) ~ `",` ~ ListValues!(T) ~ `);`;
    }


    /***************************************************************************

        Struct which stores the templated counters & values.

    ***************************************************************************/

    private struct Values
    {
//        pragma(msg, DeclareValues!(T));
        mixin(DeclareValues!(T));
    }


    /***************************************************************************

        Mixin declaration of a struct which stores the templated counters &
        values which are being output to the console. These values are reset
        once per hour.

    ***************************************************************************/

    private Values values;


    /***************************************************************************

        Mixin declaration of a struct which stores the templated counters &
        values which are being output to the stats log file. These values are
        reset upon every write.

    ***************************************************************************/

    private Values stats_values;


    /***************************************************************************

        Mixin declaration of one string buffer per tracked value. These are used
        for formatting the values with digit grouping.

    ***************************************************************************/

    //pragma(msg, DeclareStringBuffers!(T));
    mixin(DeclareStringBuffers!(T));


    /***************************************************************************

        Mixin declaring the incrementer / setter methods for the templated
        counters & values.

    ***************************************************************************/

//    pragma(msg, ValueMethods!(T));
    mixin(ValueMethods!(T));


    /***************************************************************************

        Periodically updating clock, reads the system time at most once per
        second. Passed as a reference to the constructor.

    ***************************************************************************/

    private IntervalClock clock;


    /***************************************************************************

        Stats log file

    ***************************************************************************/

    private MessageLogger log;


    /***************************************************************************

        Timer event to schedule writes to the stats log file.

    ***************************************************************************/

    private TimerEvent timer_event;


    /***************************************************************************

        Time of last console update.

    ***************************************************************************/

    private TimeOfDay last_time;

    
    /***************************************************************************

        Flag telling whether this is the first time the update() method has been
        called. If it is, the 'last_time' member is set to now.

    ***************************************************************************/

    private bool first_update;


    /***************************************************************************

        Constructor. Console output only.

        Params:
            clock = clock to use for timing

    ***************************************************************************/

    public this ( IntervalClock clock )
    {
        this.clock = clock;

        this.first_update = true;
    }


    /***************************************************************************

        Constructor. Console and log file output.

        Params:
            log_file = file name of stats log
            stats_update_period = update period of stats log file (in seconds)
            clock = clock to use for timing

    ***************************************************************************/

    public this ( char[] log_file, uint stats_update_period, IntervalClock clock )
    {
        this(clock);

        this.timer_event = new TimerEvent(&this.writeStatsLog);
        this.timer_event.set(stats_update_period, 0, stats_update_period, 0);

        this.log = new MessageLogger(log_file, "StatsLog");
        this.log.console_enabled = false;
    }


    /***************************************************************************

        Returns:
            the select client for the stats log update time event (to be
            registered with epoll)

    ***************************************************************************/

    public ISelectClient log_timer_select_client ( )
    {
        return this.timer_event;
    }


    /***************************************************************************

        Manually triggers an update, forcing the console output to be refreshed.

    ***************************************************************************/

    public void update ( )
    {
        this.update(true);
    }


    /***************************************************************************

        TimerEvent callback. Writes a line to the stats log file and resets the
        stats counters.

    ***************************************************************************/

    private bool writeStatsLog ( )
    {
        auto time = this.clock.now_DateTime.time;

        mixin(StatsOutput!(T));

        mixin(ResetCounters!("stats_values", T));

        return true;
    }


    /***************************************************************************

        Updates the console output.

        Params:
            force = if false, the update will only happen if the time has
                changed since the last update, if true, the update will always
                happen

    ***************************************************************************/

    private void update ( bool force )
    {
        auto time = this.clock.now_DateTime.time;

        if ( force || time != this.last_time )
        {
            mixin(ConsoleOutput!(T));
        }

        if ( time.hours != this.last_time.hours )
        {
            if ( this.first_update )
            {
                this.first_update = false;
            }
            else
            {
                Trace.formatln("");
            }

            mixin(ResetCounters!("values", T));
        }

        this.last_time = time;
    }
}

