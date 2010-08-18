/******************************************************************************

    Struct data serialization and deserialization tools 
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        Aug 2010: Initial release
    
    authors:        David Eckardt
    
    Serializes data of value type fields and dynamic array of value type members
    of a struct instance, recursing into struct members if present.
    
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

module core.serializer.StructSerializer;

private import ocean.core.Exception: assertEx;

struct StructSerializer
{
    static:
    
    /**************************************************************************

        Calculates the serialized byte length of s, including array fields.
        
        Params:
            s = struct instance (pointer)
            
        Returns:
            serialized byte length of s
        
     **************************************************************************/

    size_t length ( S ) ( S* s )
    {
        return S.sizeof + subArrayLength(s);
    }
    
    
    /**************************************************************************

        Dumps/serializes the content of s and its array members.
        
        Params:
            s    = struct instance (pointer)
            data = output buffer to write serialized data to
        
     **************************************************************************/

    void dump ( S, D ) ( S* s, ref D[] data )
    {
        static assert (D.sizeof == 1, typeof (*this).stringof ~ ".dump: only "
                                      "single-byte element arrays supported, "
                                      "not '" ~ D.stringof ~ "[]'");
        
        data.length = 0;
        
        dump(s, (void[] chunk) { data ~= cast (D[]) chunk; });
    }
    
    /**************************************************************************

        Dumps/serializes the content of s and its array members.
        
        send is called repeatedly; on each call, it must store or forward the
        provided data. It must return 0 to indicate success or a value different
        from 0 to abort dumping.
        
        Params:
            s    = struct instance (pointer)
            send = sending callback delegate
            
        Returns:
            passes through return value of send
        
     **************************************************************************/

    void dump ( S ) ( S* s, void delegate ( void[] data ) send )
    {
        S s_copy = *s;
        
        S* s_copy_ptr = &s_copy;
        
        resetReferences(s_copy_ptr);
        
        send((cast (void*) s_copy_ptr)[0 .. S.sizeof]);
        
        transmitArrays!(false)(s, send);
    }
    
    /**************************************************************************

        Loads/deserializes the content of s and its array members.
    
        Params:
            s    = struct instance (pointer)
            data = input buffer to read serialized data from
            
        Throws:
            Exception if data is too short
        
        Returns:
            number of bytes consumed from data
        
     **************************************************************************/

    size_t load ( S, D ) ( S* s, D[] data )
    {
        static assert (D.sizeof == 1, typeof (*this).stringof ~ ".load: only "
                       "single-byte element arrays supported, "
                       "not '" ~ D.stringof ~ "[]'");

        size_t start = 0;
        
        load(s, (void[] chunk)
        {
            size_t end = start + chunk.length;
            
            assertEx(end <= data.length, typeof (*this).stringof ~ " input data too short");
            
            chunk[] = (cast (void[]) data)[start .. end];
            
            start = end;
        });
        
        return start;
    }
    
    /**************************************************************************

        Loads/deserializes the content of s and its array members.
        
        receive is called repeatedly; on each call, it must populate the
        provided data buffer with data previously produced by dump(). It must
        return 0 to indicate success or a value different from 0 to abort
        loading.

        Params:
            s       = struct instance (pointer)
            receive = receiving callback delegate
            
        Returns:
            passes through return value of receive
        
     **************************************************************************/

    void load ( S ) ( S* s, void delegate ( void[] data ) receive )
    {
        S s_copy = *s;
        
        S* s_copy_ptr = &s_copy;
        
        receive((cast (void*) s)[0 .. S.sizeof]);
        
        copyReferences(s_copy_ptr, s);
        
        transmitArrays!(true)(s, receive);
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

    size_t subArrayLength ( S ) ( S* s )
    {
        size_t result = 0;
        
        foreach (i, T; typeof (S.tupleof))
        {
            auto field = getField!(i)(s);
            
            static if (is (T == struct))
            {
                result += subArrayLength(getField!(i)(s));                      // recursive call
            }
            else static if (is (T U == U[]))
            {
                mixin AssertSupportedArray!(T, U, S, i);
                
                result = arrayLength(*field);
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

    size_t arrayLength ( T ) ( T[] array )
    {
        size_t len = size_t.sizeof;
        
        static if (is (T U == U[]))
        {
            foreach (element; array)
            {
                len += arrayLength(element);                                    // recursive call
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

    void resetReferences ( S ) ( S* s )
    {
        foreach (i, T; typeof (S.tupleof))
        {
            auto field = getField!(i)(s);
            
            static if (is (T == struct))
            {
                resetReferences(field);                                         // recursive call
            }
            else static if (isReferenceType!(T))
            {
                *field = null;
            }
        }
    }
    
    /**************************************************************************

        Copies all references from dst to src.
        
        Params:
            src = source struct instance (pointer)
            dst = destination struct instance (pointer)
        
     **************************************************************************/

    void copyReferences ( S ) ( S* src, S* dst )
    {
        foreach (i, T; typeof (S.tupleof))
        {
            auto src_field = getField!(i)(src);
            auto dst_field = getField!(i)(dst);
            
            static if (is (T == struct))
            {
                copyReferences(src_field, dst_field);                           // recursive call
            }
            else static if (isReferenceType!(T))
            {
                *dst_field = *src_field;
            }
        }
    }
    
    /**************************************************************************

        Transmits (sends or receives) the serialized data of all array fields in
        s.
        
        Template parameter:
            receive = true: receive array data, false: send array data
        
        Params:
            s        = struct instance (pointer)
            transmit = sending/receiving callback delegate
            
        Returns:
            passes through return value of transmit
        
     **************************************************************************/

    void transmitArrays ( bool receive, S ) ( S* s, void delegate ( void[] array ) transmit )
    {
        foreach (i, T; typeof (S.tupleof))
        {
            auto field = getField!(i)(s);
            
            static if (is (T == struct))
            {
                transmitArrays!(receive)(field, transmit);                      // recursive call
            }
            else static if (is (T U == U[]))
            {
                mixin AssertSupportedArray!(T, U, S, i);
                
                transmitArray!(receive)(field, transmit);
            }
            else mixin AssertSupportedType!(T, S, i);
        }
    }
    
    /**************************************************************************

        Transmits (sends or receives) the serialized data of array. That is,
        first transmit the array content byte length as size_t value, then the
        array content raw data.
        
        Template parameter:
            receive = true: receive array data, false: send array data
        
        Params:
            array    = array to send serialized data of (pointer)
            transmit = sending/receiving callback delegate
            
        Returns:
            passes through return value of send
        
        TODO: array needs to be duped
        
     **************************************************************************/
    
    void transmitArray ( bool receive, T ) ( T[]* array, void delegate ( void[] data ) transmit )
    {
        size_t len;
        
        static if (receive)
        {
            transmit((cast (void*) &len)[0 .. len.sizeof]);
            
            array.length = len;
//            *array = new T[len];
        }
        else
        {
            len = array.length;
            
            transmit((cast (void*) &len)[0 .. len.sizeof]);
        }
        
        static if (is (T U : U[]))
        {
            for (size_t i = 0; i < len; i++)
            {
                transmitArray!(receive)(array.ptr + i, transmit);               // recursive call
            }
        }
        else
        {
            transmit((cast (void*) array.ptr)[0 .. len * T.sizeof]);
        }
    }
    
    /**************************************************************************

        Returns a pointer to the i-th field of s
        
        Template parameter:
            i = struct field index
        
        Params:
            s = struct instance (pointer)
            
        Returns:
            pointer to the i-th field of s
        
     **************************************************************************/

    FieldType!(S, i)* getField ( size_t i, S ) ( S* s )
    {
        return cast (FieldType!(S, i)*) (cast (void*) s + S.tupleof[i].offsetof);
    }
    
    /**************************************************************************

        Generates the type of the i-th field of struct type S
        
        Template parameters:
            S = struct type
            i = struct field index
        
     **************************************************************************/

    template FieldType ( S, size_t i )
    {
        alias typeof (S.tupleof)[i] FieldType;
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

    template containsReferenceType ( T ... )
    {
        static if (is (T[0] == struct))
        {
            static if (T.length == 1)
            {
                const containsReferenceType = containsReferenceType!(typeof (T[0].tupleof));
            }
            else
            {
                const containsReferenceType = containsReferenceType!(typeof (T[0].tupleof)) || containsReferenceType!(T[1 .. $]);
            }
        }
        else
        {
            static if (T.length == 1)
            {
                const containsReferenceType = isReferenceType!(T[0]);
            }
            else
            {
                const containsReferenceType = isReferenceType!(T[0]) || containsReferenceType!(T[1 .. $]);
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
            const isReferenceType = is (T == class)    ||
                                    is (T == interface)||
                                    isAssocArray!(T)   ||
                                    is (T == delegate) ||
                                    is (T == function);
        }
    }
    
    /**************************************************************************

        Tells whether T is an associative array type
        
        Template parameter:
            T = type to check
        
        Evaluates to:
            true if T is an associative array type or false otherwise
        
     **************************************************************************/
    
    template isAssocArray ( T )
    {
        const isAssocArray = is (typeof (*T.init.values)[typeof (*T.init.keys)] == T);
    }

    /**************************************************************************

        Asserts that T, which is the type of the i-th field of S, is a supported
        field type for struct serialization; typedefs and unions are currently
        not supported.
        Warns if T is an associative array.
        
        Template parameter:
            T = type to check
            S = struct type (for message generation)
            i = struct field index (for message generation)
        
     **************************************************************************/

    template AssertSupportedType ( T, S, size_t i )
    {
        static assert (!is (T == union),
                       typeof (*this).stringof ~ ": unions are not supported, sorry "
                        "(affects " ~ FieldInfo!(T, S, i) ~ ')');
        
        static assert (!is (T == typedef),
                       typeof (*this).stringof ~ ": typedefs are not supported, sorry "
                       "(affects " ~ FieldInfo!(T, S, i) ~ ')');
        
        static if (isAssocArray!(T)) pragma (msg, typeof (*this).stringof ~ 
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