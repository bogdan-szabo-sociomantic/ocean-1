/******************************************************************************

    Interruptable/resumable in-place binary protocol data deserializer for
    event-driven non-blocking I/O.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
    
    Designed to be used within an EpollWriter IOHandler. 
    
 ******************************************************************************/

module ocean.io.select.protocol.serializer.SelectSerializer;

/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.io.model.IConduit: InputStream;

private import tango.math.Math: min;

private import tango.core.Exception:              IOException;
private import ocean.core.Exception:              assertEx;

debug private import tango.util.log.Trace;

/******************************************************************************

    SelectDeserializer structure

 ******************************************************************************/

struct SelectSerializer
{
    /**************************************************************************

        Contains only static methods
    
     **************************************************************************/

    static:
    
    /**************************************************************************

        Serializes and sends data from item; increases cursor by the amount
        of bytes taken from data. item may be of scalar or array type.
        
        Params:
            item   = item to send
            data   = output data buffer
            cursor = input data cursor index
            
        Returns:
            true if more data are pending or false if finished

     **************************************************************************/

    public bool send ( T ) ( T item, void[] data, ref ulong cursor )
    {
        static if (is (T U : U[]))
        {
            return sendArray(item, data, cursor);
        }
        else
        {
            return sendValue(item, data, cursor);
        }
    }


    /**************************************************************************

        Serializes and sends an array, without first sending the array's length.
        Increases cursor by the amount of bytes taken from the array.
        
        Params:
            array  = array to send
            data   = output data buffer
            cursor = input data cursor index
            
        Returns:
            true if more data are pending or false if finished
    
     **************************************************************************/

    public bool sendArrayWithoutLength ( T ) ( T[] array, void[] data_out, ref ulong cursor )
    {
        void* data = array.ptr;
        
        ulong data_start = cursor;
        ulong end = T.sizeof * array.length;
        ulong len = min(data_out.length, end - data_start);
        
        cursor += len;
        
        data_out[0 .. len] = data[data_start .. cursor];
        
        return cursor < end;
    }


    /**************************************************************************
    
        Serializes and sends value. Increases cursor by the number of bytes
        sent.
    
        Params:
            value    = value to send
            data_out = output data buffer
            cursor   = input data cursor index
            
        Returns:
            true if more data are pending or false if finished
    
     **************************************************************************/

    private bool sendValue ( T ) ( T value, void[] data_out, ref ulong cursor )
    in
    {
        assert (cursor <= T.sizeof, "sendValue: start index out of range");
    }
    body
    {
        void*  data  = &value;
        
        ulong start = cursor;
        const  end   = T.sizeof;
        ulong len   = min(data_out.length, end - start);
        
        cursor += len;
        
        data_out[0 .. len] = data[start .. cursor];
        
        return cursor < end;
        
    }


    /**************************************************************************
    
        Serializes and sends array. Increases cursor by the number of bytes
        sent.
    
        Params:
            array    = array to send
            data_out = output data buffer
            cursor   = input data cursor index
            
        Returns:
            true if more data are pending or false if finished
    
     **************************************************************************/

    private bool sendArray ( T ) ( T[] array, void[] data_out, ref ulong cursor )
    in
    {
        assert (cursor <= T.sizeof * array.length + size_t.sizeof, "sendArray: start index out of range");
    }
    body
    {
        ulong start = cursor;
        
        bool sent_length = false;
        
        bool more        = true;
        
        if (cursor < size_t.sizeof)
        {
            sent_length = !sendValue(array.length, data_out, cursor);
        }
        
        if (cursor >= size_t.sizeof)
        {
            cursor -= size_t.sizeof;
            
            scope (exit) cursor += size_t.sizeof;
            
            void*  data  = array.ptr;
            
            ulong offset = sent_length? size_t.sizeof - start : 0;
            
            ulong data_start = cursor;
            ulong end        = T.sizeof * array.length;
            ulong len        = min(data_out.length - offset, end - data_start);
            
            cursor += len;
            
            data_out[offset .. len + offset] = data[data_start .. cursor];
            
            more = cursor < end;
        }
        
        return more;
    }
}