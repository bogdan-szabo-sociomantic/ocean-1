/*******************************************************************************

    Structure holding the user-specified context for a client request. The
    specified request context is passed back to the calling code when the i/o
    delegate is called.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        January 2011: Initial release

    authors:        Gavin Norman

*******************************************************************************/

module ocean.core.ContextUnion;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.SmartUnion;



/*******************************************************************************

    Context.

*******************************************************************************/

private union ContextUnion_
{
    hash_t  integer;
    Object  object;
    void*   pointer;
}

public alias SmartUnion!(ContextUnion_) ContextUnion;

