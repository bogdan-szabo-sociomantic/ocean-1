/*******************************************************************************

    Interface for a process which can be suspended and resumed.

    copyright: Copyright (c) 2015 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.io.model.ISuspendable;


/*******************************************************************************

    Interface to a process which can be suspended and resumed.

*******************************************************************************/

public interface ISuspendable
{
    /***************************************************************************

        Requests that further processing be temporarily suspended, until
        resume() is called.

    ***************************************************************************/

    public void suspend ( );


    /***************************************************************************

        Requests that processing be resumed.

    ***************************************************************************/

    public void resume ( );


    /***************************************************************************

        Returns:
            true if the process is suspended

    ***************************************************************************/

    public bool suspended ( );
}
