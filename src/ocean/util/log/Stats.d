/*******************************************************************************

    Classes to write statistics to be used in graphite.

    Applications that want to log statistics usually make use of the `StatsExt`
    extension (most likely by deriving from `DaemonApp`),
    which provides a `StatsLog` instance which is automatically configured from
    the application's config.ini.

    Usually two cases arise: the application wants to log a certain set of data
    periodically -- on a regular basis -- and/or it wants to log a certain
    set of data after a certain operation is completed (i.e. not periodically).

    As a result this module provide 2 sets of utilities:
    - A simple `StatsLog` class with methods to write structs;
    - A `PeriodicStatsLog` template which is built on top of the previous class
        (it uses it), integrates with Epoll and allows to write stats on
        a regular basis (with a user-specific period);

    Currently, `StatsLog` writes to a file (called `stats.log`), which is then
    parsed by a script that will feed the data to a Collectd socket.
    Every server's Collectd daemon will then report to a master Collectd server
    which aggregates the data.
    As our number of stats is growing and the write rate is increasing, we're
    planning to expose a way to directly write to the Collectd socket.
    As a result, the current API of `StatsLog` is intentionally designed
    to comply to the limitations of Collectd. See the documentation of
    `StatsLog` for more details

    Refer to the class' description for information about their actual usage.

    copyright:      Copyright (c) 2012-2015 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.log.Stats;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.core.Enforce;
import ocean.core.Exception_tango;
import ocean.core.Traits : FieldName;
import ocean.core.TypeConvert;
import ocean.io.select.EpollSelectDispatcher;
import ocean.io.select.client.TimerEvent;
import ocean.net.collectd.Collectd;
import ocean.stdc.time : time_t;
import ocean.sys.ErrnoException;
import ocean.text.convert.Layout: StringLayout;
import ocean.util.log.layout.LayoutStatsLog;
import ocean.util.log.Log;
import ocean.util.log.AppendSyslog;


version (UnitTest)
{
    import ocean.util.app.DaemonApp;
}


/*******************************************************************************

    Module logger

*******************************************************************************/

private Logger log;
static this ()
{
    log = Log.lookup("ocean.util.log.Stats");
}

/*******************************************************************************

    Wrapper around a StatsLog to periodically writes values of an aggregate
    to a logger using a timer event registered with epoll.

    Template_Params:
        T = an aggregate which contains the values that should be written to the
            file, the tuple of the aggregate's members is iterated and each
            printed

    Examples:
        See the unittest following this class for an example application

*******************************************************************************/

deprecated("Applications using the periodic stats log should instead use the "
    "DaemonApp application base class and override its onStatsTimer() method.")
public class PeriodicStatsLog ( T ) : IPeriodicStatsLog
{
    /***************************************************************************

        Delegate to get a pointer to an aggregate containing the values that are
        to be written.

    ***************************************************************************/

    private alias Const!(T)* delegate ( ) ValueDg;

    private ValueDg value_dg;

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

// Note that this usage example no longer demonstrates recommended practice.
// Applications using the PeriodicStatsLog should migrate to use the DaemonApp
// base class and use its built-in stats updated timer (the protected method
// onStatsTimer(), which can be overridden). See the StatsLog usage example to
// see what this looks like.
/// Usage example for PeriodicStatsLog in a simple application
deprecated unittest
{
    class MyPeriodicStatsApp : DaemonApp
    {
        private static struct Stats
        {
            double foo;
            double bar;
        }

        private PeriodicStatsLog!(Stats) periodic;
        private Stats stats;

        public this ()
        {
            auto epoll = new EpollSelectDispatcher;
            super(epoll, "Test", null, null);

            // 30 seconds
            this.periodic = new PeriodicStatsLog!(Stats)
                (epoll, &this.getStats, &this.resetStats,
                 this.stats_ext.stats_log, 30);

            // Here you do some processing and update `this.stats`
            // when necessary.
        }

        public Const!(Stats)* getStats ()
        {
            return &stats;
        }

        public void resetStats (StatsLog stats_log)
        {
            this.stats.foo = 0;
            this.stats.bar = 0;
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

deprecated("Applications using the periodic stats log should instead use the "
    "DaemonApp application base class and override its onStatsTimer() method.")
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

        Write period in seconds

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
            period = period after which the values should be written (seconds)
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
            period = period after which the values should be written (seconds)

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

    Transmit the values of an aggregate to be used within graphite.

    This class has 2 methods which can be used: `add` and `addObject`.

    `add` is meant for application statistics, i.e. amount of memory used,
    number of channels alive, number of connections open, largest record
    processed...

    `addObject` logs an instance of an object which belongs to a category.
    This method should be used when you have a set of standard metrics which
    you want to log for multiple instances of a type of object.
    For example, you may want to log standard stats for each channel in
    a storage engine, for each campaign of an advertiser,
    for each source of input records, etc.

    See the methods description for more informations.

    Note:
    StatsLog formerly had the ability to write single value instead of an
    aggregate. It was removed as it goes against Collectd's design, where
    data sent to the socket are sent aggregated by 'types', where a type is
    a collection of related metrics (akin to a `struct`), so single values
    are not permitted.
    In addition, it's not possible to incrementally build an aggregate either,
    as we need the aggregate's complete definition : if we send incomplete/too
    much data to Collectd, it just rejects the whole aggregate, and data is sent
    without field names, as Collectd relies on its type definition for that
    piece of information. Having the wrong order would mean some metrics are
    logged as other metrics, a bug that might not be easily identifiable.
    This was leaving too much room for error which were not easily identifiable.

    Examples:
        See the unittest following this class for an example application

*******************************************************************************/

public class StatsLog
{
    /***************************************************************************

        Stats log config class

        The field `hostname`, `app_name`, `app_instance` and `default_type`
        are values used by the Collectd integration of `StatsLog`.

        Collectd identify resources using an identifier, that has the
        following form: 'hostname/plugin-pinstance/type-tinstance'.
        Every resource written by a process MUST have the same 'hostname',
       'plugin' and 'pinstance' values.
        `hostname` value is not limited or checked in any way.
        Other identifier shall only include alphanum ([a-z] [A-Z] [0-9]),
        underscores ('_') and dots ('.').
        Instance parts can also include dashes ('-').

    ***************************************************************************/

    public static class Config
    {
        public istring file_name;
        public size_t max_file_size;
        public size_t file_count;
        public size_t start_compress;


        /***********************************************************************

            Path to the collectd socket

            It is null by default. When set through the constructor (usual value
            is provided through `default_collectd_socket`, `StatsLog` will
            write to the Collectd socket.

            When this is set, it is required that `collectd_name` and
            `collectd_instance` be set.

        ***********************************************************************/

        public istring socket_path;


        /***********************************************************************

            'hostname' to use when logging using 'add'

            This is the 'hostname' part of the identifier.
            If not set, gethostname (2) will be called.
            See this class' documentation for further details.

        ***********************************************************************/

        public istring hostname;


        /***********************************************************************

            Collectd 'plugin' name to used

            This is the 'plugin' part of the identifier, and should be set
            to your application's name. It should hardly ever change.

            By default, the name provided to the application framework will be
            used.  If the application framework isn't used, or the name needs
            to be overriden, set this value to a non-empty string.

            See this class' documentation for further details.

        ***********************************************************************/

        public istring app_name;


        /***********************************************************************

            Collectd 'plugin instance' name to used

            This is the 'pinstance' part of the identifier, and should be set
            to your application's "instance". This can be an id (1, 2, 3...)
            or a more complicated string, like the ranges over which your app
            operate ("0x00000000_0x0FFFFFFF"). Change to this value should be
            rare, if any.
            The duo of 'plugin' and 'pinstance' should uniquely identify
            a process (for the same `hostname`).

            See this class' documentation for further details.

        ***********************************************************************/

        public istring app_instance;


        /***********************************************************************

            Default 'type' to use when logging using 'add'

            This is the 'type' part of the identifier. Usually it is provided
            as a string template argument to `addObject`, but for convenience,
            `add` provide a default logging channel. If this argument is not
            supplied, `collectd_name ~ "_stats"` will be used.

            See this class' documentation for further details.

        ***********************************************************************/

        public istring default_type;


        /***********************************************************************

            Frequency at which Collectd should expect to receive metrics

            This metric is expressed in metric, and should rarely needs to be
            modified. Defaults to 30s.

        ***********************************************************************/

        public ulong interval;


        /***********************************************************************

            Constructor

            Emulates struct's default constructor by providing a default value
            for all parameters.

        ***********************************************************************/

        public this ( istring file_name = default_file_name,
            size_t max_file_size = default_max_file_size,
            size_t file_count = default_file_count,
            size_t start_compress = default_start_compress,
            istring socket_path = null,
            istring hostname = null,
            istring app_name = null,
            istring app_instance = null,
            istring default_type = null,
            ulong interval = 30)

        {
            this.file_name = file_name;
            this.max_file_size = max_file_size;
            this.file_count = file_count;
            this.start_compress = start_compress;
            // Collectd settings
            this.socket_path = socket_path;
            this.hostname = hostname;
            this.app_name = app_name;
            this.app_instance = app_instance;
            this.default_type = default_type;
            this.interval = interval;
        }
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
        Appender newAppender ( istring file, Appender.Layout layout )
        {
            return new AppendSyslog(file,
                castFrom!(size_t).to!(int)(config.file_count),
                config.max_file_size, "gzip {}", "gz",
                config.start_compress, layout);
        }

        this(config, &newAppender, name);
    }


    /// ditto
    deprecated("Replace IStatsLog.Config with StatsLog.Config")
    public this ( IStatsLog.Config config_, istring name = "Stats" )
    {
        auto config = new Config(config_.file_name, config_.max_file_size,
            config_.file_count, config_.start_compress);

        this(config, name);
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
    in
    {
        if (config.socket_path.length)
        {
            assert(config.hostname.length);
            assert(config.app_name.length);
            assert(config.default_type.length);
        }
    }
    body
    {
        this.logger = Log.lookup(name);
        this.logger.clear();
        this.logger.additive(false);

        this.logger.add(new_appender(config.file_name, new LayoutStatsLog));

        // Explicitly set the logger to output all levels, to avoid the situation
        // where the root logger is configured to not output level 'info'.
        this.logger.level = this.logger.Level.Trace;

        this.layout = new StringLayout!();

        if (config.socket_path.length)
        {
            // Will throw if it can't connect to the socket
            this.collectd = new Collectd(config.socket_path);

            this.identifier.host = config.hostname;
            this.identifier.plugin = config.app_name;
            this.identifier.plugin_instance = config.app_instance;
            this.identifier.type = config.default_type;
            this.options.interval = config.interval;
        }
    }


    /// ditto
    deprecated("Replace IStatsLog.Config with StatsLog.Config")
    public this ( IStatsLog.Config config_,
        Appender delegate ( istring file, Appender.Layout layout ) new_appender,
        istring name = "Stats" )
    {
        auto config = new Config(config_.file_name, config_.max_file_size,
            config_.file_count, config_.start_compress);

        this(config, new_appender, name);
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

    deprecated("Use the constructor which accepts a Config instance")
    public this ( size_t file_count = default_file_count,
        size_t max_file_size = default_max_file_size,
        istring file_name = default_file_name, istring name = "Stats" )
    {
        this(new Config(file_name, max_file_size, file_count), name);
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

    deprecated("Use the constructor which accepts a Config instance")
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
        if (this.collectd !is null)
            this.sendToCollectd!(null)(values, istring.init);
        return this;
    }


    /***************************************************************************

        Adds the values of the given aggregate to the stats log. Each member of
        the aggregate will be output as
        <category>/<instance>/<member name>:<member value>.

        Params:
            category = The name of the category this object belongs to.

            instance = Name of the object to add.
            values = aggregate containing values to write to the log.

    ***************************************************************************/

    public typeof(this) addObject (istring category, T)
        (cstring instance, T values)
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
        if (this.collectd !is null)
            this.sendToCollectd!(category)(values, instance);
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

        Params:
            category = the type or category of the object, such as 'channels',
                       'users'... May be null (see the 'instance' parameter).
            T = the type of the aggregate containing the fields to log

            values = aggregate containing values to write to the log. Passed as
                     ref purely to avoid making a copy -- the aggregate is not
                     modified.
            instance = the name of the instance of the category, or null if
                none. For example, if the category is 'companies', then the name
                of an instance may be "google". This value should be null if
                category is null, and non-null otherwise.

    ***************************************************************************/

    private void format ( istring category, T ) ( ref T values, cstring instance )
    {
        foreach ( i, value; values.tupleof )
        {
            auto value_name = FieldName!(i, T);

            static if (is(typeof(value) : long))
                long fmtd_value = value;
            else static if (is(typeof(value) : double))
                double fmtd_value = value;
            else
            {
                pragma(msg, "[", __FILE__, ":", __LINE__, "] '", T.stringof,
                       "' should only contain integer or floating point members");
                auto fmtd_value = value;
            }

            // stringof results in something like "values.somename", we want
            // only "somename"
            if (this.add_separator)
            {
                this.layout(' ');
            }

            static if (category.length)
            {
                assert(instance.length);
                this.layout(category, '/', instance, '/', value_name, ':',
                    fmtd_value);
            }
            else
            {
                assert(!instance.length);
                this.layout(value_name, ':', fmtd_value);
            }

            this.add_separator = true;
        }
    }


    /***************************************************************************

        Send the content of the struct to Collectd

        This will format and send data to the Collectd daemon.
        If any error happen, they will be reported by a log message but won't
        be propagated up, so applications that have trouble logging won't
        fail.

        Note:
        As with `format`, when the aggregate is a class, the members of
        the super class are not iterated over.

        Params:
            category = the type or category of the object, such as 'channels',
                       'users'... May be null (see the 'instance' parameter).
            T = the type of the aggregate containing the fields to log

            values = aggregate containing values to write to the log. Passed as
                     ref purely to avoid making a copy -- the aggregate is not
                     modified.
            instance = the name of the instance of the category, or null if
                none. For example, if the category is 'companies', then the name
                of an instance may be "google". This value should be null if
                category is null, and non-null otherwise.

    ***************************************************************************/

    private void sendToCollectd (istring category, T) (ref T values,
                                                       cstring instance)
    in
    {
        assert(this.collectd !is null);
        static if (!category.length)
            assert(!instance.length);
    }
    body
    {
        // It's a value type (struct), do a copy
        auto id = this.identifier;
        static if (category.length)
        {
            id.type = category;
            id.type_instance = instance;
        }

        // putval returns null on success, a failure reason else
        try
            this.collectd.putval!(T)(id, values, this.options);
        catch (CollectdException e)
            log.error("Sending stats to Collectd failed: {}", e);
        catch (ErrnoException e)
            log.error("I/O error while sending stats: {}", e);
    }


    /***************************************************************************

        Collectd instance

    ***************************************************************************/

    protected Collectd collectd;


    /***************************************************************************

        Default identifier when doing `add`.

    ***************************************************************************/

    protected Identifier identifier;


    /***************************************************************************

        Default set options to send

        Currently it's only `interval=30`.

    ***************************************************************************/

    protected Collectd.PutvalOptions options;
}

/// Usage example for StatsLog in a simple application
unittest
{
    class MyStatsLogApp : DaemonApp
    {
        private static struct Stats
        {
            double awesomeness;
            double bytes_written;
            double bytes_received;
        }

        private static struct Channel
        {
            double profiles_in;
            double profiles_out;
        }

        public this ()
        {
            super(null, "Test", null, null);
        }

        protected override int run (Arguments args, ConfigParser config)
        {
            return 0;
        }

        protected override void onStatsTimer ( )
        {
            // Do some heavy-duty processing ...
            Stats app_stats1 = { 42_000_000, 10_000_000,  1_000_000 };
            Stats app_stats2 = { 42_000_000,  1_000_000, 10_000_000 };
            this.stats_ext.stats_log.add(app_stats1);

            // A given struct should be `add`ed once and only once, unless
            // you flush in between
            this.stats_ext.stats_log.flush();
            this.stats_ext.stats_log.add(app_stats2);

            // Though if you use `addObject`, it's okay as long as the instance
            // name is different
            Channel disney = { 100_000, 100_000 };
            Channel discovery = { 10_000, 10_000 };

            // For the same struct type, you probably want the
            // same category name. It's not a requirement but there are
            // no known use case where you want it to differ.
            this.stats_ext.stats_log.addObject!("channel")("disney", disney);
            this.stats_ext.stats_log.addObject!("channel")("discovery", discovery);
        }
    }
}



/*******************************************************************************

    Templateless stats log base class. Contains no abstract methods, but
    declared as abstract as it is useless on its own, without deriving.

*******************************************************************************/

deprecated("Use the StatsLog class instead")
public abstract class IStatsLog
{
    /***************************************************************************

        Config class

    ***************************************************************************/

    public static class Config
    {
        istring file_name;
        size_t max_file_size;
        size_t file_count;
        size_t start_compress;

        this ( istring file_name = default_file_name,
            size_t max_file_size = default_max_file_size,
            size_t file_count = default_file_count,
            size_t start_compress = default_start_compress)
        {
            this.file_name = file_name;
            this.max_file_size = max_file_size;
            this.file_count = file_count;
            this.start_compress = start_compress;
        }
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

        Params:
            category = The category of the structure, such as 'channels',
                       'users'... Can be null (see 'instance' parameter).
            V        = type of value. Assumed to be handled by Layout

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
        (cstring value_name, V value, cstring instance = null)
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
