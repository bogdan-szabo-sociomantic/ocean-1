/******************************************************************************

    Core of Struct data deserializer

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
    In this case there is no need for using the StructLoaderCore.

    If the struct contains dynamic arrays, which are not branched, the input
    data need to be modified in-place when loading the struct instance, but no
    additional data buffers are required.
    Use StructLoaderCore.load() or StructLoaderCore.loadCopy() in this case.

    If the struct contains branched dynamic arrays, the input data need to be
    modified and an extra data buffer needs to be allocated when loading the
    struct instance.
    Use StructLoaderCore.loadCopy() in this case.

 ******************************************************************************/

module ocean.io.serialize.model.StructLoaderCore;

/*******************************************************************************

    The struct loader class

*******************************************************************************/

class StructLoaderCore
{
    /**************************************************************************

        Maximum allowed dynamic array length.
        If any dynamic array is longer than this value, a StructLoaderException
        is thrown.

     **************************************************************************/

    public size_t max_length = size_t.max;

    /**************************************************************************

        Reused Exception instance

        Not meant to be public, but needs to be accessible from StructLoader

     **************************************************************************/

    public StructLoaderException e;

    /**************************************************************************

        Type alias definition

     **************************************************************************/

    alias void[] delegate ( size_t len ) GetBufferDg;

    /***************************************************************************

        Loads the S instance represented by data by setting the dynamic array
        slices. data must have been obtained by StructSerializer.dump!(S)().

        If S contains dynamic arrays, the content of src is modified in-place.

        allow_branched_arrays = true is useful to adjust the slices after a
        buffer previously created by loadCopy() is copied or relocated.

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
                                    enough to store the branched array
                                    instances. If false, a static assertion
                                    makes sure that S does not contain branched
                                    arrays.

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

        Identical to StructLoaderCore.load with the following differences:

        If S contains branched dynamic arrays, the length of src is set so that
        the slices of the branched arrays can be stored at the end of src.

     **************************************************************************/

    public S* loadExtend ( S ) ( ref void[] src )
    out (s)
    {
        assert (s is src.ptr);
    }
    body
    {
        size_t slices_len = 0,
               data_len   = this.sliceArraysBytes!(S)(src, slices_len);
        src.length = data_len + slices_len;

        return cast (S*) this.setSlices!(S, true)(src).ptr;
    }

    /***************************************************************************

        Identical to StructLoaderCore.load with the following differences:

        Returns:
            The returned buffer slices src from the beginning.

     **************************************************************************/

    public void[] setSlices ( S, bool allow_branched_arrays = false ) ( void[] src )
    out (data)
    {
        assert (data.ptr    is src.ptr, "output doesn't start with input!");
        assert (data.length <= src.length, "Length of output less than input!");
    }
    body
    {
        this.assertDataLongEnough!(S)(src.length, S.sizeof, __FILE__, __LINE__);

        static if (allow_branched_arrays)
        {
            size_t slices_len = 0,
                   data_len   = this.sliceArraysBytes!(S)(src, slices_len);

            StructLoaderException.assertEx!(S, "data buffer too short to store branched array instances")
                                           (this.e, src.length >= data_len + slices_len, __FILE__, __LINE__);

            this.setSlices_!(S, allow_branched_arrays)(src[0 .. data_len], src[data_len .. data_len + slices_len]);

            return src[0 .. data_len + slices_len];
        }
        else
        {
            return this.setSlices_!(S, allow_branched_arrays)(src, null);
        }
    }

    /***************************************************************************

        Identical to StructLoaderCore.load with the following differences:

        Copies src to dst and loads the S instance represented by dst.
        If dst is initially null, it is set to a newly allocated array.

        S may contain branched dynamic arrays.

         Params:
             dst             = destination buffer; may be null, a new array is
                               then created
             only_extend_dst = true: do not decrease dst.length, false: set
                               dst.length to the actual referenced content

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

        Identical to StructLoaderCore.loadCopy with the following differences:

        Returns:
            the slice to the beginning of dst which contains the deserialized
            struct instance.

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
         * Resize dst and copy src[0 .. data_len] to dst[0 .. data_len].
         */

        void[] actual_dst = this.initDst(dst, src[0 .. data_len], slices_len, only_extend_dst);

        /*
         * Adjust the dynamic array instances in dst to slice the data in the
         * tail of dst, dst[S.sizeof .. data_len]. If S contains branched
         * arrays of non-zero length, call get_slice_buffer() to obtain memory
         * buffers for the dynamic array instances.
         */

        this.setSlices_!(S, true)(actual_dst[0 .. data_len], actual_dst[data_len .. $]);

        return actual_dst;
    }

    /***************************************************************************

        Identical to StructLoaderCore.load with the following differences:

        slices_buffer is resized as required or created as 'new ubyte[]' if
        initially null.

        S may contain branched dynamic arrays.

        Params:
            slices_buffer   = buffer to use for the slices
            only_extend_buffer = true: do not decrease slices_buffer.length,
                                 false: set slices_buffer.length to the actual
                                 referenced content

        Returns:
            the struct pointer, pointing to the beginning of src which contains
            the deserialized struct instance. All branched arrays of non-zero
            length in the deserialized S instance will reference data in
            slices_buffer, which in turn reference data in src.

     **************************************************************************/

    public S* loadSlice ( S ) ( void[] src, ref void[] slices_buffer, bool only_extend_buffer = false )
    {
        return cast (S*) this.loadSliceRaw!(S)(src, slices_buffer, only_extend_buffer)[0 .. S.sizeof].ptr;
    }

    /***************************************************************************

        Identical to StructLoaderCore.loadSlice with the following differences:

        Returns:
            the slice to the beginning of src which contains the deserialized
            struct instance. All branched arrays of non-zero length in the
            deserialized S instance will reference data in slices_buffer, which
            in turn reference data in src.

        Throws:
            StructLoaderException if
             - src is too short
             - or the length of a dynamic array is greater than max_length.

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
         * Resize slices_buffer.
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

        return this.setSlices_!(S, true)(src, slices_buffer);
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

        Loads the S instance represented by src. If allow_branched_arrays is
        true, slices of branched arrays are stored in slices_buffer. If false,
        S must not have branched arrays; this is checked at compile-time.
        slices_buffer is expected to have the required length which can be
        calculated using sliceArraysBytes().

        Template params:
            S                     = struct type
            allow_branched_arrays = true: allow branched arrays; src must be
                                    long enough to store the branched array
                                    instances. If false, a static assertion
                                    makes sure that S does not contain branched
                                    arrays.

         Params:
             src           = data of a serialized S instance
             slices_buffer = buffer to store slices of branched arrays, not used
                             if allow_branched_arrays is false

         Returns:
             a slice to the valid content in src.

         Throws:
             StructLoaderException if
              - src is too short
              - or the length of a dynamic array is greater than max_length or
              - slices_buffer is too short.

     **************************************************************************/

    private void[] setSlices_ ( S, bool allow_branched_arrays = false ) ( void[] src, void[] slices_buffer )
    out (data)
    {
        assert (data.ptr    is src.ptr);
        assert (data.length <= src.length);
    }
    body
    {
        static if (allow_branched_arrays)
        {
            size_t pos = 0;

            GetBufferDg get_slice_buffer = ( size_t n )
            {
                size_t start = pos;
                pos += n;
                return slices_buffer[start .. pos];
            };
        }
        else
        {
            const GetBufferDg get_slice_buffer = null;
        }

        /*
         * Adjust the dynamic array instances in src to slice the data in the
         * tail of src, src[S.sizeof .. $]. If S contains branched
         * arrays of non-zero length, call get_slice_buffer() to obtain memory
         * buffers for the dynamic array instances.
         */

        size_t arrays_length = this.sliceArrays!(allow_branched_arrays, S)
                                                 (*cast (S*) src[0 .. src.length].ptr,
                                                 src[S.sizeof .. $], get_slice_buffer);

        return src[0 .. arrays_length + S.sizeof];
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
        this.assertDataLongEnough!(T)(data.length, size_t.sizeof, __FILE__, __LINE__);

        /*
         * Obtain the array length from data, calculate the number of bytes of
         * the array and define the reading position in data.
         */

        size_t len   = *cast (size_t*) data[0 .. size_t.sizeof].ptr,
               bytes = len * T.sizeof,
               pos   = len.sizeof;

        StructLoaderException.assertLengthInRange!(T[])(this.e, len, this.max_length, __FILE__, __LINE__);

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

            this.assertDataLongEnough!(T[])(data.length, pos, __FILE__, __LINE__);
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
            this.assertDataLongEnough!(T[])(data.length, pos, __FILE__, __LINE__);

            pos += this.sliceArraysBytes_!(T)(data[pos .. $], n);
        }
        else static if (is (T V : V[]))
        {
            static if (is (V[] == T)) for (size_t i = 0; i < len; i++)
            {
                this.assertDataLongEnough!(T[])(data.length, pos, __FILE__, __LINE__);

                pos += this.sliceArrayBytes!(V)(data[pos .. $], n);
            }
            else static if (!IsPrimitive!(V)) for (size_t i = 0; i < len; i++)
            {
                this.assertDataLongEnough!(T[])(data.length, pos, __FILE__, __LINE__);

                pos += this.sliceSubArraysBytes!(V)(T.length, data[pos .. $], n);
            }
        }
        else pragma (msg, n, "sliceSubArraysBytes: no subarrays (primitive ", T.stringof, ")");

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
        this.assertDataLongEnough!(T[])(data.length, size_t.sizeof, __FILE__, __LINE__);

        /*
         * Obtain the array length from data, calculate the number of bytes of
         * the array and define the reading position in data.
         */

        size_t len   = *cast (size_t*) data[0 .. size_t.sizeof].ptr,
               bytes = len * T.sizeof,
               pos   = len.sizeof;

        StructLoaderException.assertLengthInRange!(T[])(this.e, len, this.max_length, __FILE__, __LINE__);

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

            this.assertDataLongEnough!(T[])(data.length, pos, __FILE__, __LINE__);

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
                this.assertDataLongEnough!(T[])(data.length, pos, __FILE__, __LINE__);

                pos += this.sliceArrays!(allow_branched_arrays)
                                        (element, data[pos .. $], get_slices_buffer);
            }
        }
        else static if (is (T V : V[]))
        {
            static if (is (V[] == T)) foreach (ref element; array)
            {
                this.assertDataLongEnough!(T[])(data.length, pos, __FILE__, __LINE__);

                pos += this.sliceArray!(allow_branched_arrays)
                                       (element, data[pos .. $], get_slices_buffer);
            }
            else static if (!IsPrimitive!(V))
            {
                for (size_t i = 0; i < array.length; i++)
                {
                    this.assertDataLongEnough!(T[])(data.length, pos, __FILE__, __LINE__);

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
             n     = incremented by the number of bytes required by
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

        Not meant to be public, but needs to be accessible from StructLoader

         Params:
             dst             = destination buffer; may be null, a new array is
                               then created
             src             = data of a serialized S instance
             only_extend_dst = true: do not decrease dst.length, false: set
                               dst.length to the actual referenced content

         Returns:
             dst[0 .. src.length + extra_bytes]

     **************************************************************************/

    public static void[] initDst ( ref void[] dst, void[] src,
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
            is (T == void) ||
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

        static void assertEx ( S, char[] msg, E ) ( ref E e, bool ok, char[] file, typeof (__LINE__) line )
        {
            if (!ok)
            {
                const full_msg = "Error loading " ~ S.stringof ~ ": " ~ msg;

                if (!e)
                {
                    e = new E;
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


version ( UnitTest )
{
    import ocean.io.serialize.StructDumper;
    import ocean.io.serialize.StructLoader;
}



// Test versioning and loading of old versions
unittest
{
    void[] buf;
    auto nov_loader = new StructLoaderCore();

    // Make sure functions still work without version
    struct NoVersion
    {
        int a,b,c,d;

        int[] arr;
        char[][] o;
    }

    NoVersion n;

    n.arr = [1,2,3,4,5];

    void[] dst;

    StructDumper.dump!(NoVersion)(buf, n);

    {
        auto r = nov_loader.load!(NoVersion, true)(buf);
        assert ( r.arr.length == n.arr.length, "Array length not the same!");
    }

}
