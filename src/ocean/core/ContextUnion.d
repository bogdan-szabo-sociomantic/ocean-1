/*******************************************************************************

    Structure holding a user-specified context in the form of a pointer, a class
    reference or a platform-dependant unsigned integer (a hash_t).

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        January 2011: Initial release

    authors:        Gavin Norman

*******************************************************************************/

module ocean.core.ContextUnion;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.SmartUnion;



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

