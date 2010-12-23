/*******************************************************************************
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        May 2010: Initial release

    author:         Gavin Norman

    Provides a simple means of profiling the time and memory usage taken to
    execute sections of code and display output to Trace telling how long each
    recorded section took, and the total of all sections.

    The output frequency of the profiler can be limited using the
    displayInterval() method. The update frequency defaults to ten times per
    second.

    Usage:

    ---

        import ocean.util.Profiler;

        Profiler().start("section1");
        // Code that does something
        Profiler().end("section1");

        Profiler().start("section2");
        // Code that does something else
        Profiler().end("section2");

        Profiler().display();

    ---

	The Profiler can also be used to time and display the *average* time taken
	by timed sections over a series of runs. Note that the averages are only
	updated when the displayAverages function is called, not when display is
	called.
	
	Averages example:

    ---
        
        import ocean.util.Profiler;
        
        Profiler().start("section1");
        // Code that does something
        Profiler().end("section1");

        Profiler().start("section2");
        // Code that does something else
        Profiler().end("section2");

        Profiler().displayAverages(Profiler.Time.Secs);

    ---

	Memory usage example:
	
	---

        import ocean.util.Profiler;

		// Check and display memory usage before & after a code section
		MemProfiler.check("section1", {
			// Code that does something
		});
	
		// Check and display memory usage only if the memory usage has changed
		// in a code section
		MemProfiler.check("section1", {
			// Code that does something
		}, MemProfiler.Expect.NoChange);

		// Assert that memory usage has not changed in a code section
		MemProfiler.checkAssert("section1", {
			// Code that does something
		}, MemProfiler.Expect.NoChange);

	---

    TODO: split MemProfiler into a seperate file, or maybe just remove it - I'm
    not convinced of the effectiveness of the GC.stats methods...

*******************************************************************************/

module ocean.util.Profiler;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.core.Array;

private import ocean.core.ArrayMap;

private import ocean.util.TraceProgress;

private import ocean.util.log.PeriodicTrace;

private import tango.util.log.Trace;

private import Float = tango.text.convert.Float;

private import tango.core.Memory;



/*******************************************************************************

	Profiler struct

*******************************************************************************/

class Profiler
{
    /***************************************************************************

		Helper struct to output time values in secs, millisecs and microsecs
	
	***************************************************************************/

	struct TimeDisplay
    {
	    /***********************************************************************

			Enum defining the possible time display modes.
	
	    ***********************************************************************/

		enum TimeMode
        {
        	Secs = 0,
        	MSecs,
        	USecs
        }


	    /***********************************************************************

			List of dividers for converting from a time in microseconds (as 
			returned by the StopWatch object) to times in each time mode.
	
	    ***********************************************************************/

		static const float[TimeMode.max + 1] div = [ 1000000.0, 1000.0, 1.0 ];


		/***********************************************************************

			List of names for each time mode.

		***********************************************************************/

		static const char[][TimeMode.max + 1] name = [ "s", "ms", "Us" ];


	    /***********************************************************************

			Appends a time to a char[] buffer.
			
			Params:
				name = operation being timed
				time = time in microsecs
				timemode = display mode to use
				str = buffer to write into
	
	    ***********************************************************************/

		static void appendTime ( char[] name, float time, TimeMode timemode, ref char[] str )
    	{
			str.append(name, ": ", Float.toString(time / this.div[timemode]), this.name[timemode]);
    	}
    }


    /***************************************************************************

		Convenience alias for ease of externally accessing the time modes.

	***************************************************************************/

    public alias TimeDisplay.TimeMode Time;


    /***************************************************************************

        Toggles between static display (true) and line-by-line display (false)
    
    ***************************************************************************/

    public bool static_display;


    /***************************************************************************

		Console tracer, including timer

	***************************************************************************/

    private PeriodicTrace tracer;

    
    /***************************************************************************

		Display buffer, used repeatedly

    ***************************************************************************/

    private char[] buf;


	/***************************************************************************

		List of section start times - associative array, indexed by section name
	
	***************************************************************************/

    private ArrayMap!(ulong, char[]) section_start;

    
	/***************************************************************************

		List of section end times - associative array, indexed by section name
	
	***************************************************************************/

    private ArrayMap!(ulong, char[]) section_end;


	/***************************************************************************

		List of average section times - associative array, indexed by section
		name

	***************************************************************************/
	
    private ArrayMap!(float, char[]) section_avg_time;


	/***************************************************************************

		List of the number of times a section has been times - associative array,
		indexed by section name

	 ***************************************************************************/

    private ArrayMap!(uint, char[]) section_avg_count;


    /***************************************************************************

        Constructor. Initialises the internal array maps.
        
    ***************************************************************************/

    public this ( )
    {
        this.section_start = new ArrayMap!(ulong, char[])();
        this.section_end = new ArrayMap!(ulong, char[])();
        this.section_avg_time = new ArrayMap!(float, char[])();
        this.section_avg_count = new ArrayMap!(uint, char[])();
    }


    /***************************************************************************

        Destructor. Destroys the internal array maps.
        
    ***************************************************************************/

    ~this ( )
    {
        delete this.section_start;
        delete this.section_end;
        delete this.section_avg_time;
        delete this.section_avg_count;
    }


	/***************************************************************************

		Starts timing a section of code.
		
		Params:
			name = section name
	
	***************************************************************************/

    public void start ( char[] name )
	{
        this.section_start[name] = this.tracer.timer.microsec();
	}

    
	/***************************************************************************

		Stops timing a section of code.
		
		Params:
			name = section name
	
	***************************************************************************/

    public void end ( char[] name )
	{
    	ulong end = this.tracer.timer.microsec();
		this.section_end[name] = end;
	}


    /***************************************************************************

        Sets the display update interval in microseconds.
        
        Params:
            micro_secs = minimum time (in microseconds) between display updates
        
    ***************************************************************************/

    public void displayInterval ( ulong micro_secs )
    {
    	this.tracer.interval = micro_secs;
    }


	/***************************************************************************

		Displays the times taken by all timed sections, as well as the total
		time taken by all timed sections.
		
		Params:
			time = display mode (secs, msecs, Usecs)
		
	***************************************************************************/

    public void display ( Time time = Time.MSecs )
    {
    	this.display_("", &this.getElapsed, time);
    }


	/***************************************************************************

		Calculates and displays the average times taken by all timed sections
		over the current and each previous run, as well as the average total
		time taken by all timed sections.
		
		Params:
			time = display mode (secs, msecs, Usecs)
		
	***************************************************************************/

    public void displayAverages ( Time time = Time.MSecs )
    {
    	this.display_("[AVG] ", &this.updateAverageTime, time);
    }


    /***************************************************************************

        Resets all section times which have been recorded thusfar.
        
    ***************************************************************************/
    
    public void reset ( )
    {
        this.section_start.clear();
        this.section_end.clear();
        this.resetAverages();
    }
    
    
    /***************************************************************************
    
        Resets the average section times which have been recorded thusfar.
        
    ***************************************************************************/
    
    public void resetAverages ( )
    {
        this.section_avg_time.clear();
        this.section_avg_count.clear();
    }


	/***************************************************************************

		Delegate used by display_ (below) to return the elapsed time of a
		section.
		
	***************************************************************************/

    private uint getElapsed ( char[] name, uint elapsed )
    {
    	return elapsed;
    }


    /***************************************************************************

        Updates the average time for a timed section.
        
        Params:
            name = name of timed section
            elapsed = duration of timed section (in microseconds)
        
        Returns:
            the new average time for the section, after updating
        
    ***************************************************************************/
    
    private float updateAverageTime ( char[] name, uint elapsed )
    {
        float avg;
        if ( name in this.section_avg_time )
        {
            avg = this.section_avg_time[name];
        }
        else
        {
            avg = 0.0;
        }
    
        float new_weight = 1.0;
        uint count;
        if ( name in this.section_avg_count )
        {
            count = this.section_avg_count[name];
            new_weight = 1.0 / cast(float)count;
        }

        float new_avg = (cast(float) elapsed * new_weight) + (avg * (1.0 - new_weight));
        this.section_avg_time[name] = new_avg;
        if ( name in this.section_avg_count )
        {
            this.section_avg_count[name] = this.section_avg_count[name] + 1;
        }
        else
        {
            this.section_avg_count[name] = 1;
        }
    
        return new_avg;
    }


    /***************************************************************************

        If it's time to update the display, displays the times for all timed
        sections.

        Params:
            prefix = string displayed before the times list
            dg = delegate to return the value to display for each individual
                section's time
            time = display mode (secs, msecs, Usecs)

    ***************************************************************************/

    private void display_ ( T : real ) ( char[] prefix, T delegate ( char[], uint ) dg, Time time )
    {
        if ( this.tracer.timeToUpdate() )
        {
            this.buf.length = 0;
            this.buf ~= prefix;
    
            T total = 0;
            foreach ( name, start; this.section_start )
            {
                if ( name in this.section_end )
                {
                    ulong end = this.section_end[name];
                    uint elapsed = end - start;
                    T display_time = dg(name, elapsed);
                    total += display_time;
                    TimeDisplay.appendTime(name, display_time, time, this.buf);
                    this.buf ~= ' ';
                }
            }
            TimeDisplay.appendTime("| Total", total, time, this.buf);
            this.tracer.static_display = this.static_display;
            this.tracer.format(this.buf);
        }
    }


    /***************************************************************************

		Shared instance of the Profiler.
	
	***************************************************************************/

    private static Profiler static_instance;


    /***************************************************************************

        Static destructor. Deletes the shared instance.
    
    ***************************************************************************/

    static ~this()
    {
        if ( static_instance )
        {
            delete static_instance;
        }
    }


    /***************************************************************************

		Gets the shared Profiler instance.
		
	***************************************************************************/

    public static typeof(this) opCall ( )
    {
        if ( !static_instance )
        {
            static_instance = new Profiler();
        }

        return static_instance;
    }
}



/*******************************************************************************

	Memory profiler struct

*******************************************************************************/

struct MemProfiler
{
	/***************************************************************************

		Enum of expected memory usage types. Used by the check methods, below.
	
	***************************************************************************/

	enum Expect
	{
		DontCare,	// always displays mem usage
		NoChange,	// only displays mem usage if it's changed
		MemGrow,	// only displays mem usage if it's not grown
		MemShrink	// only displays mem usage if it's not shrunk
	}


	/***************************************************************************

		Returns the current memory usage in bytes, Kb or Mb.
	
	***************************************************************************/

	static double checkUsage ( )
	{
		return GC.stats["poolSize"];
	}

	static double checkUsageKb ( )
	{
		return GC.stats["poolSize"] / 1024.0;
	}

	static double checkUsageMb ( )
	{
		return GC.stats["poolSize"] / (1024.0 * 1024.0);
	}


	/***************************************************************************

		Checks the current memory usage and compares it to a previously recorded
		value.

		Displays a message to Trace if the expected memory usage condition is
		not true.

		Params:
			name = section name
			before = previous memory usage, to compare to current
			expect = expected memory usage (grow / shrink / no change)

	***************************************************************************/

	static void checkSectionUsage ( char[] name, double before, Expect expect = Expect.DontCare )
	{
		auto after = GC.stats["poolSize"];
		checkCondition(name, expect, before, after);
	}


	/***************************************************************************

		Checks the current memory usage and compares it to a previously recorded
		value.
	
		Displays a message to Trace and asserts if the expected memory usage
		condition is not true.
	
		Params:
			name = section name
			before = previous memory usage, to compare to current
			expect = expected memory usage (grow / shrink / no change)

	***************************************************************************/
	
	static void assertSectionUsage ( char[] name, double before, Expect expect = Expect.DontCare )
	{
		auto after = GC.stats["poolSize"];
		checkCondition(name, expect, before, after);
		assertCondition(name, expect, before, after);
	}
	

	/***************************************************************************

		Records the memory usage before and after a section of code (usually an
		anonymous delegate) which is passed as the parameter 'section'.

		Displays a message to Trace if the expected condition is not true.

		Params:
			name = section name
			expect = expected memory usage (grow / shrink / no change)
			section = section of code to be profiled

	***************************************************************************/

	static R check ( R, T... ) ( char[] name, R delegate ( T ) section, Expect expect = Expect.DontCare )
	{
		static if ( is ( R == void ) )
		{
			auto before = checkUsage();
			section();
			checkSectionUsage(name, before, expect);
			return;
		}
		else
		{
			auto before = checkUsage();
			R r = section();
			checkSectionUsage(name, before, expect);
			return r;
		}
	}


	/***************************************************************************

		Records the memory usage before and after a section of code (usually an
		anonymous delegate) which is passed as the parameter 'section'.
	
		Displays a message to Trace and asserts if the expected condition is not
		true.
	
		Params:
			name = section name
			expect = expected memory usage (grow / shrink / no change)
			section = section of code to be profiled
	
	***************************************************************************/

	static R checkAssert ( R, T... ) ( char[] name, R delegate ( T ) section, Expect expect = Expect.DontCare  )
	{
		static if ( is ( R == void ) )
		{
			auto before = checkUsage();
			section();
			assertSectionUsage(name, before, expect);
			return;
		}
		else
		{
			auto before = checkUsage();
			R r = section();
			assertSectionUsage(name, before, expect);
			return r;
		}
	}


	/***************************************************************************

		Checks the memory usage before and after a section of code. Displays a
		message to Trace if the expected condition is not true.
	
		Params:
			name = section name
			expect = expected memory usage (grow / shrink / no change)
			before = mem usage before
			after = mem usage after
	
	***************************************************************************/

	static void checkCondition ( char[] name, Expect expect, double before, double after )
	{
		switch ( expect )
		{
			case Expect.NoChange:
				if ( before != after )
				{
					Trace.formatln("({}) mem usage: {} -> {} (changed by {})", name, before, after, after - before);
				}
			break;
			case Expect.MemGrow:
				if ( before >= after )
				{
					Trace.formatln("({}) mem usage: {} -> {} (shrunk by {})", name, before, after, after - before);
				}
			break;
			case Expect.MemShrink:
				if ( before <= after )
				{
					Trace.formatln("({}) mem usage: {} -> {} (changed by {})", name, before, after, after - before);
				}
			break;
			default:
			case Expect.DontCare:
				Trace.formatln("({}) mem usage: {} -> {} (changed by {})", name, before, after, after - before);
			break;
			break;
		}
	}


	/***************************************************************************

		Checks the memory usage before and after a section of code. Asserts if
		the expected condition is not true.
	
		Params:
			name = section name
			expect = expected memory usage (grow / shrink / no change)
			before = mem usage before
			after = mem usage after
	
	***************************************************************************/
	
	static void assertCondition ( char[] name, Expect expect, double before, double after )
	{
		switch ( expect )
		{
			case Expect.NoChange:
				assert(before == after, name ~ " expected no change in memory usage");
			break;
			case Expect.MemGrow:
				assert(before < after, name ~ " expected growth in memory usage");
			break;
			case Expect.MemShrink:
				assert(before > after, name ~ " expected shrink in memory usage");
			break;
			default:
			case Expect.DontCare:
			break;
		}
	}
}


