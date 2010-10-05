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

module core.serializer.StructSerializer;

/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.core.Exception: assertEx;

private import tango.core.Traits;

debug import tango.util.log.Trace;



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
            
        Returns:
            amount of data written to the buffer
        
     **************************************************************************/

    size_t dump ( S, D ) ( S* s, ref D[] data )
    {
        static assert (D.sizeof == 1, typeof (*this).stringof ~ ".dump: only "
                                      "single-byte element arrays supported, "
                                      "not '" ~ D.stringof ~ "[]'");

        size_t written = 0;

        dump(s, (void[] chunk) 
        {
            if (chunk.length + written > data.length)
            {
                data.length = chunk.length + written;
            }
            
            data[written .. written + chunk.length] = cast(D[]) chunk[];
            
            written += chunk.length; 
         });
            
        return written;
    }

    /**************************************************************************

        Dumps/serializes the content of s and its array members, using the given
        serializer object. The serializer object needs the following methods:
            
                void open ( ref Char[] output );

                void close ( ref Char[] output );
            
                void serialize ( T ) ( ref Char[] output, T* item, char[] name );
            
                void serializeStruct ( ref Char[] output, Char[] name, void delegate ( ) serialize_struct );
            
                void serializeArray ( T ) ( ref Char[] output, T[] array, Char[] name );
            
                void serializeStructArray ( T ) ( ref Char[] output, Char[] name, T[] array, void delegate ( ref T ) serialize_element );

        Unfortunately, as some of these methods are templates, it's not
        possible to make an interface for it. But the compiler will let you know
        whether a given serializer object is suitable or not ;)

        See ocean.io.serialize.JsonStructSerializer for an example.

        Params:
            s    = struct instance (pointer)
            serializer = object to do the serialization
            data = output buffer to write serialized data to

     **************************************************************************/

    public void dump ( S, Serializer, D ) ( S* s, Serializer serializer, ref D[] data )
    {
        serializer.open(data);
        serialize(s, serializer, data);
        serializer.close(data);
    }

    /**************************************************************************

        Dumps/serializes the content of s and its array members.
        
        send is called repeatedly; on each call, it must store or forward the
        provided data.
        
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
        
        transmitArrays!(false)(s, delegate void[] ( void[] data, size_t ) { send(data); return null; },false);
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

    size_t load ( S, D ) ( S* s, D[] data, bool slice = false )
    {
        static assert (D.sizeof == 1, typeof (*this).stringof ~ ".load: only "
                       "single-byte element arrays supported, "
                       "not '" ~ D.stringof ~ "[]'");

        size_t start = 0;
        
        load(s, ( void[] chunk, size_t len = 0)
        {   
            if (len == 0)
            { 
                size_t end = start + chunk.length;
                
                assertEx(end <= data.length, typeof (*this).stringof ~ " input data too short");
                
                chunk[] = (cast (void[]) data)[start .. end];                
                
                start = end;
                
	            return cast(void[])null;                
            }
            else if(slice)
            {
                auto tmp = (cast (void[]) data)[start .. start + len];
             
                start += len;
                
                return tmp;
            }
			assert(false);
        },slice);
        
        return start;
    }
    
    /**************************************************************************

        Loads/deserializes the content of s and its array members.
        
        receive is called repeatedly; 
        
        on each call, it must do one of the two, depending on the arguments:
        
        1) if (len == 0)
            populate the provided data buffer with 
            data previously produced by dump().
            Data which was populated once, should not be populated again. 
            So the delegate must behave like a stream receive function.
        
        2) if (len > 0)
        
            return a slice of len from the current position and advance the
            position. This is only used when slicing is enabled.

        Params:
            s       = struct instance (pointer)
            receive = receiving callback delegate
            slice   = optional. If true, will set dynamical arrays to
                      slices of the provided buffer
                      Warning: Do not serialize a struct into the same buffer
                               it was deserialized from.
        Returns:
            passes through return value of receive
        
     **************************************************************************/

    void load ( S ) ( S* s, void[] delegate ( void[] data , size_t len ) receive, bool slice = false )
    {
        S s_copy = *s;
        
        S* s_copy_ptr = &s_copy;

        receive((cast (void*) s)[0 .. S.sizeof],0);
        
        copyReferences(s_copy_ptr, s);
        
        transmitArrays!(true)(s, receive,slice);
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
            slice    = if true, a slice assignment 
                       instead of a copy will be done
            
        Returns:
            passes through return value of transmit
        
     **************************************************************************/

    void transmitArrays ( bool receive, S ) ( S* s, void[] delegate ( void[] array, size_t  ) transmit, bool slice )
    {
        foreach (i, T; typeof (S.tupleof))
        {
            auto field = getField!(i)(s);
            
            static if (is (T == struct))
            {
                transmitArrays!(receive)(field, transmit,slice);                // recursive call
            }
            else static if (is (T U == U[]))
            {
                mixin AssertSupportedArray!(T, U, S, i);
                
                transmitArray!(receive)(field, transmit,slice);
            }
            else mixin AssertSupportedType!(T, S, i);
        }
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
    
    void transmitArray ( bool receive, T ) ( T[]* array, void[] delegate (  void[] data, size_t  ) transmit, bool slice )
    {
        size_t len;
        
        static if (receive)
        {
            transmit((cast (void*) &len)[0 .. len.sizeof],0);
            
            static if (!isDynamicArrayType!(T))
            {
                if (slice)
                {                   
                    *array = cast(T[])transmit(null,len);
                }
                else
                {
                    array.length = len;
                }
            }
            else
            {
                array.length = len;
            }
        }
        else
        {
            len = array.length;

            transmit((cast (void*) &len)[0 .. len.sizeof],0);
        }
        
        static if (is (T U : U[]))
        {
            for (size_t i = 0; i < len; i++)
            {
                transmitArray!(receive)(array.ptr + i, transmit,slice);         // recursive call
            }
        }
        else if (!slice)
        {
            transmit((cast (void*) array.ptr)[0 .. len * T.sizeof],0);
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

        Returns the name of the ith field.

        TODO: do this with template recursion
        
        Template parameter:
            i = struct field index
        
        Params:
            s = struct instance (pointer)
            
        Returns:
            name of the ith field
        
     **************************************************************************/

    char[] getFieldName ( size_t i, S ) ( S* s )
    {
        if ( S.tupleof[i].stringof.length < 2 )
        {
            return S.tupleof[i].stringof;
        }

        size_t index = S.tupleof[i].stringof.length - 1;
        foreach_reverse ( c; S.tupleof[i].stringof )
        {
            if ( c == '.' )
            {
                break;
            }
            index--;
        }

        return S.tupleof[i].stringof[index + 1 .. $];
    }

    
    /**************************************************************************

        Dumps/serializes the content of s and its array members, using the given
        serializer object. See the description of the dump() method above for a
        full description of how the serializer object should behave.
    
        Params:
            s    = struct instance (pointer)
            serializer = object to do the serialization
            data = output buffer to write serialized data to

     **************************************************************************/
    
    private void serialize ( S, Serializer, D ) ( S* s, Serializer serializer, ref D[] data )
    {
        foreach (i, T; typeof (S.tupleof))
        {
            auto field = getField!(i)(s);
            auto field_name = getFieldName!(i)(s);

            static if (is (T == struct))
            {
                serializer.serializeStruct(data, field_name, {
                    serialize(field, serializer, data);                         // recursive call
                });
            }
            else static if (is (T U : U[]))
            {
                mixin AssertSupportedArray!(T, U, S, i);

                U[] array = *field;

                static if ( is(U == struct) )
                {
                    serializer.serializeStructArray(data, field_name, array, ( ref U element ) {
                        serialize(&element, serializer, data);                  // recursive call
                    });
                }
                else
                {
                    serializer.serializeArray(data, array, field_name);
                }
            }
            else
            {
                mixin AssertSupportedType!(T, S, i);

                static if (is (T B == enum))
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

/*******************************************************************************

	Unittests

*******************************************************************************/

debug (OceanUnitTest)
{

    /***************************************************************************

        Imports

    ***************************************************************************/

    import tango.core.Traits;
    import tango.stdc.time;
    import tango.util.Convert : to;
    import tango.time.StopWatch;
    import tango.util.log.Trace;
    import tango.core.Memory;
    
    /***************************************************************************

        Provides a growing container. It will overwrite the oldest entries as soon
        as the maxLength is reached.

    ***************************************************************************/

    struct CircularBuffer (T)
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
    
    alias CircularBuffer!(char[]) Urls;
    

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

    alias CircularBuffer!(RetargetingAction) Retargeting;
    
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
    
unittest
{
   with (StructSerializer)
   {
       byte[] buf;
       uint w=void;
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
       //load(&empty,
        //   delegate void[] (void[] d, size_t len) { d[]=buf[0..d.length]; buf = buf[d.length..$]; return null; },
        //   false);

       load(&empty,buf,true);

       assert(empty.elements.length == 40);
       
       foreach(i, url ; empty.elements)
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
   
   
   

   Trace.formatln("SerializeMe Performance Test:");
   sw.start;
   for(uint i = 0;i<100_000_000; ++i)
   {
       dump(&sm,buf);
   }
   Trace.formatln("Writing with {}/s",100_000_000/sw.stop);
   
   
   sw.start;
   for(uint i = 0;i<100_000_000; ++i)
   {
       load(&sm,buf);
   }
   Trace.formatln("Reading with {}/s",100_000_000/sw.stop);
   
   

   Trace.formatln("Retargeting Performance Test:");
   sw.start;
   for(uint i = 0;i<100_000_000; ++i)
   {
       dump(&newStruct,buf);
   }
   Trace.formatln("Writing with {}/s",100_000_000/sw.stop);
   
   
   sw.start;
   for(uint i = 0;i<100_000_000; ++i)
   {
       load(&newStruct,buf);
   }
   Trace.formatln("Reading with {}/s",100_000_000/sw.stop);
   
   
   Trace.formatln("Urls Performance Test:");
   
   
   
   
   
   
   {
   auto byte buffer[]; buffer.length = length(&empty);
   sw.start;
   for(uint i = 0;i<1_00000; ++i)
   {    
       dump(&empty,buffer );    
   }
   Trace.formatln("{} Writing preallocated buf with",1_00000/sw.stop);
   
   
   
   uint a=0;
   sw.start;
   for(uint i = 0;i<1_0000; ++i)
   {
       a=0;
       dump(&empty,(void[] data) { 
           
           if(data.length+a > buffer.length)
               assert(false);
           
           buffer[a..a+data.length] = cast(byte[])data[]; 
           a+=data.length;
           } );
   }
   Trace.formatln("{} Writing with own delegate",1_0000/sw.stop);
   
  
   sw.start;
   for(uint i = 0;i<1_000000; ++i)
   {
       load(&empty,buffer,true);
   }
   Trace.formatln("{}/s Reading using slicing",1_000000/sw.stop);
   
   
   sw.start;
   for(uint i = 0;i<1_000000; ++i)
   {
       load(&empty,buffer);
   }
   Trace.formatln("{}/s Reading with",1_000000/sw.stop);
   
   
   }
   }
   
}

}
