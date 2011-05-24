/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        January 2011: Initial release
    
    authors:        Gavin Norman

    Abstract class for asynchronously de/serializing one or more arrays. The
    following array transmission situations are supported:

        1. Single array
        2. Pair of arrays
        3. List of arrays (terminted with a blank)
        4. List of pairs of arrays (terminated with two consecutive blanks)

    For usage examples see:

        ocean.io.select.protocol.chain.serializer.SelectArraysSerializer;
        ocean.io.select.protocol.chain.serializer.SelectArraysDeserializer;

*******************************************************************************/

module ocean.io.select.protocol.chain.serializer.model.ISelectArraysTransmitter;



/*******************************************************************************

    Imports

*******************************************************************************/

debug private import tango.util.log.Trace;



/*******************************************************************************

    Abstract select arrays transmitter.

    Provides the framework of the functionality for de/serializing a sequence of
    one or more arrays from/to an asynchronously managed i/o buffer.

    Base class for:
        ocean.io.select.protocol.chain.serializer.SelectArraysSerializer
        ocean.io.select.protocol.chain.serializer.SelectArraysDeserializer

    Template params:
        IODg = type of a delegate which provides/receives arrays.

*******************************************************************************/

abstract class ISelectArraysTransmitter ( IODg )
{
    /***************************************************************************

        Abstract class used to determine when transmission of array(s) has
        finished.
        
        Different types of terminator are required depending on whether a single
        array or a list of arrays are being transmitted.
    
    ***************************************************************************/
    
    abstract class Terminator
    {
        /***********************************************************************
        
            Count of the number of arrays transmitted since the last call to
            reset().
        
        ***********************************************************************/
        
        protected uint arrays_transmitted;
        
        
        /***********************************************************************
        
            Called when transmission of an array is completed. Increments the
            count of transmitted arrays, then calls the abstract finishedArray_()
            (which must be implemented by derived classes) to determine whether
            it was the last array or whether the I/O delegate should be called
            again.
        
            Params:
                array = array just transmitted
        
            Returns:
                true if no more arrays are pending
        
        ***********************************************************************/
        
        public bool finishedArray ( void[] array )
        {
            this.arrays_transmitted++;
            return this.finishedArray_(array);
        }
        
        abstract protected bool finishedArray_ ( void[] array );
        
        
        /***********************************************************************
        
            Called when transmission is initialised. Resets the count of transmitted
            arrays, then calls reset_() (which can be overridden by derived
            classes to add any additional reset behaviour needed).
        
        ***********************************************************************/
        
        final public void reset ( )
        {
            this.arrays_transmitted = 0;
            this.reset_();
        }
        
        protected void reset_ ( )
        {
        }
    }
    
    
    /***************************************************************************
    
        Terminator used when transmitting a single array.
    
    ***************************************************************************/
    
    class SingleArrayTerminator : Terminator
    {
        protected bool finishedArray_ ( void[] array )
        {
            return super.arrays_transmitted > 0;
        }
    }
    
    
    /***************************************************************************
    
        Terminator used when transmitting a single pair of arrays.
    
    ***************************************************************************/
    
    class SinglePairTerminator : Terminator
    {
        protected bool finishedArray_ ( void[] array )
        {
            return super.arrays_transmitted > 1;
        }
    }
    
    
    /***************************************************************************
    
        Terminator used when transmitting a list of arrays. The list is regarded
        as finished when an empty string is transmitted.
    
    ***************************************************************************/
    
    class ArrayListTerminator : Terminator
    {
        protected bool finishedArray_ ( void[] array )
        {
            return array.length == 0;
        }
    }
    
    
    /***************************************************************************
    
        Terminator used when transmitting a list of array pairs. The list is
        regarded as finished when two consecutive empty strings are transmitted.
    
    ***************************************************************************/
    
    class PairListTerminator : Terminator
    {
        /***********************************************************************
        
            The last value of arrays_transmitted where the array being
            transmitted was null.
        
        ***********************************************************************/
        
        private size_t last_null_array;
        
        
        /***********************************************************************
        
            reset_() override which resets the last_null_array member.
        
        ***********************************************************************/
        
        override protected void reset_ ( )
        {
            this.last_null_array = this.last_null_array.max;
        }
    
    
        /***********************************************************************
        
            If the transmitted array is empty, see if this is the second empty
            array in a row.
        
            Params:
                array = last array transmitted
        
            Returns:
                true after transmitting two consecutive empty arrays.
        
        ***********************************************************************/
        
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
    
        Compression / decompression setting - meaning depends on whether the
        derived class is serializing (compress) or deserializing (decompress).
        
    ***************************************************************************/

    protected bool compress_decompress;


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

        Params:
            compress_decompress = sets internal de/compression flag
    
    ***************************************************************************/

    public void singleArray ( bool compress_decompress )
    {
        this.compress_decompress = compress_decompress;
        this.terminator = this.single_array_terminator;
        this.reset();
    }
    
    
    /***************************************************************************
    
        Initialises the transmission of a single pair of arrays.
    
        Params:
            compress_decompress = sets internal de/compression flag
    
    ***************************************************************************/
    
    public void singlePair ( bool compress_decompress )
    {
        this.compress_decompress = compress_decompress;
        this.terminator = this.single_pair_terminator;
        this.reset();
    }


    /***************************************************************************
    
        Initialises the transmission of a list of arrays.
    
        Params:
            compress_decompress = sets internal de/compression flag
    
    ***************************************************************************/
    
    public void arrayList ( bool compress_decompress )
    {
        this.compress_decompress = compress_decompress;
        this.terminator = this.array_list_terminator;
        this.reset();
    }
    
    
    /***************************************************************************
    
        Initialises the transmission of a list of pairs of arrays.
    
        Params:
            compress_decompress = sets internal de/compression flag
    
    ***************************************************************************/
    
    public void pairList ( bool compress_decompress )
    {
        this.compress_decompress = compress_decompress;
        this.terminator = this.pair_list_terminator;
        this.reset();
    }


    /***************************************************************************

        Receives and transmits one or more arrays.

        Note: this method is aliased to opCall, for convenient calling.

        Params:
            io_dg = input/output delegate which either provides or receives
                arrays
            data = input/output buffer  which either provides or receives
                arrays (the opposite to io_dg)
            cursor = position through input/output buffer

        Returns:
            true if the input/output buffer needs to be flushed (ie select must
            be called)

    ***************************************************************************/

    abstract public bool transmitArrays ( IODg io_dg, void[] data, ref ulong cursor );

    public alias transmitArrays opCall;


    /***************************************************************************
    
        Resets the internal state.

        Resets the terminator, then calls the reset_() method, which may be
        implemented by derived classes which need special reset behaviour.

    ***************************************************************************/
    
    final protected void reset ( )
    {
        if ( this.terminator )
        {
            this.terminator.reset();
        }

        this.reset_();
    }

    protected void reset_()
    {
    }
}

