/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        January 2011: Initial release

    authors:        Gavin Norman

    Abstract and derived classes for determining when transmission of one or
    more arrays has finished.

    Used by the GetArrays and PutArrays classes.

*******************************************************************************/

module ocean.io.select.protocol.serializer.ArrayTransmitTerminator;



/*******************************************************************************

    Imports

*******************************************************************************/

debug private import tango.util.log.Trace;



/*******************************************************************************

    Abstract class used to determine when transmission of array(s) has
    finished.
    
    Different types of terminator are required depending on whether a single
    array or a list of arrays are being transmitted.

*******************************************************************************/

abstract class Terminator
{
    /***************************************************************************
    
        Count of the number of arrays transmitted since the last call to
        reset().
    
    ***************************************************************************/
    
    protected uint arrays_transmitted;
    
    
    /***************************************************************************
    
        Called when transmission of an array is completed. Increments the
        count of transmitted arrays, then calls the abstract finishedArray_()
        (which must be implemented by derived classes) to determine whether
        it was the last array or whether the I/O delegate should be called
        again.
    
        Params:
            array = array just transmitted
    
        Returns:
            true if no more arrays are pending
    
    ***************************************************************************/
    
    public bool finishedArray ( void[] array )
    {
        this.arrays_transmitted++;
        return this.finishedArray_(array);
    }
    
    abstract protected bool finishedArray_ ( void[] array );
    
    
    /***************************************************************************
    
        Called when transmission is initialised. Resets the count of transmitted
        arrays, then calls reset_() (which can be overridden by derived
        classes to add any additional reset behaviour needed).
    
    ***************************************************************************/
    
    final public void reset ( )
    {
        this.arrays_transmitted = 0;
        this.reset_();
    }
    
    protected void reset_ ( )
    {
    }
}


/*******************************************************************************

    Terminator used when transmitting a single array.

*******************************************************************************/

class SingleArrayTerminator : Terminator
{
    protected bool finishedArray_ ( void[] array )
    {
        return super.arrays_transmitted > 0;
    }
}


/*******************************************************************************

    Terminator used when transmitting a single pair of arrays.

*******************************************************************************/

class SinglePairTerminator : Terminator
{
    protected bool finishedArray_ ( void[] array )
    {
        return super.arrays_transmitted > 1;
    }
}


/*******************************************************************************

    Terminator used when transmitting a list of arrays. The list is regarded
    as finished when an empty string is transmitted.

*******************************************************************************/

class ArrayListTerminator : Terminator
{
    protected bool finishedArray_ ( void[] array )
    {
        return array.length == 0;
    }
}


/*******************************************************************************

    Terminator used when transmitting a list of array pairs. The list is
    regarded as finished when two consecutive empty strings are transmitted.

*******************************************************************************/

class PairListTerminator : Terminator
{
    /***************************************************************************
    
        The last value of arrays_transmitted where the array being transmitted
        was null.
    
    ***************************************************************************/
    
    private size_t last_null_array;
    
    
    /***************************************************************************
    
        reset_() override which resets the last_null_array member.
    
    ***************************************************************************/
    
    override protected void reset_ ( )
    {
        this.last_null_array = this.last_null_array.max;
    }


    /***************************************************************************
    
        If the transmitted array is empty, see if this is the second empty
        array in a row.
    
        Params:
            array = last array transmitted
    
        Returns:
            true after transmitting two consecutive empty arrays.
    
    ***************************************************************************/
    
    protected bool finishedArray_ ( void[] array )
    {
        if ( array.length == 0 )
        {
            if ( this.last_null_array < super.arrays_transmitted )
            {
                return true;
            }
            else
            {
                this.last_null_array = super.arrays_transmitted;
            }
        }
    
        return false;
    }
}

