/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        12/21/2012: Initial release

    authors:        Ben Palmer

    Module to display application information in the terminal. Does not keep
    track of any values, only puts the information to the terminal in a style
    similar to the one originally used by propulsor and sonar.

    Since almost all applications that use this module also use Tango's logging
    facility, a separate appender (ocean.util.log.InsertConsole) has been
    developed to allow for application logs to be correctly displayed in the
    streaming portion. The InsertConsole appender moves the cursor just above
    the static lines, creates space by scrolling-up previously displayed content
    in the streaming portion, and then "inserts" the given log message in the
    newly created space. The existing static lines are not touched during this
    process.

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

private import ocean.util.log.layout.LayoutMessageOnly;

private import tango.stdc.math: lroundf;

private import tango.core.Memory;

private import tango.stdc.stdlib: div;

private import tango.stdc.time: clock_t, clock, tm, time_t;

private import tango.util.log.Log;

private import tango.io.Console;



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

        Convenience aliases for derived classes.

    ***************************************************************************/

    protected alias .IAdvancedMicrosecondsClock IAdvancedMicrosecondsClock;

    protected alias .TerminalOutput!(char) TerminalOutput;


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

        Expected milliseconds between calls to getCpuUsage. Needed to calculate
        the cpu usage correctly. Defaults to 1000ms.

    ***************************************************************************/

    private const ulong ms_between_calls;


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
            ms_between_calls = expected milliseconds between calls to
                               getCpuUsage (defaults to 1000ms)

    ***************************************************************************/

    public this ( char[] app_name, char[] app_version, char[] app_build_date,
        char[] app_build_author, IAdvancedMicrosecondsClock clock, uint size,
        ulong ms_between_calls = 1000 )
    {
        this.app_name.copy(app_name);
        this.app_version.copy(app_version);
        this.app_build_date.copy(app_build_date);
        this.app_build_author.copy(app_build_author);
        this.clock = clock;
        this.start_time = this.clock.now_sec;
        this.static_lines.length = size;
        this.ms_between_calls = ms_between_calls;
        this.insert_console = new InsertConsole(Cout.stream, true,
            new LayoutMessageOnly);
        this.old_terminal_size = Terminal.rows;

        this.msg = new StringLayout!(char);
    }


    /***************************************************************************

        Dispose.

        Inserts a newline after the last row of the output so that:
            1. if the application using AppStatus exits, the command prompt
               appears after the static lines portion, or
            2. if the application using AppStatus deletes the AppStatus object,
               further output appears after the static lines portion.

        Just like a destructor, this method is automatically called when the
        AppStatus object is deleted. However unlike the destructor, GC
        references will still be intact when this method is invoked (i.e.
        Stdout object will be there).

    ***************************************************************************/

    public void dispose ( )
    {
        Stdout.endrow.newline.flush;
    }


    /***************************************************************************

        Clear all the app status lines from the console (including header and
        footer).

        This method is useful for when something needs to be printed on the
        console (e.g a log message) and without calling this method the traces
        of the app status might interfere with the printed line.

        P.s: The caller need to make sure that the app status is already
        displayed before calling this method, otherwise unintended lines might
        be deleted.

    ***************************************************************************/

    public void eraseStaticLines ( )
    {
        // Add +2: One for header and one for footer
        for (size_t i = 0; i < this.static_lines.length + 2; i++)
        {
            Stdout.clearline.newline;
        }

        // Each iteration in the previous loop moves the cursor one line to
        // the bottom. We need to return it to the right position again.
        // We can't combine both loops or we will be clearing and overwriting
        // the same first line over and over.
        for (size_t i = 0; i < this.static_lines.length + 2; i++)
        {
            Stdout.up;
        }

        Stdout.flush;
    }


    /***************************************************************************

        Resizes the number of lines in the app status static display and clears
        the current content of the static lines. Also resets the cursor
        position so that the static lines are still at the bottom of the
        display.

        Note:
            A decrease in the number of static lines will result in one or more
            blank lines appearing in the upper streaming portion of the output.
            This is because on reducing the number of static lines, more space
            is created for the streaming portion, but without anything to be
            displayed there. The number of blank lines thus created will be
            equal to the amount by which the number of static lines are being
            reduced.

        Params:
            size = number of loglines that are to be displayed below the
                    title line

        Returns:
            the updated number of static lines

    ***************************************************************************/

    public size_t num_static_lines ( size_t size )
    {
        this.resetStaticLines();

        if ( this.static_lines.length > size )
        {
            // The number of static lines are being reduced

            // First remove the already displayed static lines from the console
            this.resetCursorPosition();

            // ...and then remove the static lines header
            Stdout.clearline.cr.flush.up;
        }
        else if ( this.static_lines.length < size )
        {
            // The number of static lines are being increased

            // First remove the static lines header
            Stdout.clearline.cr.flush.up;

            // ...and then push up the streaming portion on the top by
            //        the new number of static lines
            //        + the static lines header
            //        + the static lines footer
            for ( auto i = 0; i < (size + 2); ++i )
            {
                Stdout.formatln("");
            }
        }

        this.static_lines.length = size;
        this.resetCursorPosition();
        return this.static_lines.length;
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
        this.checkCursorPosition();

        foreach ( line; this.static_lines )
        {
            Stdout.formatln("");
        }
        Stdout.formatln("");

        this.printVersionInformation();
        Stdout.clearline.cr.flush.up;

        foreach_reverse ( line; this.static_lines )
        {
            if ( line.length )
            {
                Stdout.format(this.truncateLength(line));
            }
            Stdout.clearline.cr.flush.up;
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

        Print a list of arguments as a streaming line above the static lines.
        Each argument is printed using its default format.

        Params:
            ... = list of arguments for the streaming line

    ***************************************************************************/

    public void displayStreamingLineArgs ( ... )
    {
        this.displayStreamingLineArgs(_arguments, _argptr);
    }


    /***************************************************************************

        Print a list of arguments as a streaming line above the static lines.
        Each argument is printed using its default format.

        Params:
            arguments = typeinfos of arguments for the streaming line
            argptr = pointer to list of arguments for the streaming line

    ***************************************************************************/

    public void displayStreamingLineArgs ( TypeInfo[] arguments, void* argptr )
    {
        this.msg.length = 0;
        this.msg.vwrite(arguments, argptr);
        this.displayStreamingLine();
    }


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

        Returns:
            true if the memory usage was properly gathered, false if is not
            available.

    ***************************************************************************/

    public bool getMemoryUsage ( out float mem_allocated, out float mem_free )
    {
        const float Mb = 1024 * 1024;
        size_t used, free;
        GC.usage(used, free);

        if (used == 0 && free == 0)
            return false;

        mem_allocated = cast(float)(used + free) / Mb;
        mem_free = cast(float)free / Mb;

        return true;
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
            usage =
                lroundf((ticks - this.ticks) / (this.ms_between_calls * 10.f));
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

        Stdout.bold(true).format(this.truncateLength(this.heading_line)).
            bold(false).clearline.cr.flush;
    }


    /***************************************************************************

        Format the memory usage for the current program to using the
        tango memory module to calculate current usage (if available).

    ***************************************************************************/

    private void formatMemoryUsage ( )
    {
        float mem_allocated, mem_free;

        bool stats_available = this.getMemoryUsage(mem_allocated, mem_free);

        if (stats_available)
        {
            Layout!(char).print(this.heading_line,
                " Memory: Used {}Mb/Free {}Mb", mem_allocated, mem_free);
        }
        else
        {
            Layout!(char).print(this.heading_line, " Memory: n/a");
        }
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
        bold).

        Additional text may be printed at this point by sub-classes which
        override the protected printExtraVersionInformation(). This method is
        only called if there are > 0 character remaining on the terminal line
        after the standard version info has been displayed. Note that the sub-
        class is responsible for making sure that any extra text printed does
        not exceed the specified number of characters (presumably by calling
        truncateLength()).

    ***************************************************************************/

    private void printVersionInformation ( )
    {
        this.footer_line.length = 0;

        Layout!(char).print(this.footer_line, "Version {} built on {} by {}",
            this.app_version, this.app_build_date, this.app_build_author);

        Stdout.bold(true).format(this.truncateLength(this.footer_line)).
            bold(false);

        auto remaining = Terminal.columns - this.footer_line.length;
        if ( remaining )
        {
            this.footer_line.length = 0;
            this.printExtraVersionInformation(Stdout, this.footer_line,
                remaining);
        }
    }


    /***************************************************************************

        Prints additional text after the standard version info. The default
        implementation prints nothing, but sub-classes may override this method
        to provide specialised version information.

        Params:
            output = terminal output to use
            buffer = buffer which may be used for formatting (initially empty)
            max_length = the maximum number of characters remaining in the
                terminal line. It is the sub-class' responsiblity to check that
                printed text does not exceed this length, presumably by calling
                truncateLength()

    ***************************************************************************/

    protected void printExtraVersionInformation ( TerminalOutput output,
        ref char[] buffer, size_t max_length )
    {
    }


    /***************************************************************************

        Check the length of the buffer against the number of columns in the
        terminal. If the buffer is too long, set it to the terminal width.

        Params:
            buffer = buffer to check the length of

        Returns:
            the truncated buffer

    ***************************************************************************/

    protected char[] truncateLength ( ref char[] buffer )
    {
        return this.truncateLength(buffer, Terminal.columns);
    }


    /***************************************************************************

        Check the length of the buffer against the specified maximum length. If
        the buffer is too long, set it to maximum.

        Params:
            buffer = buffer to check the length of
            max = maximum number of characters in buffer

        Returns:
            the truncated buffer

    ***************************************************************************/

    protected char[] truncateLength ( ref char[] buffer, size_t max )
    {
        if ( buffer.length > max )
        {
            buffer.length = max;
        }
        return buffer;
    }


    /***************************************************************************

        Check the height of the terminal. If the height has changed, reset the
        cursor position.

    ***************************************************************************/

    private void checkCursorPosition ( )
    {
        if ( this.old_terminal_size != Terminal.rows )
        {
            this.resetCursorPosition();
        }
    }


    /***************************************************************************

        Reset the cursor position to the end of the terminal and then move the
        cursor up by the number of static lines that are being printed.

    ***************************************************************************/

    private void resetCursorPosition ( )
    {
        Stdout.endrow;
        this.old_terminal_size = Terminal.rows;

        foreach ( line; this.static_lines )
        {
            Stdout.clearline.cr.flush.up;
        }
        Stdout.clearline.cr.flush.up;
    }


    /***************************************************************************

        Reset the content of all the static lines by setting the length to 0.

    ***************************************************************************/

    private void resetStaticLines ( )
    {
        foreach ( ref line; this.static_lines )
        {
            line.length = 0;
        }
    }
}

