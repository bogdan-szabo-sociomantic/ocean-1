/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        12/21/2012: Initial release

    authors:        Ben Palmer

    Module to display application information in the terminal. Does not keep 
    track of any values, only puts the information to the terminal in a style 
    similiar to the one originally used by propulsor and sonar.

    Can display a set of static lines that stay at the bottom of the terminal 
    as well as streaming lines that are scrolled above the static lines.

    Usage Example:

    ---

        const number_of_static_lines = 2;

        AppStatus app_status = new AppStatus("test", Version.revision, 
            Version.build_date, Version.build_author, clock,
            number_of_static_lines);

        ulong c1, c2, c3, c4;

        app_status.formatStaticLine(0, "{} count1, {} count2", c1, c2);
        app_status.formatStaticLine(1, "{} count3, {} count4", c3, c4);
            
        app_status.displayStaticLines();

        app_status.displayStreamingLine("{} count5, {} count6", c5, c6);

    ---

*******************************************************************************/

module ocean.io.console.AppStatus;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.Terminal;

private import ocean.time.model.IMicrosecondsClock;

private import ocean.core.Array;

private import ocean.io.Stdout;

private import ocean.text.convert.Layout;

private import ocean.util.log.InsertConsole;

private import ocean.util.log.MessageOnlyLayout;

private import tango.stdc.math: lroundf;

private import tango.core.Memory;

private import tango.stdc.stdlib: div;

private import tango.stdc.time: clock_t, clock, tm, time_t;

private import tango.util.log.Log;



/*******************************************************************************

    Module to display static and streaming lines in the terminal.

*******************************************************************************/

public class AppStatus
{
    /***************************************************************************

        Message buffer used for formatting streaming lines. The buffer is public
        so that, if more complex formatting is needed than is provided by the
        displayStreamingLine() methods, then it can be used externally to format
        any required messages. The version of displayStreamingLine() with no
        arguments can then be called to print the contents of the buffer.

    ***************************************************************************/

    public StringLayout!(char) msg;


    /***************************************************************************

        Alias for system clock function.

    ***************************************************************************/

    private alias .clock system_clock;


    /***************************************************************************

        Interval clock, passed into the constructor. Used to display the current
        time and to calculate running time.

    ***************************************************************************/

    private const IAdvancedMicrosecondsClock clock;
    
    
    /***************************************************************************

        start time of the program. saved when first started and compared with
        the current time to get the runtime of the program

    ***************************************************************************/
    
    private time_t start_time;
    
    
    /***************************************************************************

        Saved value of the total time used by this application. Used to
        calculate the cpu load of this program

    ***************************************************************************/
    
    private clock_t ticks = -1;
    
    
    /***************************************************************************

        private buffer for storing and formatting the static lines to display

    ***************************************************************************/
    
    private char[][] static_lines;
    
    
    /***************************************************************************

        the name of the current application

    ***************************************************************************/
    
    private const char[] app_name;
    
    
    /***************************************************************************

        the version of the current application

    ***************************************************************************/
    
    private const char[] app_version;
    
    
    /***************************************************************************

        the build date of the current application

    ***************************************************************************/
    
    private const char[] app_build_date;
    
    
    /***************************************************************************

        who built the current application

    ***************************************************************************/
    
    private const char[] app_build_author;
    
    
    /***************************************************************************

        buffer used for the header line

    ***************************************************************************/
    
    private char[] heading_line;
    
    
    /***************************************************************************

        buffer used for the footer

    ***************************************************************************/
    
    private char[] footer_line;
    
    
    /***************************************************************************

        insert console used to display the streaming lines

    ***************************************************************************/
    
    private InsertConsole insert_console;
    
    
    /***************************************************************************

        saved terminal size used to check if the terminal size has changed

    ***************************************************************************/
    
    private int old_terminal_size;
     
    
    /***************************************************************************

        Constructor. Saves the current time as the program start time.
    
        Params:
            app_name = name of the application
            app_version = version of the application
            app_build_date = date the application was built
            app_build_author = who built the current build
            clock = clock used to get the current time
            size = number of loglines that are to be displayed below the 
                    title line

    ***************************************************************************/    
    
    public this ( char[] app_name, char[] app_version, char[] app_build_date, 
        char[] app_build_author, IAdvancedMicrosecondsClock clock, uint size )
    {
        this.app_name.copy(app_name);
        this.app_version.copy(app_version);
        this.app_build_date.copy(app_build_date);
        this.app_build_author.copy(app_build_author);
        this.clock = clock;
        this.start_time = this.clock.now_sec;
        this.static_lines.length = size;
        this.insert_console = new InsertConsole(new MessageOnlyLayout);
        this.old_terminal_size = Terminal.rows;

        this.msg = new StringLayout!(char);
    }

    
    /***************************************************************************

        Print the current static lines set by the calling program to Stdout 
        with a title line showing the current time, runtime, and memory and cpu 
        usage and a footer line showing the version information. 
    
        Check if the size of the terminal has changed and if it has move the
        cursor to the end of the terminal.
    
        Print a blank line for each logline and one for the footer. Then print 
        the footer and move up. Then in reverse order print a line and move the 
        cursor up. When all the lines have been printed, print the heading line.

    ***************************************************************************/
  
    public void displayStaticLines ( )
    {
        if ( this.old_terminal_size != Terminal.rows )
        {
            Stdout.endrow;
            this.old_terminal_size = Terminal.rows;
        }
        
        foreach ( line; this.static_lines )
        {
            Stdout.formatln("");
        }
        Stdout.formatln("");
        
        this.printVersionInformation();
        Stdout.clearline.cr.flush.up;
        
        foreach_reverse ( line; this.static_lines )
        {
            this.checkLength(line);
            Stdout.format(line).clearline.cr.flush.up;
        }
        
        this.printHeadingLine();
    }
    
    
    /***************************************************************************

        Format one of the applications static lines. When contrusting this
        module the calling application sets the number of static lines. 
        This method is then used to format the contents of the static lines.
    
        Params:
            index = the index of the static line to format
            format = format string of the message
            args = list of any extra arguments for the message

    ***************************************************************************/

    public void formatStaticLine ( uint index, char[] format, ... )
    {
        assert( index < this.static_lines.length, "adding too many static lines" );
        
        this.static_lines[index].length = 0;       
        Layout!(char).vprint(this.static_lines[index], format,
            _arguments, _argptr);
    }


    /***************************************************************************

        Print a formatted streaming line above the static lines.

        Params:
            format = format string of the streaming line
            ... = list of any extra arguments for the streaming line

    ***************************************************************************/

    public void displayStreamingLine ( char[] format, ... )
    {
        this.displayStreamingLine(format, _arguments, _argptr);
    }


    /***************************************************************************

        Print a formatted streaming line above the static lines.

        Params:
            format = format string of the streaming line
            arguments = typeinfos of any extra arguments for the streaming line
            argptr = pointer to list of extra arguments for the streaming line

    ***************************************************************************/

    public void displayStreamingLine ( char[] format, TypeInfo[] arguments,
        void* argptr )
    {
        this.msg.length = 0;
        this.msg.vformat(format, arguments, argptr);
        this.displayStreamingLine();
    }


    /***************************************************************************

        Print the contents of this.msg as streaming line above the static lines.

    ***************************************************************************/

    public void displayStreamingLine ( )
    {
        Hierarchy host_;
        Level level_;
        LogEvent event;
        event.set(host_, level_, this.msg[], "");

        this.insert_console.append(event);
    }


    
    /***************************************************************************

        Get the current runtime for the current program using the start time 
        and current time. Then didivde the run time in to weeks, days, hours, 
        minutes, and seconds.
    
    /***************************************************************************

        Get the current uptime for the program using the start time and current
        time. Then divide the uptime in to weeks, days, hours, minutes, and
        seconds.

        Params:
            weeks = weeks of runtime
            days = days of runtime
            hours = hours of runtime
            mins = minutes of runtime
            secs = seconds of runtime

    ***************************************************************************/
    
    public void getUptime ( out uint weeks, out uint days, out uint hours,
        out uint mins, out uint secs )
    {
        time_t uptime = this.clock.now_sec - this.start_time;
        
        uint uptimeFract ( uint denom )
        {
            with ( div(uptime, denom) )
            {
                uptime = quot;
                return rem;
            }
        } 
            
        secs = uptimeFract(60);
        mins = uptimeFract(60);
        hours = uptimeFract(24);
        days = uptimeFract(7);
        weeks = uptime;
    }
    
    
    /***************************************************************************

        Calculate the current memory usage of this program using the tango 
        memory module
    
        Params:
            mem_allocated = the amount of memory currently allocated
            mem_free = the amount of allocated memory that is currently free

    ***************************************************************************/
    
    public void getMemoryUsage ( out float mem_allocated, out float mem_free )
    {
        version ( CDGC )
        {
            const float Mb = 1024 * 1024;
            size_t used, free;
            GC.usage(used, free);

            mem_allocated = cast(float)(used + free) / Mb;
            mem_free = cast(float)free / Mb;
        }
    }
    
    
    /***************************************************************************

        Get the current cpu usage of this program. Uses the clock() method
        that returns the total current time used by this program. This is then
        used to compute the current cpu load of this program.
    
        Params:
            usage = the current CPU usage of this program as a percentage

    ***************************************************************************/
    
    public void getCpuUsage ( out long usage )
    {
        clock_t ticks = system_clock();
        if ( this.ticks >= 0 )
        {           
            usage = lroundf((ticks - this.ticks) / 10_000.f); 
        }        
        this.ticks = ticks;
    }
    
    
    /***************************************************************************

        Print the heading line. Includes the current time, runtime, and memory 
        and cpu usage of this application (prints in bold).

    ***************************************************************************/
    
    private void printHeadingLine ( )
    {
        auto time = this.clock.now_DateTime.time;
        auto date = this.clock.now_DateTime.date;
        
        this.heading_line.length = 0;
        
        Layout!(char).print(this.heading_line, "[{:d2}/{:d2}/{:d2} "
            "{:d2}:{:d2}:{:d2}] {}", date.day, date.month, date.year, 
            time.hours, time.minutes, time.seconds, this.app_name);
        
        this.formatUptime();      
        this.formatMemoryUsage();       
        this.formatCpuUsage();
        
        this.checkLength(this.heading_line);     
        Stdout.bold(true).format(this.heading_line).bold(false).
            clearline.cr.flush;
    }
    
    
    /***************************************************************************

        Format the memory usage for the current program to using the 
        tango memory module to calculate current usage

    ***************************************************************************/
    
    private void formatMemoryUsage ( ) 
    {
        float mem_allocated, mem_free;
        this.getMemoryUsage(mem_allocated, mem_free);
        Layout!(char).print(this.heading_line, " Memory: Used {}Mb/Free {}Mb", 
            mem_allocated, mem_free);
    }
    
    
    /***************************************************************************

        Format the current uptime for the current program.

    ***************************************************************************/
    
    private void formatUptime ( )
    {
        uint weeks, days, hours, mins, secs;     
        this.getUptime(weeks, days, hours, mins, secs);      
        Layout!(char).print(this.heading_line, " Uptime: {}w{:d1}d{:d2}:"
            "{:d2}:{:d2}", weeks, days, hours, mins, secs);
    }
    
    
    /***************************************************************************

        Format the current cpu usage of this program.

    ***************************************************************************/
    
    private void formatCpuUsage ( )
    {
        long usage = 0;
        this.getCpuUsage(usage);
        Layout!(char).print(this.heading_line, " CPU: {}%", usage);
    }
    
    
    /***************************************************************************

        Print the version and build information for this application (prints in
        bold)

    ***************************************************************************/
    
    private void printVersionInformation ( )
    {
        this.footer_line.length = 0;
        
        Layout!(char).print(this.footer_line, "Version {} built on {} by {}", 
            this.app_version, this.app_build_date, this.app_build_author);
        
        this.checkLength(this.footer_line);
        Stdout.bold(true).format(this.footer_line).bold(false); 
    }

    
    /***************************************************************************

        Check the length of the buffer against the number of columns in the 
        terminal. If the buffer is too long, set it to the terminal width.
    
        Params:
            buffer = buffer to check the length of

    ***************************************************************************/
    
    private void checkLength ( ref char[] buffer )
    {
        if ( buffer.length > Terminal.columns )
        {
            buffer.length = Terminal.columns;
        }
    }
}

