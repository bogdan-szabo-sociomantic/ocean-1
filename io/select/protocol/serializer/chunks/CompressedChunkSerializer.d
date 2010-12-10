/*******************************************************************************

    Array chunk serializer which compresses chunks with LZO.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.CompressedChunkSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.model.IChunkSerializer;

private import ocean.io.compress.lzo.LzoChunk;

private import ocean.io.compress.lzo.LzoHeader;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Array chunk serializer which compresses chunks with LZO and writes them to
    the data output buffer.
    
    For each whole array the following data is written:

        1. Start chunk
        2. One or more compressed content chunks (which are the chunks passed
            to the processChunk() method).
        3. Stop chunk
    
*******************************************************************************/

class CompressedChunkSerializer : IChunkSerializer
{
    /***************************************************************************
    
        Internal state
    
    ***************************************************************************/
    
    enum State
    {
        Initial,
        WriteStartChunk,
        CompressChunk,
        WriteChunk,
        EndChunk
    }
    
    private State state;
    
    
    /***************************************************************************
    
        Start chunk header
    
    ***************************************************************************/
    
    private LzoHeader!() start_header;
    
    
    /***************************************************************************
    
        LzoChunk instance & buffer
    
    ***************************************************************************/
    
    protected LzoChunk!() lzo;
    
    protected void[] lzo_buffer;
    
    
    /***************************************************************************
    
        Buffer for compressed chunk data (slice into lzo_buffer)
    
    ***************************************************************************/
    
    protected void[] compressed_chunk;
    
    
    /***************************************************************************
    
        Constructor
    
    ***************************************************************************/
    
    public this ( )
    {
        this.lzo = new LzoChunk!();
        this.lzo_buffer = new void[1024];
    }
    
    
    /***************************************************************************
    
        Destructor
    
    ***************************************************************************/
    
    public ~this ( )
    {
        delete this.lzo;
        delete this.lzo_buffer;
    }
    
    
    /***************************************************************************
    
        Resets the internal state between runs.
    
    ***************************************************************************/
    
    override public void reset ( )
    {
        super.reset();
        this.state = State.Initial;
    }
    
    
    /***************************************************************************
    
        Compresses and writes an array to the output buffer.
    
        Params:
            chunk = chunk to serialize
            array_total_length = total length of whole array (may be >
                chunk.length, if chunk is only a part of a whole array)
            last_chunk_in_array = true when this is thel last chunk in an array
            data = output buffer
            cursor = output buffer cursor
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    public bool processChunk ( void[] chunk, size_t array_total_length, bool last_chunk_in_array, void[] data, ref ulong cursor )
    {
        bool io_wait, next_chunk, finished;
        
        do
        {
            switch ( this.state )
            {
                case State.Initial:
                    this.start_header.start(array_total_length);
                    this.state = State.WriteStartChunk;
                    super.write_value_cursor = 0;
                break;
    
                case State.WriteStartChunk:
                    io_wait = this.writeArray(start_header.data_without_length(), data, cursor);
                    if ( !io_wait )
                    {
                        this.state = State.CompressChunk;
                        super.write_value_cursor = 0;
                    }
                break;
    
                case State.CompressChunk:
                    this.compressed_chunk = this.compress(chunk);
                    this.state = State.WriteChunk;
                    super.write_value_cursor = 0;
                break;
    
                case State.WriteChunk:
                    io_wait = this.writeArray(this.compressed_chunk, data, cursor);
                    if ( !io_wait )
                    {
                        if ( last_chunk_in_array )
                        {
                            // written all chunks in this array
                            this.state = State.EndChunk;
                            super.write_value_cursor = 0;
                        }
                        else
                        {
                            // start next chunk
                            this.state = State.CompressChunk;
                            next_chunk = true;
                        }
                    }
                break;
    
                case State.EndChunk:
                    io_wait = this.writeEndChunk(data, cursor);
                    if ( !io_wait )
                    {
                        // written complete array
                        finished = true;
                        this.state = State.Initial;
                        super.write_value_cursor = 0;
                        // TODO: test compressed putCat to see if this works
                    }
                break;
    
                default:
                    assert(false, typeof(this).stringof ~ " - invalid state");
            }
        } while ( !finished && !next_chunk && !io_wait );
    
        return io_wait;
    }
    
    
    /***************************************************************************
    
        Does nothing in this implementation.
        
        Note: this can only be the case because we don't allow more than a
        single value to be written compressed (a simple put). If compressed
        values in putCat were to be required, then this method would have to do
        something.
    
        Params:
            data = output buffer
            cursor = output buffer cursor
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    public bool terminate ( ListTerminationMode termination_mode, ref void[] data, ref ulong cursor )
    in
    {
        assert(termination_mode == ListTerminationMode.None);
    }
    body
    {
        return false;
    }


    /***************************************************************************
    
        Writes a stop chunk to the output buffer.
    
        Params:
            data = output buffer
            cursor = output buffer cursor
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    protected bool writeEndChunk ( ref void[] data, ref ulong cursor )
    {
        // TODO: staticize
        LzoHeader!() stop_header;
        auto stop_chunk_data = stop_header.stop.data_without_length();
    
        return this.writeArray(stop_chunk_data, data, cursor);
    }
    
    
    /***************************************************************************
    
        Compresses data.
    
        Params:
            data = data to be compressed
    
        Returns:
            compressed data, with its initial 4 bytes stripped off (this is the
            total size of the compressed data chunk, written by the lzo
            compressor - it's rewritten by the protocol writer, so we strip it
            here).
    
    ***************************************************************************/
    
    protected void[] compress ( void[] data )
    {
        this.lzo.compress(data, this.lzo_buffer);
        return this.lzo_buffer[size_t.sizeof .. $];        // slice off the chunk size, as the protocol will rewrite it
    }
}

