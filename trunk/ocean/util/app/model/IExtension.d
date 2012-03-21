/*******************************************************************************

    Base extension class for the Application framework. It just provides
    ordering to extensions.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.model.IExtension;


/*******************************************************************************

    Base extension class for the Application framework.

*******************************************************************************/

interface IExtension
{

    /***************************************************************************

        Returns a number to provide ordering to extensions.

        Smaller numbers are executed first (can be negative).

        By convention, the default order, if ordering is not important, should
        be zero.

    ***************************************************************************/

    int order ( );

}

