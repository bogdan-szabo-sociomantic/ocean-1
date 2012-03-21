/******************************************************************************
    
    Interface for a class that obtains the current UNIX wall clock time in µs.

    Copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    Version:        November 2011: Initial release
                    
    Author:         David Eckardt
    
 ******************************************************************************/

module ocean.time.model.IMicrosecondsClock;

/******************************************************************************/

interface IMicrosecondsClock
{
    /**************************************************************************
        
        Returns:
            the current UNIX wall clock time in µs.
        
     **************************************************************************/

    ulong now_us ( );
}
