/*******************************************************************************

        Copyright:
            Copyright (c) 2005 John Chapman.
            Some parts copyright (c) 2009-2016, Sociomantic Labs GmbH.
            All rights reserved.

        License: Tango 3-Clause BSD License. See LICENSE_BSD.txt for details.

        version:        Mid 2005: Initial release
                        Apr 2007: reshaped

        author:         John Chapman, Kris

******************************************************************************/

module ocean.time.chrono.Korean;

import ocean.time.chrono.GregorianBased;


/**
 * $(ANCHOR _Korean)
 * Represents the Korean calendar.
 */
public class Korean : GregorianBased {
  /**
   * $(I Property.) Overridden. Retrieves the identifier associated with the current calendar.
   * Returns: An integer representing the identifier of the current calendar.
   */
  public override uint id() {
    return KOREA;
  }

}


