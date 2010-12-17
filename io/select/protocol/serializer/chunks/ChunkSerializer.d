/*******************************************************************************

    Simple array chunk serializer.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.ChunkSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.model.IChunkSerializer;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Array chunk serializer which simply writes chunks to the data output buffer.
    
    For each whole array the following data is written:

        1. Length of whole array
        2. One or more chunks of array content (which are the chunks passed
            to the processChunk() method).

*******************************************************************************/

class ChunkSerializer : IChunkSerializer
{
    /***************************************************************************
    
        Internal state
    
    ***************************************************************************/
    
    enum State
    {
        Initial,
        WriteChunk
    }
    
    private State state;
    
    
    /***************************************************************************
    
        Resets the internal state between runs.
    
    ***************************************************************************/
    
    override public void reset ( )
    {
        super.reset();
        this.state = State.Initial;
    }
    
    
    /***************************************************************************
    
        Writes an array to the output buffer, without compression.
    
        Params:
            chunk = chunk to serialize
            array_total_length = total length of whole array (may be >
                chunk.length, if chunk is only a part of a whole array)
            last_chunk_in_array = true when this is the last chunk in an array
            data = output buffer
            cursor = output buffer cursor
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    public bool processChunk ( void[] chunk, size_t array_total_length, bool last_chunk_in_array, void[] data, ref ulong cursor )
    {
        bool io_wait, next_chunk;
        
        do
        {
            switch ( this.state )
            {
                case State.Initial:
                    io_wait = super.write(array_total_length, data, cursor); // write total array length
                    if ( !io_wait )
                    {
                        this.state = State.WriteChunk;
                        super.write_value_cursor = 0;
                    }
                break;
    
                case State.WriteChunk:
                    io_wait = this.writeArrayWithoutLength(chunk, data, cursor);
                    if ( !io_wait )
                    {
                        // get next chunk
                        next_chunk = true;
                        super.write_value_cursor = 0;
    
                        if ( last_chunk_in_array )
                        {
                            this.state = State.Initial;
                        }
                    }
                break;
    
                default:
                    assert(false, typeof(this).stringof ~ " - invalid state");
            }
        } while ( !next_chunk && !io_wait );
    
        return io_wait;
    }
    
    /***************************************************************************
    
        Writes a terminator for a list of arrays.
        
        Note: this needs to be done as the arrays are just written as raw data,
        without any kind of header structure. So an empty array represents the
        end of the list in this case.
    
        Params:
            data = output buffer
            cursor = output buffer cursor
    
        Returns:
            true if the output buffer is full and needs to be flushed
    
    ***************************************************************************/
    
    public bool terminate ( ListTerminationMode termination_mode, ref void[] data, ref ulong cursor )
    {
        with ( ListTerminationMode  ) switch ( termination_mode )
        {
            case None:
            break;
            
            case List:
                return this.writeArray(""c, data, cursor);
            break;

            case PairList:
                return this.writeArray("", data, cursor);
            break;

            default:
                assert(false, typeof(this).stringof ~ ".terminate - invalid termination mode");
        }

        return false;
    }
}

