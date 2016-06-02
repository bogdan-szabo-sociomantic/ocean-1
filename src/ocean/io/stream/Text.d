/*******************************************************************************

        Copyright:
            Copyright (c) 2007 Kris Bell.
            Some parts copyright (c) 2009-2016, Sociomantic Labs GmbH.
            All rights reserved.

        License: Tango 3-Clause BSD License. See LICENSE_BSD.txt for details.

        version:        Initial release: Oct 2007

        author:         Kris

*******************************************************************************/

module ocean.io.stream.Text;

import ocean.io.stream.Lines;

import ocean.io.stream.Format;

import ocean.io.stream.Buffered;

import ocean.io.model.IConduit;

/*******************************************************************************

        Input is buffered.

*******************************************************************************/

class TextInput : Lines!(char)
{
        /**********************************************************************

        **********************************************************************/

        this (InputStream input)
        {
                super (input);
        }
}

/*******************************************************************************

        Output is buffered.

*******************************************************************************/

class TextOutput : FormatOutput!(char)
{
        /**********************************************************************

                Construct a FormatOutput instance, tying the provided stream
                to a layout formatter.

        **********************************************************************/

        this (OutputStream output)
        {
                super (BufferedOutput.create(output));
        }
}
