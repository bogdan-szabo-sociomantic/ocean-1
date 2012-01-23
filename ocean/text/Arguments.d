/*******************************************************************************

    Command line arguments parser with automatic help text output

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        October 2010: Initial release
    
    authors:        Gavin Norman

    See tango.text.Arguments - this class just adds a single public method to
    the interface of that class.

    Usage example:

    ---
    
        void main ( char[][] cmdl )
        {
            auto app_name = cmdl[0];
        
            // Parse command line args
            scope args = new Arguments();
            args.parse(cmdl[1..$]);
        
            args("help").aliased('?').aliased('h').help("display this help");
            args("start").aliased('s').help("start of range to query (hash value - defaults to 0x00000000)");
            args("end").aliased('e').help("end of range to query (hash value - defaults to 0xFFFFFFFF)");
            args("channel").aliased('c').help("channel name to query");
            args("all_channels").aliased('A').help("query all channels");
        
            args.displayHelp(app_name);
        }
    
    ---

    Running the above code writes the following to Stderr:
    
     ./NAME command line arguments:
       -s,     --start         start of range to query (hash value - defaults to 0x00000000)
       -e,     --end           end of range to query (hash value - defaults to 0xFFFFFFFF)
       -h, -?, --help          display this help
       -c,     --channel       channel name to query
       -A,     --all_channels  query all channels

*******************************************************************************/

module ocean.text.Arguments;



/*******************************************************************************

    Imports

*******************************************************************************/

private import Tango = tango.text.Arguments;

private import tango.io.Stdout;

private import tango.math.Math : max;

private import Integer = tango.text.convert.Integer;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Arguments class.

    Derives from tango.text.Arguments, and adds a displayHelp() method.

*******************************************************************************/

class Arguments : Tango.Arguments
{
    /***************************************************************************

        Internal string used for spacing of help output.
    
    ***************************************************************************/
    
    private char[] spaces;

    
    /***************************************************************************

        Maximum text width of argument aliases.
    
    ***************************************************************************/

    private uint aliases_width;
    
    
    /***************************************************************************

        Maximum text width of argument long name.
    
    ***************************************************************************/

    private uint long_name_width;
    
    
    /***************************************************************************

        Displays the help text for all arguments which have such defined.
        
        Params:
            app_name = name of application
            output = stream where to print the errors (Stderr by default)
    
    ***************************************************************************/

    public void displayHelp ( char[] app_name, typeof(Stderr) output = Stderr )
    {
        foreach (arg; super)
        {
            this.calculateSpacing(arg);
        }

        output.format("\n{} command line arguments:\n", app_name);

        foreach (arg; super)
        {
            this.displayArgumentHelp(arg, output);
        }

        output.format("\n");
    }

    
    /***************************************************************************

        Displays any errors that happened

        Params:
            output = stream where to print the errors (Stderr by default)
    
    ***************************************************************************/

    public void displayErrors ( typeof(Stderr) output = Stderr )
    {
        output(this.errors(&output.layout.sprint));
    }
    
    
    /***************************************************************************

        Convenience method to get the value of a bool argument.

        This method is aliased as 'exists', as it has the same logic.
        
        Params:
            name = name of argument
        
        Returns:
            true if the argument is set
    
    ***************************************************************************/

    public bool getBool( char[] name )
    {
        auto arg = this.get(name);
        if ( arg )
        {
            return arg.set;
        }
        else
        {
            return false;
        }
    }

    public alias getBool exists;


    /***************************************************************************

        Convenience method to get the value of an integer argument.

        Template params:
            T = type of integer to return
        
        Params:
            name = name of argument
        
        Returns:
            integer conversion of argument value
            
    ***************************************************************************/

    public T getInt ( T ) ( char[] name )
    {
        auto arg = this.get(name);
        char[] value;

        if ( arg && arg.assigned.length == 1)
        {
            if ( arg.assigned.length )
            {
                value = arg.assigned[0];
            }
        }

        return Integer.toLong(value);
    }


    /***************************************************************************

        Convenience method to get the value of a string argument.
    
        Params:
            name = name of argument
        
        Returns:
            argument value
            
    ***************************************************************************/

    public char[] getString ( char[] name )
    {
        auto arg = this.get(name);
        char[] value;

        if ( arg && arg.assigned.length == 1)
        {
            if ( arg.assigned.length )
            {
                value = arg.assigned[0];
            }
        }
        
        return value;
    }

    
    /***************************************************************************

        Calculates the display width of the passes aliases list. (Each alias is
        a single character in the array.)
        
        Params:
            aliases = amount of argument aliases
            
        Returns:
            display width of aliases
    
    ***************************************************************************/

    private uint aliasesWidth ( size_t aliases )
    {
        auto width = aliases * 2; // *2 for a '-' before each alias
        if ( aliases > 1 )
        {
            width += (aliases - 1) * 2; // ', ' after each alias except the last
        }

        return width;
    }
    
    
    /***************************************************************************

        Delegate for the super.help method which displays nothing, but updates
        the internal maximum counters for the width of the received argument
        aliases and long names.
        
        Params:
            long_name = argument long name
            aliases = argument aliases
            help = argument help text (ignored)
    
    ***************************************************************************/

    private void calculateSpacing ( Argument arg ) //char[] long_name, char[] aliases, char[] help )
    {
        this.long_name_width = max(this.long_name_width, arg.name.length);
        this.aliases_width = max(this.aliases_width,
                this.aliasesWidth(arg.aliases.length));
    }
    
    
    /***************************************************************************

        Delegate for the super.help method which displays help text for an
        argument.
        
        Params:
            arg = argument to print
            output = stream where to print the errors (Stderr by default)
    
    ***************************************************************************/

    private void displayArgumentHelp ( Argument arg,
            typeof(Stderr) output = Stderr )
    {
        if ( arg.text.length == 0 ) return;
        
        output.format("  ");
        foreach ( i, al; arg.aliases )
        {
            output.format("-{}", al);
            if ( i != arg.aliases.length - 1 || arg.name.length )
            {
                output.format(", ");
            }
        }

        // there is no triling ", " in this case, so add two spaces instead.
        if (arg.aliases.length == 0)
        {
            output.format("  ");
        }

        output.format("{}", this.space(this.aliases_width -
                    this.aliasesWidth(arg.aliases.length)));
        output.format("--{}{}  ", arg.name, this.space(this.long_name_width - arg.name.length));
        output.formatln("{}", arg.text);
    }

    
    /***************************************************************************

        Creates a string with the specified number of spaces.
        
        Params:
            width = desired number of spaces

        Returns:
            string with desired number of spaces.
    
    ***************************************************************************/

    private char[] space ( uint width )
    {
        this.spaces.length = width;
        if ( width > 0 )
        {
            this.spaces[0..$] = ' ';
        }

        return this.spaces;
    }
}

