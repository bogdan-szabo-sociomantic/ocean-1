// TODO


module ocean.io.select.protocol.serializer.model.ISelectArraysTransmitter;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.ArrayTransmitTerminator;

private import ocean.io.compress.lzo.LzoHeader,
               ocean.io.compress.lzo.LzoChunk;

debug private import tango.util.log.Trace;



abstract class ISelectArraysTransmitter
{
    /***************************************************************************
    
        Transmission state.
    
    ***************************************************************************/

    enum State
    {
        Initial,
        GetArray,
        TransmitArray,
        Finished
    }

    protected State state;


    /***************************************************************************

        Toggles array decompression - should be set externally by the user.
    
    ***************************************************************************/

    // TODO: could give this a generic name?
//    public bool decompress;


    /***************************************************************************

        Terminator instances.
    
    ***************************************************************************/
    
    protected SingleArrayTerminator single_array_terminator;
    protected SinglePairTerminator single_pair_terminator;
    protected ArrayListTerminator array_list_terminator;
    protected PairListTerminator pair_list_terminator;
    
    
    /***************************************************************************
    
        Reference to the terminator instance currently being used.
    
    ***************************************************************************/
    
    protected Terminator terminator;


    /***************************************************************************
    
        Constructor
        
    ***************************************************************************/
    
    public this ( )
    {
        this.single_array_terminator = new SingleArrayTerminator();
        this.single_pair_terminator = new SinglePairTerminator();
        this.array_list_terminator = new ArrayListTerminator();
        this.pair_list_terminator = new PairListTerminator();
    }


    /***************************************************************************
        
        Destructor

    ***************************************************************************/
    
    ~this ( )
    {
        delete this.single_array_terminator;
        delete this.single_pair_terminator;
        delete this.array_list_terminator;
        delete this.pair_list_terminator;
    }


    /***************************************************************************
    
        Initialises the transmission of a single array.
    
    ***************************************************************************/

    // TODO: generic name?
    public alias getSingleArray putSingleArray;

    public void getSingleArray ( )
    {
        this.terminator = this.single_array_terminator;
        this.reset();
    }
    
    
    /***************************************************************************
    
        Initialises the transmission of a single pair of arrays.
    
    ***************************************************************************/
    
    // TODO: generic name?
    public alias getPair putPair;

    public void getPair ( )
    {
        this.terminator = this.single_pair_terminator;
        this.reset();
    }


    /***************************************************************************
    
        Initialises the transmission of a list of arrays.
    
    ***************************************************************************/
    
    // TODO: generic name?
    public alias getArrayList putArrayList;

    public void getArrayList ( )
    {
        this.terminator = this.array_list_terminator;
        this.reset();
    }
    
    
    /***************************************************************************
    
        Initialises the transmission of a list of pairs of arrays.
    
    ***************************************************************************/
    
    // TODO: generic name?
    public alias getPairList putPairList;

    public void getPairList ( )
    {
        this.terminator = this.pair_list_terminator;
        this.reset();
    }
    
    
    /***************************************************************************
    
        Tells whether the given array contains an lzo compression start chunk.

        Template params:
            TODO

        Params:
            array = array to test

        Returns:
            true if a compression start chunk is found at the beginning of the
            passed array.

    ***************************************************************************/
    
    protected bool isLzoStartChunk ( bool length_inline ) ( void[] array )
    {
        LzoHeader!(length_inline) header;
    
        if ( array.length < header.read_length )
        {
            return false;
        }
        else
        {
            return header.tryReadStart(array[0..header.read_length]);
        }
    }


    /***************************************************************************
    
        Resets the internal state.

        TODO

    ***************************************************************************/
    
    final protected void reset ( )
    {
        if ( this.terminator )
        {
            this.terminator.reset();
        }

        this.state = State.Initial;
        
        this.reset_();
    }

    protected void reset_()
    {
    }
}

