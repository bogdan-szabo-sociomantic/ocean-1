/*******************************************************************************

    Utility class to do more common tasks an application with unittests have to
    do.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.UnittestedApp;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.Application : Application;

private import ocean.util.app.ext.UnittestExt;



/*******************************************************************************

    Extensible class to do all the common task an application with unittests
    have to do.

    Example:

    ---

    import ocean.util.app.UnittestedApp;

    class Test : UnittestedApp
    {
        this ( )
        {
            super("test", "Tests unittests");
        }
        protected override int run ( char[][] args )
        {
            return 0;
        }

    }

    int main(char[][] args)
    {
        auto app = new Test;
        return app.main(args);
    }

    ---

*******************************************************************************/

abstract class UnittestedApp : Application
{

    /***************************************************************************

        Unittest extension.

    ***************************************************************************/

    public UnittestExt utest_ext;


    /***************************************************************************

        Constructor.

        This constructor only setup the internal state of the class, but does
        not call any extension or user code. The application runs only when the
        main() method is called.

        Params:
            name = name of the application
            desc = short description of the application
            omit_unittest = if true, omit unittest run

    ***************************************************************************/

    this ( char[] name, char[] desc, bool omit_unittest = false )
    {
        super(name, desc);
        this.utest_ext = new UnittestExt(omit_unittest);
        this.registerExtension(this.utest_ext);
    }

}

