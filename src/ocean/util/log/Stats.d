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

import ocean.core.Traits : FieldName;

import ocean.core.TypeConvert;

import ocean.io.select.EpollSelectDispatcher;

import ocean.io.select.client.TimerEvent;

import ocean.text.convert.Layout: StringLayout;

import ocean.util.log.layout.LayoutStatsLog;

import tango.transition;
import tango.core.Traits;
import tango.util.log.Log;
import tango.util.log.AppendSyslog;

import tango.stdc.time : time_t;

/*******************************************************************************

    Periodically writes values of an aggregate to a logger using a timer event
    registered with epoll. Uses the statslog format which is:

        date key:value, key:value

    (The date part of the output is handled by the logger layout in
    ocean.util.log.layout.LayoutStatsLog.)

    Template Params:
        T = an aggregate which contains the values that should be written to the
            file, the tuple of the aggregate's members is iterated and each
            printed

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
            // Only numeric and floating points types are accepted.
            private struct Stats
            {
                int x = 23;
                float y = 23.23;
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

public class PeriodicStatsLog ( T ) : IPeriodicStatsLog
{
    /***************************************************************************

        Delegate to get a pointer to an aggregate containing the values that are
        to be written.

    ***************************************************************************/

    private alias T* delegate ( ) ValueDg;

    private const ValueDg value_dg;

    /***************************************************************************

        Delegate to be called after outputting a line to the log. Provided as a
        convenience to user code, allowing special behaviour (for example the
        resetting of transient stats values) to occur after writing each log.

    ***************************************************************************/

    private alias void delegate ( StatsLog stats_log ) PostLogDg;

    private PostLogDg post_log_dg;

    /***************************************************************************

        Constructor. Registers an update timer with the provided epoll selector.
        The timer first fires 5 seconds after construction, then periodically
        as specified. Each time the timer fires, it calls the user-provided
        delegate, value_dg, which should return a pointer to an aggregate of type
        T containing the values to be written to the next line in the log. Once
        the log line has been written, the optional post_log_dg is called (if
        provided), which may be used to implement special behaviour in the user
        code, such as resetting transient values in the logged aggregate.

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
        delegate, value_dg, which should return a pointer to an aggregate of
        type T containing the values to be written to the next line in the log.
        Once the log line has been written, the optional post_log_dg is called
        (if provided), which may be used to implement special behaviour in the
        user code, such as resetting transient values in the logged aggregate.

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
        istring file_name = IStatsLog.default_file_name )
    {
        this(epoll, value_dg, post_log_dg,
             new StatsLog(file_count, max_file_size, file_name),
             period);
    }


    /***************************************************************************

        Constructor. Registers an update timer with the provided epoll selector.

        The timer first fires 5 seconds after construction, then periodically
        as specified. Each time the timer fires, it calls the user-provided
        delegate, value_dg, which should return a pointer to an aggregate of
        type T containing the values to be written to the next line in the log.
        Once the log line has been written, the optional post_log_dg is called
        (if provided), which may be used to implement special behaviour in the
        user code, such as resetting transient values in the logged aggregate or
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

        super(epoll, stats_log, period);
    }


    /***************************************************************************

        Called when the timer event fires. Calls the user's value delegate and
        adds the returned value to the stats log, then calls the optional post-
        log delegate.

    ***************************************************************************/

    protected override void addStats ( )
    {
        this.stats_log.add(*this.value_dg());

        if ( this.post_log_dg )
        {
            this.post_log_dg(this.stats_log);
        }
    }
}


/*******************************************************************************

    Templateless periodic stats log base class.

    The constructors register an update timer with the provided epoll selector.
    The timer first fires 5 seconds after construction, then periodically as
    specified. Each time the timer fires, it calls the abstract method
    addStats() before flushing the logger, writing one line.

*******************************************************************************/

public abstract class IPeriodicStatsLog
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

    protected StatsLog stats_log;

    /***************************************************************************

        Write period

    ***************************************************************************/

    private time_t period;

    /***************************************************************************

        Timer which fires to write log output.

    ***************************************************************************/

    private TimerEvent timer;

    /***************************************************************************

        Construct from config. Registers and starts timer.

        Params:
            epoll = epoll select dispatcher
            config = instance of the config class

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, Config config )
    {
        with(config) this(epoll,
                          new StatsLog(file_count, max_file_size, file_name),
                          period);
    }


    /***************************************************************************

        Construct from individual settings. Registers and starts timer.

        Params:
            epoll = epoll select dispatcher
            file_count = maximum number of log files before old logs are
                over-written
            max_file_size = size in bytes at which the log files will be rotated
            period = period after which the values should be written
            file_name = name of log file

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll,
        size_t file_count = IStatsLog.default_file_count,
        size_t max_file_size = IStatsLog.default_max_file_size,
        time_t period = IStatsLog.default_period,
        istring file_name = IStatsLog.default_file_name )
    {
        this(epoll,
             new StatsLog(file_count, max_file_size, file_name),
             period);
    }


    /***************************************************************************

        Construct from the provided StatsLog instance. Registers and starts
        timer.

        Params:
            epoll = epoll select dispatcher
            stats_log = Stats log instance to use
            period = period after which the values should be written

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, StatsLog stats_log,
        time_t period = IStatsLog.default_period )
    {
        this.period = period;

        this.timer = new TimerEvent(&this.write_);
        epoll.register(timer);
        timer.set(5, 0, period, 0);

        this.stats_log = stats_log;
    }


    /***************************************************************************

        Called by the timer at the end of each period. Calls the abstract
        addStats() and then flushes the stats to the logger.

    ***************************************************************************/

    private bool write_ ( )
    {
        this.addStats();

        this.stats_log.flush();

        return true;
    }


    /***************************************************************************

        Called when the timer event fires. The method is expected to add any
        desired stats to the log, using the this.stats_log member. The added
        stats will be automatically flushed to the logger.

    ***************************************************************************/

    abstract protected void addStats ( );
}


/*******************************************************************************

   Writes values of an aggregate to a logger. Uses the statslog format which is:

        date key: value, key: value

    (The date part is not written by this class. Instead we rely on the logger
    layout in ocean.util.log.layout.LayoutStatsLog.)

    Usage Example
    ---
    struct MyStats
    {
        size_t bytes_in, bytes_out, awesomeness;
    }

    auto stats_log = new StatsLog(new IStatsLog.Config("log/stats.log",
        10_000, 5));

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

        Constructor. Creates the stats log using the AppendSysLog appender.

        Params:
            config = instance of the config class
            name   = name of the logger, should be set to a different string
                     when using more than two StatLogs

    ***************************************************************************/

    public this ( Config config, istring name = "Stats" )
    {
        super(config, name);
    }


    /***************************************************************************

        Constructor. Creates the stats log using the appender returned by the
        provided delegate.

        Params:
            config = instance of the config class
            new_appender = delegate which returns appender to use for stats log
            name   = name of the logger, should be set to a different string
                     when using more than two StatLogs

    ***************************************************************************/

    public this ( Config config,
        Appender delegate ( istring file, Appender.Layout layout ) new_appender,
        istring name = "Stats" )
    {
        super(config, new_appender, name);
    }


    /***************************************************************************

        Constructor

        Params:
            file_count = maximum number of log files before old logs are
                over-written
            max_file_size = size in bytes at which the log files will be rotated
            file_name = name of the file to write the stats to
            name   = name of the logger, should be set to a different string
                     when using more than two StatLogs

    ***************************************************************************/

    public this ( size_t file_count = default_file_count,
        size_t max_file_size = default_max_file_size,
        istring file_name = default_file_name, istring name = "Stats" )
    {
        super(new Config(file_name, max_file_size, file_count), name);
    }


    /***************************************************************************

        Constructor

        Uses the same default values for file_count and max_file_size as the
        other constructor.

        Params:
            file_name = name of the file to write the stats to
            name   = name of the logger, should be set to a different string
                     when using more than two StatLogs

    ***************************************************************************/

    public this ( istring file_name, istring name = "Stats" )
    {
        this(default_file_count, default_max_file_size, file_name, name);
    }


    /***************************************************************************

        Adds the values of the given aggregate to the stats log. Each member
        of the aggregate will be output as <member name>:<member value>.

        Params:
            values = aggregate containing values to write to the log.

    ***************************************************************************/

    public typeof(this) add ( T ) ( T values )
    {
        static assert (is(T == struct) || is(T == class),
                       "Parameter to add must be a struct or a class");
        this.format!(null)(values, istring.init);
        this.add_separator = true;

        return this;
    }


    /***************************************************************************

        Adds the values of the given aggregate to the stats log. Each member of
        the aggregate will be output as <member name>:<member value>.

        Template params:
            category = The name of the category this object belongs to.

        Params:
            instance = Name of the object to add.
            values = aggregate containing values to write to the log.

    ***************************************************************************/

    public typeof(this) addObject (istring category, T)
        (istring instance, T values)
    in
    {
        static assert (is(T == struct) || is(T == class),
                       "Parameter to add must be a struct or a class");
        static assert(category.length,
                      "Template parameter 'category' should not be null");
        assert (instance.length, "Object name should not be null");
    }
    body
    {
        this.format!(category)(values, instance);
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

        Writes the values from the provided aggregate to the format_buffer
        member.

        Each member of the aggregate is output as either:
        <category name>/<object name>/<member name>:<member value>
        if a category is provided, or as:
        <member name>:<member value>
        if no category is provided.
        It's a runtime error to provide a category but no instance name, or the
        other way around.

        Note: When the aggregate is a class, the members of the super class
        are not iterated over.

        Template params:
            category = The type of object we log. You should use a single type
                       per category.

        Params:
            values = aggregate containing values to write to the log. Passed as
                     ref purely to avoid making a copy -- the aggregate is not
                     modified.
            instance = The name of the instance of the category, or null if none

    ***************************************************************************/

    private void format ( istring category, T ) ( ref T values, istring name )
    {
        foreach ( i, value; values.tupleof )
        {
            static if (!isIntegerType!(typeof(value))
                       && !isRealType!(typeof(value)))
            {
                pragma(msg, "[", __FILE__, ":", __LINE__, "]", T.stringof,
                       " should only contain integer or floating point members");
            }
            // stringof results in something like "values.somename", we want
            // only "somename"
            if (this.add_separator)
            {
                this.layout(' ');
            }
            this.formatValue!(category)(FieldName!(i, T), value, name);
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
        istring file_name = default_file_name;
        size_t max_file_size = default_max_file_size;
        size_t file_count = default_file_count;
        size_t start_compress = default_start_compress;

        this ( istring file_name, size_t max_file_size, size_t file_count )
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
    public const istring default_file_name = "log/stats.log";
    public const size_t default_start_compress = 4;


    /***************************************************************************

        Logger instance

    ***************************************************************************/

    protected Logger logger;


    /***************************************************************************

        Message formatter

    ***************************************************************************/

    protected StringLayout!() layout;


    /***************************************************************************

        Constructor

        Params:
            config = instance of the config class
            name   = name of the logger, should be set to a different string
                     when using more than two StatLogs

    ***************************************************************************/

    public this ( Config config, istring name = "Stats" )
    {
        Appender newAppender ( istring file, Appender.Layout layout )
        {
            return new AppendSyslog(file,
                castFrom!(size_t).to!(int)(config.file_count),
                config.max_file_size, "gzip {}", "gz",
                config.start_compress, layout);
        }

        this(config, &newAppender, name);
    }


    /***************************************************************************

        Constructor

        Params:
            config = instance of the config class
            new_appender = delegate which returns appender to use for stats log
            name   = name of the logger, should be set to a different string
                     when using more than two StatLogs

    ***************************************************************************/

    public this ( Config config,
        Appender delegate ( istring file, Appender.Layout layout ) new_appender,
        istring name = "Stats" )
    {
        this.logger = Log.lookup(name);
        this.logger.clear();
        this.logger.additive(false);

        this.logger.add(new_appender(config.file_name, new LayoutStatsLog));

        // Explcitly set the logger to output all levels, to avoid the situation
        // where the root logger is configured to not output level 'info'.
        this.logger.level = this.logger.Level.Trace;

        this.layout = new StringLayout!();
    }


    /***************************************************************************

        Writes the specified name:value pair to the layout.

        Template Params:
            category = The category of the structure, such as 'channels',
                       'users'... Can be null (see 'instance' parameter).
            V        = type of value. Assumed to be handled by Layout

        Params:
            value_name = name of the value we log in that category.
                         If a category is a structure, a value_name
                         is the name of a field. This value should not
                         be null.
            value    = value of stats log entry
            instance = name of the object in a given category.
                       For example, if the category is 'channels', then a name
                       name would be a channel name, like 'campaign_metadata'.
                       This value should be null if category is null,
                       and non-null otherwise.

    ***************************************************************************/

    protected void formatValue (istring category, V)
        (cstring value_name, V value, istring instance = null)
    in
    {
        assert(value_name !is null);
        static if (category.length)
        {
            assert(instance !is null);
        }
        else
        {
            assert(instance is null);
        }
    }
    body
    {
        static if (category.length)
        {
            this.layout(category, '/', instance, '/', value_name, ':', value);
        }
        else
        {
            this.layout(value_name, ':', value);
        }
    }
}
