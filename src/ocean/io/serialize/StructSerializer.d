/******************************************************************************

    Struct data serialization and deserialization tools

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        Aug 2010: Initial release

    authors:        David Eckardt, Gavin Norman

    Serializes data of value type fields and dynamic array of value type members
    of a struct instance, recursing into struct members if present.


    !!!!                             Warning                                !!!!
    !!!!                          -------------                             !!!!
    !!!!           The use of dynamic arrays has a big effect on            !!!!
    !!!!           the performance and should be done with care             !!!!

    Values of struct fields of these types will be serialized and restored at
    serialization:

        - Basic value types: numeric types, char types
        - Static arrays of basic value types

    Struct members, which are dynamic arrays of basic value types, are
    serialized and restored as well. However, care must be take if
    deserialization is done repeatedly to avoid a memory leak condition. This
    can be done by following deserialization step 0.

    Multi-dimensional arrays are supported.
    Arrays of structs, which do not contain reference types (as defined below),
    are supported.

    Values of struct fields of reference types will be set to null at
    serialization and not restored at serialization. Reference types are:

            - pointers, dynamic arrays, associative arrays,
            - classes, interfaces
            - delegates, function references

    Note that the content of associative arrays is currently discarded. In other
    words, associoative arrays must be dumped and loaded separately.

    Struct fields of these types are (currently) not supported:

            - arrays of reference types listed above
            - unions
            - typedefs

    In particular, serialization is done in the following steps:

        1. All reference type fields of the provided struct are set to null,
           recursing into struct members if present.

        2. The raw data image of the struct is written; this image includes the
           data of all sub-struct members since structs are value types.

        3. For each dynamic array member of the struct and its sub-structs the
           array data are serialized. That is,
            - first the array raw data byte length is written as a raw data
              image of a size_t value,
            - then the array content raw data is written.

    Deserialization is done in these steps:

        0. Before populating a struct instance by deserialization, the reference
           type members can be set to a valid instance. If not, that type
           members will be null, and a new array instance will created when the
           dynamic array members are restored.
           Thus, if deserialization is done repeatedly with the same struct
           instance, it is recommended to set the dynamic array members to
           existing array instances in order to avoid a memory leak condition.

        1. The raw data image of the struct is read; this image includes the
           data of all sub-struct members since structs are value types.

        2. For each dynamic array member of the struct and its sub-structs the
           array data are deserialized. That is,
            - first the array raw data byte length is read from a raw data image
              of a size_t value,
            - then the array length is calculated from the byte length and the
              array element type,
            - after that the array length is set to the calculated length,
            - finally the array content raw data is read and the array populated
              with it.

 ******************************************************************************/

module ocean.io.serialize.StructSerializer;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.serialize.SimpleSerializer;

import ocean.core.Exception;

import tango.io.model.IConduit: IOStream, InputStream, OutputStream;

import tango.core.Traits;



/*******************************************************************************

    SerializerException

*******************************************************************************/

class SerializerException : Exception
{
    mixin DefaultExceptionCtor;

    /***************************************************************************

        StructSerializer Exception

    ***************************************************************************/

    static class LengthMismatch : SerializerException
    {
        size_t bytes_expected, bytes_got;

        this ( size_t bytes_expected, size_t bytes_got,
               istring msg, istring file, typeof(__LINE__) line )
        {
            super(msg, file, line);

            this.bytes_expected = bytes_expected;
            this.bytes_got      = bytes_got;
        }
    }
}


/*******************************************************************************

    Struct serializer

    Template params:
        AllowUnions = if true, unions will be serialized as raw bytes, without
            checking whether the union contains dynamic arrays. Otherwise unions
            cause a compile-time error.

    TODO: proper union support -- must recurse into unions looking for dynamic
    arrays

*******************************************************************************/

struct StructSerializer ( bool AllowUnions = false )
{
    import ocean.core.Traits : ContainsDynamicArray, FieldName, FieldType, GetField;
    import tango.core.Traits : isAssocArrayType;

    static:

    /**************************************************************************

        Calculates the serialized byte length of s, including array fields.

        Params:
            s = struct instance (pointer)

        Returns:
            serialized byte length of s

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    size_t length ( S ) ( S* s )
    in
    {
        assertStructPtr!("length")(s);
    }
    body
    {
        return S.sizeof + subArrayLength(s);
    }

    /**************************************************************************

        Dumps/serializes the content of s and its array members.
        THe method will resize the output array to fit the size of the content.

        Params:
            s    = struct instance (pointer)
            data = output buffer to write serialized data to

        Returns:
            amount of data written to the buffer

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    size_t dump ( S, D ) ( S* s, ref D[] data )
    {
        mixin AssertSingleByteType!(D, typeof (*this).stringof ~ ".dump");

        size_t written = 0;

        scope (exit) data.length = written;

        return dump(s, (void[] chunk)
        {
            if (chunk.length + written > data.length)
            {
                data.length = chunk.length + written;
            }

            data[written .. written + chunk.length] = cast(D[]) chunk[];

            written += chunk.length;
         });
    }


    /**************************************************************************

        Dumps/serializes the content of s and its array members.
        THe method won't resize the output array to fit the content, it will
        rather try to use it as it is.

        Params:
            s    = struct instance (pointer)
            data = output buffer to write serialized data to, size must fit
                   the struct (use length() to get the required size)

        Returns:
            amount of data written to the buffer

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    size_t dumpStatic ( S, D ) ( S* s, D[] data )
    {
        mixin AssertSingleByteType!(D, typeof (*this).stringof ~ ".dump");

        size_t written = 0;

        return dump(s, (void[] chunk)
        {
            assert ( data.length >= written + chunk.length, "output buffer too small!" );

            data[written .. written + chunk.length] = cast(D[]) chunk[];

            written += chunk.length;
         });
    }


    /**************************************************************************

        Loads/deserializes the content of s and its array members.

        Params:
            s     = struct instance (pointer)
            data  = input buffer to read serialized data from
            slice = optional. If true, will set dynamical arrays to
                    slices of the provided buffer.
                    Warning: Do not serialize a struct into the same buffer
                             it was deserialized from.
        Throws:
            Exception if data is too short

        Returns:
            number of bytes consumed from data

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    size_t load ( S, D ) ( S* s, D[] data )
    {
        mixin AssertSingleByteType!(D, typeof (*this).stringof ~ ".load");

        size_t start = 0;

        return load(s, ( void[] chunk )
        {
            size_t end = start + chunk.length;

            assertLongEnough(end, data.length);

            chunk[] = (cast (void[]) data)[start .. end];

            start = end;
        });
    }

    /**************************************************************************

        Sets s to reference data and the array members of s to slice the
        corresponding data sections. As a result, no data are moved and s can
        be used as if it would be a pointer to a struct.

        Params:
            s     = struct instance pointer output
            data  = input buffer of serialized struct data to reference to

        Returns:
            number of bytes used from data

        Throws:
            Exception if data is too short

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    size_t loadSlice ( D, S ) ( out S* s, D[] data )
    {
        mixin AssertSingleByteType!(D, typeof (*this).stringof ~ ".loadSlice");

        const size_t pos = S.sizeof;

        assertLongEnough(pos, data.length);

        s = cast (S*) data.ptr;

        return sliceArrays(s, (cast (void[]) data)[pos .. $]) + pos;
    }

    /**************************************************************************

        Use loadSlice() instead.

     **************************************************************************/

    deprecated size_t load ( S, D ) ( S* s, D[] data, bool slice )
    {
        assert (false);
        return 0;
    }


    /**************************************************************************

        Sets s to reference data and the array members of s to slice the
        corresponding data sections. As a result, no data are moved and s can
        be used as if it would be a pointer to a struct.

        Params:
            data  = input buffer of serialized struct data to reference to

        Returns:
            struct instance pointer output

        Throws:
            Exception if data is too short

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    S loadSlice ( S, D ) ( D[] data, out size_t n )
    in
    {
        static if (is (S T == T*))
        {
            static assert (is (T == struct), typeof (*this).stringof ~
                           ".loadSlice: need pointer to a struct, not '" ~ T.stringof ~ '\'');
        }
        else if (is (S == struct))
        {
            static assert (false, typeof (*this).stringof ~ ".loadSlice: need a"
                           " pointer to struct (hint: use '" ~ S.stringof ~ "*'"
                           " instead of '" ~ S.stringof ~ "')");
        }
        else static assert (false, typeof (*this).stringof ~ ".loadSlice: need "
                            "a pointer to struct, not '" ~ S.stringof ~ '\'');
    }
    body
    {
        S s;

        n = loadSlice(s, data);

        return s;
    }

    /**************************************************************************

        Dumps/serializes the content of s and its array members, writing
        serialized data to output.

        Params:
            s      = struct instance (pointer)
            output = output stream to write serialized data to

        Returns:
            number of bytes written

     **************************************************************************/

    size_t dump ( S ) ( S* s, OutputStream output )
    {
        return dump(s, (void[] data) {SimpleSerializer.transmit(output, data);});
    }

    /**************************************************************************

        Dumps/serializes the content of s and its array members.

        send is called repeatedly; on each call, it must store or forward the
        provided data.

        Params:
            s    = struct instance (pointer)
            send = sending callback delegate

        Returns:
            number of bytes written

     **************************************************************************/

    size_t dump ( S ) ( S* s, void delegate ( void[] data ) receive )
    in
    {
        assertStructPtr!("dump")(s);
    }
    body
    {
        return transmit!(false)(s, receive);
    }

    /**************************************************************************

        Loads/deserializes the content of s and its array members, reading
        serialized data from input.

        Params:
            s     = struct instance (pointer)
            input = input stream to read data from

        Returns:
            number of bytes read

     **************************************************************************/

    size_t load ( S ) ( S* s, InputStream input )
    {
        return load(s, (void[] data) {SimpleSerializer.transmit(input, data);});
    }

    /**************************************************************************

        Loads/deserializes the content of s and its array members.

        receive is called repeatedly; on each call, it must populate the
        provided data buffer with data previously produced by dump(). Data which
        was populated once should not be populated again. So the delegate must
        behave like a stream receive function.

        Params:
            s       = struct instance (pointer)
            receive = receiving callback delegate

        Returns:
            number of bytes read

     **************************************************************************/

    size_t load ( S ) ( S* s, void delegate ( void[] data ) receive )
    in
    {
        assertStructPtr!("load")(s);
    }
    body
    {
        return transmit!(true)(s, receive);
    }

    /**************************************************************************

        Dumps/serializes or loads/deserializes the content of s and its
        members.

        transmit_data is called repeatedly; on each call,
         - if receive is false, it must it must store or forward the provided
           data;
         - if receive is true, it must populate the provided data buffer with
           data previously produced by dump(). Data which was populated once
           should not be populated again. So the delegate must behave like a
           stream receive function.

        Params:
            s             = struct instance (pointer)
            transmit_data = sending/receiving callback delegate

        Returns:
            number of bytes read or written

     **************************************************************************/

    size_t transmit ( bool receive, S ) ( S* s, void delegate ( void[] data ) transmit_data )
    in
    {
        assert (s, typeof (*this).stringof ~ ".transmit (receive = " ~
                receive.stringof ~ "): source pointer of type '" ~ S.stringof ~
                "*' is null");
    }
    body
    {
        S s_copy = *s;

        S* s_copy_ptr = &s_copy;

        static if (receive)
        {
            transmit_data((cast (void*) s)[0 .. S.sizeof]);

            copyReferences(s_copy_ptr, s);
        }
        else
        {
            resetReferences(s_copy_ptr);

            transmit_data((cast (void*) s_copy_ptr)[0 .. S.sizeof]);
        }

        return S.sizeof + transmitArrays!(receive)(s, transmit_data);
    }


    /**************************************************************************

        Dumps/serializes the content of s and its array members, using the given
        serializer object. The serializer object needs the following methods:

            void open ( D, char[] name );

            void close ( D, char[] name );

            void serialize ( T ) ( D, ref T item, char[] name );

            void openStruct ( D, char[] name );

            void closeStruct ( D, char[] name );

            void serializeArray ( T ) ( D, char[] name, T[] array );

              Optional:

                void serializeStaticArray ( T ) ( D, char[] name, T[] array );

              If this methond doesn't exist, serializeArray will be used.

            void openStructArray ( T ) ( D, char[] name, T[] array );

            void closeStructArray ( T ) ( D, char[] name, T[] array );

        Unfortunately, as some of these methods are templates, it's not
        possible to make an interface for it. But the compiler will let you know
        whether a given serializer object is suitable or not ;)

        See ocean.io.serialize.JsonStructSerializer for an example.

        Template params:
            S = type of struct to serialize
            Serializer = type of serializer object
            D = tuple of data parameters passed to the serializer

        Params:
            s    = struct instance (pointer)
            serializer = object to do the serialization
            data = parameters for serializer

     **************************************************************************/

    public void serialize ( S, Serializer, D ... ) ( S* s, Serializer serializer, ref D data )
    {
        serializer.open(data, S.stringof);
        serialize_(s, serializer, data);
        serializer.close(data, S.stringof);
    }


    /**************************************************************************

        Loads/deserializes the content of s and its array members, using the
        given deserializer object. The deserializer object needs the following
        methods:

                void open ( ref Char[] input, char[] name );

                void close ( );

                void deserialize ( T ) ( ref T output, char[] name );

                void deserializeStruct ( ref T output, Char[] name, void delegate ( ) deserialize_struct );

                void deserializeArray ( T ) ( ref T[] output, Char[] name );

                void deserializeStaticArray ( T ) ( T[] output, Char[] name );

                void deserializeStructArray ( T ) ( ref T[] output, Char[] name, void delegate ( ref T ) deserialize_element );

        Unfortunately, as some of these methods are templates, it's not
        possible to make an interface for it. But the compiler will let you know
        whether a given deserializer object is suitable or not ;)

        See ocean.io.serialize.JsonStructDeserializer for an example.

        Params:
            s = struct instance (pointer)
            deserializer = object to do the deserialization
            data = input buffer to read serialized data from

     **************************************************************************/

    public void deserialize ( S, Deserializer, D ) ( S* s, Deserializer deserializer, D[] data )
    {
        deserializer.open(data, S.stringof);
        deserialize_(s, deserializer, data);
        deserializer.close();
    }


    /**************************************************************************

        Calculates the sum of the serialized byte length of all array fields of
        s.

        Params:
            s       = struct instance (pointer)
            receive = receiving callback delegate

        Returns:
            byte length of all array fields of s

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    public size_t subArrayLength ( S ) ( S* s )
    {
        size_t result = 0;

        foreach (i, T; typeof (S.tupleof))
        {
            T* field = GetField!(i, T, S)(s);

            static if (is (T == struct))
            {
                result += subArrayLength(field);                                // recursive call
            }
            else static if (is (T U == U[]))
            {
                mixin AssertSupportedArray!(T, U, S, i);

                result += arrayLength(*field);
            }
            else mixin AssertSupportedType!(T, S, i);
        }

        return result;
    }


    /**************************************************************************

        Calculates the sum of the serialized byte length array which may be
        multidimensional.

        Params:
            array = input array

        Returns:
            byte length of array

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    public size_t arrayLength ( T ) ( T[] array )
    {
        size_t len = size_t.sizeof;

        static if (is (T U == U[]))
        {
            foreach (i, element; array)
            {
                static if (is (U == struct))
                {
                    len += subArrayLength(array.ptr + i);                       // recursive call
                }
                else
                {
                    len += arrayLength(element);                                // recursive call
                }
            }
        }
        else
        {
            len += array.length * T.sizeof;
        }

        return len;
    }

    /**************************************************************************

        Resets all references in s to null.

        Params:
            s = struct instance (pointer)

     **************************************************************************/

    S* resetReferences ( S ) ( S* s )
    {
        foreach (i, T; typeof (S.tupleof))
        {
            T* field = GetField!(i, T, S)(s);

            static if (is (T == struct))
            {
                resetReferences(field);                                         // recursive call
            }
            else static if (isReferenceType!(T))
            {
                *field = null;
            }
        }

        return s;
    }

    /**************************************************************************

        Copies all references from dst to src.

        Params:
            src = source struct instance (pointer)
            dst = destination struct instance (pointer)

     **************************************************************************/

    S* copyReferences ( S ) ( S* src, S* dst )
    {
        foreach (i, T; typeof (S.tupleof))
        {
            T* src_field = GetField!(i, T, S)(src),
               dst_field = GetField!(i, T, S)(dst);

            static if (is (T == struct))
            {
                copyReferences(src_field, dst_field);                           // recursive call
            }
            else static if (isReferenceType!(T))
            {
                *dst_field = *src_field;
            }
        }

        return dst;
    }

    /**************************************************************************

        Transmits (sends or receives) the serialized data of all array fields in
        s.

        Template parameter:
            receive = true: receive array data, false: send array data

        Params:
            s        = struct instance (pointer)
            transmit = sending/receiving callback delegate
            slice    = if true, a slice assignment
                       instead of a copy will be done

        Returns:
            passes through return value of transmit

        FIXME: Does currently not scan static array fields for a struct type
        containing dynamic arrays. Example:

         ---
             struct S1
             {
                 int[] x;
             }

             struct S2
             {

                 S1[7] y;   // elements contain a dynamic array
             }
         ---

     **************************************************************************/

    size_t transmitArrays ( bool receive, S ) ( S* s, void delegate ( void[] array ) transmit )
    {
        size_t bytes = 0;

        foreach (i, T; typeof (S.tupleof))
        {
            T* field = GetField!(i, T, S)(s);

            static if (is (T == struct))
            {
                bytes += transmitArrays!(receive)(field, transmit);             // recursive call
            }
            else static if (is (T U == U[]))
            {
                mixin AssertSupportedArray!(T, U, S, i);

                bytes += transmitArray!(receive)(*field, transmit);
            }
            else mixin AssertSupportedType!(T, S, i);
        }

        return bytes;
    }

    /***************************************************************************

        Transmits (sends or receives) the serialized data of array. That is,
        first transmit the array content byte length as size_t value, then the
        array content raw data.

        Template parameter:
            receive = true: receive array data, false: send array data

        Params:
            array    = array to send serialized data of (pointer)
            transmit = sending/receiving callback delegate
            slice    = if true, a slice assignment
                       instead of a copy will be done

        Returns:
            passes through return value of send

        TODO: array needs to be duped

     **************************************************************************/

    size_t transmitArray ( bool receive, T ) ( ref T[] array, void delegate ( void[] data ) transmit_dg )
    {
        size_t len,
               bytes = len.sizeof;

        static if (!receive)
        {
            len = array.length;
        }

        transmit_dg((cast (void*) &len)[0 .. len.sizeof]);

        static if (receive)
        {
            array.length = len;
        }

        static if (is (T == struct))                                            // recurse into substruct
        {                                                                       // if it contains dynamic
            const RecurseIntoStruct = ContainsDynamicArray!(typeof (T.tupleof));// arrays
        }
        else
        {
            const RecurseIntoStruct = false;
        }

        static if (is (T U == U[]))                                             // recurse into subarray
        {
            foreach (ref element; array)
            {
                bytes += transmitArray!(receive)(element, transmit_dg);
            }
        }
        else static if (RecurseIntoStruct)
        {
            debug ( StructSerializer ) pragma (msg, typeof (*this).stringof  ~ ".transmitArray: "
                               "array elements of struct type '" ~ T.stringof ~
                               "' contain subarrays");

            foreach (ref element; array)
            {
                bytes += transmit!(receive)(&element, transmit_dg);
            }
        }
        else
        {
            size_t n = len * T.sizeof;

            transmit_dg((cast (void*) array.ptr)[0 .. n]);

            bytes += n;
        }

        return bytes;
    }

    /***************************************************************************

        Sets all dynamic array members of s to slice the corresponding sections
        of data. data must be a concatenated sequence of chunks generated by
        transmitArray() for each dynamic array member of S.

        Params:
            s    = pointer to struct instance to set arrays to slice data
            data = array data to slice

        Returns:
            number of data bytes sliced

        Throws:
            Exception if data is too short

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    size_t sliceArrays ( S ) ( S* s, void[] data )
    {
        size_t pos = 0;

        foreach (i, T; typeof (S.tupleof))
        {
            T* field = GetField!(i, T, S)(s);

            static if (is (T == struct))
            {
                pos += sliceArrays(field, data[pos .. $]);
            }
            else static if (is (T U == U[]))
            {
                debug ( StructSerializer ) pragma (msg, "sliceArrays " ~ S.stringof ~ ": " ~ FieldInfo!(T, S, i));

                mixin AssertSupportedArray!(T, U, S, i);

                pos += sliceArray(*field, data[pos .. $]);
            }
            else mixin AssertSupportedType!(T, S, i);
        }

        return pos;
    }

    /***************************************************************************

        Creates an array slice to data. Data must start with a size_t value
        reflecting the byte length, followed by the array content data.

        Params:
            s    = pointer to struct instance to set arrays to slice data
            data = array data to slice

        Returns:
            number of data bytes sliced

        Throws:
            Exception if data is too short

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    size_t sliceArray ( T ) ( out T[] array, void[] data )
    {
        size_t end = size_t.sizeof;

        assertLongEnough(end, data.length);

        size_t len = *cast (size_t*) data.ptr;

        static if (is (T U == U[]))
        {
            debug ( StructSerializer ) pragma (msg, "sliceArray > " ~ U.stringof);

            foreach (ref element; resizeArray(array, len))
            {
                end += sliceArray(element, data[end .. $]);
            }
        }
        else
        {
            debug ( StructSerializer ) pragma (msg, "sliceArray: " ~ T.stringof);

            end += len * T.sizeof;

            assertLongEnough(end, data.length);

            array = (cast (T*) (data.ptr + size_t.sizeof))[0 .. len];
        }

        return end;
    }

    deprecated("For binary serialization, use ocean.util.serialize")
    T[] resizeArray ( T ) ( ref T[] array, size_t len )
    {
        static if (is (T U == U[]))
        {
            if (array.length > len)
            {
                foreach (ref element; array[len .. $])
                {
                    element.length = 0;
                }
            }
        }

        array.length = len;

        return array;
    }

    /**************************************************************************

        Dumps/serializes the content of s and its array members, using the given
        serializer object. See the description of the dump() method above for a
        full description of how the serializer object should behave.

        Template params:
            S = type of struct to serialize
            Serializer = type of serializer object
            D = tuple of data parameters passed to the serializer

        Params:
            s = struct instance (pointer)
            serializer = object to do the serialization
            data = parameters for serializer

     **************************************************************************/

    private void serialize_ ( S, Serializer, D ... ) ( S* s, Serializer serializer, ref D data )
    {
        foreach (i, T; typeof (S.tupleof))
        {
            T*    field = GetField!(i, T, S)(s);
            const field_name = FieldName!(i, S);

            static if ( is(T == struct) )
            {
                serializer.openStruct(data, field_name);
                serialize_(field, serializer, data);                            // recursive call
                serializer.closeStruct(data, field_name);
            }
            else static if( is(T U : U[]) )
            {
                U[] array = *field;

                static if ( is(BaseTypeOfArrays!(U) == struct) )
                {
                    serializeStructArray(array, field_name, serializer, data);
                }
                else static if ( isStaticArrayType!(T) &&
                                 is ( typeof(serializer.serializeStaticArray!(T)) ) )
                {
                    serializer.serializeStaticArray(data, field_name, array);
                }
                else
                {
                    serializer.serializeArray(data, field_name, array);
                }
            }
            else
            {
                mixin AssertSupportedType!(T, S, i);

                static if ( is(T B == enum) )
                {
                    serializer.serialize(data, cast(B)(*field), field_name);
                }
                else static if ( is(T B == typedef) )
                {
                    serializer.serialize(data, cast(B)(*field), field_name);
                }
                else
                {
                    serializer.serialize(data, *field, field_name);
                }
            }
        }
    }

    /**************************************************************************

        Dumps/serializes array which is expected to be a one- or multi-
        dimensional array of structs, using the given serializer object. See the
        description of the dump() method above for a full description of how the
        serializer object should behave.

        Template params:
            T = array base type, should be a struct or a (possibly
                multi-dimensional) array of structs
            Serializer = type of serializer object
            D = tuple of data parameters passed to the serializer

        Params:
            array = array to serialize
            field_name = the name of the struct field that contains the array
            serializer = object to do the serialization
            data = parameters for serializer

     **************************************************************************/

    private void serializeStructArray ( T, Serializer, D ... ) ( T[] array,
        char[] field_name, Serializer serializer, ref D data )
    {
        serializer.openStructArray(data, field_name, array);

        foreach ( ref element; array )
        {
            static if ( is(T U : U[]) )
            {
                serializeStructArray(element, field_name, serializer, data);
            }
            else
            {
                static assert(is(T == struct));
                serializer.openStruct(data, T.stringof);
                serialize_(&element, serializer, data);
                serializer.closeStruct(data, T.stringof);
            }
        }

        serializer.closeStructArray(data, field_name, array);
    }

    /**************************************************************************

        Loads/deserializes the content of s and its array members, using the
        given deserializer object. See the description of the load() method
        above for a full description of how the deserializer object should
        behave.

        Params:
            s = struct instance (pointer)
            deserializer = object to do the deserialization
            data = input buffer to read serialized data from

     **************************************************************************/

    private void deserialize_ ( S, Deserializer, D ) ( S* s, Deserializer deserializer, D[] data )
    {
        foreach (i, T; typeof (S.tupleof))
        {
            T*    field      = GetField!(i, T, S)(s);
            const field_name = FieldName!(i, S);

            static if ( is(T == struct) )
            {
                deserializer.openStruct(data, field_name);
                deserialize_(field, serializer, data);                          // recursive call
                deserializer.closeStruct(data, field_name);
            }
            else static if ( is(T U : U[]) )
            {
                static if ( is(U == struct) )
                {
                    deserializer.openStructArray(data, field_name, array);
                    foreach ( element; array )
                    {
                        deserializer.openStruct(data, U.stringof);
                        deserialize_(&element, serializer, data);               // recursive call
                        deserializer.closeStruct(data, U.stringof);
                    }
                    deserializer.closeStructArray(data, field_name, array);
                }
                else
                {
                    static if ( isStaticArrayType!(T) )
                    {
                        deserializer.deserializeStaticArray(*field, field_name);
                    }
                    else
                    {
                        deserializer.deserializeArray(*field, field_name);
                    }
                }
            }
            else
            {
                mixin AssertSupportedType!(T, S, i);

                static if ( is(T B == enum) )
                {
                    deserializer.deserialize(cast(B)(*field), field_name);
                }
                else static if ( is(T B == typedef) )
                {
                    deserializer.deserialize(cast(B)(*field), field_name);
                }
                else
                {
                    deserializer.deserialize(*field, field_name);
                }
            }
        }
    }

    /**************************************************************************

        Asserts pos <= data.length; pos is assumed to be the element index in an
        input data array of length data_length. This checking is always done,
        even in release mode.

        Params:
            pos         = input data array position
            data_length = input data array length

        Throws:
            Exception if not pos <= data_length

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    private void assertLongEnough ( size_t pos, size_t data_length )
    {
        enforce(pos <= data_length, typeof (*this).stringof ~ " input data too short");
    }

    /**************************************************************************

        Asserts s != null; s is assumed to be the struct source or destination
        pointer. In addition a warning message is printed at compile time if
        S is a pointer to a pointer.
        The s != null checking is done in assert() fashion; that is, it is not
        done in release mode.

        Template params:
            func = invoking function (for message generation)

        Params:
            s = pointer to a source or destination struct; shall not be null

        Throws:
            Exception if s is null

     **************************************************************************/

    private void assertStructPtr ( char[] func, S ) ( S* s )
    {
        static if (is (S T == T*))
        {
            pragma (msg, typeof (*this).stringof ~ '.' ~ func ~ " - warning: "
                    "passing struct pointer argument of type '" ~ (S*).stringof ~
                    "' (you " "probably want '" ~ (T*).stringof ~ "')");
        }

        assert (s, typeof (*this).stringof ~ '.' ~ func ~ ": "
                "pointer of type '" ~ S.stringof ~ "*' is null");
    }

    /**************************************************************************

        Evaluates to true if T contains a reference type. If T contains a
        struct, the struct and its sub-structs, if any, are recursively scanned
        for reference types.

        Template parameters:
            T = type tuple to scan for reference types

        Evaluates to:
            true if T or a sub-struct of an element of T contains a reference
            type or false otherwise

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    template ContainsReferenceType ( T ... )
    {
        static if (is (T[0] == struct))
        {
            static if (T.length == 1)
            {
                const ContainsReferenceType = ContainsReferenceType!(typeof (T[0].tupleof));
            }
            else
            {
                const ContainsReferenceType = ContainsReferenceType!(typeof (T[0].tupleof)) || ContainsReferenceType!(T[1 .. $]);
            }
        }
        else
        {
            static if (T.length == 1)
            {
                const ContainsReferenceType = isReferenceType!(T[0]);
            }
            else
            {
                const ContainsReferenceType = isReferenceType!(T[0]) || ContainsReferenceType!(T[1 .. $]);
            }
        }
    }

    /**************************************************************************

        Tells whether T is a reference type. That is

            - pointer, dynamic array, associative array,
            - class, interface
            - delegate, function reference

        Template parameter:
            T = type to check

        Evaluates to:
            true if T is a reference type or false otherwise

     **************************************************************************/

    template isReferenceType ( T )
    {
        static if (is (T U == U[]) || is (T U == U*))                           // dynamic array or pointer
        {
            const isReferenceType = true;
        }
        else
        {
            const isReferenceType = is (T == class)      ||
                                    is (T == interface)  ||
                                    isAssocArrayType!(T) ||
                                    is (T == delegate)   ||
                                    is (T == function);
        }
    }

    /**************************************************************************

        Asserts that T is a single-byte type; T is assumed to be the element
        type for a serialized data array.

        Template parameters:
            T       = type which shall be of single byte size
            context = context where T is used (for message generation)

     **************************************************************************/

    deprecated("For binary serialization, use ocean.util.serialize")
    template AssertSingleByteType ( T, char[] context )
    {
        static assert (T.sizeof == 1, context ~ ": only single-byte element"
                       "arrays supported for data, not '" ~ T.stringof ~ "[]'");

    }

    /**************************************************************************

        Asserts that T, which is the type of the i-th field of S, is a supported
        field type for struct serialization; typedefs and unions are currently
        not supported.
        Warns if T is an associative array.

        Template parameters:
            T = type to check
            S = struct type (for message generation)
            i = struct field index (for message generation)

     **************************************************************************/

    template AssertSupportedType ( T, S, size_t i )
    {
        static assert (AllowUnions || !is (T == union),
                       typeof (*this).stringof ~ ": unions are not supported, sorry "
                        "(affects " ~ FieldInfo!(T, S, i) ~ ") -- use AllowUnions "
                        "template flag to enable shallow serialization of unions");

        static if (isAssocArrayType!(T)) pragma (msg, typeof (*this).stringof ~
                                             " - Warning: content of associative array will be discarded "
                                             "(affects " ~ FieldInfo!(T, S, i) ~ ')');
    }

    /**************************************************************************

        Asserts that T, which is an array of U and the type of the i-th field of
        S, is a supported array field type for struct serialization;
        multi-dimensional arrays and arrays of reference types or structs are
        currently not supported.

        Template parameter:
            T = type to check
            U = element type of array type T
            S = struct type (for message generation)
            i = struct field index (for message generation)

     **************************************************************************/

    template AssertSupportedArray ( T, U, S, size_t i )
    {
       static if (is (U V == V[]))
       {
           static assert (!isReferenceType!(V), typeof (*this).stringof ~ ": arrays "
                          "of reference types are not supported, sorry "
                          "(affects " ~ FieldInfo!(T, S, i) ~ ')');
       }
       else
       {
           static assert (!isReferenceType!(U), typeof (*this).stringof ~ ": arrays "
                          "of reference types are not supported, sorry "
                          "(affects " ~ FieldInfo!(T, S, i) ~ ')');
       }
    }

    /**************************************************************************

        Generates a struct field information string for messages

     **************************************************************************/

    template FieldInfo ( T, S, size_t i )
    {
        const FieldInfo = '\'' ~ S.tupleof[i].stringof ~ "' of type '" ~ T.stringof ~ '\'';
    }
}


/*******************************************************************************

    Test for plugin serializer

*******************************************************************************/

version ( UnitTest )
{
    import ocean.core.Test;

    struct TestSerializer
    {
        import tango.text.convert.Format;

        void open ( ref char[] dst, char[] name )
        {
            dst ~= "{";
        }

        void close ( ref char[] dst, char[] name )
        {
            dst ~= "}";
        }

        void serialize ( T ) ( ref char[] dst, ref T item, char[] name )
        {
            Format.format(dst, "{} {}={} ", T.stringof, name, item);
        }

        void openStruct ( ref char[] dst, char[] name )
        {
            dst ~= name ~ "={";
        }

        void closeStruct ( ref char[] dst, char[] name )
        {
            dst ~= "} ";
        }

        void serializeArray ( T ) ( ref char[] dst, char[] name, T[] array )
        {
            static if ( is(T == char) )
            {
                Format.format(dst, "{}[] {}=\"{}\" ", T.stringof, name, array);
            }
            else
            {
                Format.format(dst, "{}[] {}={} ", T.stringof, name, array);
            }
        }

        void serializeStaticArray ( T ) ( ref char[] dst, char[] name, T[] array )
        {
            Format.format(dst, "{}[{}] {}={} ", T.stringof, array.length, name, array);
        }

        void openStructArray ( T ) ( ref char[] dst, char[] name, T[] array )
        {
            dst ~= name ~ "={";
        }

        void closeStructArray ( T ) ( ref char[] dst, char[] name, T[] array )
        {
            dst ~= "} ";
        }
    }
}

unittest
{
    struct TestStruct
    {
        char[] name;
        int[] numbers;
        int x;
        float y;
        struct InnerStruct
        {
            int z;
        }

        int[4] static_array;
        InnerStruct a_struct;
        InnerStruct[] some_structs;
    }

    TestStruct s;
    s.name = "hello";
    s.numbers = [12, 23];
    s.some_structs.length = 2;

    TestSerializer ser;
    char[] dst;
    StructSerializer!().serialize(&s, ser, dst);
    test!("==")(dst, "{char[] name=\"hello\" int[] numbers=[12, 23] int x=0 float y=nan int[4] static_array=[0, 0, 0, 0] a_struct={int z=0 } some_structs={InnerStruct={int z=0 } InnerStruct={int z=0 } } }");
}


/*******************************************************************************

    Unittests

*******************************************************************************/

version (UnitTest)
{

    /***************************************************************************

        Imports

    ***************************************************************************/

    import tango.core.Traits;
    import tango.stdc.time;
    import tango.util.Convert : to;
    import tango.time.StopWatch;
    import tango.core.Memory;
    debug ( OceanPerformanceTest ) import ocean.io.Stdout : Stderr;

    /***************************************************************************

        Provides a growing container. It will overwrite the oldest entries as soon
        as the maxLength is reached.

    ***************************************************************************/

    struct CircularBuffer_ (T)
    {
        /***********************************************************************

            growing array of elements

        ***********************************************************************/

        T[] elements;

        /***********************************************************************

           maximum allowed size of the array

        ***********************************************************************/

        size_t maxLength = 50;

        /***********************************************************************

            current write position

        ***********************************************************************/

        size_t write = 0;

        /***********************************************************************

            Pushes an element on the Cache. If maxLength isn't reached, resizes
            the cache. If it is reached, overwrites the oldest element

            Params:
                element = The element to push into the cache

        ***********************************************************************/

        void push (T element)
        {
            if (this.elements.length == this.write)
            {
                if (this.elements.length < this.maxLength)
                {
                    this.elements.length = this.elements.length + 1;
                }
                else
                {
                    this.write = 0;
                }
            }

            static if (isArrayType!(T))
            {
                this.elements[this.write].length = element.length;
                this.elements[this.write][] = element[];
            }
            else
            {
                this.elements[this.write] = element;
            }

            ++this.write;
        }

        /***********************************************************************

            Returns the offset-newest element. Defaults to 0 (the newest)

            Params:
                offset = the offset-newest element. The higher this number, the
                         older the returned element. Defaults to zero. (the newest
                         element)

        ***********************************************************************/

        T* get (size_t offset=0)
        {
            if (offset < this.elements.length)
            {
                if (cast(int)(this.write - 1 - offset) < 0)
                {
                    return &elements[$ - offset + this.write - 1];
                }

                return &elements[this.write - 1 - offset];
            }

            throw new Exception("Element does not exist");
        }
    }

    alias CircularBuffer_!(char[]) Urls;


    /***************************************************************************

        Retargeting profile

    ***************************************************************************/

    struct RetargetingAction
    {
        hash_t id;
        hash_t adpan_id;
        time_t lastseen;
        ubyte action;


        static RetargetingAction opCall(hash_t id,hash_t adpan_id,time_t lastseen,
                                        ubyte action)
        {

            RetargetingAction a = { id,adpan_id,lastseen,action };

            return a;
        }
    }

    /***************************************************************************

        Retargeting list

    ***************************************************************************/

    alias CircularBuffer_!(RetargetingAction) Retargeting;

    struct MeToo(int deep)
    {
        uint a;
        char[] jo;
        int[2] staticArray;
        static if(deep > 0)
            MeToo!(deep-1) rec;

        static if(deep > 0)
            static MeToo opCall(uint aa, char[] jo, int sta, int stb,MeToo!(deep-1) rec)
            {
                MeToo a = {aa,jo,[sta,stb],rec};
                return a;
            }
        else
            static MeToo!(0) opCall(uint aa, char[] jo, int sta, int stb,)
            {
                MeToo!(0) a = {aa,jo,[sta,stb]};
                return a;
            }
    }
}

deprecated unittest
{
    with (StructSerializer!())
    {
        byte[] buf;
        size_t w=void;
        {
            Retargeting retargeting;

            retargeting.maxLength = 55;

            for(uint i = 0; i < 55; ++i)
                retargeting.push(RetargetingAction(i,i+2,3,4));

            w = retargeting.write;
            dump(&retargeting,buf);
            assert(length(&retargeting) == buf.length);
        }
        Retargeting newStruct;

        load(&newStruct,buf);

        assert(newStruct.maxLength == 55);
        assert(newStruct.write == w);

        foreach(i, el ; newStruct.elements)
        {
            assert(el.id == i);
            assert(el.adpan_id == i+2);
            assert(el.lastseen == 3 && el.action == 4);
        }


        {
            Urls urls;

            for(uint i=0;i<40;++i)
                urls.push("http://example.com/"~to!(char[])(i));

            buf.length = 0;
            // dump(&urls,(void[] data){ buf~=cast(byte[])data; });
            dump(&urls,buf);
        }
        Urls empty;
        Urls* emptyp;
        //load(&emptyp,
        //   delegate void[] (void[] d, size_t len) { d[]=buf[0..d.length]; buf = buf[d.length..$]; return null; },
        //   false);

        loadSlice(emptyp,buf);

        assert(emptyp.elements.length == 40);

        foreach(i, url ; emptyp.elements)
            assert(url == "http://example.com/"~to!(char[])(i));



        struct SerializeMe
        {


            MeToo!(4)[] structArray;
        }

        {
            SerializeMe sm;
            sm.structArray ~= MeToo!(4)(1,"eins",2,3,MeToo!(3)(2,"zwei",2,3,MeToo!(2)(3,"drei",2,3,MeToo!(1)(4,"",2,3,MeToo!(0)(5,"",2,3)))));
            sm.structArray ~= MeToo!(4)(2,"eins",2,3,MeToo!(3)(2,"zwei",2,3,MeToo!(2)(3,"drei",2,3,MeToo!(1)(4,"",2,3,MeToo!(0)(5,"",2,3)))));
            sm.structArray ~= MeToo!(4)(3,"eins",2,3,MeToo!(3)(2,"zwei",2,3,MeToo!(2)(3,"drei",2,3,MeToo!(1)(4,"",2,3,MeToo!(0)(5,"",2,3)))));
            sm.structArray ~= MeToo!(4)(4,"eins",2,3,MeToo!(3)(2,"zwei",2,3,MeToo!(2)(3,"drei",2,3,MeToo!(1)(4,"",2,3,MeToo!(0)(5,"",2,3)))));


            dump(&sm,buf);
        }

        SerializeMe dsm;
        load(&dsm,buf);

        assert(dsm.structArray.length == 4);

        foreach(i, ar ; dsm.structArray)
        {
            assert(ar.a == i+1);
            assert(ar.jo == "eins");
            assert(ar.staticArray[0] == 2);
            assert(ar.staticArray[1] == 3);
            assert(ar.rec.a == 2);
            assert(ar.rec.jo == "zwei");
            assert(ar.rec.staticArray[0] == 2);
            assert(ar.rec.staticArray[1] == 3);
            assert(ar.rec.rec.a == 3);
            assert(ar.rec.rec.jo == "drei");
            assert(ar.rec.rec.staticArray[0] == 2);
            assert(ar.rec.rec.staticArray[1] == 3);
            assert(ar.rec.rec.rec.a == 4);
            assert(ar.rec.rec.rec.jo == "");
            assert(ar.rec.rec.rec.staticArray[0] == 2);
            assert(ar.rec.rec.rec.staticArray[1] == 3);
            assert(ar.rec.rec.rec.rec.a == 5);
            assert(ar.rec.rec.rec.rec.jo == "");
            assert(ar.rec.rec.rec.rec.staticArray[0] == 2);
            assert(ar.rec.rec.rec.rec.staticArray[1] == 3);
        }


        StopWatch sw;



        SerializeMe sm;
        sm.structArray ~= MeToo!(4)(1,"eins",2,3,MeToo!(3)(2,"zwei",2,3,MeToo!(2)(3,"drei",2,3,MeToo!(1)(4,"",2,3,MeToo!(0)(5,"",2,3)))));
        sm.structArray ~= MeToo!(4)(2,"eins",2,3,MeToo!(3)(2,"zwei",2,3,MeToo!(2)(3,"drei",2,3,MeToo!(1)(4,"",2,3,MeToo!(0)(5,"",2,3)))));
        sm.structArray ~= MeToo!(4)(3,"eins",2,3,MeToo!(3)(2,"zwei",2,3,MeToo!(2)(3,"drei",2,3,MeToo!(1)(4,"",2,3,MeToo!(0)(5,"",2,3)))));
        sm.structArray ~= MeToo!(4)(4,"eins",2,3,MeToo!(3)(2,"zwei",2,3,MeToo!(2)(3,"drei",2,3,MeToo!(1)(4,"",2,3,MeToo!(0)(5,"",2,3)))));

        buf.length = length(&sm);

        /****************************************************************************

          Performance Test

          Results for struct SerializeMe:
          Writing with 4049768.36/s (worst 3.6m)
          Reading with 7587750.42/s

        ****************************************************************************/



        debug ( OceanPerformanceTest )
        {
            Stderr.formatln("SerializeMe Performance Test:");
            sw.start;
            for(uint i = 0;i<100_000_000; ++i)
            {
                dump(&sm,buf);
            }
            Stderr.formatln("Writing with {}/s",100_000_000/sw.stop);

            // FIXME !!: This causes a segfault:
            /*
             * Program received signal SIGSEGV, Segmentation fault.
             __memcpy_ssse3 () at ../sysdeps/i386/i686/multiarch/memcpy-ssse3.S:1099
             1099    ../sysdeps/i386/i686/multiarch/memcpy-ssse3.S: No such file or directory.
             in ../sysdeps/i386/i686/multiarch/memcpy-ssse3.S
             (gdb) bt
             #0  __memcpy_ssse3 () at ../sysdeps/i386/i686/multiarch/memcpy-ssse3.S:1099
             #1  0x08101d7c in _d_arraycopy ()
             #2  0x080b30a9 in ocean.io.serialize.StructSerializer.StructSerializer.load!(SerializeMe,byte).load.__dgliteral32 (this=0xffffc670, chunk=581442738273124356)
             at /home/mathias/workspace/includes/ocean/io/serialize/StructSerializer.d:197
             #3  0x00000078 in ?? ()
             #4  0xffffc4f0 in ?? ()
             #5  0x080b1293 in ocean.io.serialize.StructSerializer.__unittest1 ()
             at /home/mathias/workspace/includes/ocean/io/serialize/StructSerializer.d:1703
             #6  0xd969d540 in ?? ()
             */

            sw.start;
            for(uint i = 0;i<100_000_000; ++i)
            {
                load(&sm,buf);
            }
            Stderr.formatln("Reading with {}/s",100_000_000/sw.stop);



            Stderr.formatln("Retargeting Performance Test:");
            sw.start;
            for(uint i = 0;i<100_000_000; ++i)
            {
                dump(&newStruct,buf);
            }
            Stderr.formatln("Writing with {}/s",100_000_000/sw.stop);


            sw.start;
            for(uint i = 0;i<100_000_000; ++i)
            {
                load(&newStruct,buf);
            }
            Stderr.formatln("Reading with {}/s",100_000_000/sw.stop);


            Stderr.formatln("Urls Performance Test:");


            {
                byte[] buffer;
                buffer.length = length(emptyp);
                sw.start;
                for(uint i = 0;i<1_00000; ++i)
                {
                    dump(emptyp,buffer );
                }
                Stderr.formatln("{} Writing preallocated buf with",1_00000/sw.stop);



                uint a=0;
                sw.start;
                for(uint i = 0;i<1_0000; ++i)
                {
                    a=0;
                    dump(emptyp,(void[] data) {

                            if(data.length+a > buffer.length)
                            assert(false);

                            buffer[a..a+data.length] = cast(byte[])data[];
                            a+=data.length;
                            } );
                }
                Stderr.formatln("{} Writing with own delegate",1_0000/sw.stop);


                sw.start;
                for(uint i = 0;i<1_000000; ++i)
                {
                    load(emptyp,buffer);
                }
                Stderr.formatln("{}/s Reading using slicing",1_000000/sw.stop);

                sw.start;
                for(uint i = 0;i<1_000000; ++i)
                {
                    load(&empty,buffer);
                }
                Stderr.formatln("{}/s Reading with",1_000000/sw.stop);

                foreach(i, url ; empty.elements)
                    assert(url == "http://example.com/"~to!(char[])(i));

            }
        }
    }
}
