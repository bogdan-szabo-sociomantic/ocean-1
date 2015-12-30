/*******************************************************************************

    Command line arguments parser with automatic help text output

    copyright:      Copyright (c) 2010-2012 sociomantic labs. All rights reserved

    version:        October 2010: Initial release

    authors:        Gavin Norman, Leandro Lucarella

    This module extends the 'tango.text.Arguments' module.

    Usage example:

    ---

        void main ( istring[] cmdl )
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

import tango.transition;

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

    private mstring spaces;


    /***************************************************************************

        Maximum text width of argument aliases.

    ***************************************************************************/

    private size_t aliases_width;


    /***************************************************************************

        Maximum text width of argument long name.

    ***************************************************************************/

    private size_t long_name_width;


    /***************************************************************************

        Application's name to use in help messages.

    ***************************************************************************/

    public istring name;


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

    public istring usage = "{0} [OPTIONS] [ARGS]";


    /***************************************************************************

        One line description of what the program does (as a format string).

        This is used as a format string to print a short description of what the
        program does. The first argument is the program's name (but you usually
        shouldn't use it here).

    ***************************************************************************/

    public istring desc;


    /***************************************************************************

        Long description about the program and how to use it (as a format
        string).

        This is used as a format string to print a long description of what the
        program does and how to use it. The first argument is the program's
        name.

    ***************************************************************************/

    public istring help;


    /***************************************************************************

        Initializes the Arguments

        Params:
            name = Name of the application (to show in the help message)
            desc = Short description of what the program does (should be
                         one line only, preferably less than 80 characters)
            usage = How the program is supposed to be invoked
            help = Long description of what the program does and how to use it

    ***************************************************************************/

    public this ( istring app_name = null, istring desc = null,
            istring usage = null, istring help = null )
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

    public bool getBool ( cstring name )
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

    public T getInt ( T ) ( cstring name )
    {
        auto arg = this.get(name);
        cstring value;

        if ( arg && arg.assigned.length == 1)
        {
            if ( arg.assigned.length )
            {
                value = arg.assigned[0];
            }
        }

        auto num = Integer.toLong(value);
        enforce(num <= T.max && num >= T.min);
        return cast(T) num;
    }


    /***************************************************************************

        Convenience method to get the value of a string argument.

        Params:
            name = name of argument

        Returns:
            argument value

    ***************************************************************************/

    public istring getString ( cstring name )
    {
        auto arg = this.get(name);
        istring value;

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

    private size_t aliasesWidth ( size_t aliases )
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
            arg = the argument instance

    ***************************************************************************/

    private void calculateSpacing ( Argument arg )
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
        bool params = arg.min > 0 || arg.max > 0;
        if ( params )              extras++;
        if ( arg.options.length )  extras++;
        if ( arg.deefalts.length ) extras++;
        if ( extras )
        {
            // comma separate sections if more info to come
            void next ( )
            {
                extras--;
                if ( extras )
                {
                    output.format(", ");
                }
            }

            output.format(" (");

            if ( params )
            {
                if ( arg.min == arg.max )
                {
                    output.format("{} param{}", arg.min, arg.min == 1 ? "" : "s");
                }
                else
                {
                    output.format("{}-{} params", arg.min, arg.max);
                }
                next();
            }

            if ( arg.options.length )
            {
                output.format("{}", arg.options);
                next();
            }

            if ( arg.deefalts.length )
            {
                output.format("default: {}", arg.deefalts);
                next();
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

    private mstring space ( size_t width )
    {
        this.spaces.length = width;
        if ( width > 0 )
        {
            this.spaces[0..$] = ' ';
        }

        return this.spaces;
    }
}

