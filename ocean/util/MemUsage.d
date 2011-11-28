/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        November 2011: Initial release

    author:         Gavin Norman

    Simple helper classes for tracking memory allocations in section of code.

    The scope classes are designed so that they track the memory allocation
    difference between the point at which they are instantiated and the point at
    which they are destroyed (i.e. upon the scope exiting).

    Usage example:

    ---

        import ocean.util.MemUsage;
        import tango.io.Stdout;

        // Demonstrates how to use the two scope classes defined in this module.
        // In this example they both produce exactly the same result.

        // Printing version (outputs difference to specified output, default is
        // Stderr)
        {
            scope m = new PrintMemUsage("something", Stderr);
            // Code that we're interested in profiling
        }

        // Flexible version (do what you like with the result)
        {
            scope m = new MemUsage((int diff) { Stderr.formatln("something allocated {}b", diff);  });
            // Code that we're interested in profiling
        }

    ---

    Build:

    Requires the -version=CDGC flag

*******************************************************************************/

module ocean.util.MemUsage;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.io.Stdout;

private import tango.core.Memory;



version ( CDGC )
{
    /***************************************************************************

        Basic mem usage tracker, passes memory difference to a delegate.

    ***************************************************************************/

    public scope class MemUsage
    {
        /***********************************************************************

            Bytes used when instance was constructed.

        ***********************************************************************/

        private size_t used;


        /***********************************************************************

            Delegate to pass memory usage difference to.

        ***********************************************************************/

        private void delegate ( int ) dg;


        /***********************************************************************

            Constructor. Stores the current memory usage.

            Params:
                dg = delegate to pass memory usage difference to

        ***********************************************************************/

        public this ( void delegate ( int ) dg )
        in
        {
            assert(dg !is null, typeof(this).stringof ~ ".ctor: output delegate is null");
        }
        body
        {
            this.dg = dg;
    
            size_t free;
            GC.usage(this.used, free);
        }


        /***********************************************************************

            Destructor. Calculates the difference in memory usage and passes it
            to the provided delegate.

        ***********************************************************************/

        ~this ( )
        {
            size_t new_used, free;
            GC.usage(new_used, free);

            this.dg(new_used - this.used);
        }
    }



    /***************************************************************************

        Printing mem usage tracker, prints memory difference to an output.

    ***************************************************************************/

    public scope class PrintMemUsage : MemUsage
    {
        /***********************************************************************

            Identifier string to display with output. Set in constructor.

        ***********************************************************************/

        private const char[] name;


        /***********************************************************************

            Output stream to use. Set in constructor.

        ***********************************************************************/

        private const typeof(Stdout) output;


        /***********************************************************************

            Constructor.

            Params:
                name = identifier string to display output
                output = output stream to write to

        ***********************************************************************/

        public this ( char[] name, typeof(Stdout) output = Stderr )
        {
            this.name = name;
            this.output = output;

            super(&this.outputDg);
        }


        /***********************************************************************

            Called from the super class destructor. Outputs the memory usage
            difference to the specified stream.

        ***********************************************************************/

        private void outputDg ( int diff )
        {
            this.output.formatln("{} allocated {}b", this.name, diff);
        }
    }
}
else
{
    static assert(false, "MemUsage only works with version=CDGC");
}

