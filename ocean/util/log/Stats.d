/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        21/02/2012: Split into StatsLog & PeriodicStats

    authors:        Mathias, Gavin

    Classes to write statistics log files in the standard format expected by
    cacti.

*******************************************************************************/

module ocean.util.log.Stats;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.io.select.event.TimerEvent;

private import ocean.text.convert.Layout: StringLayout;

private import ocean.util.log.LayoutStatsLog;

private import tango.util.log.Log;
private import tango.util.log.AppendSyslog;

private import tango.stdc.time : time_t;

/*******************************************************************************

    Periodically writes values of a struct to a logger using a timer event
    registered with epoll. Uses the statslog format which is:

        date key:value, key:value

    (The date part of the output is handled by the logger layout in
    ocean.util.log.LayoutStatsLog.)

    Template Params:
        T = a struct which contains the values that should be written to the
            file, the tuple of the struct's members is iterated and each printed

    Usage example:

    ---

        import ocean.io.select.EpollSelectDispatcher;
        import ocean.util.log.Stats;

        class MyLogger
        {
            // Epoll instance used for logging timer.
            private const EpollSelectDispatcher epoll;

            // Struct whose fields define the values to write to each line of
            // the stats log file.
            private struct Stats
            {
                bool b = true;
                int x = 23;
                float y = 23.23;
                char[] s = "hello";
            }

            // Instance of Stats struct
            private Stats stats;

            // Periodic logger instance
            private alias PeriodicStatsLog!(Stats) Logger;
            private const Logger logger;

            public this ( EpollSelectDispatcher epoll )
            {
                this.epoll = epoll;
                this.logger = new Logger(epoll, &this.getStats,
                    &this.resetStats);
            }

            // Delegate which is passed to the logger's ctor and is called
            // periodically, and returns a pointer to the struct with the values
            // to be written to the next line in the log file.
            private Stats* getStats ( )
            {
                // Set values of this.stats

                return &this.stats;
            }

            // Delegate which is passed to the logger's ctor and is called after
            // each log line which is written. Used here to reset the stats
            // counters.
            private void resetStats ( StatsLog unused )
            {
                this.stats = this.stats.init;
            }
        }

        auto epoll = new EpollSelectDispatcher;
        auto stats = new MyLogger(epoll);

        // Set everything going (including the stats logging timer).
        epoll.eventLoop();

    ---

*******************************************************************************/

public class PeriodicStatsLog ( T )
{
    /***************************************************************************

        Config class

    ***************************************************************************/

    public static class Config : IStatsLog.Config
    {
        time_t period = IStatsLog.default_period; // 30 seconds
    }

    /***************************************************************************

        Instance of the stats log

    ***************************************************************************/

    private const StatsLog stats_log;

    /***************************************************************************

        Write period

    ***************************************************************************/

    private const time_t period;

    /***************************************************************************

        Delegate to get a pointer to a struct containing the values that are to
        be written.

    ***************************************************************************/

    private alias T* delegate ( ) ValueDg;

    private ValueDg value_dg;

    /***************************************************************************

        Delegate to be called after outputting a line to the log. Provided as a
        convenience to user code, allowing special behaviour (for example the
        resetting of transient stats values) to occur after writing each log.

    ***************************************************************************/

    private alias void delegate ( StatsLog stats_log ) PostLogDg;

    private PostLogDg post_log_dg;

    /***************************************************************************

        Timer which fires to write log output.

    ***************************************************************************/

    private const TimerEvent timer;

    /***************************************************************************

        Constructor. Registers an update timer with the provided epoll selector.
        The timer first fires 5 seconds after construction, then periodically
        as specified. Each time the timer fires, it calls the user-provided
        delegate, value_dg, which should return a pointer to a struct of type T
        containing the values to be written to the next line in the log. Once
        the log line has been written, the optional post_log_dg is called (if
        provided), which may be used to implement special behaviour in the user
        code, such as resetting transient values in the logged struct.

        Params:
            epoll    = epoll select dispatcher
            value_dg = delegate to query the current values
            post_log_dg = delegate to call after writing a log line (may be
                null)
            config      = instance of the config class

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, ValueDg value_dg,
                  PostLogDg post_log_dg, Config config )
    {
        with(config) this(epoll, value_dg, post_log_dg,
                          new StatsLog(file_count, max_file_size, file_name),
                          period);
    }


    /***************************************************************************

        Constructor. Registers an update timer with the provided epoll selector.
        The timer first fires 5 seconds after construction, then periodically
        as specified. Each time the timer fires, it calls the user-provided
        delegate, value_dg, which should return a pointer to a struct of type T
        containing the values to be written to the next line in the log. Once
        the log line has been written, the optional post_log_dg is called (if
        provided), which may be used to implement special behaviour in the user
        code, such as resetting transient values in the logged struct.

        Params:
            epoll    = epoll select dispatcher
            value_dg = delegate to query the current values
            post_log_dg = delegate to call after writing a log line (may be
                null)
            file_count = maximum number of log files before old logs are
                over-written
            max_file_size = size in bytes at which the log files will be rotated
            period   = period after which the values should be written
            file_name = name of log file

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, ValueDg value_dg,
        PostLogDg post_log_dg, size_t file_count = IStatsLog.default_file_count,
        size_t max_file_size = IStatsLog.default_max_file_size,
        time_t period = IStatsLog.default_period,
        char[] file_name = IStatsLog.default_file_name )
    {
        this(epoll, value_dg, post_log_dg,
             new StatsLog(file_count, max_file_size, file_name),
             period);
    }


    /***************************************************************************

        Constructor. Registers an update timer with the provided epoll selector.

        The timer first fires 5 seconds after construction, then periodically
        as specified. Each time the timer fires, it calls the user-provided
        delegate, value_dg, which should return a pointer to a struct of type T
        containing the values to be written to the next line in the log. Once
        the log line has been written, the optional post_log_dg is called (if
        provided), which may be used to implement special behaviour in the user
        code, such as resetting transient values in the logged struct or
        addition of further values using the StatsLog.add methods. The stats
        values will be written to file after post_log_dg returned.

        Params:
            epoll       = epoll select dispatcher
            value_dg    = delegate to query the current values
            post_log_dg = delegate to call after writing a log line (may be
                          null)
            stats_log   = Stats log instance to use
            period      = period after which the values should be written

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, ValueDg value_dg,
                  PostLogDg post_log_dg, StatsLog stats_log,
                  time_t period = IStatsLog.default_period )
    in
    {
        assert(value_dg !is null, "Value delegate is null");
    }
    body
    {
        this.value_dg = value_dg;
        this.post_log_dg = post_log_dg;
        this.period = period;

        this.timer = new TimerEvent(&this.write_);
        epoll.register(timer);
        timer.set(5, 0, period, 0);

        this.stats_log = stats_log;
    }


    /***************************************************************************

        Called by the timer at the end of each period, writes the values to
        the logger

    ***************************************************************************/

    private bool write_ ( )
    {
        this.stats_log.add(*this.value_dg());

        if ( this.post_log_dg )
        {
            this.post_log_dg(this.stats_log);
        }

        this.stats_log.flush();

        return true;
    }
}



/*******************************************************************************

    Writes values of a struct to a logger. Uses the statslog format which is:

        date key: value, key: value

    (The date part is not written by this class. Instead we rely on the logger
    layout in ocean.util.log.LayoutStatsLog.)

    Usage Example
    ---
    struct MyStats
    {
        size_t bytes_in, bytes_out, awesomeness;
    }

    auto stats_log = new StatsLog(new IStatsLog.Config("log/stats.log", 10_000, 5));

    MyStats stats;

    stats_log.add(stats)
        .add([ "DynVal" : 34, "DynVal2" : 52])
        .add("dyn3", 62)
        .flush();
    ---

*******************************************************************************/

public class StatsLog : IStatsLog
{
    /***************************************************************************

        Whether to add a separator or not

    ***************************************************************************/

    private bool add_separator = false;

    /***************************************************************************

        Constructor

        Params:
            config = instance of the config class

    ***************************************************************************/

    public this ( Config config )
    {
        super(config);
    }


    /***************************************************************************

        Constructor

        Params:
            file_count = maximum number of log files before old logs are
                over-written
            max_file_size = size in bytes at which the log files will be rotated
            file_name = name of the file to write the stats to

    ***************************************************************************/

    public this ( size_t file_count = default_file_count,
        size_t max_file_size = default_max_file_size,
        char[] file_name = default_file_name )
    {
        super(new Config(file_name, max_file_size, file_count));
    }


    /***************************************************************************

        Constructor

        Uses the same default values for file_count and max_file_size as the
        other constructor.

        Params:
            file_name = name of the file to write the stats to

    ***************************************************************************/

    public this ( char[] file_name )
    {
        this(default_file_count, default_max_file_size, file_name);
    }


    /***************************************************************************

        Adds one or several values to be outputted to the stats log.

        This function is written using variadic templates to work around the
        limits of template deduction. This function is equivalent to the
        following three functions:

        *************************************************************************
        * Adds the values of the given struct to the stats log. Each member of
        * the struct will be output as <member name>:<member value>.
        *
        * Params:
        *     values = struct containing values to write to the log. Passed as ref
        *         purely to avoid making a copy -- the struct is not modified.
        * ---
        * public typeof(this) add ( T ) ( T values )
        * ---

        *************************************************************************
        * Add another value to the stats
        *
        * Params:
        *     name = name of the value
        *     value = the value to add
        * ---
        * public typeof(this) add ( T ) ( char[] name, T value )
        * ---

        *************************************************************************
        * Add values from an associative array to the stats
        *
        * Params:
        *     values = The associative array with the values to add
        * ---
        * public typeof(this) add ( T ) ( T[char[]] values )
        * ----

        Don't forget to call .flush() after all values have been added.

        Returns:
            A reference to this class so that

            ---
                add(myValues).add("abc", 3).add("efg", 2).flush()
            ---

            can be used to write values

    ***************************************************************************/

    public typeof(this) add ( T... ) ( T parameters )
    {
        static if ( T.length == 1 )
        {   // only parameter a struct
            static if ( is ( T[0] == struct ) )
            {
                this.format(parameters[0]);
            }
            else // only parameter not a struct, assumed AA
            {
                this.formatAssocArray(parameters[0], this.add_separator);
            }
        }
        // two parameters always (assumed to be) name, value
        else static if ( T.length == 2 )
        {
            this.formatValue(parameters[0], parameters[1], this.add_separator);
        }
        else static assert (false,
                "StatsLog.add(...): called with invalid amount of parameters");

        this.add_separator = true;

        return this;
    }


    /***************************************************************************

        Flush everything to file and prepare for the next iteration

    ***************************************************************************/

    public void flush ( )
    {
        this.logger.info(this.layout[]);
        this.add_separator = false;
        this.layout.clear();
    }


    /***************************************************************************

        Formats the values from the provided struct to the internal string
        buffer. Each member of the struct is formatted as
        <member name>:<member value>.

        Params:
            values = struct containing values to format. Passed as ref purely to
                avoid making a copy -- the struct is not modified.

        Returns:
            formatted string

    ***************************************************************************/

    private char[] format ( T ) ( ref T values )
    {
        this.formatStruct(values);

        return this.layout[];
    }


    /***************************************************************************

        Writes the values from the provided struct to the format_buffer member.
        Each member of the struct is output as <member name>:<member value>.

        Params:
            values = struct containing values to write to the log. Passed as ref
                purely to avoid making a copy -- the struct is not modified.

    ***************************************************************************/

    private void formatStruct ( T ) ( ref T values )
    {
        foreach ( i, value; values.tupleof )
        {
            // stringof results in something like "values.somename", we want
            // only "somename"
            this.formatValue(values.tupleof[i].stringof["values.".length .. $],
                             value,
                             this.add_separator);
            this.add_separator = true;
        }
    }
}


/*******************************************************************************

    Templateless stats log base class. Contains no abstract methods, but
    declared as abstract as it is useless on its own, without deriving.

*******************************************************************************/

public abstract class IStatsLog
{
    /***************************************************************************

        Config class

    ***************************************************************************/

    public static class Config
    {
        char[] file_name = default_file_name;
        size_t max_file_size = default_max_file_size;
        size_t file_count = default_file_count;

        this ( char[] file_name, size_t max_file_size, size_t file_count )
        {
            this.file_name = file_name;
            this.max_file_size = max_file_size;
            this.file_count = file_count;
        }

        this(){}
    }

    /***************************************************************************

        Stats log default settings (used in ctor)

    ***************************************************************************/

    public const time_t default_period = 30; // 30 seconds
    public const default_file_count = 10;
    public const default_max_file_size = 10 * 1024 * 1024; // 10Mb
    public const char[] default_file_name = "log/stats.log";


    /***************************************************************************

        Logger instance

    ***************************************************************************/

    protected const Logger logger;


    /***************************************************************************

        Message formatter

    ***************************************************************************/

    protected const StringLayout!() layout;


    /***************************************************************************

        Constructor

        Params:
            file_count = maximum number of log files before old logs are
                over-written
            max_file_size = size in bytes at which the log files will be rotated
            file_name = name of the file to write the stats to

    ***************************************************************************/

    public this ( Config config, char[] name = "Stats" )
    {
        this.logger = Log.lookup(name);
        this.logger.clear();
        this.logger.additive(false);

        this.logger.add(new AppendSyslog(config.file_name, config.file_count,
                                         config.max_file_size, "gzip {}", "gz", 4,
                                         new LayoutStatsLog));

        // Explcitly set the logger to output all levels, to avoid the situation
        // where the root logger is configured to not output level 'info'.
        this.logger.level = this.logger.Level.Trace;

        this.layout = new StringLayout!();
    }


    /***************************************************************************

        Writes the entries of the provided associative array to the
        format_buffer member. Each entry of the associative array is output as
        <key>:<value>.

        Template Params:
            A = type of associative array value. Assumed to be handled by Layout

        Params:
            values = associative array of values to write to the log
            add_separator = flag telling whether a separator (space) should be
                added before a stats value is formatted. After a single value
                has been formatted the value of add_separator is set to true.

    ***************************************************************************/

    protected void formatAssocArray ( A ) ( A[char[]] values, ref bool add_separator )
    {
        foreach ( name, value; values )
        {
            this.formatValue(name, value, add_separator);
            add_separator = true;
        }
    }


    /***************************************************************************

        Writes the specified name:value pair to the format_buffer member.

        Template Params:
            V = type of value. Assumed to be handled by Layout

        Params:
            name = name of stats log entry
            value = value of stats log entry
            add_separator = flag telling whether a separator (space) should be
                added before the stats value is formatted

    ***************************************************************************/

    protected void formatValue ( V ) ( char[] name, V value, bool add_separator )
    {
        if (add_separator)
        {
            this.layout(' ');
        }

        this.layout(name, ':', value);
    }
}

