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

            // Periodic logger instance
            private alias PeriodicStatsLog!(Stats) Logger;
            private const Logger logger;

            public this ( EpollSelectDispatcher epoll )
            {
                this.epoll = epoll;
                this.logger = new Logger(epoll, &this.getStats);
            }

            // Delegate which is passed to the logger's ctor and is called
            // periodically, and returns a struct with the values to be written
            // to the next line in the log file.
            private Stats getStats ( )
            {
                Stats s;

                // Set values of s

                return s;
            }
        }

        auto epoll = new EpollSelectDispatcher;
        auto stats = new MyLogger(epoll);

        // Set everything going (including the stats logging timer).
        epoll.eventLoop();

    ---

*******************************************************************************/

public class PeriodicStatsLog ( T ) : StatsLog!(T)
{
    /***************************************************************************

        Write period

    ***************************************************************************/

    private const time_t period;

    /***************************************************************************

        Delegate to get a pointer to a struct containing the values that are to
        be written.

    ***************************************************************************/

    private alias T* delegate ( ) ValueDg;

    private ValueDg dg;

    /***************************************************************************

        Timer which fires to write log output.

    ***************************************************************************/

    private const TimerEvent timer;

    /***************************************************************************

        Constructor. Registers an update timer with the provided epoll selector.
        The timer first fires 5 seconds after construction, then periodically
        as specified. Each time the timer fires, it calls the user-provided
        delegate, dg, which should return a struct of type T containing the
        values to be written to the next line in the log.

        Params:
            epoll    = epoll select dispatcher
            dg       = delegate to query the current values
            file_count = maximum number of log files before old logs are
                over-written
            max_file_size = size in bytes at which the log files will be rotated
            period   = period after which the values should be written
            file_name = name of log file

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, ValueDg dg,
        size_t file_count = default_file_count,
        size_t max_file_size = default_max_file_size,
        time_t period = default_period, char[] file_name = default_file_name )
    in
    {
        assert(value_dg !is null, "Value delegate is null");
    }
    body
    {
        this.dg     = dg;
        this.period = period;

        this.timer = new TimerEvent(&this.write_);
        epoll.register(timer);
        timer.set(5, 0, period, 0);

        super(file_count, max_file_size, file_name);
    }

    /***************************************************************************

        Called by the timer at the end of each period, writes the values to
        the logger

    ***************************************************************************/

    private bool write_ ( )
    {
        this.write(*this.dg());

        return true;
    }
}



/*******************************************************************************

    Writes values of a struct to a logger. Uses the statslog format which is:

        date key: value, key: value

    The date part is not written by this class. Instead we rely on the logger
    layout in ocean.util.log.LayoutStatsLog.

    Template Params:
        T = a struct which contains the values that should be written to the
            file, the tuple of the struct's members is iterated and each printed

*******************************************************************************/

public class StatsLog ( T ) : IStatsLog
{
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
        super(file_count, max_file_size, file_name);
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

        Writes the values from the provided struct to the logger. Each member of
        the struct is output as <member name>:<member value>.

        Params:
            values = struct containing values to write to the log

    ***************************************************************************/

    public void write ( ref T values )
    {
        this.format(values);

        this.logger.info(this.layout[]);
    }


    /***************************************************************************

        Writes the values from the provided struct to the logger, followed by
        the additional values contained in the provided associative array. Each
        member of the struct is output as <member name>:<member value>. Each
        entry in the associative array is output as <key>:<value>.

        This method can be useful when some of the values which are to be
        written to the log are only known at run-time (for example a list of
        names of channels in a dht or queue).

        Params:
            values = struct containing values to write to the log
            additional = associative array of additional values to write to the
                log

    ***************************************************************************/

    public void writeExtra ( A ) ( ref T values, A[char[]] additional )
    {
        this.formatExtra(values, additional);

        this.logger.info(this.layout[]);
    }


    /***************************************************************************

        Formats the values from the provided struct to the internal string
        buffer. Each member of the struct is formatted as
        <member name>:<member value>.

        Params:
            values = struct containing values to format

        Returns:
            formatted string

    ***************************************************************************/

    public char[] format ( ref T values )
    {
        this.layout.clear();

        bool add_separator = false;
        this.formatStruct(values, add_separator);

        return this.layout[];
    }


    /***************************************************************************

        Formats the values from the provided struct to the internal string
        buffer, followed by the additional values contained in the provided
        associative array. Each member of the struct is formatted as
        <member name>:<member value>. Each entry in the associative array is
        formatted as <key>:<value>.

        This method can be useful when some of the values which are to be
        written to the log are only known at run-time (for example a list of
        names of channels in a dht or queue).

        Params:
            values = struct containing values to write to format
            additional = associative array of additional values to format

        Returns:
            formatted string

    ***************************************************************************/

    public char[] formatExtra ( A ) ( ref T values, A[char[]] additional )
    {
        this.layout.clear();

        bool add_separator = false;
        this.formatStruct(values, add_separator);
        this.formatAssocArray(additional, add_separator);

        return this.layout[];
    }


    /***************************************************************************

        Writes the values from the provided struct to the format_buffer member.
        Each member of the struct is output as <member name>:<member value>.

        Params:
            values = struct containing values to write to the log
            add_separator = flag telling whether a separator (space) should be
                added before a stats value is formatted. After a single value
                has been formatted the value of add_separator is set to true.

    ***************************************************************************/

    private void formatStruct ( ref T values, ref bool add_separator )
    {
        foreach ( i, value; values.tupleof )
        {
            // stringof results in something like "values.somename", we want
            // only "somename"
            this.formatValue(values.tupleof[i].stringof["values.".length .. $],
                             value,
                             add_separator);
            add_separator = true;
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

    public this ( size_t file_count = default_file_count,
        size_t max_file_size = default_max_file_size,
        char[] file_name = default_file_name )
    {
        this.logger = Log.lookup(file_name);
        this.logger.clear();
        this.logger.additive(false);

        this.logger.add(new AppendSyslog(file_name, file_count,
                                         max_file_size, "gzip {}", "gz", 4,
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

