/*******************************************************************************

    Class for array put forwarding. Receives arrays one by one from a variety of
    sources (streams, buffers, lists), splits them into chunks and processes
    them (possibly with compression), writing to a data output buffer.

    Puts single arrays and lists of arrays.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman
    
*******************************************************************************/

module ocean.io.select.protocol.serializer.model.PutArrays;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.ChunkDelegates;

private import ocean.io.select.protocol.serializer.chunks.source.model.IChunkSource,
               ocean.io.select.protocol.serializer.chunks.source.model.ChunkSourceType,
               ocean.io.select.protocol.serializer.chunks.model.IChunkSerializer,
               ocean.io.select.protocol.serializer.chunks.model.ChunkSerializerType;

private import ocean.io.select.protocol.serializer.chunks.source.DelegateChunkSource;

private import tango.math.Math: min;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Put arrays class.

    Template params:
        Input = input device type, typically an InputStream or a buffer
        Compressed = write compressed / uncompressed data?
    
    Gets arrays from the input device (using a class derived from IChunkSource),
    and splits them into chunks (with a maximum size). The input arrays are
    chunked in this manner to:

        1. Minimize buffering.
        2. Enable compression, which needs to work with chunks.

    Each chunk is processed and output is written to the output buffer by an
    instance of a class derived from IChunkSerializer.
    
    Note: Reading from the input device will always succeed (as it's either a
    variable in memory or a socket, which will block until the data is
    received).
    
    On the other hand, writing to the output buffer must be interruptable /
    resumable, as we may have to write half variables.

*******************************************************************************/

class PutArrays ( bool Compressed = false )
{
    /***************************************************************************
    
        Source of arrays to process
        
    ***************************************************************************/

//    private ChunkSourceType!(Input) chunk_source;

    private DelegateChunkSource chunk_source;

    /***************************************************************************
    
        Chunk buffer (slice into the chunk stored in chunk_source)
    
    ***************************************************************************/

    private void[] chunk;


    /***************************************************************************
    
        Chunk serializer
    
    ***************************************************************************/

    private IChunkSerializer serializer;


    /***************************************************************************
    
        Processing state
    
    ***************************************************************************/
    
    enum State
    {
        Initial,
        StartArray,
        ReadChunk,
        ProcessChunk,
        Terminate,
        Finished
    }
    
    private State state;
    
    
    /***************************************************************************
    
        Maximum size of chunk to receive and process
    
    ***************************************************************************/
    
    const size_t DefaultOutputBufferLength = 1024;
    
    private size_t output_buffer_length = this.DefaultOutputBufferLength;
    
    /***************************************************************************
    
        Total remaining size (bytes) of the current array being received &
        processed. This value is decreased as chunks of the array are processed.
    
    ***************************************************************************/
    
    private size_t array_length_to_read;
    
    
    /***************************************************************************
    
        List termination mode
    
    ***************************************************************************/
    
    private IChunkSerializer.ListTerminationMode termination_mode;


    /***************************************************************************
    
        Constructor
        
    ***************************************************************************/

    public this ( size_t output_buffer_length = DefaultOutputBufferLength )
    {
        this.chunk_source = new DelegateChunkSource;
        
        this.serializer = new ChunkSerializerType!(Compressed);
        
        this.output_buffer_length = output_buffer_length;
        
        this.chunk = new void[this.output_buffer_length];
    }
    
    /***************************************************************************
    
        Destructor
        
    ***************************************************************************/

    ~this ( )
    {
        delete this.chunk_source;
        delete this.serializer;
        delete this.chunk;
    }

    
    /***************************************************************************
    
        Resets the internal state between runs.
        
    ***************************************************************************/

    public void reset ( )
    {
        this.state = State.Initial;
        this.termination_mode = IChunkSerializer.ListTerminationMode.None;
        this.array_length_to_read = 0;

        this.chunk_source.reset();
        this.chunk.length = 0;

        this.serializer.reset();
    }

    
    /***************************************************************************
    
        Receives and processes a single array
        
        Params:
            input  = data source (stream / buffer)
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
            input  = data source (stream / buffer)
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
    
        Receives and processes a list of arrays:
            1. The length of an array is read from the input source.
            2. Repeatedly:
                a. Read the array in one chunk at a time
                b. Process each chunk
                Until the whole array has been processed
            3. Check the finishing condition, and return to step 2 if not
               finished.
            
        Params:
            input     = data source (stream / buffer)
            data      = output buffer
            cursor    = position through output buffer
            finish_dg = delegate for finishing condition
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/

    private bool processArrayList ( ChunkDelegates.PutValueDg input, void[] data, ref ulong cursor,
                                    bool delegate ( ChunkDelegates.PutValueDg input, void[] array ) finish_dg )
    {
        do
        {
            switch ( this.state )
            {
                case State.Initial:
                    this.state = State.StartArray;
                break;
    
                case State.StartArray:
                    this.array_length_to_read = this.chunk_source.readArrayLength(input);
                    this.state = State.ReadChunk;
                break;

                case State.ReadChunk:
                    this.chunk.length = min(this.array_length_to_read, this.output_buffer_length);
                    this.chunk_source.getNextChunk(input, this.chunk);
                    
                    if ( finish_dg(input, this.chunk) )
                    {
                        this.state = State.Terminate;
                    }
                    else
                    {
                        this.state = State.ProcessChunk;
                    }
                break;

                case State.ProcessChunk:
                    auto last_chunk_in_array = (this.array_length_to_read - this.chunk.length) == 0;

                    auto still_writing_chunk = this.serializer.processChunk(this.chunk,
                                                                            this.array_length_to_read,
                                                                            last_chunk_in_array,
                                                                            data,
                                                                            cursor);

                    if ( still_writing_chunk )
                    {
                        return true;
                    }
                    else                                                        // finished this chunk
                    {
                        this.array_length_to_read -= this.chunk.length;
                        if ( !last_chunk_in_array )
                        {
                            this.state = State.ReadChunk;                       // read more chunks from this array
                        }
                        else                                                    // no more chunks to read, finished whole array
                        {
                            this.chunk_source.nextArray();
                            this.state = State.StartArray;
                        }
    
                        if ( finish_dg(input, this.chunk) )
                        {
                            this.state = State.Terminate;
                        }
                    }
                break;

                case State.Terminate:
                    auto still_writing_terminator = this.serializer.terminate(this.termination_mode, data, cursor);
                    if ( still_writing_terminator )
                    {
                        return true;
                    }

                    this.state = State.Finished;
                break;
            }
        } while ( this.state != State.Finished );

        return false;
    }


    /***************************************************************************
    
        Checks whether one or more arrays have been processed.
    
        Params:
            input = data source (stream / buffer)
            array = data to check (not used)
    
        Returns:
            true if one or more arrays have been processed
    
    ***************************************************************************/
    
    private bool processedOneArray ( ChunkDelegates.PutValueDg input, void[] array )
    {
        return this.chunk_source.arrays_processed > 0;
    }


    /***************************************************************************
    
        Checks whether this is the last array in the list.
        
        For buffered array lists we can simply check whether we've processed
        every array in the list.
        
        For streamed array lists, the end is indicated by an empty array.
    
        Params:
            input = data source (stream / buffer)
            array = data to check
    
        Returns:
            true if the array is a stop header
    
    ***************************************************************************/
    
    private bool endOfList ( ChunkDelegates.PutValueDg input, void[] array )
    {
        return this.chunk_source.endOfList(input, array);
    }
}

