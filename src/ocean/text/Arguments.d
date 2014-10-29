/*******************************************************************************

    Command line arguments parser with automatic help text output

    copyright:      Copyright (c) 2010-2012 sociomantic labs. All rights reserved

    version:        October 2010: Initial release

    authors:        Gavin Norman, Leandro Lucarella

    See tango.text.Arguments - this class just adds a single public method to
    the interface of that class.

    Usage example:

    ---

        void main ( char[][] cmdl )
        {
            // Parse command line args
            scope args = new Arguments(cmdl[0],
                    "Test ocean's Arguments parser",
                    "{0} [OPTIONS]",
                    "This program test the ocean's Argument parser. It takes "
                    "no positional arguments but can take several options.");

            args("help").aliased('?').aliased('h').help("display this help");
            args("start").aliased('s').help("start of range to query (hash value - defaults to 0x00000000)");
            args("end").aliased('e').help("end of range to query (hash value - defaults to 0xFFFFFFFF)");
            args("channel").aliased('c').help("channel name to query");
            args("all_channels").aliased('A').help("query all channels");

            args.parse(cmdl[1..$]);

            args.displayHelp(Stdout);
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

import Tango = tango.text.Arguments;

import tango.io.Stdout;

import tango.math.Math : max;

import Integer = tango.text.convert.Integer;




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

        Application's name to use in help messages.

    ***************************************************************************/

    public char[] name;


    /***************************************************************************

        Application's short usage description (as a format string).

        This is used as a format string to print the usage, the first argument
        is the program's name. This string should describe how to invoke the
        program.

        If you use multiple-line usage, it's better to start following lines
        with a tab (\t).

        Examples:

        ---
        args.usage = "{0} [OPTIONS] SOMETHING FILE";
        args.usage = "{0} [OPTIONS] SOMETHING FILE\n"
                     "\t{0} --version";
        ---

    ***************************************************************************/

    public char[] usage = "{0} [OPTIONS] [ARGS]";


    /***************************************************************************

        One line description of what the program does (as a format string).

        This is used as a format string to print a short description of what the
        program does. The first argument is the program's name (but you usually
        shouldn't use it here).

    ***************************************************************************/

    public char[] desc;


    /***************************************************************************

        Long description about the program and how to use it (as a format
        string).

        This is used as a format string to print a long description of what the
        program does and how to use it. The first argument is the program's
        name.

    ***************************************************************************/

    public char[] help;


    /***************************************************************************

        Initializes the Arguments

        Params:
            name = Name of the application (to show in the help message)
            desc = Short description of what the program does (should be
                         one line only, preferably less than 80 characters)
            usage = How the program is supposed to be invoked
            help = Long description of what the program does and how to use it

    ***************************************************************************/

    public this ( char[] app_name = null, char[] desc = null,
            char[] usage = null, char[] help = null )
    {
        this.name = app_name;
        this.desc = desc;
        if (usage != "")
            this.usage = usage;
        this.help = help;
    }


    /***************************************************************************

        Displays the help text for all arguments which have such defined.

        Params:
            output = stream where to print the errors (Stderr by default)

    ***************************************************************************/

    public void displayHelp ( typeof(Stderr) output = Stderr )
    {
        if (this.desc != "")
        {
            output.formatln(this.desc, this.name);
            output.newline;
        }

        output.formatln("Usage:\t" ~ this.usage, this.name);
        output.newline;

        if (this.help != "")
        {
            output.formatln(this.help, this.name);
            output.newline;
        }

        foreach (arg; super)
        {
            this.calculateSpacing(arg);
        }

        output.formatln("Program options:");

        foreach (arg; super)
        {
            this.displayArgumentHelp(arg, output);
        }

        output.newline;
    }


    /***************************************************************************

        Displays the help text for all arguments which have such defined.

        Params:
            app_name = name of application
            output = stream where to print the errors (Stderr by default)

    ***************************************************************************/

    deprecated public void displayHelp ( char[] app_name,
            typeof(Stderr) output = Stderr )
    {
        this.name = app_name;
        this.displayHelp(output);
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

        // there is no trailing ", " in this case, so add two spaces instead.
        if (arg.aliases.length == 0)
        {
            output.format("  ");
        }

        output.format("{}", this.space(this.aliases_width -
                    this.aliasesWidth(arg.aliases.length)));
        output.format("--{}{}  ", arg.name, this.space(this.long_name_width - arg.name.length));
        output.format("{}", arg.text);

        uint extras;
        if ( arg.options.length )  extras++;
        if ( arg.deefalts.length ) extras++;
        if ( extras )
        {
            output.format(" (");

            if ( arg.options.length )
            {
                output.format("{}", arg.options);

                // comma separate if more info to come
                extras--;
                if ( extras )
                {
                    output.format(", ");
                }
            }

            if ( arg.deefalts.length )
            {
                output.format("default: {}", arg.deefalts);
            }

            output.format(")");
        }
        output.newline.flush;
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

