// Deprecated: use ocean.util.log.StatsLog.

/*******************************************************************************

	Progress tracing class.

	copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

	version:        Apr 2010: Initial release

	authors:        Gavin Norman

	The file contains two structs:

		ConsoleTracer: the basic struct for writing streaming / static strings
			to the console (Trace output). Includes functionality for limiting
			the frequency of display updates.

		TraceProgress: Progress tracer, described fully below. Uses the
			ConsoleTracer struct for its console output.


	Progress tracing struct which send progress messages to Trace and TraceLog.
	Progress can be displayed in terms of "iterations completed" or in terms of
	"percentage completed", and can be displayed to either or both Trace &/
	TraceLog.
	
	The message output can be set to take place every X iterations (called one
	"interval").

	The output can be set to show either the total cumulative progress, or the
	incremental progress per interval, or both.

	Console output can be set to either static or streaming mode. Streaming mode
	outputs a new line of information each interval. Static mode progressively
	erases and re-writes the same line of text (using \b characters sent to the
	console).
	
	The time (in seconds, milliseconds or microseconds) can	optionally be
	displayed.

	An optionl "work done" value can be displayed, which is passed to the TraceProgress
	object each iteration. This value can be used to keep track of the amount of
	work done per interval, in terms of quantities like chars, Kb, documents,
	etc.

	The default output is to the log file only, and shows the count of
	iterations completed.

	There's also a global instance of the TraceProgress, which can be accessed with the
	TraceProgress() static method. This is useful if multiple functions in a 
	program need to feed information into the tracer.

	Example usage 1 - Displays progress to the log file as a percentage of the
	total once per iteration:

		---

		uint max = 1000;
		TraceProgress progress;
		progress.initDisplay(TraceProgress.Name("test"), TraceProgress.Percentage(max));
		for ( int i = 0; i < max; i++ )
		{
			// Do stuff...

			progress.tick();
		}
		progress.finished();

		---


	Example usage 2: Displays progress to the log file once per iteration, and
	also to the console as a dynamically updated (over-written) line of text:

		---

		TraceProgress progress;
		progress.initDisplay(TraceProgress.Name("test), TraceProgress.ConsoleDisplay.Static,
			TraceProgress.ConsoleDisplay.All);
		foreach ( val; data_source )
		{
			// Do stuff...

			progress.tick();
		}
		progress.finished();

		---


	Example usage 3: Displays progress to the log file once per 1000 iterations,
	and	also to the console as a dynamically updated (over-written) line of
	text. The total time taken is also displayed:

		---

		TraceProgress progress;
		progress.initDisplay(TraceProgress.Name("test), TraceProgress.ConsoleDisplay.Static,
			TraceProgress.ConsoleDisplay.All, TraceProgress.Interval(1000), TraceProgress.Time.Secs);
		foreach ( val; data_source )
		{
			// Do stuff...

			progress.tick();
		}
		progress.finished();

		---

    
	Example usage 4: Displays incremental progress to the log file once per 1000
	iterations,	and	also to the console as streaming lines of text. The time per
	interval (1000 iterations) is displayed, along with the number of bytes
	processed per interval:

		---

		TraceProgress progress;
		progress.initDisplay(TraceProgress.Name("test), TraceProgress.ConsoleDisplay.Streaming,
			TraceProgress.ConsoleDisplay.PerInterval, TraceProgress.LogDisplay.PerInterval,
			TraceProgress.Interval(1000), TraceProgress.Time.Secs, TraceProgress.WorkDone("bytes"));
		foreach ( val; data_source )
		{
			// Do stuff...
			uint bytes_processed = some_value;

			progress.tick(bytes_processed);
		}
		progress.finished();

		---

*******************************************************************************/

module ocean.util.TraceProgress;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.io.SyncOut; //iutil.log.Trace;

private import ocean.util.TraceLog;

private import tango.time.StopWatch;

private import tango.text.convert.Format;



/*******************************************************************************

	ConsoleTracer class.
	

*******************************************************************************/

struct ConsoleTracer
{
    /***************************************************************************

		Timer, shared by all instances of this struct (there's only one time!)
	
	***************************************************************************/
	
	static StopWatch timer;


	/***************************************************************************

		A char buffer, used repeatedly for static display on the console
	
	***************************************************************************/
	
	char[] buf;


	/***************************************************************************

		The maximum size of string displayed to the console so far. This is
		recorded so that static displays can safely overwrite previous content.

	***************************************************************************/

	uint max_strlen;


	/***************************************************************************

		Time of last update

	***************************************************************************/

	ulong last_update_time;

	
	/***************************************************************************

		Time retrieved by last time update check

	***************************************************************************/

	ulong now;


	/***************************************************************************

		Minimum time between updates (microsec)

	***************************************************************************/

	ulong update_interval;


	/***************************************************************************

		Checks if it's time to update the display.
		
		Returns:
			true if the display update interval has passed
	
	***************************************************************************/

	bool timeToUpdate ( )
	{
		this.now = timer.microsec();
		return this.now > this.last_update_time + this.update_interval;
	}


	/***************************************************************************

		Writes a list of strings to the console if the update interval has
		passed. Static display.

		Params:
			strings = the list of strings to display

	***************************************************************************/

	void updateStatic ( char[] string )
	{
		this.updateStatic([string]);
	}

	void updateStatic ( char[][] strings )
	{
		if ( this.timeToUpdate() )
		{
			this.writeStatic(strings);
		}
	}


	/***************************************************************************

		Writes a list of strings to the console if the update interval has
		passed. Streaming display.
	
		Params:
			strings = the list of strings to display

	***************************************************************************/

	void updateStreaming ( char[] string )
	{
		this.updateStreaming([string]);
	}

	void updateStreaming ( char[][] strings )
	{
		if ( this.timeToUpdate() )
		{
			this.writeStreaming(strings);
		}
	}

	
	/***************************************************************************

		Writes a list of strings to the console.
	
		The strings are written, followed by a string of equal length filled
		with backspace characters, moving the console cursor back to the start
		of the line.
	
		In streaming display mode the strings are written, followed by a
		newline.
	
		Params:
			strings = the list of strings to display
	
	***************************************************************************/

	void writeStatic ( char[] string )
	{
		this.writeStatic([string]);
	}

	void writeStatic ( char[][] strings )
	{
		this.last_update_time = this.now;

		// Work out the total length of all the strings
		uint strings_length;
		foreach ( string; strings )
		{
			strings_length += string.length;
		}

		// Pad out with extra spaces, if the current strings are shorter than
		// the previous longest display
		if ( strings_length < max_strlen )
		{
			buf.length = max_strlen - strings_length;
			buf[0..$] = ' ';
		}
		else
		{
			max_strlen = strings_length;
			buf.length = 0;
		}

		// Write the strings followed by a backspace string of equal length
		char[][] all = strings ~ buf;
		foreach ( string; all )
		{
			if ( string.length > 0 )
			{
				Trace.format(string);
			}
		}
		this.formatBackspaceString(buf, max_strlen);
		Trace.format(buf);
		Trace.flush();
	}


	/***************************************************************************

		Writes a list of strings to the console.
	
		The strings are written, followed by a newline.
	
		Params:
			strings = the list of strings to display
	
	***************************************************************************/

	void writeStreaming ( char[] string )
	{
		this.writeStreaming([string]);
	}

	void writeStreaming ( char[][] strings )
	{
		this.last_update_time = this.now;

		for ( uint i = 0; i < strings.length - 1; i++ )
		{
			if ( strings[i].length > 0 )
			{
				Trace.format(strings[i]);
			}
		}
		Trace.formatln(strings[$ - 1]);
	}


	/***************************************************************************
	
		Formats a string with a specified number of backspace '\b' characters.
	
		Params:
			str = char buffer to be written into
			
			length = number of characters to write to the string
	
	***************************************************************************/
	
	protected void formatBackspaceString ( ref char[] str, uint length )
	{
		str.length = length;
		str[0..$] = '\b';
	}


	/***************************************************************************

		Static constructor, starts the shared timer.

	***************************************************************************/

	static this ( )
	{
		timer.start();
	}
}



/*******************************************************************************

	Progress tracer class.

*******************************************************************************/

deprecated public struct TraceProgress
{
    
    /***************************************************************************
     
        Default console update interval in microseconds. Default is 100ms
     
     **************************************************************************/
    
    private     const uint      DisplayUpdateInterval = 100000;
    
	/***************************************************************************

		Struct representing a single quantity which TraceProgress is counting.
		
		The template argument T is the type of the quantity being tracked.
	
	***************************************************************************/

	public struct Counter ( T )
	{
		/***********************************************************************

			Counter display mode enum.
			
				Off = the counter is not displayed.
				Normal = the counter's value is outputted normally.
				Divided = the counter's value is divided by a specified value
					(the float_div property) before outputting.
				Percentage = the counter's value is displayed as a percentage
					of a total (the percentage_max property).

		***********************************************************************/

		enum DisplayMode
		{
			Off,
			Normal,
			Divided,
			Percentage
		}


		/***********************************************************************

			The counter's initial value.
		
		***********************************************************************/

		T initial;


		/***********************************************************************

			The counter's current value.
	
		***********************************************************************/

		T current;

		
		/***********************************************************************

			The last value which was displayed.
	
		***********************************************************************/

		T last_displayed;


		/***********************************************************************

			The counter's title, which is displayed in messages.
	
		***********************************************************************/

		char[] title = "";

		
		/***********************************************************************

			The counter's display mode (Off, Normal, Divided, Percentage).
	
		***********************************************************************/

		DisplayMode display_mode = DisplayMode.Off;

		
		/***********************************************************************

			Display division value, for counters of Divided display mode.
	
		***********************************************************************/

		float float_div;


		/***********************************************************************

			Percentage display maximum value, for counters of Percentage display
			mode.
	
		***********************************************************************/

		T percentage_max;

		
		/***********************************************************************

			Sets display mode to off.
			
			Params:
				void
			
			Returns:
				void
	
		***********************************************************************/
	
		void displayOff ( )
		{
			this.display_mode = DisplayMode.Off;
		}
	

		/***********************************************************************

			Sets Normal display mode.
			
			Params:
				void
			
			Returns:
				void
	
		***********************************************************************/

		void displayAsNormal ( )
		{
			this.display_mode = DisplayMode.Normal;
		}


		/***********************************************************************

			Sets Percentage display mode.
			
			Params:
				max = the maximum (100%) value for the counter
			
			Returns:
				void
	
		***********************************************************************/

		void displayAsPercentage ( T max )
		{
			this.display_mode = DisplayMode.Percentage;
			this.percentage_max = max;
		}


		/***********************************************************************

			Sets Divided display mode.
			
			Params:
				div = the display divider for the counter
			
			Returns:
				void
	
		***********************************************************************/

		void displayAsDivided ( float div )
		{
			this.display_mode = DisplayMode.Divided;
			this.float_div = div;
		}


		/***********************************************************************

			Writes the counter's progress this interval into the buffer
			provided.
			
			Params:
				str = output string buffer
			
			Returns:
				void
	
		***********************************************************************/

		void display ( ref char[] str )
		{
			display_(str, this.getProgressThisInterval());
		}


		/***********************************************************************

			Writes the counter's total progress into the buffer	provided.
			
			Params:
				str = output string buffer
			
			Returns:
				void
	
		***********************************************************************/

		void displayTotal ( ref char[] str )
		{
			display_(str, this.getTotalProgress());
		}


		/***********************************************************************

			Sets the counter's current value.
			
			Params:
				value = value to set
			
			Returns:
				void
	
		***********************************************************************/

		void set ( T value )
		{
			this.current = value;
		}

		
		/***********************************************************************

			Sets the counter's current, initial and last_displayed value to be
			identical.
			
			Params:
				value = value to reset to
			
			Returns:
				void
	
		***********************************************************************/

		void reset ( T value )
		{
			this.initial = value;
			this.current = value;
			this.last_displayed = value;
		}


		/***********************************************************************

			Is this counter being displayed?

			Params:
				void

			Returns:
				bool - is the counter's display mode anything except Off?
		
		***********************************************************************/

		bool isActive ( )
		{
			return this.display_mode != DisplayMode.Off;
		}

		
		/***********************************************************************

			Returns the counter's progress this interval.
			
			Params:
				void
			
			Returns:
				T - progress this interval
	
		***********************************************************************/

		T getProgressThisInterval ( )
		{
			return this.current - this.last_displayed;
		}


		/***********************************************************************

			Returns the counter's total progress.
			
			Params:
				void
			
			Returns:
				T - total progress
	
		***********************************************************************/

		T getTotalProgress ( )
		{
			return this.current - this.initial;
		}


		/***********************************************************************

			Overloaded ++ operator. Increments the counter's current value.
			
			Params:
				void
			
			Returns:
				void
	
		***********************************************************************/

		void opPostInc ( )
		{
			this.current ++;
		}


		/***********************************************************************

			Overloaded += operator. Adds to the counter's current value.
			
			Params:
				add = value to add to the current value
			
			Returns:
				void
	
		***********************************************************************/

		void opAddAssign ( T add )
		{
			this.current += add;
		}


		/***********************************************************************

			Worker display method. Writes the passed value into the passed
			string buffer, according to the counter's display mode.
			
			Params:
				str = string buffer to be written into
				
				value = value to be written
			
			Returns:
				void
	
		***********************************************************************/

		void display_ ( ref char[] str, T value )
		{
			if ( this.display_mode != DisplayMode.Off )
			{
				switch ( this.display_mode )
				{
					case DisplayMode.Normal:
						str ~= Format("{} {} - ", value, this.title);
						break;

					case DisplayMode.Divided:
						str ~= Format("{} {} - ", cast(float) value / this.float_div, this.title);
						break;

					case DisplayMode.Percentage:
						float progress = cast(float) value / cast(float) this.percentage_max;
						uint progress_percent = cast(uint)(progress * 100);
						str ~= Format("{}% {} - ", progress_percent, this.title);
						break;

					default:
						break;
				}
			}
		}

		/***********************************************************************

			Starts the counter counting from the next interval.
			
			Params:
				void
			
			Returns:
				void
	
		***********************************************************************/
		
		void interval ( )
		{
			this.last_displayed = this.current;
		}
	}


	/***************************************************************************

		Enum : determines what kind of output the tracer should produce:
	
			Off = none.
			Total = cumulative progress.
			PerInterval = progress per interval.
			All = both cumulative and incremental display.
	
	***************************************************************************/
	
	public enum DisplayMode
	{
		Off,
		Total,
		PerInterval,
		All
	}


	/***************************************************************************

		Protected property : tracks the total number of iteration counts

	***************************************************************************/

	protected Counter!(uint) count;


	/***************************************************************************

		Protected property : tracks the total work done (this value can be used
		to represent different quantities in each application - eg: Kb or 
		documents processed).
	
	***************************************************************************/
	
	protected Counter!(ulong) work_done;


	/***************************************************************************

		Protected property : tracks the total time taken by the process

	***************************************************************************/

	protected Counter!(ulong) time;


	/***************************************************************************

		Protected property : Console tracer object, includes stopwatch
	
	***************************************************************************/

	protected ConsoleTracer console_trace;


	/***************************************************************************

		Protected property : display a progress message after this many
		iterations
	
	***************************************************************************/

	protected uint interval_size = 1;


	/***************************************************************************

		Protected property : the title of this tracer, for message display

	***************************************************************************/

	protected char[] title = "";


	/***************************************************************************

		Protected property : a char buffer, used for per interval message
		formatting
	
	***************************************************************************/

	protected char[] per_interval_str;


	/***************************************************************************

		Protected property : a char buffer, used for total message formatting
	
	***************************************************************************/
	
	protected char[] total_str;
	

	/***************************************************************************

		Protected property : console (Trace) output mode
	
	***************************************************************************/

	protected DisplayMode console_display = DisplayMode.Off;

	
	/***************************************************************************

		Protected property : is the console (Trace) streaming or static?
		(Streaming outputs a new line of text per interval, whereas static moves
		the console cursor backwards to continually overwrite a single line.)
	
	***************************************************************************/

	protected bool console_streaming = true;


	/***************************************************************************

		Protected property : should a spinner be displayed in the console
		output?
	
	***************************************************************************/
	
	protected bool spinner = false;


	/***************************************************************************

		Protected property : the progressive spinner "animation" strings
	
	***************************************************************************/

	protected static const char[][] rotor = ["| ", "/ ", "- ", "\\ "];


	/***************************************************************************

		Protected property : counter used for spinner animation
	
	***************************************************************************/

	protected uint spin_counter;


	/***************************************************************************

		Protected property : log output mode
	
	***************************************************************************/

	protected DisplayMode log_display = DisplayMode.All;


	/***************************************************************************

		Struct to pass a title into TraceProgress' constructor.
	
	***************************************************************************/
	
	public struct Name
	{
		char[] name;
	}


	/***************************************************************************
	
		Struct to pass an interval size (ie how many iterations between message
		updates) into TraceProgress' constructor.
	
	***************************************************************************/
	
	public struct Interval
	{
		uint interval = 1;
	}
	
	
	/***************************************************************************

		Enum to pass a console display mode into TraceProgress' constructor.
	
	***************************************************************************/
	
	public enum ConsoleDisplay
	{
		Off,
		Total,
		PerInterval,
		All,
		Static,
		Streaming,
		Spinner
	}


	/***************************************************************************

		Enum to pass a log display mode into TraceProgress' constructor.
	
	***************************************************************************/

	public enum LogDisplay
	{
		Off,
		Total,
		PerInterval,
		All
	}


	/***************************************************************************
	
		Enum to pass a time display mode into TraceProgress' constructor.
	
	***************************************************************************/

	public enum Time
	{
		Off,
		Secs,
		Msecs,
		Usecs
	}


	/***************************************************************************

		Struct to specify percentage iterations display to TraceProgress'
		constructor.

		The max_iteration property specifies the 100% value.

	***************************************************************************/
	
	public struct Percentage
	{
		uint max_iteration;
	}
	

	/***************************************************************************
	
		Struct to pass work done setup info to TraceProgress' constructor.
		
		The title property specifies the name of the work done quanityt being
		tracked (for example, this might be "chars" or "Kb").
		
		The div property (if > 0) sets a divider on the display of the work done
		quantity (for example if the quantity being tracked is bytes, it may be
		more convenient to display progress in terms of Kb, in which case the 
		divider should be set to 1024).
	
	***************************************************************************/
	
	public struct WorkDone
	{
		char[] title;
		float div = 0;
	}

	/***************************************************************************
		
		Constructor. Accepts a list of variadic arguments, which are checked for
		validity and interpreted one by one. Valid argument types are the
		structs defined above:

			Name = sets the tracer's title
			Time = sets time display active
			WorkDone = sets work done display active
			Interval = sets the display interval
			ConsoleDisplay = sets console output display mode
			LogDisplay = sets logoutput display mode
			Percentage = sets percentage disply mode of the count property.

		Any other arguments cause an assert.

		The constructor also initialises the timer and the internal counters.

		(The constructor has been coded this way to allow a variable list of
		parameters to be passed in any order, without the confusion of having a
		huge number of different constructors.)

		Params:
			variadic, see above
			
	***************************************************************************/

	public void initDisplay ( ... )
	{
		this.console_trace.update_interval = this.DisplayUpdateInterval; // console update 10 times a second
		
		// Always show the iteration counter
		this.count.displayAsNormal();

		// Reset the counters to their initial values
		this.resetCounters();

		// Interpret the constructor arguments
		for ( int i = 0; i < _arguments.length; i++ )
		{
			if ( _arguments[i] == typeid(Name) )
			{
				this.interpretNameArg(_argptr);
			}
			else if ( _arguments[i] == typeid(Interval) )
			{
				this.interpretIntervalArg(_argptr);
			}
			else if ( _arguments[i] == typeid(ConsoleDisplay) )
			{
				this.interpretConsoleDisplayArg(_argptr);
			}
			else if ( _arguments[i] == typeid(LogDisplay) )
			{
				this.interpretLogDisplayArg(_argptr);
			}
			else if ( _arguments[i] == typeid(WorkDone) )
			{
				this.interpretWorkDoneArg(_argptr);
			}
			else if ( _arguments[i] == typeid(Time) )
			{
				this.interpretTimeArg(_argptr);
			}
			else if ( _arguments[i] == typeid(Percentage) )
			{
				this.interpretPercentageArg(_argptr);
			}
			else
			{
				Trace.formatln("Invalid argument in TraceProgress constructor.");
				assert(false, "Invalid argument in TraceProgress constructor.");
			}
		}
	}


	/***************************************************************************
	
		Sets the tracer's console display mode (see DisplayMode enum).	
			
		Params:
			mode = the display mode to set
			
		Returns:
			void
	
	***************************************************************************/

	public void setConsoleDisplayMode ( DisplayMode mode )
	{
		this.console_display = mode;
	}


	/***************************************************************************
	
		Sets the tracer's console streaming mode.
		
		Params:
			stream = true = streaming, false = static
			
		Returns:
			void
	
	***************************************************************************/

	public void setConsoleStreaming ( bool stream )
	{
		this.console_streaming = stream;
	}


	/***************************************************************************
	
		Sets the tracer's log display mode (see DisplayMode enum).
			
		Params:
			mode = the display mode to set
			
		Returns:
			void
	
	***************************************************************************/
	
	public void setLogDisplayMode ( DisplayMode mode )
	{
		this.log_display = mode;
	}
	

	/***************************************************************************
	
		Sets the tracer's title.
		
		Params:
			_title = the title of the tracer, displayed in every progress
				message
			
		Returns:
			void
	
	***************************************************************************/

	public void setTitle ( char[] _title )
	{
		title = _title.dup ~ " | ";
	}


	/***************************************************************************
	
		Sets the message update interval.
		
		Params:
			_interval = the number of iterations between message updates
	
		Returns:
			void
	
	***************************************************************************/

	public void setInterval ( uint _interval )
	{
		this.interval_size = _interval;
	}


	/***************************************************************************

		Activates the display of time passed.
		
		Params:
			void
	
		Returns:
			void
	
	***************************************************************************/

	public void setTimeMode ( Time mode )
	{
		switch ( mode )
		{
			case Time.Off:
				this.time.displayOff();
				break;
			case Time.Secs:
				this.time.title = "s";
				this.time.displayAsDivided(1000000);
				break;
			case Time.Msecs:
				this.time.title = "ms";
				this.time.displayAsDivided(1000);
				break;
			case Time.Usecs:
				this.time.title = "Us";
				this.time.displayAsNormal();
				break;
		}
	}


	/***************************************************************************

		Activates the display of work done.
		
		Params:
			_work_done_title = the unit title of the work done (eg. Mb, chars,
			etc)
	
		Returns:
			void
	
	***************************************************************************/

	public void showWorkDone ( char[] _work_done_title )
	{
		this.work_done.displayAsNormal();
		this.work_done.title = _work_done_title.dup;
	}


	/***************************************************************************

		Activates the display of work done, and sets a divider value for it.
		
		Params:
			_work_done_title = the unit title of the work done (eg. Mb, chars,
			etc)
			
			div = divider for the units of work done
	
		Returns:
			void
	
	***************************************************************************/
	
	public void showWorkDone ( char[] _work_done_title, float div )
	{
		this.work_done.displayAsDivided(div);
		this.work_done.title = _work_done_title.dup;
	}


	/***************************************************************************

		Sets the iterations progress to display as a percentage of the total. If
		the number of iterations passed is 0, the request is meaningless and is
		ignored.
		
		Params:
			max = the total number of iterations in the process
	
		Returns:
			void
	
	***************************************************************************/

	public void showIterationsAsPercentage ( uint max )
	{
		if ( max > 0 )
		{
			this.count.displayAsPercentage(max);
		}
	}


	/***************************************************************************

		Sets the console's spinner display mode.
		
		Params:
			_spinner = true: on, false: off
	
		Returns:
			void
	
	***************************************************************************/
	
	public void showConsoleSpinner( bool _spinner )
	{
		this.spinner = _spinner;
	}
	

	/***************************************************************************
	
		Advances the tracer one iteration. The iteration counter is incremented,
		and the passing of an interval is checked.
		
		Params:
			void
	
		Returns:
			void

	***************************************************************************/

	public void tick ( )
	{
		this.count++;

		if ( this.count.getProgressThisInterval() >= this.interval_size )
		{
			interval();
		}
	}


	/***************************************************************************

		Advances the tracer one iteration. The total of work done is increased
		by the passed value.

		Params:
			_work_done = the amount of work done this tick

		Returns:
			void
	
	***************************************************************************/

	public void tick ( ulong _work_done )
	{
		this.work_done += _work_done;
		this.tick();
	}

	
	/***************************************************************************
	
		Spins the console spinner clockwise or anti-clockwise and updates the
		console display.
		
		Params:
			void
	
		Returns:
			void
	
	***************************************************************************/

	public void spin ( bool clockwise )
	{
		if ( this.spinner )
		{
	    	if ( clockwise )
	    	{
	    		this.spinClockwise();
	    	}
	    	else
	    	{
	    		this.spinAntiClockwise();
	    	}
	
			this.write(this.console_display, this.spinnerString(), "",
					this.console_streaming ? &this.console_trace.updateStreaming : &this.console_trace.updateStatic);
		}
	}


	/***************************************************************************
	
		Spins the console spinner clockwise.
		
		Params:
			void
	
		Returns:
			void
	
	***************************************************************************/

	protected void spinClockwise ( )
	{
		this.spin_counter++;
		if ( this.spin_counter == this.rotor.length )
		{
			this.spin_counter = 0;
		}
	}


	/***************************************************************************
	
		Spins the console spinner anti-clockwise.
		
		Params:
			void
	
		Returns:
			void
	
	***************************************************************************/

	public void spinAntiClockwise ( )
	{
		if ( this.spin_counter == 0 )
		{
			this.spin_counter = this.rotor.length;
		}
		this.spin_counter--;
	}


	/***************************************************************************
	
		Finishes the trace. Displays a finished message and resets the counters.
		
		Params:
			void
	
		Returns:
			void
	
	***************************************************************************/

	public void finished ( )
	{
        this.console_trace.update_interval = 0;
        
		this.updateTimer();

		this.display("finished");

		if ( this. console_display != DisplayMode.Off && !this.console_streaming )
		{
			Trace.format("\n");
		}
		
		this.resetCounters();
        
        this.console_trace.update_interval = this.DisplayUpdateInterval;
	}


	/***************************************************************************

		Sets TraceProgress' title based on a Name argument from a variadic
		arguments list.
		
		Params:
			arg_ptr = a variadic args pointer which is shifted on to the next
				argument after this argument is interpreted
	
		Returns:
			void
	
	***************************************************************************/

	protected void interpretNameArg ( ref void* arg_ptr )
	{
		Name name = *cast(Name*) arg_ptr;

		this.setTitle(name.name);

		arg_ptr += name.sizeof;
	}


	/***************************************************************************

		Sets TraceProgress' interval size based on an Interval argument from a
		variadic arguments list.
		
		Params:
			arg_ptr = a variadic args pointer which is shifted on to the next
				argument after this argument is interpreted
	
		Returns:
			void
	
	***************************************************************************/

	protected void interpretIntervalArg ( ref void* arg_ptr )
	{
		Interval interval = *cast(Interval*) arg_ptr;

		this.setInterval(interval.interval);

		arg_ptr += Interval.sizeof;
	}

	
	/***************************************************************************

		Sets TraceProgress' console display mode based on a ConsoleDisplay
		argument from a variadic arguments list.
		
		Params:
			arg_ptr = a variadic args pointer which is shifted on to the next
				argument after this argument is interpreted
	
		Returns:
			void
	
	***************************************************************************/

	protected void interpretConsoleDisplayArg( ref void* arg_ptr )
	{
		ConsoleDisplay console = *cast(ConsoleDisplay*) arg_ptr;

		switch ( console )
		{
			case ConsoleDisplay.Off:
				this.setConsoleDisplayMode(DisplayMode.Off);
				break;
			case ConsoleDisplay.Total:
				this.setConsoleDisplayMode(DisplayMode.Total);
				break;
			case ConsoleDisplay.PerInterval:
				this.setConsoleDisplayMode(DisplayMode.PerInterval);
				break;
			case ConsoleDisplay.All:
				this.setConsoleDisplayMode(DisplayMode.All);
				break;
			case ConsoleDisplay.Static:
				this.setConsoleStreaming(false);
				break;
			case ConsoleDisplay.Streaming:
				this.setConsoleStreaming(true);
				break;
			case ConsoleDisplay.Spinner:
				this.showConsoleSpinner(true);
				break;
		}

		arg_ptr += ConsoleDisplay.sizeof;
	}

	/***************************************************************************

		Sets TraceProgress' log display mode based on a LogDisplay argument from a
		variadic arguments list.
		
		Params:
			arg_ptr = a variadic args pointer which is shifted on to the next
				argument after this argument is interpreted
	
		Returns:
			void
	
	***************************************************************************/
	
	protected void interpretLogDisplayArg( ref void* arg_ptr )
	{
		LogDisplay console = *cast(LogDisplay*) arg_ptr;

		switch ( console )
		{
			case LogDisplay.Off:
				this.setLogDisplayMode(DisplayMode.Off);
				break;
			case LogDisplay.Total:
				this.setLogDisplayMode(DisplayMode.Total);
				break;
			case LogDisplay.PerInterval:
				this.setLogDisplayMode(DisplayMode.PerInterval);
				break;
			case LogDisplay.All:
				this.setLogDisplayMode(DisplayMode.All);
				break;
		}
	
		arg_ptr += LogDisplay.sizeof;
	}

	
	/***************************************************************************

		Sets TraceProgress' time display from a Time argument from a variadic
		arguments list.
		
		Params:
			arg_ptr = a variadic args pointer which is shifted on to the next
				argument after this argument is interpreted
	
		Returns:
			void
	
	***************************************************************************/

	protected void interpretTimeArg ( ref void* arg_ptr )
	{
		Time time = *cast(Time*) arg_ptr;

		this.setTimeMode(time);

		arg_ptr += Time.sizeof;
	}


	/***************************************************************************

		Sets TraceProgress' iteration display to percentage mode, from a
		Percentage argument from a variadic arguments list.
		
		Params:
			arg_ptr = a variadic args pointer which is shifted on to the next
				argument after this argument is interpreted
	
		Returns:
			void
	
	***************************************************************************/
	
	protected void interpretPercentageArg ( ref void* arg_ptr )
	{
		Percentage percentage = *cast(Percentage*) arg_ptr;

		this.showIterationsAsPercentage(percentage.max_iteration);
	
		arg_ptr += Percentage.sizeof;
	}
	

	/***************************************************************************

		Sets TraceProgress' work done display from a WorkDone argument from a
		variadic arguments list.
		
		Params:
			arg_ptr = a variadic args pointer which is shifted on to the next
				argument after this argument is interpreted
	
		Returns:
			void
	
	***************************************************************************/

	protected void interpretWorkDoneArg ( ref void* arg_ptr )
	{
		WorkDone work_done = *cast(WorkDone*) arg_ptr;

		if ( work_done.div > 0 )
		{
			this.showWorkDone(work_done.title, work_done.div);
		}
		else
		{
			this.showWorkDone(work_done.title);
		}

		arg_ptr += WorkDone.sizeof;
	}


	/***************************************************************************

		Resets all internal counters to their initial values.
	
		Params:
			void
	
		Returns:
			void
	
	***************************************************************************/
	
	protected void resetCounters ( )
	{
		this.work_done.reset(0);
	
		this.count.reset(0);
	
		this.time.reset(this.console_trace.timer.microsec());
	}
	

	/***************************************************************************
	
		Marks the passing of an interval. Updates the timer, displays the
		progress message, and tells the counters to start counting the next
		interval.
	
		Params:
			void
	
		Returns:
			void
	
	***************************************************************************/

	protected void interval ( )
	{
		this.updateTimer();

		this.display();
		
		this.count.interval();
		this.time.interval();
		this.work_done.interval();
	}


	/***************************************************************************
	 
		 Updates the timer, if it's active.
		 
		 Params:
		 	void
		 
		 Returns:
		 	void
	
	***************************************************************************/
	
	protected void updateTimer ( )
	{
		if(this.time.isActive()) {
			this.time.set(this.console_trace.timer.microsec());
		}
	}


	/***************************************************************************

		Displays TraceProgress' progress message. First the per interval and total
		messages are formatted. Then the messages are written to the console and
		the log.

		Params:
			append = string to append to the end of the messages displayed

		Returns:
			void

	***************************************************************************/

	protected void display ( char[] append = "" )
	{
		this.updateDisplayStrings();
		this.write(this.console_display, this.spinnerString(), append,
				this.console_streaming ? &this.console_trace.updateStreaming : &this.console_trace.updateStatic);
		this.write(this.log_display, "", append, &this.writeToLog);
	}


	/***************************************************************************

		Updates the internal string buffers with the latest info for this
		interval and the total progress.

		Params:
			append = string to append to the end of the messages displayed

		Returns:
			void

	***************************************************************************/

	protected void updateDisplayStrings ( )
	{
		this.formatProgressThisInterval(this.per_interval_str);
		this.formatTotalProgress(this.total_str);
	}


	/***************************************************************************

		Gets the spinner string, if it's active. Otherwise returns "".

		Returns:
			string to display for progress spinner

	***************************************************************************/

	protected char[] spinnerString ( )
	{
		return this.spinner ? this.rotor[this.spin_counter] : "";
	}

	/***************************************************************************

		Writes TraceProgress' progress message to a particular output. A list of
		strings is built up, depending on the display mode set. The strings are
		written by a delegate which is passed as a parameter.
	
		Params:
			mode = display mode (see DisplayMode enum)

			append = string to append to the end of the messages displayed
			
			write_dg = delegate to write the list of strings produced
	
		Returns:
			void
	
	***************************************************************************/

	protected void write ( DisplayMode mode, char[] prepend, char[] append, void delegate ( char[][] ) write_dg )
	{
		switch ( mode )
		{
			case DisplayMode.Off:
				break;
			case DisplayMode.Total:
				write_dg([prepend, this.title, this.total_str, append]);
				break;
			case DisplayMode.PerInterval:
				write_dg([prepend, this.title, this.per_interval_str, append]);
				break;
			case DisplayMode.All:
				const char[] spacer = "| ";
				write_dg([prepend, this.title, this.total_str, spacer, this.per_interval_str, append]);
				break;
		}
	}


	/***************************************************************************

		Writes a list of strings to the trace log, followed by a newline.
	
		Params:
			strings = the list of strings to display
	
		Returns:
			void
	
	***************************************************************************/

	protected void writeToLog ( char[][] strings )
	{
		uint strings_length;
		foreach ( string; strings )
		{
			strings_length += string.length;
		}

		if ( strings_length > 0 )
		{
			foreach ( string; strings )
			{
				TraceLog.write(string);
			}
			TraceLog.write("\n");
		}
	}


	/***************************************************************************
	
		Formats a string with a message to display the progress this interval.
	
		Params:
			str = char buffer to be written into
	
		Returns:
			void
	
	***************************************************************************/

	protected void formatProgressThisInterval ( ref char[] str )
	{
        str.length = 0;
        
		str ~= "Last Interval: ";
		this.count.display(str);
		this.time.display(str);
		this.work_done.display(str);
	}


	/***************************************************************************
	
		Formats a string with a message to display the total progress.
	
		Params:
			str = char buffer to be written into
	
		Returns:
			void
	
	***************************************************************************/

	protected void formatTotalProgress ( ref char[] str )
	{
        str.length = 0;
        
		str ~= "Total: ";
		this.count.displayTotal(str);
		this.time.displayTotal(str);
		this.work_done.displayTotal(str);
	}


	/***************************************************************************
	
		Static protected property: Global instance of this struct
	
	***************************************************************************/

	protected static TraceProgress static_instance;


	/***************************************************************************
	
		Static method: Gets the global TraceProgress instance

		Params:
			void
	
		Returns:
			global instance of this struct
	
	***************************************************************************/

	public static typeof(this) instance ( )
	{
		return &this.static_instance;
	}
}

