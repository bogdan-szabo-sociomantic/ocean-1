/******************************************************************************

    Interruptable/resumable in-place binary protocol data deserializer for
    event-driven non-blocking I/O.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
    
    Designed to be used within an SelectWriter IOHandler. 
    
 ******************************************************************************/

module ocean.io.select.protocol.serializer.SelectDeserializer;

/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.io.model.IConduit: OutputStream;

private import tango.math.Math:      min;

private import tango.stdc.string:    memcpy;

private import tango.core.Exception: IOException;
private import ocean.core.Exception: assertEx;

debug private import tango.util.log.Trace;

/******************************************************************************

    SelectDeserializer structure

 ******************************************************************************/

struct SelectDeserializer
{
    /**************************************************************************

        Contains only static methods

     **************************************************************************/

    static:
    
    /**************************************************************************

        Receives and deserializes item; increases cursor by the number of bytes
        taken from data. item may be of scalar or array type.
        
        If item is an array (or string), its content is preceeded by the
        string/array length represented as size_t value.
        For arrays/strings the first elements are used as intermediate buffer
        to store the total amount of data to be received. Thus, array length
        will initially be size_t.sizeof (typically 4 bytes). Until finished, the
        array must not be changed from outside.
        
        Params:
            item   = item to receive data for
            data   = input data
            cursor = output data cursor index
            
        Returns:
            true if more data are required or false if finished

     **************************************************************************/

    public bool receive ( T ) ( ref T item, void[] data, ref ulong cursor )
    {
        static if (is (T U : U[]))
        {
            return receiveArray(item, data, cursor);
        }
        else
        {
            return receiveValueData(&item, T.sizeof, data, cursor);
        }
    }
    
    /**************************************************************************

        Receives and deserializes data for array; increases cursor by the number
        of bytes taken from data.
        
        The first elements are used as intermediate buffer to store the total
        amount of data to be received. Thus, array length will initially be
        size_t.sizeof (typically 4 bytes). Until finished, the array must not be
        changed from outside.
        
        As an option, the raw array data, including the leading byte length
        value, can be stored in array. To do so, set strip_length to true; array
        must then be of type void[].
        
        Params:
            array  = array to receive
            data   = input data
            cursor = output data cursor index
            
        Returns:
            true if more data are required or false if finished
    
     **************************************************************************/

    public bool receiveArray ( bool strip_length = true, T ) ( ref T[] array, void[] data, ref ulong cursor )
    {
        const size_storage_len = Size_tElements!(T);
        
        static if (strip_length)
        {
            const size_t array_offset = 0;
        }
        else
        {
            const size_t array_offset = size_t.sizeof;
        }
        
        bool more            = true;
        
        size_t start         = cursor;
        
        size_t data_start    = 0;
        
        if (!cursor && array.length != size_storage_len)
        {
            array.length = size_storage_len;
        }
        
        if (cursor < size_t.sizeof)
        {
            assert (array.length == size_storage_len);

            size_t items_to_receive;

            bool received_length = !receiveArrayLength(array, items_to_receive, data, cursor);

//            Trace.formatln("received_length = {}, array length to receive = {}", received_length, items_to_receive);

            if (received_length)
            {
                setArrayLength!(strip_length, T)(array, items_to_receive * T.sizeof);

                data_start = size_t.sizeof - start;
            }
        }
        
        return receiveArrayContent(array, array_offset, data[data_start .. $], cursor);
    }
    
    /**************************************************************************

        Sets the length of array to (bytes / T.sizeof).
        
        If strip_length is false, size_t.sizeof is added the array length as
        extra space for the leading length value. This is supported for raw
        data (void[]) only to avoid data aligning mismatches and seemingly
        corrupted output data.
        
        IMPORTANT NOTE: If bytes is not divisable by T.sizeof, the resulting
        array byte length will be less than bytes; this will likely lead to
        protocol confusion.
        Hence, before an array of base type T is sent, it must be sure that its
        byte length equals T * array.length. 
        
        Params:
            array        = destination array
            array_offset = start position in array
            data         = input data
            cursor       = output data cursor index
            
     **************************************************************************/

    private static void setArrayLength ( bool strip_length = true, T ) ( ref T[] array, size_t bytes )
    {
        static if (strip_length)
        {
            array.length = bytes / T.sizeof;
        }
        else
        {
            static assert (is (T == void), "Preserving length is only supported for raw data ('void[]'), not '" ~ T.stringof ~ "[]'");
            
            array.length = bytes + size_t.sizeof;
            
            *cast (size_t*) array.ptr = bytes;
        }
    }
    
    /**************************************************************************

        Receives the content of array. The array will be populated starting
        from index array_offset. The cursor is expected to have an offset of
        size_t.sizeof as a result of receiving the leading array length value.
        
        Params:
            array        = destination array
            array_offset = start position in array
            data         = input data
            cursor       = output data cursor index
            
        Returns:
            true if more data are required or false if finished
    
     **************************************************************************/
    
    private bool receiveArrayContent ( void[] array, size_t array_offset, void[] data, ref ulong cursor )
    {
        bool more = true;
        
        if (cursor >= size_t.sizeof)
        {
            cursor -= size_t.sizeof;
            
            scope (exit) cursor += size_t.sizeof;
            
            more = receiveValueData(array.ptr + array_offset, array.length - array_offset, data, cursor);
        }
        
        return more;
    }
    
    /**************************************************************************

        Appends bytes from data to dst so that dst gets the length of end,
        starting at cursor in dst.
        Increases cursor by the number of bytes taken from data.
        
        Params:
            dst    = destination buffer
            end    = destination buffer length
            data   = input data
            cursor = output data cursor index
            
        Returns:
            true if more data are required or false if finished
    
     **************************************************************************/

    private bool receiveValueData ( void* dst, size_t end, void[] data, ref ulong cursor )
    in
    {
        assert (cursor <= end, "receiveValueData: start index out of range");
    }
    body
    {
        size_t start = cursor;
        size_t len   = min(data.length, end - start);
        
        cursor += len;
        
        dst[start .. cursor] = data[0 .. len];
        
        return cursor < end;
    }
    
    /**************************************************************************

        Receives the preceeding length value of array and stores it at the
        beginning of the array.
        
        Params:
            array  = destination array
            len    = length of array
            data   = input data
            cursor = output data cursor index
            
        Returns:
            true if more data are required or false if finished
    
     **************************************************************************/

    private bool receiveArrayLength ( void[] array, out size_t len, void[] data, ref ulong cursor )
    in
    {
        assert (array.length >= size_t.sizeof,
                typeof (this).stringof ~ ".receiveArrayLength: incoming array too short");
    }
    body
    {
        bool more = receiveValueData(array.ptr, size_t.sizeof, data, cursor);
        
        if (!more)
        {
            len = *cast (size_t*) array.ptr;
        }
        
        return more;
    }
    
    /**************************************************************************

        Calculates the number of elements of an array of base type T required
        to hold a size_t value.
    
     **************************************************************************/
    
    template Size_tElements ( T )
    {
        const Size_tElements = size_t.sizeof / T.sizeof + !!(size_t.sizeof % T.sizeof);
    }
}