/*******************************************************************************

    Utility functions to configure tango loggers

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        
    
    authors:        Mathias Baumann
    
    Configures tango loggers.
    
    A logger in the config file can be configured using the following syntax:
    
        [LOG.LoggerName]
        console   = true
        file      = log/logger_name.log
        propagate = false
        level     = info
        additive  = true
    
    General logger configuration can be made like this:
    
        [LOG]
        file_count    = 10
        max_file_size = 500000
        
    Upon calling the configureLoggers function, logger related configuration
    will be read and the according loggers configured accordingly.
        
    Usage Example (You probably will only need to do this):
    -------
    import Log = ocean.util.log.Util;
    // ...
    Log.configureLoggers(Config().iterateClasses!(Log.Config)("LOG"),
                         Config().get!(Log.MetaConfig)("LOG"));
    -------
    
*******************************************************************************/

module ocean.util.log.Util;

/***************************************************************************

    Imports

***************************************************************************/
    
private import ocean.util.Config;
private import ocean.util.config.ClassFiller;
private import ocean.util.config.ConfigParser;

private import ocean.util.log.SimpleLayout;

private import tango.util.log.Log;
private import tango.util.log.AppendSyslog;
private import ocean.util.log.InsertConsole;
private import tango.util.log.AppendConsole;
private import tango.util.log.LayoutDate;

debug private import ocean.util.log.Trace;

/*******************************************************************************

    Configuration class for loggers 

*******************************************************************************/

class Config
{
    /***************************************************************************
    
        Level of the logger
    
    ***************************************************************************/

    public char[] level;
    
    /***************************************************************************
    
        Whether to use console output or not 
    
    ***************************************************************************/

    public SetInfo!(bool) console;
    
    /***************************************************************************
    
        Whether to use file output and if, which file path
    
    ***************************************************************************/

    public SetInfo!(char[]) file;
    
    /***************************************************************************
    
        Whether to propagate that level to the children
    
    ***************************************************************************/

    public bool propagate;
    
    /***************************************************************************
    
        Whether this logger should be additive or not
    
    ***************************************************************************/
    
    bool additive;
        
    /***************************************************************************
    
        Buffer size of the buffer output
    
    ***************************************************************************/

    public size_t buffer_size = 0;
}

/*******************************************************************************

    Configuration class for logging

*******************************************************************************/

class MetaConfig
{
    /***************************************************************************
    
        How many files should be created
    
    ***************************************************************************/
        
    size_t file_count    = 10;
    
    /***************************************************************************
    
        Maximum size of one log file
    
    ***************************************************************************/

    size_t max_file_size = 500 * 1024 * 1024;

    /***************************************************************************
    
        Index of the first file that should be compressed
        
        E.g. 4 means, start compressing with the forth file
    
    ***************************************************************************/

    size_t start_compress = 4;

    /***************************************************************************
    
        Tango buffer size, if 0, internal stack based buffer of 2048 will be 
        used.
    
    ***************************************************************************/

    size_t buffer_size   = 0;
}

/*******************************************************************************

    Convenience alias for iterating over Config classes

*******************************************************************************/
    
alias ClassIterator!(Config) ConfigIterator;

/*******************************************************************************

    Clear any default appenders at startup

*******************************************************************************/
    
static this ( )
{
    Log.root.clear();
}

/*******************************************************************************

    Sets up logging configuration.
    
    Params:
        config   = an instance of an class iterator for Config 
        m_config = an instance of the MetaConfig class
        use_insert_appender = whether to use the insert appender which
                              doesn't support newlines in the output msg

*******************************************************************************/
    
public void configureLoggers ( Source = ConfigParser ) 
                             ( ClassIterator!(Config, Source) config, 
                               MetaConfig m_config, bool loose = false,
                               bool use_insert_appender = false )
{
    config.loose = loose;
    
    foreach (name, settings; config)
    {
        bool console_enabled = false;
        Logger log;
        
        if ( name == "Root" ) 
        {
            log = Log.root;
            console_enabled = settings.console(true);
        }
        else
        {
            log = Log.lookup(name);
            console_enabled = settings.console();
        }

        size_t buffer_size = m_config.buffer_size;
        if ( settings.buffer_size )
        {
            buffer_size = settings.buffer_size;
        }

        if ( buffer_size > 0 )
        {
            log.buffer(new char[](buffer_size));
        }

        log.clear();
        // if console/file is specifically set, don't inherit other appenders
        // (unless we have been specifically asked to be additive)
        log.additive = settings.additive ||
                       !(settings.console.set || settings.file.set);
        
        if ( settings.file.set )
        {
            log.add(new AppendSyslog(settings.file(), 
                                     m_config.file_count,
                                     m_config.max_file_size,
                                     "gzip {}", "gz", m_config.start_compress,
                                     new LayoutDate));
        }
                                   
        if ( console_enabled )
        {
            if ( use_insert_appender )
            {
                log.add(new InsertConsole(new SimpleLayout));
            }
            else
            {
                log.add(new AppendConsole(new SimpleLayout));
            }
        }
        
        with (settings) if ( level.length > 0 ) switch ( level )
        {
            case "Trace":
            case "trace":
            case "TRACE":
            case "Debug":
            case "debug":
            case "DEBUG":
                log.level(Level.Trace, propagate);
                break;
                
            case "Info":
            case "info":
            case "INFO":
                log.level(Level.Info, propagate);
                break;
                
            case "Warn":
            case "warn":
            case "WARN":
                log.level(Level.Warn, propagate);
                break;
                
            case "Error":
            case "error":
            case "ERROR":
                log.level(Level.Error, propagate);
                break;
                
            case "Fatal":
            case "fatal":
            case "FATAL":
                log.level(Level.Info, propagate);
                break;
                
            case "None":
            case "none":
            case "NONE":
            case "Off":
            case "off":
            case "OFF":
            case "Disabled":
            case "disabled":
            case "DISABLED":
                log.level(Level.None, propagate);
                break;
            default:
                throw new Exception("Invalid value for log level in section"
                                    " [" ~ name ~ "]");
        }
    }
}
