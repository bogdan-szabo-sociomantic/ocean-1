/*******************************************************************************
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        May 2010: Initial release

    author:         Gavin Norman

    Provides a simple means of profiling the time and memory usage taken to
    execute sections of code and display output to Trace telling how long each
    recorded section took, and the total of all sections.
    
    The output frequency of the profiler can be limited using the
    setDisplayUpdateInterval method.

    Usage:
       
    ---
        
        import ocean.util.Profiler;
        
        Profiler.instance().timeSection("section1", {
        	// Code that does something
        });

        Profiler.instance().timeSection("section2", {
        	// Code that does something else
        });

        Profiler.instance().display();

    ---

	The Profiler can also be used to time and display the *average* time taken
	by timed sections over a series of runs. Note that the averages are only
	updated when the displayAverages function is called, not when display is
	called.
	
	Averages example:

    ---
        
        import ocean.util.Profiler;
        
        Profiler.instance().timeSection("section1", {
        	// Code that does something
        });

        Profiler.instance().timeSection("section2", {
        	// Code that does something else
        });

        Profiler.instance().displayAverages(Profiler.Time.Secs);

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

*******************************************************************************/

module ocean.util.Profiler;



/*******************************************************************************

	Imports

*******************************************************************************/

private import tango.util.log.Trace;

private import ocean.util.TraceProgress;

private import Float = tango.text.convert.Float;

private import tango.core.Memory;



/*******************************************************************************

	Profiler struct

*******************************************************************************/

struct Profiler
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
			str ~= name ~ ": " ~ Float.toString(time / this.div[timemode]) ~ this.name[timemode];
    	}
    }


    /***************************************************************************

		Convenience alias for ease of externally accessing the time modes.

	***************************************************************************/

	alias TimeDisplay.TimeMode Time;


    /***************************************************************************

		Console tracer, including timer

	***************************************************************************/

    ConsoleTracer tracer;

    
    /***************************************************************************

		Display buffer, used repeatedly

    ***************************************************************************/

    char[] buf;


	/***************************************************************************

		List of section start times - associative array, indexed by section name
	
	***************************************************************************/

    ulong[char[]] section_start;

    
	/***************************************************************************

		List of section end times - associative array, indexed by section name
	
	***************************************************************************/

    ulong[char[]] section_end;


	/***************************************************************************

		List of average section times - associative array, indexed by section
		name

	***************************************************************************/
	
    float[char[]] section_avg_time;


	/***************************************************************************

		List of the number of times a section has been times - associative array,
		indexed by section name

	 ***************************************************************************/

    uint[char[]] section_avg_count;


	/***************************************************************************

		Starts timing a section of code.
		
		Params:
			name = section name
	
	***************************************************************************/

    void startSection ( char[] name )
	{
    	if ( !(name in this.section_start) )
    	{
    		this.section_start[name] = 0;
    	}
    	ulong* start = &this.section_start[name];
		*start = this.tracer.timer.microsec();
	}

    
	/***************************************************************************

		Stops timing a section of code.
		
		Params:
			name = section name
	
	***************************************************************************/

    void endSection ( char[] name )
	{
    	ulong end = this.tracer.timer.microsec();
		this.section_end[name] = end;
	}


    void setDisplayUpdateInterval ( ulong micro_secs )
    {
    	this.tracer.update_interval = micro_secs;
    }


	/***************************************************************************

		Displays the times taken by all timed sections, as well as the total
		time taken by all timed sections.
		
		Params:
			time = display mode (secs, msecs, Usecs)
			streaming = streaming display
		
	***************************************************************************/

    void display ( Time time = Time.MSecs, bool streaming = true )
    {
    	this._display!(uint)("", &this.getElapsed, time, streaming);
    }


	/***************************************************************************

		Calculates and displays the average times taken by all timed sections
		over the current and each previous run, as well as the average total
		time taken by all timed sections.
		
		Params:
			time = display mode (secs, msecs, Usecs)
			streaming = streaming display
		
	***************************************************************************/

    void displayAverages ( Time time = Time.MSecs, bool streaming = true )
    {
    	this._display!(float)("[AVG] ", &this.getAverage, time, streaming);
    }


	/***************************************************************************

		If it's time to update the display, displays the times for all timed
		sections.
		
		Params:
			prefix = string displayed before the times list
			dg = delegate to return the value to display for each individual
				section's time
			time = display mode (secs, msecs, Usecs)
			streaming = streaming display
		
	***************************************************************************/

    void _display ( T : real ) ( char[] prefix, T delegate ( char[], uint ) dg, Time time, bool streaming )
    {
    	if ( this.tracer.timeToUpdate() )
    	{
    		this.buf.length = 0;
    		this.buf ~= prefix;

			T total = 0;
	    	foreach ( name, start; this.section_start )
	    	{
				ulong* end_ptr = name in this.section_end;
				if ( end_ptr )
	    		{
	    			uint elapsed = *end_ptr - start;
	    			T display_time = dg(name, elapsed);
	    			total += display_time;
	    			TimeDisplay.appendTime(name, display_time, time, this.buf);
	    			this.buf ~= ' ';
	    		}
	    	}
			TimeDisplay.appendTime("| Total", total, time, this.buf);
			if ( streaming )
			{
				this.tracer.writeStreaming(this.buf);
			}
			else
			{
				this.tracer.writeStatic(this.buf);
			}
    	}
    }


	/***************************************************************************

		Delegate used by _display (above) to return the elapsed time of a
		section.
		
	***************************************************************************/

    uint getElapsed ( char[] name, uint elapsed )
    {
    	return elapsed;
    }


	/***************************************************************************

		Delegate used by _display (above) to return the average time of a
		section.
		
	***************************************************************************/

    float getAverage ( char[] name, uint elapsed )
    {
		return this.updateAverageTime(name, elapsed);
    }
    

	/***************************************************************************

		Updates the average time for a timed section.
		
		Params:
			name = name of timed section
			elapsed = duration of timed section (in microseconds)
		
		Returns:
			the new average time for the section, after updating
		
	***************************************************************************/

    float updateAverageTime ( char[] name, uint elapsed )
	{
		float* avg_ptr = name in this.section_avg_time;
		float avg = avg_ptr ? *avg_ptr : 0;

		float new_weight = 1.0;
		uint* count_ptr = name in this.section_avg_count;
		if ( count_ptr )
		{
			new_weight = 1.0 / cast(float) *count_ptr;
		}

		float new_avg = (cast(float) elapsed * new_weight) + (avg * (1.0 - new_weight));
		this.section_avg_time[name] = new_avg;
		this.section_avg_count[name]++;

		return new_avg;
	}


	/***************************************************************************

		Resets the average section times which have been recorded thusfar.
		
	***************************************************************************/

    void resetAverages ( )
	{
		foreach ( key, val; this.section_avg_time )
		{
			this.section_avg_time.remove(key);
		}
		foreach ( key, val; this.section_avg_count )
		{
			this.section_avg_count.remove(key);
		}
	}


	/***************************************************************************

		Times a section of code (usually an anonymous delegate) which is passed
		as the parameter 'section'.
		
		Params:
			name = section name
			section = section of code to be timed
	
	***************************************************************************/

    R timeSection ( R, T... ) ( char[] name, R delegate ( T ) section )
    {
    	static if ( is ( R == void ) )
    	{
	    	this.startSection(name);
	    	section();
	    	this.endSection(name);
    	}
    	else
    	{
	    	this.startSection(name);
	    	R r = section();
	    	this.endSection(name);
	    	return r;
    	}
    }


    /***************************************************************************

		Shared instance of the Profiler.
	
	***************************************************************************/

    static Profiler static_instance;


	/***************************************************************************

		Gets the shared Profiler instance.
		
	***************************************************************************/

    static public typeof(this) instance ()
    {
    	return &static_instance;
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
			auto before = GC.stats["poolSize"];
			section();
			auto after = GC.stats["poolSize"];
			checkCondition(name, expect, before, after);
			return;
		}
		else
		{
			auto before = GC.stats["poolSize"];
			R r = section();
			auto after = GC.stats["poolSize"];
			checkCondition(name, expect, before, after);
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
			auto before = GC.stats["poolSize"];
			section();
			auto after = GC.stats["poolSize"];
			checkCondition(name, expect, before, after);
			assertCondition(name, expect, before, after);
			return;
		}
		else
		{
			auto before = GC.stats["poolSize"];
			R r = section();
			auto after = GC.stats["poolSize"];
			checkCondition(name, expect, before, after);
			assertCondition(name, expect, before, after);
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


