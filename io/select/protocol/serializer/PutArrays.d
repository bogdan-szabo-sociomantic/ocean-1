/*******************************************************************************

    Class for array put forwarding. Receives arrays one by one from a delegate,
    splits them into chunks and processes them (possibly with compression),
    writing to a data output buffer.

    Puts single arrays, pairs of arrays, lists of arrays and lists of pairs.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        August 2010: Initial release
                    December 2010: Only reads from delegates

    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.select.protocol.serializer.model.PutArrays;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.ChunkDelegates;

private import ocean.io.select.protocol.serializer.chunks.model.IChunkSerializer,
               ocean.io.select.protocol.serializer.chunks.model.ChunkSerializerType;

private import tango.math.Math: min;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Put arrays class.
    
    Template params:
        Compressed = write compressed / uncompressed data?
    
    Gets arrays from an input delegate, and splits them into chunks (with a
    maximum size). The input arrays are chunked in this manner to:

        1. Minimize buffering.
        2. Enable compression, which needs to work with chunks.

    Each chunk is processed and written to the output buffer by an instance of a
    class derived from IChunkSerializer.
    
    Note: Reading from the input device will always succeed (as it's just a
    delegate which provides the array to process).

    On the other hand, writing to the output buffer must be interruptable /
    resumable, as we may have to write half variables.

*******************************************************************************/

class PutArrays ( bool Compressed = false )
{
    /***************************************************************************
    
        Chunk buffer (slice into the chunk passed by input delegate).
    
    ***************************************************************************/
    
    private char[] chunk;


    /***************************************************************************
    
        Count of the number of arrays processed since the last call to reset().
    
    ***************************************************************************/

    private uint arrays_processed;


    /***************************************************************************
    
        The last value of arrays_processed where the chunk being processed was
        null.
    
    ***************************************************************************/
    
    private uint last_null_array;


    /***************************************************************************
    
        Asynchronous chunk serializer, may provide compression.
    
    ***************************************************************************/
    
    private IChunkSerializer serializer;


    /***************************************************************************
    
        Processing state.
    
    ***************************************************************************/
    
    enum State
    {
        StartArray,
        ReadChunk,
        ProcessChunk,
        Terminate,
        Finished
    }
    
    private State state;
    
    
    /***************************************************************************
    
        Maximum size of chunk to receive and process.
    
    ***************************************************************************/
    
    const size_t DefaultOutputBufferLength = 1024;
    
    private size_t output_buffer_length = this.DefaultOutputBufferLength;


    /***************************************************************************
    
        Array to process, received from input delegate.
    
    ***************************************************************************/

    private char[] array;


    /***************************************************************************
    
        Total remaining size (bytes) of the current array being received &
        processed. This value is decreased as chunks of the array are processed.
    
    ***************************************************************************/
    
    private size_t array_length_to_read;
    
    
    /***************************************************************************
    
        List termination mode.
    
    ***************************************************************************/
    
    private IChunkSerializer.ListTerminationMode termination_mode;
    
    
    /***************************************************************************
    
        Constructor
        
    ***************************************************************************/
    
    public this ( size_t output_buffer_length = DefaultOutputBufferLength )
    {
        this.serializer = new ChunkSerializerType!(Compressed);

        this.output_buffer_length = output_buffer_length;
    }


    /***************************************************************************
    
        Destructor
        
    ***************************************************************************/
    
    ~this ( )
    {
        delete this.serializer;
        delete this.chunk;
    }
    
    
    /***************************************************************************
    
        Resets the internal state between runs.
        
    ***************************************************************************/
    
    public void reset ( )
    {
        this.state = State.StartArray;
        this.termination_mode = IChunkSerializer.ListTerminationMode.None;
        this.last_null_array = this.last_null_array.max;
        this.arrays_processed = 0;
    
        this.serializer.reset();
    }
    
    
    /***************************************************************************
    
        Receives and processes a single array
        
        Params:
            input  = input delegate
            data   = output buffer
            cursor = position through output buffer
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    public bool putSingleArray ( ChunkDelegates.PutValueDg input, void[] data, ref ulong cursor )
    {
        this.termination_mode = IChunkSerializer.ListTerminationMode.None;
        return this.processArrayList(input, data, cursor, &this.processedOneArray);
    }
    
    
    /***************************************************************************
    
        Receives and processes a list of arrays
    
        Params:
            input  = input delegate
            data   = output buffer
            cursor = position through output buffer
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    public bool putArrayList ( ChunkDelegates.PutValueDg input, void[] data, ref ulong cursor )
    {
        this.termination_mode = IChunkSerializer.ListTerminationMode.List;
        return this.processArrayList(input, data, cursor, &this.endOfList);
    }
    
    
    /***************************************************************************
    
        Receives and processes a list of pairs
    
        Params:
            input  = input delegate
            data   = output buffer
            cursor = position through output buffer
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/

    public bool putPairList ( ChunkDelegates.PutValueDg input, void[] data, ref ulong cursor )
    {
        this.termination_mode = IChunkSerializer.ListTerminationMode.List;
        return this.processArrayList(input, data, cursor, &this.endOfNullPair);
    }


    /***************************************************************************
    
        Receives and processes a list of arrays:
            1. An array is read from the input delegate.
            2. Repeatedly:
                a. Extracts chunks one at a time from the received array
                b. Process each chunk
                Until the whole array has been processed
            3. Check the finishing condition, and return to step 1 if not
               finished.

        Params:
            input     = input delegate
            data      = output buffer
            cursor    = position through output buffer
            finish_dg = delegate for finishing condition
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/

    private bool processArrayList ( ChunkDelegates.PutValueDg input, void[] data, ref ulong cursor,
                                    bool delegate ( void[] array ) finish_dg )
    {
        do
        {
            with ( State ) switch ( this.state )
            {
                case StartArray:
                    this.array = input();
                    this.array_length_to_read = this.array.length;

                    this.state = ReadChunk;
                break;

                case ReadChunk:
                    this.getNextChunk(this.chunk, this.array);

                    // TODO: previously there was a check to finish_dg here - is this necessary?

                    this.state = ProcessChunk;
                break;
    
                case ProcessChunk:
                    auto still_writing_chunk = this.processChunk(data, cursor);
                    if ( still_writing_chunk )
                    {
                        return true;
                    }
                    else                                                        // finished this chunk
                    {
                        if ( this.lastChunkInArray() )                          // no more chunks to read, finished whole array
                        {
                            this.arrays_processed++;
                            this.state = StartArray;
                        }
                        else
                        {
                            this.state = ReadChunk;                             // read more chunks from this array
                        }
    
                        if ( finish_dg(this.chunk) )
                        {
                            this.state = Terminate;
                        }
                    }
                break;
    
                case Terminate:
                    auto still_writing_terminator = this.serializer.terminate(this.termination_mode, data, cursor);
                    if ( still_writing_terminator )
                    {
                        return true;
                    }
    
                    this.state = Finished;
                break;
            }
        } while ( this.state != State.Finished );
    
        return false;
    }


    /***************************************************************************
    
        Pulls the next chunk from the array being processed.

        Params:
            chunk = string to be set to the next chunk
            source = array to read chunk from
    
    ***************************************************************************/

    private void getNextChunk ( ref char[] chunk, char[] source )
    {
        auto len = min(this.array_length_to_read, this.output_buffer_length);
        auto pos = source.length - this.array_length_to_read;

        chunk = source[pos .. pos + len];
        this.array_length_to_read -= len;
    }


    /***************************************************************************

        Serializes a chunk of data (may include compressing the chunk).

        Params:
            data      = output buffer
            cursor    = position through output buffer
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/

    private bool processChunk ( void[] data, ref ulong cursor )
    {
        auto still_writing_chunk = this.serializer.processChunk(this.chunk, this.array.length,
                this.lastChunkInArray(), data, cursor);

        return still_writing_chunk;
    }


    /***************************************************************************

        Returns:
            true if the current chunk is the last in the current array
    
    ***************************************************************************/

    private bool lastChunkInArray ( )
    {
        return this.array_length_to_read == 0;
    }


    /***************************************************************************
    
        Checks whether one or more arrays have been processed.
    
        Params:
            input = data source (stream / buffer)
            array = data to check (not used)
    
        Returns:
            true if one or more arrays have been processed
    
    ***************************************************************************/
    
    private bool processedOneArray ( void[] array )
    {
        return this.arrays_processed > 0;
    }
    
    
    /***************************************************************************
    
        Checks whether this is the last array in the list (indicated by an
        empty array).
        
        Params:
            array = data to check
    
        Returns:
            true if the array indicates the end of the list
    
    ***************************************************************************/
    
    private bool endOfList ( void[] array )
    {
        return array.length == 0;
    }


    /***************************************************************************
    
        Checks whether this is the last array in the list of pairs (indicated by
        two empty arrays in a row).
        
        Params:
            array = data to check
    
        Returns:
            true if the array indicates the end of the list of pairs
    
    ***************************************************************************/

    private bool endOfNullPair ( void[] array )
    {
        if ( array.length == 0 )
        {
            if ( this.last_null_array < this.arrays_processed )
            {
                return true;
            }
            else
            {
                this.last_null_array = this.arrays_processed;
            }
        }

        return false;
    }
}

