/*******************************************************************************

    copyright:      Copyright (c) 2007 Kris Bell. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        Sep 2007: Initial release
    Nov 2007: Added stream wrappers

    author:         Kris

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

