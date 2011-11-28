module ocean.util.log.Stats;

private import ocean.util.log.Trace,
               ocean.io.select.EpollSelectDispatcher,
               ocean.io.select.event.TimerEvent,
               ocean.text.convert.Layout,
               ocean.util.log.LayoutStatsLog;

public import ocean.util.log.Util;

private import tango.util.log.Log,
               tango.util.log.AppendSyslog;

/*******************************************************************************

    Writes periodically values of a struct to a logger.
    Uses the statslog format which is:
    
    date key: value, key: value
    
    The date part is not written by this class. Instead we rely on the logger
    layout which needs to be the StatsLog layout
    
     Template Params:
         T = a struct which contains the values that should be written to the file

*******************************************************************************/

class Stats ( T )
{   
    /***************************************************************************

        Type of the delegate
        
    ***************************************************************************/

    alias T delegate ( ) ValueDg;
       
    /***************************************************************************

        Logger instance
        
    ***************************************************************************/

    const private Logger logger;
    
    /***************************************************************************

        Write period
        
    ***************************************************************************/

    const private time_t period;
     
    /***************************************************************************

        Buffer for the formatting
        
    ***************************************************************************/

    private char[] format_buffer;
         
    /***************************************************************************

        Delegate to get the values that are to be written
        
    ***************************************************************************/

    private ValueDg dg;
    
    /***************************************************************************

        Constructor
        
        Params:
            epoll    = epoll select dispatcher
            dg       = delegate to query the current values
            period   = period after which the values should be written

    ***************************************************************************/

    this ( EpollSelectDispatcher epoll, ValueDg dg, size_t file_count = 10, 
           size_t max_file_size = 10 * 1024 * 1024, time_t period = 300 )
    {         
        this.dg     = dg;
        this.period = period;
        this.logger = Log.lookup("Stats");
        this.logger.clear();
        this.logger.additive(false);
        
        this.logger.add(new AppendSyslog("log/stats.log", file_count, 
                                         max_file_size, "gzip {}", "gz", 4,
                                         new LayoutStatsLog));
        
        auto timer = new TimerEvent(&this.write);
        epoll.register(timer);
        timer.set(5, 0, period, 0);
    }
     
    /***************************************************************************

        Called by the timer at the end of each period, writes the values to
        the logger
        
    ***************************************************************************/

    private bool write ( )
    {
        this.format_buffer.length = 0;

        char[] separator = "";

        auto values = this.dg();
        
        foreach (i, value; values.tupleof)
        {
            Layout!(char).print(this.format_buffer, "{}{}:{}", separator,
                                values.tupleof[i].stringof[7 .. $], value);

            separator = " ";
        }

        this.logger.info(this.format_buffer);

        return true;
    }
}