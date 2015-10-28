/*******************************************************************************

        copyright:      Copyright (c) 2007 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Initial release: Oct 2007

        author:         Kris

*******************************************************************************/

module tango.io.stream.Text;

import tango.io.stream.Lines;

import tango.io.stream.Format;

import tango.io.stream.Buffered;

import tango.io.model.IConduit;

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
