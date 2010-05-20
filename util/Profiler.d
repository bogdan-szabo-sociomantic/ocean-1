/*******************************************************************************
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        May 2010: Initial release

    author:         Gavin Norman

    Provides a simple means of profiling the time taken to execute sections of
    code and display an output to Trace telling how long each recorded section
    took, and the total of all sections.
    
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


*******************************************************************************/

module ocean.util.Profiler;



/*******************************************************************************

	Imports

*******************************************************************************/

private import tango.util.log.Trace;

private import tango.time.StopWatch;

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

			Outputs a time to Trace, followed by a newline.
			
			Params:
				name = operation being timed
				time = time in microsecs
				timemode = display mode to use
	
	    ***********************************************************************/

		static void traceTimeNl ( char[] name, float time, TimeMode timemode )
    	{
   			Trace.formatln("{}: {}{} ", name, time / this.div[timemode], this.name[timemode]);
    	}


	    /***********************************************************************

			Outputs a time to Trace.
			
			Params:
				name = operation being timed
				time = time in microsecs
				timemode = display mode to use
	
	    ***********************************************************************/

		static void traceTime ( char[] name, float time, TimeMode timemode )
    	{
    		Trace.format("{}: {}{} ", name, time / this.div[timemode], this.name[timemode]);
    	}
    }


    /***************************************************************************

		Convenience alias for ease of externally accessing the time modes.

	***************************************************************************/

	alias TimeDisplay.TimeMode Time;


    /***************************************************************************

		Timer, shared by all instances of this struct (there's only one time!)

	***************************************************************************/

    static StopWatch timer;

    
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
		*start = timer.microsec();
	}

    
	/***************************************************************************

		Stops timing a section of code.
		
		Params:
			name = section name
	
	***************************************************************************/

    void endSection ( char[] name )
	{
    	ulong end = timer.microsec();
		this.section_end[name] = end;
	}


	/***************************************************************************

		Displays the times taken by all timed sections, as well as the total
		time taken by all timed sections.
		
		Params:
			time = display mode (secs, msecs, Usecs)
		
	***************************************************************************/

    void display ( Time time = Time.MSecs )
    {
//    	ulong mem_size = cast(ulong) GC.stats["poolSize"];

		uint total;
    	foreach ( name, start; this.section_start )
    	{
			ulong* end_ptr = name in this.section_end;
			if ( end_ptr )
    		{
    			uint elapsed = *end_ptr - start;
    			total += elapsed;
    			TimeDisplay.traceTime(name, elapsed, time);
    		}
    	}
		TimeDisplay.traceTimeNl("- Total", total, time);
//		Trace.formatln("Allocated memory: {}bytes", mem_size);
    }


	/***************************************************************************

		Calculates and displays the average times taken by all timed sections
		over the current and each previous run, as well as the average total
		time taken by all timed sections.
		
		Params:
			time = display mode (secs, msecs, Usecs)
		
	***************************************************************************/

    void displayAverages ( Time time = Time.MSecs )
	{
    	Trace.format("[AVG] ");
    	uint total;
		foreach ( name, start; this.section_start )
		{
			ulong* end_ptr = name in this.section_end;
			if ( end_ptr )
			{
				uint elapsed = *end_ptr - start;
				auto avg_time = this.updateAverageTime(name, elapsed);

				total += avg_time;
				TimeDisplay.traceTime(name, avg_time, time);
			}
		}
		TimeDisplay.traceTimeNl("- Total", total, time);
	}

    
	/***************************************************************************

		Updates the average time for a timed section.
		
		Params:
			name = name of timed section
			elapsed = duration of timed section (in microseconds)
		
		Returns:
			
		
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

		Times a section of code which is passed as the T template argument.
		(Uses D's lazy evaluation feature so that the code section is executed
		inside this function.) 
		
		Params:
			name = section name
			T = section of code to be timed
	
	***************************************************************************/

    void timeSection ( T ) ( char[] name, T section )
    {
    	this.startSection(name);
    	section();
    	this.endSection(name);
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


	/***************************************************************************

		Static constructor. Starts the internal timer.
	
	***************************************************************************/

    static this ( )
	{
		timer.start();
	}
}

