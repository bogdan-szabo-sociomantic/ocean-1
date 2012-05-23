/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        22/05/2012: Initial release

    authors:        Gavin Norman, Leandro Lucarella

    Mixin template to set up a static Logger instance with the same name as the
    module which the template is mixed into.

    Usage example:

    ---

        import ocean.util.log.StaticModuleLogger;

        // Creates a static Logger instance with the specified name ("log", in
        // this example).
        mixin StaticModuleLogger!("log");

        static this ( )
        {
            // The Logger instance can then be used as normal in this module.
            log.trace("hello");
        }

    ---

*******************************************************************************/

module ocean.util.log.StaticModuleLogger;



/*******************************************************************************

    Mixin template to set up a static logger.

    The following are mixed in:
        1. The import of tango.util.log.Log.
        2. A Logger variable with the specified name.
        3. A static module constructor which looks up the logger with the
           module's name and assigns it to the Logger instance variable.

    Template params:
        logger = name of Logger instance variable

*******************************************************************************/

template StaticModuleLogger ( char[] logger )
{
    private import tango.util.log.Log;

    private class _AutoModuleNameDummyClass { }

    mixin("private Logger " ~ logger ~ ";");

    const cut_len = 50 + logger.length;

    static this ( )
    {
        mixin(logger) =
            Log.lookup(_AutoModuleNameDummyClass.classinfo.name[0..$-cut_len]);
    }
}

