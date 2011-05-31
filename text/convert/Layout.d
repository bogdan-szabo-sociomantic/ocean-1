/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman

    Layout class (wrapping tango.text.convert.Layout) with a single static
    method to write a formatted string into a provided buffer.

    Note: This module exists because a method with this behaviour does not exist
    in tango's Layout -- the closest being the sprint() method, which writes to
    an output buffer, but which will not exceed the passed buffer's length.

*******************************************************************************/

module ocean.text.convert.Layout;



/*******************************************************************************

    Imports

*******************************************************************************/

private import TangoLayout = tango.text.convert.Layout;



class Layout ( T )
{
    /***************************************************************************

        Outputs a formatted string into the provided buffer.

        Params:
            output = output buffer, length will be increased to accommadate
                formatted string
                formatStr = format string
                ... = format string parameters

    ***************************************************************************/

    static public void print ( ref char[] output, T[] formatStr, ... )
    {
        size_t layoutSink ( char[] s )
        {
            output ~= s;
            return s.length;
        }

        TangoLayout.Layout!(T).instance.convert(&layoutSink, _arguments, _argptr, formatStr);
    }
}

