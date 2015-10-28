/*******************************************************************************

        copyright:      Copyright (c) 2007 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Jan 2007: Initial release

        author:         Kris

        Exposes the library version number

*******************************************************************************/

module tango.core.Version;

import tango.transition;

/// Tango's version.
public enum Tango {
    Major = 1, /// Major version number.
    Minor = 2  /// Minor version number.
}

istring getVersionString();
