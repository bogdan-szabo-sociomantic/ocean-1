/*******************************************************************************

    Copyright:      Copyright (C) 2014 sociomantic labs. All rights reserved

    Key exception -- thrown when an error event was reported for a selected key.

*******************************************************************************/

module ocean.io.select.selector.EpollException;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.ErrnoIOException;

/******************************************************************************/

class EpollException : ErrnoIOException { }
