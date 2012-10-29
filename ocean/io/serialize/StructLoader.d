/******************************************************************************

    Struct data deserializer 
    
    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved
    
    version:        June 2012: Initial release
    
    author:         David Eckardt
    
    Loads a struct instance from serialized data, which were previously produced
    by StructSerializer.dump(), by referencing the data.
    
    The struct may or may not contain branched dynamic arrays. "Branched" means
    that the dynamic array element type contains a dynamic array. Examples:
    
        - multi-dimensional dynamic arrays like int[][] x,
        - arrays of structs that contain dynamic arrays like
          struct S { int[] x; } S[] y
    
    Note that static arrays of dynamic arrays or vice versa are no branched
    dynamic arrays in this sense as long as there is only one dynamic array in
    the type nesting:
    
        - int[x][], int[][x], int[x][][y] are not branched dynamic arrays,
        - int[][x][], int[][][x], int[x][][] are branched dynamic arrays.
    
    If the struct does not contain dynamic arrays at all, then the struct data
    can simply be deserialized by casting the data pointer:
    ---
        void[] data;
        // populate data...
        
        // data[0 .. S.sizeof] makes sure the buffer is long enough.
        S* s = cast (S*) data[0 .. S.sizeof].ptr;
        // *s is now a valid S instance as long as data exists.
    ---
    In this case there is no need for using the StructLoader.
    
    If the struct contains dynamic arrays, which are not branched, the input
    data need to be modified in-place when loading the struct instance, but no
    additional data buffers are required.
    Use StructLoader.load() or StructLoader.loadCopy() in this case.

    If the struct contains branched dynamic arrays, the input data need to be
    modified and an extra data buffer needs to be allocated when loading the
    struct instance.
    Use StructLoader.loadCopy() in this case.

 ******************************************************************************/

module ocean.io.serialize.StructLoader;

/******************************************************************************/

class StructLoader
{
    /**************************************************************************
    
        Maximum allowed dynamic array length.
        If any dynamic array is longer than this value, a StructLoaderException
        is thrown.

     **************************************************************************/

    public size_t max_length = size_t.max;
    
    /**************************************************************************
    
        Reused Exception instance

     **************************************************************************/

    private StructLoaderException e;
    
    /**************************************************************************
    
        Type alias definition

     **************************************************************************/
    
    alias void[] delegate ( size_t len ) GetBufferDg;
    
    /***************************************************************************
    
        Loads the S instance represented by data. data must have been obtained
        by StructSerializer.dump!(S)().
        
        S must not contain branched dynamic arrays.
        
        If S contains dynamic arrays, the content of src is modified in-place.
        
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
               same scope. (If you don't do that, src may be relocated in
               memory, turning all dynamic arrays into dangling, segfault prone
               references!)
            2. The members of the obtained instance may be written to as long as
               the length of arrays is not changed.
            3. It is safe to use "cast (S*) src.ptr" to obtain the S instance.
            4. It is safe (however pointless) to load the same buffer twice.
            5. When copying the content of src or doing src.dup, run this method
               on the newly created copy. (If you don't do that, the dynamic
               arrays of the copy will reference the original!) Make sure that
               the original remains unchanged until this method has returned.
            
        Template params:
            S                     = struct type
            allow_branched_arrays = true: allow branced arrays; src must be long
                                    enough to store the branched array instances
             
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
    
    public S* load ( S, bool allow_branched_arrays = false ) ( void[] src )
    out (s)
    {
        assert (s is src.ptr);
    }
    body
    {
        return cast (S*) this.setSlices!(S, allow_branched_arrays)(src).ptr;
    }
    
    /***************************************************************************
    
        Loads the S instance represented by data by setting the dynamic array
        slices. data must have been obtained by StructSerializer.dump!(S)().
        
        S must not contain branched dynamic arrays.
                    
        If S contains dynamic arrays, the content of src is modified in-place.
        
        allow_branched_arrays = true is useful to adjust the slices after a
        buffer previously created by loadCopy() is copied or relocated.
        
        Notes:
            1. After this method has returned, do not change src.length to a
               value other than 0, unless you set the content of src to zero
               bytes *before* changing the size. (If you don't do that, src may 
               be relocated in memory, turning all dynamic arrays into dangling,
               segfault prone references!)
            2. The members of the obtained instance may be written to as long as
               the length of arrays is not changed.
            3. It is safe to use "cast (S*) src.ptr" to obtain the S instance.
            4. It is safe (however pointless) to load the same buffer twice.
            5. When copying the content of src or doing src.dup, run this method
               on the newly created copy. (If you don't do that, the dynamic
               arrays of the copy will reference the original!) Make sure that
               the original remains unchanged until this method has returned.
            
        Template params:
            S                     = struct type
            allow_branched_arrays = true: allow branced arrays; src must be long
                                    enough to store the branched array instances
             
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
    
    public void[] setSlices ( S, bool allow_branched_arrays = false ) ( void[] src )
    out (data)
    {
        assert (data.ptr    is src.ptr);
        assert (data.length <= src.length);
    }
    body
    {
        this.assertDataLongEnough!(S)(src.length, S.sizeof, __FILE__, __LINE__);
        
        static if (allow_branched_arrays)
        {
            size_t slices_len = 0,
                   data_len   = this.sliceArraysBytes!(S)(src, slices_len);
            
            StructLoaderException.assertEx(this.e, src.length >= data_len + slices_len,
                                           "data buffer too short to store branched array instances",
                                           __FILE__, __LINE__);
            
            size_t pos = data_len;
            
            GetBufferDg get_slice_buffer = ( size_t n )
            {
                size_t start = pos;
                pos += n;
                return src[start .. pos];
            };
        }
        else
        {
            const size_t slices_len = 0;
            
            const GetBufferDg get_slice_buffer = null;
        }
        
        size_t used = this.sliceArrays!(allow_branched_arrays, S)
                                       (*cast (S*) src[0 .. src.length].ptr,
                                        src[S.sizeof .. $ - slices_len], get_slice_buffer) + slices_len;
        
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
             dst             = destination buffer; may be null, a new array is
                               then created
             src             = data of a serialized S instance
             only_extend_dst = true: do not decrease dst.length, false: set
                               dst.length to the actual referenced content
             
         Returns:
             deserialised S instance
             
         Throws:
             StructLoaderException if src is too short or the length of a
             dynamic array is greater than max_length.
        
        Out:
            The returned S instance is dst.ptr. 

     **************************************************************************/
    
    public S* loadCopy ( S ) ( ref void[] dst, void[] src, bool only_extend_dst = false )
    out (s)
    {
        assert (s is dst.ptr);
    }
    body
    {
        return cast (S*) this.loadCopyRaw!(S)(dst, src, only_extend_dst).ptr;
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
             dst             = destination buffer; may be null, a new array is
                               then created
             src             = data of a serialized S instance
             only_extend_dst = true: do not decrease dst.length, false: set
                               dst.length to the actual referenced content
             
         Returns:
             a slice to the valid content in dst. 
             
         Throws:
             StructLoaderException if src is too short or the length of a
             dynamic array is greater than max_length.
        
        Out:
            - If only_extend_dst = false, the returned slice is dst, otherwise
              it is the beginning of dst.
            - The length of the returned slice (and therefore dst) is at least
              src.length.  

     **************************************************************************/
    
    public void[] loadCopyRaw ( S ) ( ref void[] dst, void[] src, bool only_extend_dst = false )
    out (raw)
    {
        assert (raw.ptr is dst.ptr);
        
        if (only_extend_dst)
        {
            assert (raw.length <= dst.length);
        }
        else
        {
            assert (raw.length == dst.length);
        }
    }
    body
    {
        this.assertDataLongEnough!(S)(src.length, S.sizeof, __FILE__, __LINE__);
        
        /*
         * Calculate the number of bytes used in src, data_len, and the number
         * of bytes required for branched array instances, slices_len.
         * data_len is at least S.sizeof; src[0 .. S.sizeof] refers to the S
         * instance while src[S.sizeof .. data_len] contains the serialised
         * dynamic arrays. 
         * slices_len = 0 indicates that there are no branched arrays at all or
         * none of non-zero size. data_len + slice_len is the minimum required
         * size for dst.
         */
        
        size_t slices_len = 0,
               data_len   = this.sliceArraysBytes!(S)(src, slices_len);
        
        /*
         * Delegate to be called back when a buffer for a branched array
         * instance is required. Returns unique slices of length n to somewhere
         * in dst[data_len .. data_len + slices_len].
         */
        
        size_t pos = data_len;
        
        GetBufferDg get_slice_buffer = ( size_t n )
        {
            size_t start = pos;
            pos += n;
            return dst[start .. pos];
        };
        
        /*
         * Resize dst and copy src[0 .. data_len] to dst[0 .. data_len].
         */
        
        void[] actual_dst = this.initDst(dst, src[0 .. data_len], slices_len, only_extend_dst);
        
        /*
         * Adjust the dynamic array instances in dst to slice the data in the
         * tail of dst, dst[S.sizeof .. data_len]. If S contains branched
         * arrays of non-zero length, call get_slice_buffer() to obtain memory
         * buffers for the dynamic array instances.
         */
        
        size_t used = this.sliceArrays!(true, S)
                                       (*cast (S*) actual_dst[0 .. S.sizeof].ptr,
                                        actual_dst[S.sizeof .. data_len], get_slice_buffer);
        
        assert (S.sizeof + used == data_len);
        assert (pos == data_len + slices_len);
        
        return dst[0 .. pos];
    }
    
    /***************************************************************************
    
        Loads the S instance represented by src. src must have been obtained by
        the StructDumper.dump. slices_buffer is resized as required or created
        as 'new ubyte[]' if initially null.
        
        S may contain branched dynamic arrays.
        
        Template params:
            S = struct type
             
         Params:
             src             = data of a serialized S instance
             only_extend_dst = true: do not decrease dst.length, false: set
                               dst.length to the actual referenced content
             
         Returns:
             the deserialized S instance, references src.
             
         Throws:
             StructLoaderException if src is too short or the length of a
             dynamic array is greater than max_length.

     **************************************************************************/
    
    public S* loadSlice ( S ) ( void[] src, ref void[] slices_buffer, bool only_extend_buffer = false )
    {
        return cast (S*) this.loadSliceRaw!(S)(src, slices_buffer, only_extend_buffer)[0 .. S.sizeof].ptr;
    }
    
    /***************************************************************************
    
        Loads the S instance represented by src. src must have been obtained by
        the StructDumper.dump. slices_buffer is resized as required or created
        as 'new ubyte[]' if initially null.
        
        S may contain branched dynamic arrays.
        
        Template params:
            S = struct type
             
         Params:
             src             = data of a serialized S instance
             only_extend_dst = true: do not decrease dst.length, false: set
                               dst.length to the actual referenced content
             
         Returns:
             a slice to the valid content in src. 
             
         Throws:
             StructLoaderException if src is too short or the length of a
             dynamic array is greater than max_length.

     **************************************************************************/
    
    public void[] loadSliceRaw ( S ) ( void[] src, ref void[] slices_buffer, bool only_extend_buffer = false )
    {
        this.assertDataLongEnough!(S)(src.length, S.sizeof, __FILE__, __LINE__);
        
        /*
         * Calculate the number of bytes used in src, data_len, and the number
         * of bytes required for branched array instances, slices_len.
         * data_len is at least S.sizeof; src[0 .. S.sizeof] refers to the S
         * instance while src[S.sizeof .. data_len] contains the serialised
         * dynamic arrays. 
         * slices_len = 0 indicates that there are no branched arrays at all or
         * none of non-zero size. data_len + slice_len is the minimum required
         * size for dst.
         */
        
        size_t slices_len = 0;
        
        src = src[0 .. this.sliceArraysBytes!(S)(src, slices_len)];
        
        /*
         * Delegate to be called back when a buffer for a branched array
         * instance is required. Returns unique slices of length n to somewhere
         * in dst[data_len .. data_len + slices_len].
         */
        
        size_t pos = 0;
        
        GetBufferDg get_slice_buffer = ( size_t n )
        {
            size_t start = pos;
            pos += n;
            return slices_buffer[start .. pos];
        };
        
        /*
         * Resize dst and copy src[0 .. data_len] to dst[0 .. data_len].
         */
        
        if (slices_buffer is null && !slices_len)
        {
            slices_buffer = new ubyte[slices_len];
        }
        else if (slices_buffer.length != slices_len)
        {
            if (slices_buffer.length < slices_len || !only_extend_buffer)
            {
                slices_buffer.length = slices_len;
            }
        }
        
        /*
         * Adjust the dynamic array instances in dst to slice the data in the
         * tail of dst, dst[S.sizeof .. data_len]. If S contains branched
         * arrays of non-zero length, call get_slice_buffer() to obtain memory
         * buffers for the dynamic array instances.
         */
        
        size_t used = this.sliceArrays!(true, S)
                                       (*cast (S*) src[0 .. S.sizeof].ptr,
                                        src[S.sizeof .. $], get_slice_buffer);
        
        assert (S.sizeof + used == src.length);
        assert (pos == slices_len);
        
        return src;
    }
    
    /***************************************************************************
    
        Calculates the number of bytes required by loadCopy() for array
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
    
    public size_t sliceArraysBytes ( S ) ( void[] data, out size_t bytes )
    out (n)
    {
        assert (n >= S.sizeof);
    }
    body
    {
        this.assertDataLongEnough!(S)(data.length, S.sizeof, __FILE__, __LINE__);
        
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
             n     = incremented by the number of bytes required by sliceArray()
             
         Returns:
             number of bytes used in data
        
     **************************************************************************/
    
    private size_t sliceArrayBytes ( T ) ( void[] data, ref size_t n )
    {
        StructLoaderException.assertDataLongEnough!(T)(this.e, data.length, size_t.sizeof, __FILE__, __LINE__);
        
        /*
         * Obtain the array length from data, calculate the number of bytes of
         * the array and define the reading position in data.  
         */
        
        size_t len   = *cast (size_t*) data[0 .. size_t.sizeof].ptr,
               bytes = len * T.sizeof,
               pos   = len.sizeof;
        
        StructLoaderException.assertLengthInRange!(T)(this.e, len, this.max_length, __FILE__, __LINE__);
        
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
            return pos + this.sliceSubArraysBytes!(T)(len, data[pos .. $], n);
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
    
    private size_t sliceSubArraysBytes ( T ) ( size_t len, void[] data, ref size_t n )
    {
        size_t pos = 0;
        
        static if (is (T == struct)) for (size_t i = 0; i < len; i++)
        {
            this.assertDataLongEnough!(T)(data.length, pos, __FILE__, __LINE__);
            
            pos += this.sliceArraysBytes_!(T)(data[pos .. $], n);
        }
        else static if (is (T V : V[]))
        {
            static if (is (V[] == T)) for (size_t i = 0; i < len; i++)
            {
                this.assertDataLongEnough!(T)(data.length, pos, __FILE__, __LINE__);
                
                pos += this.sliceArrayBytes!(V)(data[pos .. $], n);
            }
            else static if (!IsPrimitive!(V)) for (size_t i = 0; i < len; i++)
            {
                this.assertDataLongEnough!(T)(data.length, pos, __FILE__, __LINE__);
                
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
    
    private size_t sliceArrays ( bool allow_branched_arrays, S )
                               ( ref S s, void[] data, GetBufferDg get_slices_buffer )
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
                this.assertDataLongEnough!(S)(data.length, pos, __FILE__, __LINE__);
                
                pos += this.sliceArrays!(allow_branched_arrays)
                                        (*this.getField!(i, Field)(s), data[pos .. $], get_slices_buffer);
            }
            else static if (is (Field Element : Element[]))
            {
                static if (is (Element[] == Field))
                {
                    this.assertDataLongEnough!(S)(data.length, pos, __FILE__, __LINE__);
                    
                    pos += this.sliceArray!(allow_branched_arrays)
                                           (*this.getField!(i, Field)(s), data[pos .. $], get_slices_buffer);
                }
                else static if (!IsPrimitive!(Element))
                {
                    this.assertDataLongEnough!(S)(data.length, pos, __FILE__, __LINE__);
                    
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
    
    private size_t sliceArray ( bool allow_branched_arrays, T )
                              ( out T[] array, void[] data, GetBufferDg get_slices_buffer )
    in
    {
        static if (allow_branched_arrays) assert (get_slices_buffer !is null);
    }
    body
    {
        this.assertDataLongEnough!(T)(data.length, size_t.sizeof, __FILE__, __LINE__);
        
        /*
         * Obtain the array length from data, calculate the number of bytes of
         * the array and define the reading position in data.  
         */
        
        size_t len   = *cast (size_t*) data[0 .. size_t.sizeof].ptr,
               bytes = len * T.sizeof,
               pos   = len.sizeof;
        
        StructLoaderException.assertLengthInRange!(T)(this.e, len, this.max_length, __FILE__, __LINE__);
        
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
                                             (array, data[pos .. $], get_slices_buffer);
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
    
    private size_t sliceSubArrays ( bool allow_branched_arrays, T )
                                  ( T[] array, void[] data, GetBufferDg get_slices_buffer )
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
                this.assertDataLongEnough!(T)(data.length, pos, __FILE__, __LINE__);
                
                pos += this.sliceArrays!(allow_branched_arrays)
                                        (element, data[pos .. $], get_slices_buffer);
            }
        }
        else static if (is (T V : V[]))
        {
            static if (is (V[] == T)) foreach (ref element; array)
            {
                this.assertDataLongEnough!(T)(data.length, pos, __FILE__, __LINE__);
                
                pos += this.sliceArray!(allow_branched_arrays)
                                       (element, data[pos .. $], get_slices_buffer);
            }
            else static if (!IsPrimitive!(V))
            {
                for (size_t i = 0; i < array.length; i++)
                {
                    this.assertDataLongEnough!(T)(data.length, pos, __FILE__, __LINE__);
                    
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
                this.assertDataLongEnough!(S)(data.length, pos, __FILE__, __LINE__);
                
                pos += this.sliceArraysBytes_!(Field)(data[pos .. $], n);
            }
            else static if (is (Field Element : Element[]))
            {
                static if (is (Element[] == Field))
                {
                    this.assertDataLongEnough!(S)(data.length, pos, __FILE__, __LINE__);
                    
                    pos += this.sliceArrayBytes!(Element)(data[pos .. $], n);
                }
                else static if (!IsPrimitive!(Element))
                {
                    this.assertDataLongEnough!(S)(data.length, pos, __FILE__, __LINE__);
                    
                    pos += this.sliceSubArraysBytes!(Element)(Field.length, data[pos .. $], n);
                }
            }
        }
        
        return pos;
    }

    /**************************************************************************

        Returns a pointer to the i-th field of s.
        
        Template parameter:
            i = struct field index
            T = struct field type
        
        Params:
            s = struct instance to reference
            
        Returns:
            pointer to the i-th field of s.
        
     **************************************************************************/
    
    private static T* getField ( size_t i, T, S ) ( ref S s )
    {
        return cast (T*) ((cast (void*) &s) + S.tupleof[i].offsetof);
    }

    /**************************************************************************

        Sets dst.length to src.length + extra_bytes, copies src[] to
        dst[0 .. src.length] and clears dst[src.length .. $].
        
         Params:
             dst             = destination buffer; may be null, a new array is
                               then created
             src             = data of a serialized S instance
             only_extend_dst = true: do not decrease dst.length, false: set
                               dst.length to the actual referenced content
            
         Returns:
             dst[0 .. src.length + extra_bytes] 
        
     **************************************************************************/
    
    private static void[] initDst ( ref void[] dst, void[] src,
                                    size_t extra_bytes, bool only_extend_dst = false )
    out (dst_out)
    {
        assert (dst_out.ptr is dst.ptr);
        assert (dst_out.length == src.length + extra_bytes);
        
        if (only_extend_dst)
        {
            assert (dst.length >= dst_out.length);
        }
        else
        {
            assert (dst.length == dst_out.length);
        }
    }
    body
    {
        size_t total_len = src.length + extra_bytes;
        
        if (dst is null)
        {
            /*
             * Create a new dst buffer and initialise it to the struct content.
             */
            
            dst = new ubyte[total_len];
            
            dst[0 .. src.length] = src[];
        }
        else if (dst.length < total_len)
        {
            if (dst.length < src.length)
            {
                /*
                 * Initialise the dst buffer to the beginning of the struct
                 * content, extend dst and initialise the remaining part in dst.
                 */
                
                size_t old_dst_len = dst.length;
                
                dst[] = src[0 .. dst.length];
                
                dst.length = total_len;
                
                dst[old_dst_len .. src.length] = src[old_dst_len .. $];
            }
            else
            {
                /*
                 * Initialise the dst buffer to the struct content, clear what
                 * is behind and extend the dst buffer.
                 */
                
                dst[0 .. src.length] = src[];
                (cast (ubyte[]) dst)[src.length .. $] = 0;
                dst.length = total_len;
            }
        }
        else
        {
            /*
             * Initialise the dst buffer to the struct content, clear what is
             * behind and shorten the dst buffer if requested.
             */
            
            dst[0 .. src.length] = src[];
            (cast (ubyte[]) dst)[src.length .. $] = 0;
            
            if (!only_extend_dst)
            {
                dst.length = total_len;
            }
        }
        
        return dst[0 .. total_len];
    }
    
    private void assertDataLongEnough ( T ) ( size_t len, size_t required, char[] file, typeof (__LINE__) line )
    {
        StructLoaderException.assertDataLongEnough!(T)(this.e, len, required, file, line);
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
        
        static void assertEx ( S, char[] msg ) ( ref typeof (this) e, bool ok, char[] file, typeof (__LINE__) line )
        {
            if (!ok)
            {
                const full_msg = "Error loading " ~ S.stringof ~ ": " ~ msg;
                
                if (!e)
                {
                    e = new typeof (this);
                }
                
                e.msg  = full_msg;
                e.file = file;
                e.line = line;
                
                throw e;
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
        
        static void assertLengthInRange ( S ) ( ref typeof (this) e, size_t len, size_t max, char[] file, typeof (__LINE__) line )
        {
            assertEx!(S, "array too long")(e, len <= max, file, line);
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
        
        static void assertDataLongEnough ( S ) ( ref typeof (this) e, size_t len, size_t required, char[] file, typeof (__LINE__) line )
        {
            assertEx!(S, "input data too short")(e, len >= required, file, line);
        }
    }
}

/******************************************************************************

    Struct loader bundled with a buffer that keeps the most recently
    deserialized data.

 ******************************************************************************/

class BufferedStructLoader ( S ) : IBufferedStructLoader
{
    /**************************************************************************

        Struct type alias.

     **************************************************************************/

    alias S Struct;
    
    /**************************************************************************

        Constructor.
        
        Note that bytes_reserved > Struct.sizeof only makes sense if the struct
        contains dynamic arrays. In this case Struct.sizeof plus the estimated
        number of bytes required for the content of the dynamic arrays may be
        supplied.
        
        Params:
            bytes_reserved = minimum buffer size for preallocation, will be
                             rounded up to Struct.sizeof.

     **************************************************************************/
    
    public this ( size_t bytes_reserved = Struct.sizeof )
    {
        super((cast (void*) &Struct.init)[0 .. Struct.sizeof], bytes_reserved);
    }
    
    /***************************************************************************
    
        Loads data and adjusts the dynamic arrays in the serialised struct.
        
        Note: This may turn an array slice previously obtained from this method
        or a struct pointer obtained from load() into a dangling reference.
        
        Params:
            data = serialised struct data
            
        Returns:
            a slice to the internal buffer that holds the loaded struct data.
            
        Throws:
            StructLoaderException on data inconsistency.
        
     **************************************************************************/
    
    public void[] loadRaw ( void[] src )
    {
        return this.loader.loadCopyRaw!(Struct)(this.buffer, src, this.extend_only);
    }
    
    /***************************************************************************
    
        Loads data and adjusts the dynamic arrays in the serialised struct.
        
        Note: This may turn an array slice previously obtained from loadRaw()
        or a struct pointer obtained from this method into a dangling reference.
        
        Params:
            data = serialised struct data
            
        Returns:
            a pointer to the deserialized struct instance. 
            
        Throws:
            StructLoaderException on data inconsistency.
        
     **************************************************************************/
    
    public Struct* load ( void[] src )
    {
        return this.loader.loadCopy!(Struct)(this.buffer, src, this.extend_only);
    }
    
    /***************************************************************************
    
        Copies the current struct data to dst and adjusts the dynamic arrays in
        the serialised struct in dst.
        
        Params:
            dst = destination buffer
            
        Returns:
            a pointer to the deserialized struct instance in dst. 
            
        Throws:
            StructLoaderException on data inconsistency.
        
     **************************************************************************/
    
    public Struct* copyTo ( D = void ) ( ref D[] dst )
    in
    {
        static assert (D.sizeof == 1, "need a single-byte array type, not \"" ~ D.stringof ~ '"');
    }
    out (s)
    {
        assert (s is dst.ptr);
    }
    body
    {
        return this.loader.loadCopy!(Struct)(this.buffer, dst, this.extend_only);
    }
}

/******************************************************************************

    Type independent BufferedStructLoader base class.

 ******************************************************************************/

abstract class IBufferedStructLoader
{
    /***************************************************************************
    
        Set to true to disable decreasing the buffer size when shorter data are
        loaded.
        
     **************************************************************************/

    public bool extend_only = false;
    
    
    /***************************************************************************
    
        Struct data length (without dynamic array content).
        
     **************************************************************************/
    
    public const size_t struct_size;
    
    /***************************************************************************
    
        StructLoader instance
        
     **************************************************************************/
    
    protected const StructLoader loader;
    
    /***************************************************************************
    
        Reused buffer storing loaded struct data
        
     **************************************************************************/
    
    protected void[] buffer;
    
    /***************************************************************************
    
        Struct initialisation data
        
     **************************************************************************/
    
    private const void[] struct_init;
    
    
    /***************************************************************************
    
        Consistency check
        
     **************************************************************************/
    
    invariant ( )
    {
        assert (this.buffer.length   >= this.struct_size);
    }
    
    
    /***************************************************************************
    
        Constructor
        
        Params:
            struct_init    = struct initialisation data; struct_init.length
                             specifies the struct size
            bytes_reserved = minimum buffer length, rounded up to the struct
                             type size
        
     **************************************************************************/
    
    protected this ( void[] struct_init, size_t bytes_reserved = 0 )
    out
    {
        assert (this);
        assert (this.struct_size == this.struct_init.length);
    }
    body
    {
        this.struct_init = struct_init;
        this.struct_size = struct_init.length;
        this.loader      = new StructLoader;
        
        this.loader.initDst(this.buffer, this.struct_init, bytes_reserved);
    }
    
    
    /***************************************************************************
    
        Disposer
        
     **************************************************************************/
    
    protected override void dispose ( )
    {
        delete this.loader;
        delete this.buffer;
    }
    
    /***************************************************************************
    
        Loads data and adjusts the dynamic arrays in the serialised struct.
        
        Note: This may turn an array slice previously obtained from this method
        into a dangling reference.
        
        Params:
            data = serialised struct data
            
        Returns:
            a slice to the internal buffer that holds the loaded struct data.
            
        Throws:
            StructLoaderException on data inconsistency.
        
     **************************************************************************/
    
    abstract public void[] loadRaw ( void[] data )
    out (raw)
    {
        assert (raw.length >= this.struct_size);
    }
    body
    {
        return null;
    }
    
    /***************************************************************************
    
        Clears and reinialises the struct data buffer.
        
        Note: An array slice previously obtained from loadRaw() will stay valid 
        but reference the .init value of the struct.
        
        Returns:
            this instance.
        
     **************************************************************************/
    
    public typeof (this) clear ( )
    {
        this.buffer[0 .. struct_init.length] = this.struct_init[];
        (cast (ubyte[]) this.buffer)[struct_init.length .. $] = 0;
        
        return this;
    }
    
    /***************************************************************************
    
        Specifies the minimum struct data buffer length and sets the buffer
        length to it.
        
        Note: This may turn an array slice previously obtained from getRaw()
        into a dangling reference.
        
        Params:
            bytes_reserved_ = minimum struct data buffer length, will be rounded
                              up to the struct type size
        
        Returns:
            this instance.
        
     **************************************************************************/
    
    public typeof (this) minimize ( size_t bytes_reserved = 0 )
    out
    {
        assert (this.buffer.length == bytes_reserved);
    }
    body
    {
        this.loader.initDst(this.buffer, this.struct_init, bytes_reserved);
        
        return this;
    }
}

