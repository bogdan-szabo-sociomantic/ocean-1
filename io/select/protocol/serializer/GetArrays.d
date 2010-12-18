/*******************************************************************************

    Class for get array forwarding. Receives arrays from a data input buffer,
    possibly decompresses compressed data, and forwards to an output destination
    (a stream buffer, delegate, etc).

    Gets single arrays, lists of arrays and lists of pairs.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.select.protocol.serializer.GetArrays;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.dest.model.IChunkDest,
               ocean.io.select.protocol.serializer.chunks.dest.model.ChunkDestType;

private import ocean.io.select.protocol.serializer.chunks.ChunkDeserializer;

private import ocean.io.select.protocol.serializer.chunks.dest.ValueDelegateChunkDest;
private import ocean.io.select.protocol.serializer.chunks.dest.PairDelegateChunkDest;

private import ocean.io.compress.lzo.LzoHeader;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Get arrays class.

    Template params:
        Output = output device type, typically an OutputStream or a buffer
    
    Gets arrays from the input buffer, using an instance of ChunkDeserializer,
    and sends them to output destination (an instance of a class derived from
    IChunkDest).

    Note: Writing to the output device will always succeed (as it's either a
    variable in memory or a socket, which will block until the data is
    sent).
    
    On the other hand, reading from the input buffer must be interruptable /
    resumable, as we may have to read half variables.

*******************************************************************************/

class GetArrays ( Output )
{
    /***************************************************************************
    
        Chunk destination
    
    ***************************************************************************/

    private ChunkDestType!(Output) chunk_dest;


    /***************************************************************************
    
        Chunk deserializer
    
    ***************************************************************************/

    private ChunkDeserializer deserializer;

    
    /***************************************************************************
    
        Processing state
    
    ***************************************************************************/
    
    enum State
    {
        GetArray,
        ProcessArray,
        Finished
    }
    
    private State state;
    
    
    /***************************************************************************

        Count of complete arrays processed. Each chunked array counts as one.
    
    ***************************************************************************/
    
    private uint arrays_processed;


    /***************************************************************************

        Has a list terminator (null string) been read? Used by isNullPair().

    ***************************************************************************/

    private bool got_first_terminator;


    /***************************************************************************
    
        Constructor
        
    ***************************************************************************/
    
    public this ( )
    {
        this.chunk_dest = new ChunkDestType!(Output);
        
        this.deserializer = new ChunkDeserializer;
    }


    /***************************************************************************
        
        Destructor

    ***************************************************************************/
    
    ~this ( )
    {
        delete this.chunk_dest;
        delete this.deserializer;
    }


    /***************************************************************************
    
        Resets the internal state between runs.
        
    ***************************************************************************/
    
    public void reset ( )
    {
        this.state = State.GetArray;

        this.arrays_processed = 0;
        this.got_first_terminator = false;
        
        this.deserializer.reset();
        this.chunk_dest.reset();
    }
    
    
    /***************************************************************************
    
        Receives and processes a single array
        
        Params:
            output    = output data device (stream / buffer)
            data      = input buffer
            cursor    = position through input buffer
    
        Returns:
            true if the input buffer is empty and needs to be refilled
    
    ***************************************************************************/
    
    public bool getSingleArray ( Output output, void[] data, ref ulong cursor )
    {
        return this.processArrayList(output, data, cursor, &this.isEndOfFirstArray);
    }
    
    
    /***************************************************************************
    
        Receives and processes a pair

        Params:
            output = data output device (stream / buffer)
            data = input buffer
            cursor = position through input buffer
    
        Returns:
            true if the input buffer is empty and needs to be refilled
    
    ***************************************************************************/
    
    public bool getPair ( Output output, void[] data, ref ulong cursor )
    {
        return this.processArrayList(output, data, cursor, &this.isEndOfFirstPair);
    }


    /***************************************************************************
    
        Receives and processes a list of arrays
        
        Params:
            output    = output data device (stream / buffer)
            data      = input buffer
            cursor    = position through input buffer
    
        Returns:
            true if the input buffer is empty and needs to be refilled
    
    ***************************************************************************/
    
    public bool getArrayList ( Output output, void[] data, ref ulong cursor )
    {
        return this.processArrayList(output, data, cursor, &this.isNull);
    }
    
    
    /***************************************************************************
    
        Receives and processes a list of pairs
        
        Params:
            output    = output data device (stream / buffer)
            data      = input buffer
            cursor    = position through input buffer
    
        Returns:
            true if the input buffer is empty and needs to be refilled
    
    ***************************************************************************/
    
    public bool getPairList ( Output output, void[] data, ref ulong cursor )
    {
        return this.processArrayList(output, data, cursor, &this.isEndOfNullPair);
    }
    
    
    /***************************************************************************
    
        Receives and processes a list of arrays:
            1. An array is read from the input buffer.
            2. The array is processed.
            3. Check the finishing condition, and return to step 1 if not
               finished.
            4. Call the terminateList() method when finished.
    
        Params:
            output    = output data device (stream / buffer)
            data      = input buffer
            cursor    = position through input buffer
            finish_dg = delegate for finishing condition
    
        Returns:
            true if the input buffer is empty and needs to be refilled
    
    ***************************************************************************/
    
    private bool processArrayList ( Output output, void[] data, ref ulong cursor, bool delegate ( void[] ) finish_dg )
    {
        void[] array;

        this.deserializer.newBuffer();

        do
        {
            with ( State ) switch ( this.state )
            {
                case GetArray:
                    auto io_wait = this.deserializer.getNextArray(data, cursor);
                    if ( io_wait )
                    {
                        return true;
                    }

                    array = this.deserializer.array;
                    this.state = ProcessArray;
                break;

                case ProcessArray:
                    this.chunk_dest.processArray(output, array);

                    if ( this.isEndOfArray(array) )
                    {
                        this.arrays_processed++;
                    }
                    
                    // Check whether this was the last array to process
                    if ( finish_dg(array) )
                    {
                        this.state = Finished;
                    }
                    else
                    {
                        this.deserializer.nextArray();
                        this.state = GetArray;
                    }
                break;
            }
        }
        while ( this.state != State.Finished );

        return false;
    }


    /***************************************************************************

        Checks whether an array is an end. This can occur in two cases:
        
            1. The stop chunk of a chunked array.
            2. An un-chunked array (is always its own ending!)
    
        Params:
            array = data to check
    
        Returns:
            true if the array is an end
        
    ***************************************************************************/

    private bool isEndOfArray ( void[] array )
    {
        LzoHeader!(false) header;
        
        if ( header.tryRead(array) )
        {
            return header.type == header.type.Stop;
        }
        else
        {
            return true;
        }
    }

    /***************************************************************************
    
        Checks whether an array is the end of the first array processed.
    
        Params:
            array = data to check
    
        Returns:
            true if the array is the end of the first array
    
    ***************************************************************************/
    
    private bool isEndOfFirstArray ( void[] array )
    {
        return this.arrays_processed > 0;
    }
    
    
    /***************************************************************************
    
        Checks whether an array is the end of the first array pair processed.
    
        Params:
            array = data to check
    
        Returns:
            true if the array is the end of the first pair
    
    ***************************************************************************/
    
    private bool isEndOfFirstPair ( void[] array )
    {
        return this.arrays_processed > 1;
    }
    

    /***************************************************************************
    
        Checks whether an array is a null end of list terminator.
    
        Params:
            array = data to check
    
        Returns:
            true if the array is null
    
    ***************************************************************************/
    
    private bool isNull ( void[] array )
    {
        return array.length == 0;
    }
    
    
    /***************************************************************************
    
        Checks whether a double null terminator has occurred.
    
        Params:
            array = data to check
    
        Returns:
            true if a double null terminator has occurred
    
    ***************************************************************************/
    
    private bool isEndOfNullPair ( void[] array )
    {
        if ( this.got_first_terminator && array.length == 0 )
        {
            return true;
        }
    
        this.got_first_terminator = array.length == 0;
    
        return false;
    }
}

