/******************************************************************************

    Struct data serializer

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        October 2012: Initial release

    author:         David Eckardt

    Dumps a struct instance to serialized data, also serializing the contents
    of dynamic arrays in the struct.

 ******************************************************************************/

deprecated module ocean.io.serialize.StructDumper;

/******************************************************************************

    Imports.

 ******************************************************************************/

import ocean.core.Traits: ContainsDynamicArray;

import ocean.io.serialize.model.StructVersionBase;

/******************************************************************************

    Serializes instances of struct type S and keeps a data buffer for the
    serialized data.

 ******************************************************************************/

class StructDumper
{
    /**************************************************************************

        If true the passed buffer reference will never be resized to something
        smaller its current length.
        If false, the passed buffer reference could be set to something smaller
        its current length

     **************************************************************************/

    public bool extend_only = false;

    /***************************************************************************

        Serializes the data in s

        Params:
            s = struct to serialize
            buffer = buffer to write to (resize behavior depending on
                     this.extend_only)

        Template Params:
            S = type of the struct to dump

        See_Also: this.extend_only

    ***************************************************************************/

    void[] opCall ( S ) ( ref void[] buffer, ref S s )
    {
        return this.dump(buffer, s, this.extend_only);
    }

    /**************************************************************************

        Serializes the data in s.

        If S.StructVersion exists, the version will be written in the first byte
        of the serialized data.

        Params:
            s            = instance of S to serialize
            extend_only  = if true the passed buffer reference will never be
                           resized to something smaller its current length.
                           if false, the passed buffer reference could be set to
                           something smaller its current length
        Template Params:
            S = struct type

        Returns:
            the data serialized from s.

     **************************************************************************/

    static void[] dump ( S ) ( ref void[] buffer, ref S s, bool extend_only = false )
    {
        static if ( StructVersionBase.hasVersion!(S)() )
        {
            StructVersionBase.Version version_ = StructVersionBase.getStructVersion!(S);

            auto resized = resize(buffer, DumpArrays.length(s) + version_.sizeof,
                                  extend_only);

            resized[0 .. StructVersionBase.Version.sizeof] = (cast(void*)&version_)
                                        [0 .. StructVersionBase.Version.sizeof];

            DumpArrays.dump(s, resized[StructVersionBase.Version.sizeof.. $]);

            return resized;
        }
        else
        {
            return DumpArrays.dump(s, resize(buffer, DumpArrays.length(s),
                                             extend_only));
        }
    }

    /***************************************************************************

        Return the serialized length of input

        Template Params:
            type of the struct

        Params:
            input = struct to get the serialized length of

        Returns:
            serialized length of input

    ***************************************************************************/

    static size_t length ( S ) ( ref S input )
    {
        static if ( StructVersionBase.hasVersion!(S)() )
        {
            return DumpArrays.length(input) + StructVersionBase.Version.sizeof;
        }
        else
        {
            return DumpArrays.length(input);
        }
    }

    /***************************************************************************

        Resizes the passed buffer reference

        Params:
            buffer = buffer to resize
            len    = length to resize to
            extend_only  = if true the passed buffer reference will never be
                           resized to something smaller its current length.
                           if false, the passed buffer reference could be set to
                           something smaller its current length

        Returns:
            slice to the potentially resized buffer

    ***************************************************************************/

    private static void[] resize ( ref void[] buffer, size_t len, bool extend_only = false )
    out (buffer_out)
    {
        assert (buffer_out.ptr is buffer.ptr);

        if (extend_only)
        {
            assert (buffer_out.length <= buffer.length);
        }
        else
        {
            assert (buffer_out.length == buffer.length);
        }
    }
    body
    {
        if (len != buffer.length)
        {
            if (buffer is null)
            {
                buffer = new ubyte[len];
            }
            else if (len > buffer.length || !extend_only)
            {
                buffer.length = len;
            }
        }

        return buffer[0 .. len];
    }
}

class BufferedStructDumper : StructDumper
{
    /**********************************************************************

        Internal data buffer of variable length.

     **********************************************************************/

    private void[] buffer;

    /**********************************************************************

        Actual valid data in the buffer.

     **********************************************************************/

    private void[] data_;

    /**********************************************************************

        Disposer.

     **********************************************************************/

    protected override void dispose ( )
    {
        if (this.buffer)
        {
            delete this.buffer;
        }
    }

    /**********************************************************************

        Makes sure that data_ always slices the head of buffer.

     **********************************************************************/

    invariant ( )
    {
        assert (this.data_.ptr    == this.buffer.ptr);
        assert (this.data_.length <= this.buffer.length);
    }

    /**************************************************************************

        Constructor.

        Params:
            n = number of bytes to preallocate the internal buffer.

     **************************************************************************/

    public this ( size_t n = 0 )
    {
        this.buffer = new ubyte[n];

        // Set this.data_ so that the class invariant won't fail.

        this.data_ = this.buffer[0 .. 0];
    }

    /**************************************************************************

        Serializes the data in s.

        Params:
            s = instance of S to serialize

        Template Params:
            S = type of the struct to dump

        Returns:
            the data serialized from s.

        See_Also: extend_only

     **************************************************************************/

    public void[] opCall ( S ) ( ref S s )
    {
        return this.data_ = super.opCall(this.buffer, s);
    }

    /**************************************************************************

        Obtains the data of the most recent serialized instance of S.

        Returns:
            the data f the most recent serialized instance of S.

     **************************************************************************/

    void[] opSlice ( )
    {
        return this.data_;
    }

    /**************************************************************************

        Minimizes the length of the internal data buffer.
        This is only meaningful if contains_dynamic_array and extend_only are
        true.

     **************************************************************************/

    void minimize ( )
    {
        if (this.buffer.length != this.data_.length)
        {
            this.buffer.length = this.data_.length;
            this.data_         = this.buffer;
        }
    }
}

/******************************************************************************

    Actual serialization functions.

    TODO: Move these into a separate module.

 ******************************************************************************/

struct DumpArrays
{
    static:

    /**************************************************************************

        Calculates the length of the serialized data of s.

        Params:
            s = S instance to calculate the length of the serialized data for

        Returns:
            the length of the serialized data of s.

     **************************************************************************/

    size_t length ( S ) ( S s )
    {
        static if (ContainsDynamicArray!(S))
        {
            return s.sizeof + arraysLength(s);
        }
        else
        {
            return s.sizeof;
        }
    }

    /**************************************************************************

        Calculates the length of the serialized dynamic arrays in s.

        Params:
            s = S instance to calculate the length of the serialized dynamic
                arrays for

        Returns:
            the length of the serialized dynamic arrays of s.

     **************************************************************************/

    size_t arraysLength ( S ) ( ref S s )
    {
        size_t len = 0;

        static if (ContainsDynamicArray!(S)) foreach (i, ref field; s.tupleof)
        {
            alias typeof (field) T;

            static if (is (T == struct))
            {
                // Recurse into struct field.

                len += arraysLength(field);
            }
            else static if (is (T Base : Base[]))
            {
                static if (is (Base[] == T))
                {
                    // Dump dynamic array.

                    len += arrayLength(field);
                }
                else static if (ContainsDynamicArray!(Base))
                {
                    // Recurse into static array elements which contain a
                    // dynamic array.

                    foreach (element; s.tupleof[i])
                    {
                        len += arrayLength(field);
                    }
                }
            }
            else static if (is (T == union))
            {
                static assert (!ContainsDynamicArray!(T),
                               T.stringof ~ " " ~ s.tupleof[i].stringof ~
                               " - unions containing dynamic arrays are is not "
                               "allowed, sorry");
            }
        }

        return len;
    }

    /**************************************************************************

        Calculates the length of the serialized dynamic arrays in all elements
        of array.

        Params:
            array = array to calculate the length of the serialized dynamic
                    arrays in all elements

        Returns:
             the length of the serialized dynamic arrays in all elements of
             array.

     **************************************************************************/

    size_t arrayLength ( T ) ( T[] array )
    {
        size_t len = size_t.sizeof;

        static if (is (T Base == Base[]))
        {
            // array is a dynamic array of dynamic arrays.

            foreach (element; array)
            {
                len += arrayLength(element);
            }
        }
        else
        {
            // array is a dynamic array of values.

            len += array.length * T.sizeof;

            static if (ContainsDynamicArray!(T))
            {
                foreach (element; array)
                {
                    len += elementLength(element);
                }
            }
        }

        return len;
    }

    /**************************************************************************

        Calculates the length of the serialized dynamic arrays in element.

        Params:
            element = element to calculate the length of the serialized dynamic
                      arrays

        Returns:
             the length of the serialized dynamic arrays in element.

     **************************************************************************/

    size_t elementLength ( T ) ( T element )
    {
        static assert (ContainsDynamicArray!(T), T.stringof ~
                       " contains no dynamic array - nothing to do");


        static if (is (T == struct))
        {
            static if (ContainsDynamicArray!(T))
            {
                return arraysLength(element);
            }
        }
        else static if (is (T Base : Base[]))
        {
            static assert (!is (Base[] == T),
                           "expected a static, not a dynamic array of " ~ T.stringof);

            size_t len = 0;

            foreach (subelement; element)
            {
                len += elementLength(subelement);
            }

            return len;
        }
        else
        {
            static assert (false,
                           "struct or static array expected, not " ~ T.stringof);
        }
    }

    /**************************************************************************

        Serializes the data in s.

        Params:
            s    = instance of S to serialize
            data = destination buffer

        Returns:
            the data serialized from s, slices data[0 .. length(s)].

        In:
            data.length must be at least length(s).

        Out:
            The returned slice references data[0 .. length(s)].

     **************************************************************************/

    void[] dump ( S ) ( ref S s, void[] data )
    in
    {
        assert (data.length >= length(s), "Destination buffer too small!");
    }
    out (data_out)
    {
        assert (data_out.ptr == data.ptr);
        assert (data_out.length == length(s));
    }
    body
    {
        S* s_dumped = cast (S*) data[0 .. S.sizeof];

        *s_dumped = s;

        static if (ContainsDynamicArray!(S))
        {
            void[] remaining = dumpArrays(*s_dumped, data[S.sizeof .. $]);

            return data[0 .. $ - remaining.length];
        }
        else
        {
            return data[0 .. s.sizeof];
        }
    }

    /**************************************************************************

        Serializes the dynamic array data in s and sets the dynamic arrays to
        null.

        Params:
            s    = instance of S to serialize and reset the dynamic arrays
            data = destination buffer

        Returns:
            the tail of data, starting with the next after the last byte that
            was populated.

     **************************************************************************/

    void[] dumpArrays ( S ) ( ref S s, void[] data )
    {
        static if (ContainsDynamicArray!(S)) foreach (i, T; typeof (s.tupleof))
        {
            static if (is (T == struct))
            {
                // Recurse into struct field.

                data = dumpArrays(s.tupleof[i], data);
            }
            else static if (is (T Base : Base[]))
            {
                static if (is (Base[] == T))
                {
                    // Dump dynamic array.

                    data = dumpArray(s.tupleof[i], data);

                    s.tupleof[i] = null;
                }
                else static if (ContainsDynamicArray!(Base))
                {
                    // Recurse into static array elements which contain a
                    // dynamic array.

                    foreach (element; s.tupleof[i])
                    {
                        data = dumpArray(s.tupleof[i], data);
                    }
                }
            }
            else static if (is (T == union))
            {
                static assert (!ContainsDynamicArrays!(T),
                               T.stringof ~ " " ~ s.tupleof[i].stringof ~
                               " - unions containing dynamic arrays are is not "
                               "allowed, sorry");
            }
        }

        return data;
    }

    /**************************************************************************

        Serializes array and the dynamic arrays in all of its elements and sets
        the dynamic arrays, including array itself, to null.

        Params:
            array = this array and all dynamic subarrays will be serialized and
                    reset
            data  = destination buffer

        Returns:
            the tail of data, starting with the next after the last byte that
            was populated.

     **************************************************************************/

    void[] dumpArray ( T ) ( T[] array, void[] data )
    {
        *cast (size_t*) data[0 .. size_t.sizeof] = array.length;

        data = data[size_t.sizeof .. $];

        if (array.length)
        {
            static if (is (T Base == Base[])) foreach (ref element; array)
            {
                // array is a dynamic array of dynamic arrays:
                // Recurse into subarrays.

                data = dumpArray(element, data);
            }
            else
            {
                // array is a dynamic array of values: Dump array.

                size_t n = array.length * T.sizeof;

                T[] dst = (cast (T[]) (data[0 .. n]));

                data = data[n .. $];

                dst[] = array[];

                static if (ContainsDynamicArray!(T))
                {
                    // array is an array of structs or static arrays which
                    // contain dynamic arrays: Recurse into array elements.

                    data = dumpArrayElements(dst, data);
                }
            }
        }

        return data;
    }

    /**************************************************************************

        Serializes the dynamic arrays in all elements of array and sets them to
        null.

        Params:
            array = the dynamic arrays of all members of this array will be
                    serialized and reset
            data  = destination buffer

        Returns:
            the tail of data, starting with the next after the last byte that
            was populated.

     **************************************************************************/

    void[] dumpArrayElements ( T ) ( T[] array, void[] data )
    {
        // array is a dynamic array of structs or static arrays which
        // contain dynamic arrays.

        static assert (ContainsDynamicArray!(T), "nothing to do for " ~ T.stringof);

        static if (is (T == struct)) foreach (ref element; array)
        {
            data = dumpArrays(element, data);
            resetReferences(element);
        }
        else static if (is (T Base : Base[]))
        {
            static assert (!is (Base[] == T),
                           "expected static, not dynamic array of " ~ T.stringof);

            foreach (element; array)
            {
                data = dumpElement(element, data);
                resetArrayReferences(element);
            }
        }
        else
        {
            static assert (false);
        }

        return data;
    }

    /**************************************************************************

        Resets all dynamic arrays in s to null.

        Params:
            s = struct instance to resets all dynamic arrays

        Returns:
            a pointer to s

     **************************************************************************/

    static S* resetReferences ( S ) ( ref S s )
    {
        static assert (is (S == struct), "struct expected, not " ~ S.stringof);
        static assert (ContainsDynamicArray!(S), "nothing to do for " ~ S.stringof);

        foreach (i, T; typeof (s.tupleof))
        {
            static if (is (T == struct))
            {
                // Recurse into field of struct type if it contains
                // a dynamic array.
                static if (ContainsDynamicArray!(T))
                {
                    resetReferences(s.tupleof[i]);
                }
            }
            else static if (is (T Base : Base[]))
            {
                static if (is (Base[] == T))
                {
                    // Reset field of dynamic array type.

                    s.tupleof[i] = null;
                }
                else static if (ContainsDynamicArray!(Base))
                {
                    // Field of static array that contains a dynamic array:
                    // Recurse into field array elements.

                    resetArrayReferences(s.tupleof[i]);
                }
            }
            else static if (is (T == union))
            {
                static assert (!ContainsDynamicArrays!(T),
                               T.stringof ~ " " ~ s.tupleof[i].stringof ~
                               " - unions containing dynamic arrays are is not "
                               "allowed, sorry");
            }
        }

        return &s;
    }

    /**************************************************************************

        Resets all dynamic arrays in all elements of array to null.

        Params:
            array = all dynamic arrays in all elements of this array will be
                    reset to to null.

        Returns:
            array

     **************************************************************************/

    static T[] resetArrayReferences ( T ) ( T[] array )
    {
        static assert (ContainsDynamicArray!(T), "nothing to do for " ~ S.stringof);

        static if (is (T Base : Base[]))
        {
            static if (is (Base[] == T))
            {
                // Reset elements of dynamic array type.

                array[] = null;
            }
            else foreach (element; array)
            {
                // Recurse into static array elements.

                resetArrayReferences(element);
            }
        }
        else foreach (ref element; array)
        {
            static assert (is (T == struct), "struct expected, not " ~ T.stringof);

            // Recurse into struct elements.

            resetReferences(element);
        }

        return array;
    }
}
