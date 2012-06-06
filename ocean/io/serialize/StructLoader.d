module ocean.io.serialize.StructLoader;

class StructLoader
{
    public size_t max_length = size_t.max;
    
    private const StructLoaderException e;
    
    alias void[] delegate ( size_t len ) GetBufferDg;
    
    public this ( )
    {
        this.e = new StructLoaderException;
    }
    
    protected override void dispose ( )
    {
        delete this.e;
    }
    
    /***************************************************************************
    
        Loads the S instance represented by data. data must have been obtained
        by StructSerializer.dump!(S)().
        
        S must not contain branched dynamic arrays.
        
        The content of src is modified in-place.
        
        Notes:
            1. After this method has returned, do not change src.length to a
               value other than 0, unless you set the content of src to zero
               bytes *before* changing the size:
               ---
                   {
                       S* s = load!(S)(data);
                       
                       // do something with s...
                   }
                   
                   (cast (ubyte[]) data)[] = 0; // clear data
                   
                   data.length = 1234;          // resize data
               ---
               Of course the obtained instance gets invalid when src is cleared
               and should be reset to null *before* clearing src if it is in the
               same scope.
            2. The members of the obtained instance may be written to unless the
               length of arrays is not changed.
            3. It is safe to use "cast (S*) src.ptr" to obtain the S instance.
            4. It is safe (however pointless) to load the same buffer twice.
            
        Template params:
            S = struct type
             
         Params:
             src = data of a serialized S instance
             
         Returns:
             deserialized S instance
             
         Throws:
             StructLoaderException if src is too short or the length of a
             dynamic array is greater than max_length.
             
        Out:
            The returned pointer is src.ptr.

     **************************************************************************/
    
    S* load ( S ) ( void[] src )
    out (s)
    {
        assert (s is src.ptr);
    }
    body
    {
        return cast (S*) this.setSlices!(S)(src).ptr;
    }
    
    /***************************************************************************
    
        Loads the S instance represented by data by setting the dynamic array
        slices. data must have been obtained by StructSerializer.dump!(S)().
        The content of src is modified in-place.
        S must not contain branched dynamic arrays.
                    
        3. It is safe to use "cast (S*) src.ptr" to obtain the S instance.

        
        Notes:
            1. After this method has returned, do not change src.length to a
               value other than 0, unless you set the content of src to zero
               bytes *before* changing the size.
            2. The members of the obtained instance may be written to unless the
               length of arrays is not changed.
            3. It is safe (however pointless) to load the same buffer twice.
            
        Template params:
            S = struct type
             
         Params:
             src = data of a serialized S instance
             
         Returns:
             deserialized S instance
             
         Throws:
             StructLoaderException if src is too short or the length of a
             dynamic array is greater than max_length.
        
        Out:
            The returned buffer is src.
        
     **************************************************************************/
    
    void[] setSlices ( S ) ( void[] src )
    out (data)
    {
        assert (data.ptr    is src.ptr);
        assert (data.length <= src.length);
    }
    body
    {
        S* s = cast (S*) src.ptr;
        
        size_t used = this.sliceArrays!(false, S)(*s, src[S.sizeof .. $], null);
        
        return src[0 .. used];
    }
    
    /***************************************************************************
    
        Copies src to dst and loads the S instance represented by dst. src must
        have been obtained by StructSerializer.dump!(S)(). dst is resized as
        required. If dst is initially null, it is set to a newly allocated
        array.
        
        S may contain branched dynamic arrays.
        
        Notes:
            1. After this method has returned, do not change dst.length to a
               value other than 0, unless you set the content of src to zero
               bytes *before* changing the size. Of course the obtained instance
               gets invalid when dst is cleared and should be reset to null
               *before* clearing dst if it is in the same scope.
            2. The members of the obtained instance may be written to unless the
               length of arrays is not changed.
            3. It is safe to use "cast (S*) dst.ptr" to obtain the S instance.
            
        Template params:
            S = struct type
             
         Params:
             src = data of a serialized S instance
             
         Returns:
             deserialized S instance
             
         Throws:
             StructLoaderException if src is too short or the length of a
             dynamic array is greater than max_length.
        
        Out:
            The returned S instance is dst.ptr. 

     **************************************************************************/
    
    S* loadCopy ( S, bool allow_branched_arrays = true ) ( ref void[] dst, void[] src )
    out (s)
    {
        assert (s is dst.ptr);
    }
    body
    {
        size_t slices_len = 0,
               data_len   = this.sliceArraysBytes!(S)(src, slices_len);
               
        static if (allow_branched_arrays)
        {
            size_t total_len = slices_len + data_len;
            
            size_t pos = data_len;
            
            void[] getSliceBuffer ( size_t n )
            {
                size_t start = pos;
                pos += n;
                return dst[start .. pos];
            }
            
            GetBufferDg get_slice_buffer = &getSliceBuffer;
        }
        else
        {
            assert (!slices_len);
            
            alias data_len total_len;
            
            const GetBufferDg get_slice_buffer = null;
        }
        
        if (dst is null)
        {
            dst = new ubyte[total_len];
        }
        else
        {
            dst.length = total_len;
        }
        
        dst[0 .. data_len] = src[0 .. data_len];
        
        S* s = cast (S*) dst.ptr;
        
        size_t used = this.sliceArrays!(allow_branched_arrays, S)
                                       (*s, dst[S.sizeof .. $], get_slice_buffer);
        
        static if (allow_branched_arrays)
        {
            assert (pos == total_len);
        }
        
        assert (S.sizeof + used == data_len);
        
        return s;
    }
    
    /***************************************************************************
    
        Calculates the number of bytes required by loadSlice() for array
        instances when loading a serialized S instance from data.
        
        Note that this value is always zero if S does not contain a dynamic
        array whose element type contains a dynamic array.
        
        Template params:
            S = struct type
             
         Params:
             data  = data previously obtained by dump() from a S instance
             bytes = number of bytes required by loadSlice
             
         Returns:
             number of bytes used in data
        
     **************************************************************************/
    
    size_t sliceArraysBytes ( S ) ( void[] data, out size_t bytes )
    {
        this.e.assertDataLongEnough!(S)(data.length, S.sizeof, __FILE__, __LINE__);
        
        return S.sizeof + this.sliceArraysBytes_!(S)(data[S.sizeof .. $], bytes);
    }
    
    /***************************************************************************
    
        Calculates the number of bytes required by sliceArray() for array
        instances when loading the serialized dynamic array of element type T
        from data.
        
        Note that this value is always zero if T does not contain a dynamic
        array.
        
        Template params:
            T = array element type
             
         Params:
             data  = data of one dynamic array previously obtained by dump()
             bytes = incremented by the number of bytes required by sliceArray()
             
         Returns:
             number of bytes used in data
        
     **************************************************************************/
    
    size_t sliceArrayBytes ( T ) ( void[] data, ref size_t n )
    {
        this.e.assertDataLongEnough!(T)(data.length, size_t.sizeof, __FILE__, __LINE__);
        
        /*
         * Obtain the array length from data, calculate the number of bytes of
         * the array and define the reading position in data.  
         */
        
        size_t len   = *cast (size_t*) data[0 .. size_t.sizeof].ptr,
               bytes = len * T.sizeof,
               pos   = len.sizeof;
        
        this.e.assertLengthInRange!(T)(len, this.max_length, __FILE__, __LINE__);
        
        static if (is (T U == U[]))
        {
            /*
             * If array is an array of slices (dynamic arrays), obtain a data
             * buffer for these slices.
             */
            
            n += bytes;
        }
        else
        {
            /*
             * array is an array of values so the values will follow in data.
             */
            
            pos += bytes;
        }
        
        static if (IsPrimitive!(T))
        {
            return pos;
        }
        else
        {
            return pos + this.sliceSubArraysBytes!(T)(len, data[len.sizeof .. $], n);
        }
    }
    
    /***************************************************************************
    
        Calculates the number of bytes required by sliceSubArrays() for array
        instances when loading the elements of a serialized dynamic array of
        element type T and length len from data.
        
        Note that this value is always zero if T does not contain a dynamic
        array.
        
        Template params:
            T = array element type
             
         Params:
             len   = dynamic array length
             data  = data of one dynamic array elements
             bytes = incremented by the number of bytes required by
                     sliceSubArrays()
             
         Returns:
             number of bytes used in data
        
     **************************************************************************/
    
    size_t sliceSubArraysBytes ( T ) ( size_t len, void[] data, ref size_t n )
    {
        size_t pos = 0;
        
        static if (is (T == struct)) for (size_t i = 0; i < len; i++)
        {
            this.e.assertDataLongEnough!(T)(data.length, pos, __FILE__, __LINE__);
            
            pos += this.sliceArraysBytes_!(T)(data[pos .. $], n);
        }
        else static if (is (T V : V[]))
        {
            static if (is (V[] == T)) for (size_t i = 0; i < len; i++)
            {
                this.e.assertDataLongEnough!(T)(data.length, pos, __FILE__, __LINE__);
                
                pos += this.sliceArrayBytes!(V)(data[pos .. $], n);
            }
            else static if (!IsPrimitive!(V)) for (size_t i = 0; i < len; i++)
            {
                this.e.assertDataLongEnough!(T)(data.length, pos, __FILE__, __LINE__);
                
                pos += this.sliceSubArraysBytes!(V)(T.length, data[pos .. $], n);
            }
        }
        else pragma (msg, ind, "sliceSubArraysBytes: no subarrays (primitive ", T.stringof, ")");
        
        return pos;
    }
    
    /***************************************************************************
    
        Sets all dynamic array members of s to slice the corresponding sections
        of data. data must be a concatenated sequence of chunks generated by
        transmitArray() for each dynamic array member of S.
        
        Template params:
            allow_branched_arrays = true: allow dynamic arrays of element types which
                              contain dynamic arrays
        
        Params:
            s                 = struct instance to set arrays to slice data
            data              = array data to slice
            get_slices_buffer = delegate to obtain buffers for array instances,
                                ignored and may be null if allow_branched_arrays is
                                false
            
        Returns:
            number of data bytes sliced 
        
        Throws:
            Exception if data is too short
        
        In:
            If allow_branched_arrays is true, get_slices_buffer must not be null.
        
     **************************************************************************/
    
    size_t sliceArrays ( bool allow_branched_arrays, S ) ( ref S s, void[] data,
                                                     GetBufferDg get_slices_buffer )
    in
    {
        static if (allow_branched_arrays) assert (get_slices_buffer !is null);
    }
    body
    {
        size_t pos = 0;
        
        foreach (i, Field; typeof (S.tupleof))
        {
            static if (is (Field == struct))
            {
                this.e.assertDataLongEnough!(S)(data.length, pos, __FILE__, __LINE__);
                
                pos += this.sliceArrays!(allow_branched_arrays)
                                        (*this.getField!(i, Field)(s), data[pos .. $], get_slices_buffer);
            }
            else static if (is (Field Element : Element[]))
            {
                static if (is (Element[] == Field))
                {
                    this.e.assertDataLongEnough!(S)(data.length, pos, __FILE__, __LINE__);
                    
                    pos += this.sliceArray!(allow_branched_arrays)
                                           (*this.getField!(i, Field)(s), data[pos .. $], get_slices_buffer);
                }
                else static if (!IsPrimitive!(Element))
                {
                    this.e.assertDataLongEnough!(S)(data.length, pos, __FILE__, __LINE__);
                    
                    pos += this.sliceSubArrays!(allow_branched_arrays)
                                               (*this.getField!(i, Field)(s), data[pos .. $], get_slices_buffer);
                }
            }
        }
        
        return pos;
    }
    
    /***************************************************************************
    
        Creates an array slice to data. Data must start with a size_t value
        reflecting the byte length, followed by the array content data.
        
        Template params:
            allow_branched_arrays = true: allow T to contain dynamic arrays
        
        Params:
            array             = resulting array
            data              = array data to slice
            get_slices_buffer = delegate to obtain buffers for array instances,
                                ignored and may be null if allow_branched_arrays is
                                false
            
        Returns:
            number of data bytes sliced 
        
        Throws:
            Exception if data is too short
        
        In:
            If allow_branched_arrays is true, get_slices_buffer must not be null.
            
     **************************************************************************/
    
    size_t sliceArray ( bool allow_branched_arrays, T ) ( out T[] array, void[] data,
                                                          GetBufferDg get_slices_buffer )
    in
    {
        static if (allow_branched_arrays) assert (get_slices_buffer !is null);
    }
    body
    {
        this.e.assertDataLongEnough!(T)(data.length, size_t.sizeof, __FILE__, __LINE__);
        
        /*
         * Obtain the array length from data, calculate the number of bytes of
         * the array and define the reading position in data.  
         */
        
        size_t len   = *cast (size_t*) data[0 .. size_t.sizeof].ptr,
               bytes = len * T.sizeof,
               pos   = len.sizeof;
        
        this.e.assertLengthInRange!(T)(len, this.max_length, __FILE__, __LINE__);
        
        static if (is (T U == U[]))
        {
            static assert (allow_branched_arrays, typeof (array).stringof ~ " detected but > 1D arrays are not allowed");
            
            /*
             * If array is an array of slices (dynamic arrays), obtain a data
             * buffer for these slices.
             */
            
            array = cast (T[]) get_slices_buffer(bytes);
        }
        else
        {
            /*
             * array is an array of values so the values will follow in data.
             */
            
            pos += bytes;
            
            array = cast (T[]) data[len.sizeof .. pos];
        }
        
        assert (array.length == len);
        
        static if (IsPrimitive!(T))
        {
            return pos;
        }
        else
        {
            /*
             * If array is an array of a non-primitive type, recurse into the
             * array elements.
             */
            
            return pos + this.sliceSubArrays!(allow_branched_arrays)
                                             (array, data[len.sizeof .. $], get_slices_buffer);
        }
    }
    
    /***************************************************************************
    
        Sets the elements of array to slice the corresponding parts of data if
        T contains a dynamic array.
        
        Template params:
            allow_branched_arrays = true: allow T to contain dynamic arrays
        
        Params:
            array             = array to adjust elements
            data              = array data to slice
            get_slices_buffer = delegate to obtain buffers for array instances,
                                ignored and may be null if allow_branched_arrays is
                                false
            
        Returns:
            number of data bytes sliced 
        
        Throws:
            Exception if data is too short
        
        In:
            If allow_branched_arrays is true, get_slices_buffer must not be null.
            
     **************************************************************************/
    
    size_t sliceSubArrays ( bool allow_branched_arrays, T ) ( T[] array, void[] data,
                                                              GetBufferDg get_slices_buffer )
    in
    {
        static if (allow_branched_arrays) assert (get_slices_buffer !is null);
    }
    body
    {
        size_t pos = 0;
        
        static if (is (T == struct))
        {
            foreach (ref element; array)
            {
                this.e.assertDataLongEnough!(T)(data.length, pos, __FILE__, __LINE__);
                
                pos += this.sliceArrays!(allow_branched_arrays)
                                        (element, data[pos .. $], get_slices_buffer);
            }
        }
        else static if (is (T V : V[]))
        {
            static if (is (V[] == T)) foreach (ref element; array)
            {
                this.e.assertDataLongEnough!(T)(data.length, pos, __FILE__, __LINE__);
                
                pos += this.sliceArray!(allow_branched_arrays)
                                       (element, data[pos .. $], get_slices_buffer);
            }
            else static if (!IsPrimitive!(V))
            {
                for (size_t i = 0; i < array.length; i++)
                {
                    this.e.assertDataLongEnough!(T)(data.length, pos, __FILE__, __LINE__);
                    
                    pos += this.sliceSubArrays!(allow_branched_arrays)
                                               (array[i], data[pos .. $], get_slices_buffer);
                }
            }
        }
        
        return pos;
    }
    
    /***************************************************************************
    
        Calculates the number of bytes required by sliceArrays() for array
        instances when loading the serialized dynamic arrays for a S instance
        from data.
        
        Note that this value is always zero if S does not contain a dynamic
        array whose element type contains a dynamic array.
        
        Template params:
            S = struct type
             
         Params:
             data  = dynamic array data previously obtained by dump() from a S
                     instance
             bytes = incremented by the number of bytes required by
                     sliceArrays()
             
         Returns:
             number of bytes used in data
        
     **************************************************************************/
    
    private size_t sliceArraysBytes_ ( S ) ( void[] data, ref size_t n )
    {
        size_t pos = 0;
        
        foreach (i, Field; typeof (S.tupleof))
        {
            static if (is (Field == struct))
            {
                this.e.assertDataLongEnough!(S)(data.length, pos, __FILE__, __LINE__);
                
                pos += this.sliceArraysBytes_!(Field)(data[pos .. $], n);
            }
            else static if (is (Field Element : Element[]))
            {
                static if (is (Element[] == Field))
                {
                    this.e.assertDataLongEnough!(S)(data.length, pos, __FILE__, __LINE__);
                    
                    pos += this.sliceArrayBytes!(Element)(data[pos .. $], n);
                }
                else static if (!IsPrimitive!(Element))
                {
                    this.e.assertDataLongEnough!(S)(data.length, pos, __FILE__, __LINE__);
                    
                    pos += this.sliceSubArraysBytes!(Element)(Field.length, data[pos .. $], n);
                }
            }
        }
        
        return pos;
    }

    /**************************************************************************

        Returns a pointer to the i-th field of s
        
        Template parameter:
            i = struct field index
            T = struct field type
        
        Params:
            s = struct instance
            
        Returns:
            pointer to the i-th field of s
        
     **************************************************************************/
    
    private static T* getField ( size_t i, T, S ) ( ref S s )
    {
        return cast (T*) ((cast (void*) &s) + S.tupleof[i].offsetof);
    }

    /**************************************************************************
    
        Evaluates to true if T is a primitive type.
        
     **************************************************************************/
    
    template IsPrimitive ( T )
    {
        const IsPrimitive =
            is (T : real)  || // bool, (u)byte/short/int/long, float/double/real
            is (T : dchar) || // char/wchar/dchar
            is (T : creal);   // cfloat/cdouble/creal
    }
    
    /*************************************************************************/
    
    static class StructLoaderException : Exception
    {
        /**********************************************************************/
        
        this ( ) {super("");}
        
        /**********************************************************************
        
            Throws this instance if ok is false.
            
            Template params:
                S   = type of the struct which is currently loaded
                msg = error message
            
            Params:
                ok   = condition that should be true
                file = source code file name
                line = source code line number
            
            Throws:
                this instance if ok is false.
            
         **********************************************************************/
        
        void assertEx ( S, char[] msg ) ( bool ok, char[] file, typeof (__LINE__) line )
        {
            if (!ok)
            {
                const full_msg = "Error loading " ~ S.stringof ~ ": " ~ msg;
                
                this.msg  = full_msg;
                this.file = file;
                this.line = line;
                
                throw this;
            }
        }
        
        /**********************************************************************
        
            Throws this instance if len is not at most max.
            
            Template params:
                S   = type of the struct which is currently loaded
            
            Params:
                len  = length of a dynamic array to deserialize 
                max  = allowed maximum dynamic array length
                file = source code file name
                line = source code line number
            
            Throws:
                this instance if len is not at most max.
            
         **********************************************************************/
        
        void assertLengthInRange ( S ) ( size_t len, size_t max, char[] file, typeof (__LINE__) line )
        {
            this.assertEx!(S, "array too long")(len <= max, file, line);
        }
        
        /**********************************************************************
        
            Throws this instance if len is not at lest required.
            
            Template params:
                S = type of the struct that is currently loaded
            
            Params:
                len      = provided number of data bytes
                required = required number of data bytes
                file     = source code file name
                line     = source code line number
            
            Throws:
                this instance if len is not at most max.
            
         **********************************************************************/
        
        void assertDataLongEnough ( S ) ( size_t len, size_t required, char[] file, typeof (__LINE__) line )
        {
            this.assertEx!(S, "input data too short")(len >= required, file, line);
        }
    }
}