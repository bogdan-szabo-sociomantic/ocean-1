/*******************************************************************************

    Copyright:
        Copyright (c) 2007 Kris Bell.
        Some parts copyright (c) 2009-2016, Sociomantic Labs GmbH.
        All rights reserved.

    License: Tango 3-Clause BSD License. See LICENSE_BSD.txt for details.

    Version:
        Sep 2007: Initial release
        Nov 2007: Added stream wrappers

    Authors: Kris

 *******************************************************************************/

module ocean.text.convert.Format;

import ocean.text.convert.Layout_tango;

/******************************************************************************

  Constructs a global utf8 instance of Layout

 ******************************************************************************/

public Layout!(char) Format;

static this()
{
    Format = Layout!(char).instance;
}

