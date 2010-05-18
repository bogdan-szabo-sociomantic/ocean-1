/*******************************************************************************
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        May 2010: Initial release

    author:         Gavin Norman

    --
    
    Description:

    Provides a simple means of profiling the time taken to execute sections of
    code and display an output to Trace telling how long each recorded section
    took, and the total of all sections.
    
    --
    
    Usage:
       
    ---
        
        import ocean.util.Profiler
        
        Profiler.instance().timeSection("section1", {
        	// Code that does something
        });

        Profiler.instance().timeSection("section2", {
        	// Code that does something else
        });

        Profiler.instance().display();

    --

*******************************************************************************/

module ocean.util.Profiler;



/*******************************************************************************

	Imports

*******************************************************************************/

private import tango.util.log.Trace;

private import tango.time.StopWatch;



/*******************************************************************************

	Profiler struct

*******************************************************************************/

struct Profiler
{
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
		
	***************************************************************************/

    void display ( )
    {
		ulong total;
    	foreach ( name, start; this.section_start )
    	{
    		if ( name in section_end )
    		{
    			ulong elapsed = section_end[name] - start;
    			total += elapsed;
    			Trace.format("{}: {}ms  ", name, cast(float)elapsed / 1000.0);
    		}
    	}
		Trace.formatln("- Total: {}ms", cast(float)total / 1000.0);
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

    static Profiler instance ()
    {
    	return static_instance;
    }


	/***************************************************************************

		Static constructor. Starts the internal timer.
	
	***************************************************************************/

    static this ( )
	{
		timer.start();
	}
}

