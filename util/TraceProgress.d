/*******************************************************************************

	Progress tracing class.

	copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

	version:        Apr 2010: Initial release

	authors:        Gavin Norman

	Progress tracing class which send progress messages to Trace and TraceLog.
	Progress can be displayed in terms of "iterations completed" or in terms of
	"percentage completed", and can be displayed to either or both Trace &/
	TraceLog.
	
	The message output can be set to take place every X iterations (called one
	"interval").

	The output can be set to show either the total cumulative progress, or the
	(incremental) progress per interval.

	Console output can be set to either static or streaming mode. Streaming mode
	outputs a new line of information each interval. Static mode progerssively
	erases and re-writes the same line of text (using \b characters sent to the
	console).
	
	The time (in seconds) per interval can optionally be displayed.

	An optionl "work done" value can be displayed, which is passed to the Tracer
	object each iteration. This value can be used to keep track of the amount of
	work done per interval, in terms of quantities like chars, Kb, documents,
	etc.

	The default output is to the log file only, and shows the count of
	iterations completed.


	Example usage 1 - Displays progress to the log file as a percentage of the
	total once per iteration:

		uint max = 1000;
		scope progress = Tracer(Tracer.Title("test"), Tracer.Percentage(max));
		for ( int i = 0; i < max; i++ )
		{
			// Do stuff...

			progress.tick();
		}
		progress.finished();


	Example usage 2: Displays progress to the log file once per iteration, and
	also to the console as a dynamically updated (over-written) line of text:

		scope progress = Tracer(Tracer.Title("test), Tracer.ConsoleStatic());
		foreach ( val; data_source )
		{
			// Do stuff...

			progress.tick();
		}
		progress.finished();


	Example usage 3: Displays progress to the log file once per 1000 iterations,
	and	also to the console as a dynamically updated (over-written) line of
	text. The total time taken is also displayed:

		scope progress = Tracer(Tracer.Title("test), Tracer.ConsoleStatic(),
			Tracer.Interval(1000), Tracer.Time());
		foreach ( val; data_source )
		{
			// Do stuff...

			progress.tick();
		}
		progress.finished();

    
	Example usage 4: Displays incremental progress to the log file once per 1000
	iterations,	and	also to the console as streaming lines of text. The time per
	interval (1000 iterations) is displayed, along with the number of bytes
	processed per interval:

		scope progress = Tracer(Tracer.Title("test), Tracer.IncConsoleStreaming(),
			Tracer.Interval(1000), Tracer.Time(), Tracer.WorkDone("bytes"));
		foreach ( val; data_source )
		{
			// Do stuff...
			uint bytes_processed = some_value;

			progress.tick(bytes_processed);
		}
		progress.finished();
    
*******************************************************************************/

module src.core.TraceProgress;



/*******************************************************************************

	Imports

*******************************************************************************/

private import tango.util.log.Trace;

private import ocean.util.TraceLog;

private import tango.time.StopWatch;

private import tango.text.convert.Format;



/*******************************************************************************

	Tracer class.

*******************************************************************************/

public class Tracer
{
	/***************************************************************************

		Enum : determines what kind of output the tracer should produce:

			Off = none.
			Total = cumulative progress.
			Incremental = progress per interval.

	***************************************************************************/

	public enum DisplayMode
	{
		Off,
		Total,
		Incremental
	}


	/***************************************************************************

		Struct representing a single quantity which the Tracer is counting.
		
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
			
			Also sets the last_displayed property to = the current property,
			meaning that the counter starts counting the next interval.

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
						str ~= Format(" - {} {}", value, this.title);
						break;

					case DisplayMode.Divided:
						str ~= Format(" - {} {}", cast(float) value / this.float_div, this.title);
						break;

					case DisplayMode.Percentage:
						float progress = cast(float) value / cast(float) this.percentage_max;
						uint progress_percent = cast(uint)(progress * 100);
						str ~= Format(" - {}% {}", progress_percent, this.title);
						break;

					default:
						break;
				}

				// Start counting from the next interval
				this.last_displayed = this.current;
			}
		}
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

		Protected property : stopwatch used for time tracking
	
	***************************************************************************/

	protected StopWatch timer;


	/***************************************************************************

		Protected property : display a progress message after this many
		iterations
	
	***************************************************************************/

	protected uint interval_size = 1;


	/***************************************************************************

		Protected property : the title of this tracer, for message display

	***************************************************************************/

	protected char[] title;


	/***************************************************************************

		Protected property : a char buffer, used for message formatting
	
	***************************************************************************/

	protected char[] str;


	/***************************************************************************

		Protected property : a char buffer, used for static display on the
		console (filled with backspace characters)
	
	***************************************************************************/

	protected char[] backspace_str;


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

		Protected property : log output mode
	
	***************************************************************************/

	protected DisplayMode log_display = DisplayMode.Incremental;


	/***************************************************************************

		Struct to pass a title into the Tracer's constructor.
	
	***************************************************************************/
	
	public struct Name
	{
		char[] name;
	}
	
	
	/***************************************************************************
	
		Struct to pass an interval size (ie how many iterations between message
		updates) into the Tracer's constructor.
	
	***************************************************************************/
	
	public struct Interval
	{
		uint interval = 1;
	}
	
	
	/***************************************************************************
	
		Struct to specify a static console output setup into the Tracer's
		constructor.
		
		If the max_iterations property is set, the counter display is set to
		percentage mode.
	
	***************************************************************************/
	
	public struct ConsoleStatic
	{
		uint max_iteration = 0;
	}
	
	
	/***************************************************************************
	
		Struct to specify a streaming  console output setup into the Tracer's
		constructor.
		
		If the max_iterations property is set, the counter display is set to
		percentage mode.
	
	***************************************************************************/
	
	public struct ConsoleStreaming
	{
		uint max_iteration = 0;
	}
	
	
	/***************************************************************************
	
		Struct to specify an incremental static console output setup into the
		Tracer's constructor.
		
		If the max_iterations property is set, the counter display is set to
		percentage mode.
	
	***************************************************************************/
	
	public struct IncConsoleStatic
	{
		uint max_iteration = 0;
	}
	
	
	/***************************************************************************
	
		Struct to specify an incremental streaming console output setup into the
		Tracer's constructor.
		
		If the max_iterations property is set, the counter display is set to
		percentage mode.
	
	***************************************************************************/
	
	public struct IncConsoleStreaming
	{
		uint max_iteration = 0;
	}
	
	
	/***************************************************************************
	
		Struct to specify time display setup to the Tracer's constructor.
	
	***************************************************************************/
	
	public struct Time
	{
		// Required to avoid segmentation faults when incrementing _agrptr
		uint dummy;
	}

	
	/***************************************************************************

		Struct to specify percentage iterations display to the Tracer's
		constructor.

		The max_iteration property specifies the 100% value.

	***************************************************************************/
	
	public struct Percentage
	{
		uint max_iteration;
	}
	

	/***************************************************************************
	
		Struct to pass work done setup info to the Tracer's constructor.
		
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
			ConsoleStatic = sets static console display mode
			ConsoleStreaming = sets streaming console display mode
			IncConsoleStatic = sets incremental static console display mode
			IncConsoleStreaming = sets incremental streaming console display mode
			Percentage = sets percentage disply mode of the count property.

		Any other arguments cause an assert.

		The constructor also initialises the timer and the internal counters.

		(The constructor has been coded this way to allow a variable list of
		parameters to be passed in any order, without the confusion of having a
		huge number of different constructors.)

		Params:
			variadic, see above
			
	***************************************************************************/

	public this ( ... )
	{
		// Start the timer
		this.timer.start();

		// Always show the iteration counter
		this.count.title = "iterations";
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
			else if ( _arguments[i] == typeid(ConsoleStatic) )
			{
				this.interpretConsoleStaticArg(_argptr);
			}
			else if ( _arguments[i] == typeid(ConsoleStreaming) )
			{
				this.interpretConsoleStreamingArg(_argptr);
			}
			else if ( _arguments[i] == typeid(IncConsoleStatic) )
			{
				this.interpretIncConsoleStaticArg(_argptr);
			}
			else if ( _arguments[i] == typeid(IncConsoleStreaming) )
			{
				this.interpretIncConsoleStreamingArg(_argptr);
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
				Trace.formatln("Invalid argument in Tracer constructor.");
				assert(false, "Invalid argument in Tracer constructor.");
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
	
		Sets the tracer's console streaming mode (see StreamMode enum).
		
		Params:
			stream = the stream mode to set
			
		Returns:
			void
	
	***************************************************************************/

	public void setConsoleStreaming ( bool stream )
	{
		this.console_streaming = stream;
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
		title = _title.dup;
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

	public void showTime ( )
	{
		this.time.title = "secs";
		this.time.displayAsDivided(1000000);
	}


	/***************************************************************************

		Activates the display of work done.
		
		Params:
			void
	
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
			void
	
		Returns:
			void
	
	***************************************************************************/
	
	public void showWorkDone ( char[] _work_done_title, float div )
	{
		this.work_done.displayAsDivided(div);
		this.work_done.title = _work_done_title.dup;
	}


	/***************************************************************************

		Sets the iterations progress to display as a percentage of the total.
		
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
	
		Finishes the trace. Displays a finished message and resets the counters.
		
		Params:
			void
	
		Returns:
			void
	
	***************************************************************************/

	public void finished ( )
	{
		getTotalProgress(this.str);
		this.str ~= " - finished\n";

		writeToConsole(this.str);
		writeToLog(this.str);
		
		this.resetCounters();
	}


	/***************************************************************************

		Sets the Tracer's title based on a Name argument from a variadic
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

		Sets the Tracer's interval size based on an Interval argument from a
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

		Sets the Tracer's console display mode based on a ConsoleStatic
		argument from a variadic arguments list.
		
		Params:
			arg_ptr = a variadic args pointer which is shifted on to the next
				argument after this argument is interpreted
	
		Returns:
			void
	
	***************************************************************************/

	protected void interpretConsoleStaticArg( ref void* arg_ptr )
	{
		ConsoleStatic console = *cast(ConsoleStatic*) arg_ptr;

		this.setConsoleDisplayMode(DisplayMode.Total);
		this.setConsoleStreaming(false);
		this.showIterationsAsPercentage(console.max_iteration);

		arg_ptr += ConsoleStatic.sizeof;
	}


	/***************************************************************************

		Sets the Tracer's console display mode based on a ConsoleStreaming
		argument from a variadic arguments list.
		
		Params:
			arg_ptr = a variadic args pointer which is shifted on to the next
				argument after this argument is interpreted
	
		Returns:
			void
	
	***************************************************************************/

	protected void interpretConsoleStreamingArg( ref void* arg_ptr )
	{
		ConsoleStreaming console = *cast(ConsoleStreaming*) arg_ptr;

		this.setConsoleDisplayMode(DisplayMode.Total);
		this.setConsoleStreaming(true);
		this.showIterationsAsPercentage(console.max_iteration);

		arg_ptr += ConsoleStreaming.sizeof;
	}


	/***************************************************************************

		Sets the Tracer's console display mode based on an IncConsoleStatic
		argument from a variadic arguments list.
		
		Params:
			arg_ptr = a variadic args pointer which is shifted on to the next
				argument after this argument is interpreted
	
		Returns:
			void
	
	***************************************************************************/

	protected void interpretIncConsoleStaticArg( ref void* arg_ptr )
	{
		IncConsoleStatic console = *cast(IncConsoleStatic*) arg_ptr;

		this.setConsoleDisplayMode(DisplayMode.Incremental);
		this.setConsoleStreaming(false);
		this.showIterationsAsPercentage(console.max_iteration);

		arg_ptr += IncConsoleStatic.sizeof;
	}

	
	/***************************************************************************

		Sets the Tracer's console display mode based on a IncConsoleStreaming
		argument from a variadic arguments list.
		
		Params:
			arg_ptr = a variadic args pointer which is shifted on to the next
				argument after this argument is interpreted
	
		Returns:
			void
	
	***************************************************************************/

	protected void interpretIncConsoleStreamingArg( ref void* arg_ptr )
	{
		IncConsoleStreaming console = *cast(IncConsoleStreaming*) arg_ptr;

		this.setConsoleDisplayMode(DisplayMode.Incremental);
		this.setConsoleStreaming(true);
		this.showIterationsAsPercentage(console.max_iteration);

		arg_ptr += IncConsoleStreaming.sizeof;
	}

	
	/***************************************************************************

		Sets the Tracer's time display from a Time argument from a variadic
		arguments list.
		
		Params:
			arg_ptr = a variadic args pointer which is shifted on to the next
				argument after this argument is interpreted
	
		Returns:
			void
	
	***************************************************************************/

	protected void interpretTimeArg ( ref void* arg_ptr )
	{
		this.showTime();

		arg_ptr += Time.sizeof;
	}


	/***************************************************************************

		Sets the Tracer's iteration display to percentage mode, from a
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

		Sets the Tracer's work done display from a WorkDone argument from a
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
	
		this.time.reset(this.timer.microsec());
	}
	

	/***************************************************************************
	
		Marks the passing of an interval. Updates the timer and displays
		the progress message.
	
		Params:
			void
	
		Returns:
			void
	
	***************************************************************************/

	protected void interval ( )
	{
		if ( this.time.isActive() )
		{
			this.time.set(timer.microsec());
		}

		this.display();
	}


	/***************************************************************************

		Displays the Tracer's progress message.

		In total display mode the cumulative totals of all counters are shown.

		In incremental display mode just the progress this interval is shown.

		Params:
			void

		Returns:
			void

	***************************************************************************/

	protected void display ( )
	{
		// Total display
		if ( console_display == DisplayMode.Total || log_display == DisplayMode.Total )
		{
			this.getTotalProgress(this.str);
			if ( console_display == DisplayMode.Total )
			{
				writeToConsole(this.str);
			}
			if ( log_display == DisplayMode.Total )
			{
				writeToLog(this.str);
			}
		}

		// Incremental display
		if ( console_display == DisplayMode.Incremental || log_display == DisplayMode.Incremental )
		{
			this.getProgressThisInterval(this.str);
			if ( console_display == DisplayMode.Incremental )
			{
				writeToConsole(this.str);
			}
			if ( log_display == DisplayMode.Incremental )
			{
				writeToLog(this.str);
			}
		}
	}


	/***************************************************************************

		Writes a message to the console (unless console display is switched
		off).

		In static display mode a single (progressively overwritten) total
		progress message is shown.

		In streaming display mode each new message displays on a new line,
		resulting in a stream of incremental progress messages.
		
		Params:
			void
	
		Returns:
			void
	
	***************************************************************************/

	protected void writeToConsole ( char[] str )
	{
		if ( console_display != DisplayMode.Off && str.length > 0 )
		{
			if ( console_streaming )
			{
				Trace.format(str ~ "\n");
				Trace.flush();
			}
			else
			{
				Trace.format(str);

				this.backspace_str.length = str.length;
				this.backspace_str[0..$] = '\b';
				Trace.format(this.backspace_str);

				Trace.flush();
			}
		}
	}


	/***************************************************************************

		Writes a message to the TraceLog (unless log display is switched off).
		
		Params:
			void
	
		Returns:
			void
	
	***************************************************************************/

	protected void writeToLog ( char[] str )
	{
		if ( log_display != DisplayMode.Off && str.length > 0 )
		{
			TraceLog.write(str ~ "\n");
		}
	}


	/***************************************************************************
	
		Formats a string with a message to display the progress this interval.
	
		Params:
			str = char buffer to be written into
	
		Returns:
			void
	
	***************************************************************************/

	protected void getProgressThisInterval ( out char[] str )
	{
		str ~= this.title;

		this.count.display(str);
		this.time.display(str);
		this.work_done.display(str);

		str ~= " [this interval]";
	}


	/***************************************************************************
	
		Formats a string with a message to display the total progress.
	
		Params:
			str = char buffer to be written into
	
		Returns:
			void
	
	***************************************************************************/

	protected void getTotalProgress ( out char[] str )
	{
		str ~= this.title;
	
		this.count.displayTotal(str);
		this.time.displayTotal(str);
		this.work_done.displayTotal(str);

		str ~= " [total]";
	}
}

