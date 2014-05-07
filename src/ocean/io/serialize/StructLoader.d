/******************************************************************************

    Struct data deserializer with version support

    copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    version:        March 2014: Initial release

    author:         Mathias Baumann

    Extends the StructLoaderCore with the ability to load versioned structs

 ******************************************************************************/

module ocean.io.serialize.StructLoader;


private import ocean.core.StructConverter,
               ocean.core.Array : copy;

private import ocean.util.container.ConcatBuffer;

private import ocean.io.serialize.StructDumper,
               ocean.io.serialize.model.StructVersionBase,
               ocean.io.serialize.model.StructLoaderCore;

public import ocean.io.serialize.model.StructLoaderCore;

/*******************************************************************************

    StructLoader that supports versioned structs

*******************************************************************************/

class StructLoader
{
    /***************************************************************************

        Shorthand declaration for the version size

    ***************************************************************************/

    private const VSize = StructVersionBase.Version.sizeof;

    /***************************************************************************

        Convenience alias to prevent typing & increase readability

    ***************************************************************************/

    private alias StructVersionBase.GetPreviousOrSame Prev;

    /***************************************************************************

        Exception thrown when the loaded version is not known to us

    ***************************************************************************/

    static class UnknownVersionException :
        StructLoaderCore.StructLoaderException
    {
    }

    /***************************************************************************

        Exception instance for when we encounter a version unknown to us.
        will be allocated upon use

    ***************************************************************************/

    private UnknownVersionException       unknown_exception;

    /***************************************************************************

        Buffers used when doing a conversion from an older struct to a newer one.

        There are two buffers because if a conversion over more than two
        versions happens, we have a call stack likes this:

        Assume src is in version 0 and dst the user target buffer.

        load(src, dst) // Requested Version 3
          |
          + load(src, tmp_a) // Requests version 2
          |   |
          |   + load(src, tmp_b) // Requests version 1
          |   |   |
          |   |   + load(src, tmp_a) // Requests version 0
          |   |   |
          |   |   + convert(tmp_b, tmp_a) // convert 0->1 and write to tmp_b
          |   |
          |   + convert(tmp_a, tmp_b) // convert 1->2 and write to tmp_a
          |
          + convert(dst, tmp_a) // convert 2->3 and write to dst

        The third load() (v1) can't use tmp_a again else destination and source
        for the converted struct would be the same and overwrite each other
        while converting.

        To avoid this we check whether the given dst is one of the buffers and
        choose accordingly the other buffer as required.

    ***************************************************************************/

    private void[] convert_buffer_a, convert_buffer_b;

    /***************************************************************************

        Wrapped instance of simple struct loader

    ***************************************************************************/

    const private StructLoaderCore loader;

    /***************************************************************************

        Instance to access struct version functions

    ***************************************************************************/

    const private StructVersionBase struct_version;

    /***************************************************************************

        Allocates wrapped instance

    ***************************************************************************/

    public this ( )
    {
        this(new StructLoaderCore);
    }

    /***************************************************************************

        Allocates wrapped instance

        Params:
            loader = instance of StructLoaderCore to use. Useful for sharing a
                     loader instance

    ***************************************************************************/

    public this ( StructLoaderCore loader )
    {
        this.loader = loader;
        this.struct_version = new StructVersionBase;
    }

    /***************************************************************************

        Deletes wrapped instance on explicit deletion

    ***************************************************************************/

    public void dispose ( )
    {
        delete this.loader;
        delete this.struct_version;
    }

    /***************************************************************************

        Checks whether S has a version and if so whether the serialized struct
        in src equals the requested version in S.StructVersion.

        If it has a version and it matches the requested one, we "rewind" src so
        that it points to the actual data and let the caller handle the
        deserialisation.

        If it has a version but it is older, we call the caller-provided
        converter delegate and return the result (which is supposed to be the
        deserialized converted struct)

        If it has a version but it is newer we throw an exception.

        If it has no version we do nothing.

        Template Params:
            S = type we want to deserialize to

        Params:
            src = serialized struct

        Returns:
            deserialized and converted struct or null

    ***************************************************************************/

    private void[] handleVersion ( S ) ( ref void[] src,
                                         void[] delegate ( ) converter )
    {
        static if ( StructVersionBase.hasVersion!(S)() )
        {
            const version_ = StructVersionBase.getStructVersion!(S);

            static if ( version_ > 0 ) if ( this.struct_version.getVersion(src) < version_ )
            {
                static assert ( StructVersionBase.getStructVersion!(S) - 1 ==
                                StructVersionBase.getStructVersion!(S.StructPrevious),
                                S.stringof ~ ".StructPrevious.StructVersion "
                                "must always have one version less than "
                                " S.StructVersion!");

                return converter();
            }

            UnknownVersionException.assertEx!(S, "Unknown version!")
                                           (this.unknown_exception,
                                            this.struct_version.getVersion(src) == version_,
                                            __FILE__, __LINE__);

            src = src[StructLoader.VSize .. $];
        }

        return null;
    }

    /+**************************************************************************

        Loads the S instance represented by data by setting the dynamic array
        slices. data must have been obtained by StructSerializer.dump!(S)().

        If S contains dynamic arrays, the content of src is modified in-place.

        allow_branched_arrays = true is useful to adjust the slices after a
        buffer previously created by loadCopy() is copied or relocated.

        If S.StructVersion exists the first byte of the serialized data must
        contain that version. If the version does not match
        ocean.core.StructConverter.structCopy will be used to convert from the
        current version to the latest. See structCopy on how to
        control/influence the conversion.

        S.StructVersion is expected to be declared like this:
        ----
        struct S
        {
            // Current version
            static const ubyte StructVersion = 3;

            // Alias to previous version 2, if existing
            alias .OldS StructPrevious;
        }
        ----

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
             The version doesn't match. If you want to avoid throwing in the
             case of a version mismatch use getVersion to figure out
             whether there is a valid version before loading

             StructLoaderException if src is too short or the length of a
             dynamic array is greater than max_length.

         Out:
            The returned pointer is src.ptr+1.

    **************************************************************************+/

    public S* load ( S, bool allow_branched_arrays = false ) ( void[] src )
    out (s)
    {
        static if ( StructVersionBase.hasVersion!(S)() )
        {
            assert (s is src.ptr + StructLoader.VSize,
                    "Returned value does not start with expected offset");
        }
    }
    body
    {
        return cast (S*) this.setSlices!(S, allow_branched_arrays)(src).ptr;
    }

    /***************************************************************************

        Identical to load() with the following differences:

        If S contains branched dynamic arrays, the length of src is set so that
        the slices of the branched arrays can be stored at the end of src.

     **************************************************************************/

    public S* loadExtend ( S ) ( ref void[] src )
    out (s)
    {
        static if ( StructVersionBase.hasVersion!(S)() )
        if ( StructVersionBase.getStructVersion!(S) ==
             this.struct_version.getVersion(src) )
        {
            assert (s is (src.ptr+1),
                    "Returned value doesn't match source");
        }
    }
    body
    {
        auto orig_src = src;

        void[] convert ( )
        {
             auto buf = src.ptr == this.convert_buffer_a.ptr ?
                                    &this.convert_buffer_b :
                                    &this.convert_buffer_a;

             (*buf).copy(src);

             auto prev = this.loadExtend!(Prev!(S))(*buf);

             auto cur = this.convertStructFromPrevious!(Prev!(S), S)
                                        (*cast(Prev!(S)*) prev, src);

             return (cast(void*)cur)[0 .. cur.sizeof];
        }

        if ( auto ret = this.handleVersion!(S)(src, &convert) )
        {
            return cast(S*)ret.ptr;
        }

        // src is changed in handleVersion(), but in this one case we need the
        // unchanged version
        src = orig_src;

        size_t slices_len = 0,
               data_len   = this.sliceArraysBytes!(S)(src, slices_len);

        static if ( StructVersionBase.hasVersion!(S)() )
        {
            src.length = data_len + slices_len + StructLoader.VSize;
            return cast (S*) this.loader.setSlices!(S, true)(src[StructLoader.VSize..$]).ptr;
        }
        else
        {
            src.length = data_len + slices_len;
            return cast (S*) this.loader.setSlices!(S, true)(src).ptr;
        }
    }

    /***************************************************************************

        Identical to load() with the following differences:

        Returns:
            The returned buffer slices src from the beginning.

     **************************************************************************/

    public void[] setSlices ( S, bool allow_branched_arrays = false ) ( void[] src )
    out (data)
    {
        static if ( StructVersionBase.hasVersion!(S)() )
        {
            // check only valid if no conversion happened
            static if ( StructVersionBase.canConvertStruct!(S)() == false )
            {
                assert (data.ptr    is src.ptr, "output doesn't start with input!");
                assert (data.length <= src.length+1, "Length of output more than input!");
            }
        }
        else
        {
            assert (data.ptr    is src.ptr, "output doesn't start with input!");
            assert (data.length <= src.length, "Length of output less than input!");
        }
    }
    body
    {
        void[] convert ( )
        {
            auto buf = src.ptr == this.convert_buffer_a.ptr ?
                                                &this.convert_buffer_b :
                                                &this.convert_buffer_a;

            (*buf).copy(src);

            auto prev = this.setSlices!(Prev!(S),
                                        allow_branched_arrays) (*buf);

            auto cur = this.convertStructFromPrevious!(Prev!(S), S)
                ( *cast(Prev!(S)*) prev, src);

            return (cast(void*) cur)[0 .. (*cur).sizeof];
        }

        if ( auto ret = this.handleVersion!(S)(src, &convert) )
        {
            return ret;
        }

        return this.loader.setSlices!(S, allow_branched_arrays)(src);
    }

    /***************************************************************************

        Identical to load() with the following differences:

        Copies src to dst and loads the S instance represented by dst.
        If dst is initially null, it is set to a newly allocated array.

        S may contain branched dynamic arrays.

         Params:
             dst             = destination buffer; may be null, a new array is
                               then created
             only_extend_dst = true: do not decrease dst.length, false: set
                               dst.length to the actual referenced content

     **************************************************************************/

    public S* loadCopy ( S ) ( ref void[] dst, void[] src,
                               bool only_extend_dst = false )
    {
        return cast (S*) this.loadCopyRaw!(S)
                                          (dst, src, only_extend_dst).ptr;
    }

    /***************************************************************************

        Identical to loadCopy() with the following differences:

        Returns:
            the slice to the beginning of dst which contains the deserialized
            struct instance.

     **************************************************************************/

    public void[] loadCopyRaw ( S ) ( ref void[] dst, void[] src,
                                      bool only_extend_dst = false )
    {
        void[] convert ( )
        {
            void[]* buf = dst.ptr == this.convert_buffer_a.ptr ?
                                                     &this.convert_buffer_b :
                                                     &this.convert_buffer_a;

            auto prev = this.loadCopyRaw!(Prev!(S))(*buf, src,
                                                    only_extend_dst);

            auto cur = this.convertStructFromPrevious!(Prev!(S), S)
                                                (*cast(Prev!(S)*) prev, dst);

            auto void_ptr = cast(void*) cur;

            return void_ptr[0 .. S.sizeof];
        }

        if ( auto ret = handleVersion!(S)(src, &convert) )
        {
            return ret;
        }

        return this.loader.loadCopyRaw!(S)(dst, src, only_extend_dst);
    }

    /***************************************************************************

        Identical to load() with the following differences:

        slices_buffer is resized as required or created as 'new ubyte[]' if
        initially null.

        S may contain branched dynamic arrays.

        Params:
            slices_buffer   = buffer to use for the slices
            only_extend_buffer = true: do not decrease slices_buffer.length,
                                 false: set slices_buffer.length to the actual
                                 referenced content

        Returns:
            the struct pointer, pointing to the beginning of src plus one byte
            for the version which contains the deserialized struct instance. All
            branched arrays of non-zero length in the deserialized S instance
            will reference data in slices_buffer, which in turn reference data
            in src.

    ***************************************************************************/

    public S* loadSlice ( S ) ( void[] src, ref void[] slices_buffer,
                                bool only_extend_buffer = false )
    {
        return cast (S*) this.loadSliceRaw!(S)
            (src, slices_buffer, only_extend_buffer)[0 .. S.sizeof].ptr;
    }

    /***************************************************************************

        Identical to loadSlice with the following differences:

        Returns:
            the slice to the beginning of src plus one byte for the version
            which contains the deserialized struct instance. All branched arrays
            of non-zero length in the deserialized S instance will reference
            data in slices_buffer, which in turn reference data in src.

        Throws:
            StructLoaderException if
             - src is too short
             - or the length of a dynamic array is greater than max_length.


    ***************************************************************************/

    public void[] loadSliceRaw ( S )
                               ( void[] src, ref void[] slices_buffer,
                                 bool only_extend_buffer = false )
    {
        void[] convert ( )
        {
            auto buf = src.ptr == this.convert_buffer_a.ptr ?
                                             &this.convert_buffer_b :
                                             &this.convert_buffer_a;

            (*buf).copy(src);

            auto prev = this.loadSliceRaw!(Prev!(S))(*buf, slices_buffer,
                                                     only_extend_buffer);

            auto cur = this.convertStructFromPrevious!(Prev!(S), S)
                                                 (*cast(Prev!(S)*) prev, src);

            return (cast(void*) cur)[0 .. (*cur).sizeof];
        }

        if ( auto ret = this.handleVersion!(S)(src, &convert) )
        {
            return ret;
        }

        return this.loader.loadSliceRaw!(S)(src, slices_buffer, only_extend_buffer);
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

    public size_t sliceArraysBytes ( S ) ( void[] data, out size_t bytes)
    {
        static if ( StructVersionBase.hasVersion!(S)() )
        {
            return this.loader.sliceArraysBytes!(S)(data[StructLoader.VSize..$], bytes);
        }
        else
        {
            return this.loader.sliceArraysBytes!(S)(data, bytes);
        }
    }

    /***************************************************************************

        Simple version aware casting to the desired struct type. Ignores
        arrays completely.

        Use this if you are not interested in any array and just want a fast and
        performant access without any costly validations, allocations, memory
        copies or checks.

        Template Params:
            S = struct to cast to
            consider_version = whether to check if the struct has version
                               information and if so, consider it for the
                               returned pointer

        Returns:
            pointer to the struct

    ***************************************************************************/

    public static S* rawStructPtr ( S, bool consider_version = true ) ( void[] data )
    {
        static if ( consider_version && StructVersionBase.hasVersion!(S) )
        {
            return cast(S*) (data.ptr + StructLoader.VSize);
        }
        else
        {
            return cast(S*) data.ptr;
        }
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
    {
        return StructLoaderCore.initDst(dst, src, extra_bytes, only_extend_dst);
    }

    /***************************************************************************

        Updates a struct to the next version

        Template Parameters:
            Old = old version of the struct
            New = new version of the struct

        Params:
            old = instance of the old struct
            dst = buffer to use for the new struct

        Returns:
            pointer to the new struct

    ***************************************************************************/

    private New* convertStructFromPrevious ( Old, New ) ( ref Old old,
                                                         ref void[] dst )
    {
        return this.struct_version.convertStructFromPrevious!(Old, New)
                                                             (this, old, dst);
    }
}

/******************************************************************************

    Struct loader bundled with a buffer that keeps the most recently
    deserialized data.

    Template Params:
        S = struct type for this buffered loader
        Loader = class to use to load struct (VersionedStructLoader or
                 StructLoaderCore are the only compatible once at this time)

 ******************************************************************************/

class BufferedStructLoader ( S, Loader = StructLoader )
    : IBufferedStructLoader!(Loader)
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

abstract class IBufferedStructLoader ( Loader = StructLoader )
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

    protected const Loader loader;

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
        this.loader      = new Loader;

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

version ( UnitTest )
{
    /***************************************************************************

        Imports required for the UnitTest

    ***************************************************************************/

    import ocean.util.Unittest,
           ocean.io.serialize.StructDumper,
           ocean.util.container.ConcatBuffer,
           ocean.util.log.Trace;

    import tango.core.Memory,
           tango.core.Tuple,
           tango.time.StopWatch;

    // Convenience alias for an allocator delegate
    alias void[] delegate ( size_t ) Dg;

    /***************************************************************************

        Wrapper for all flavours of load functions of the StructLoader

    ***************************************************************************/

    New* wrapLoad ( Old, New, Loader ) ( Loader loader, ref void[] src, ref void[] dst )
    {
        size_t bytes;
        auto datalen = loader.sliceArraysBytes!(Old)(src, bytes);
        src.length = StructLoader.VSize + bytes + datalen;

        return loader.load!(New, true)(src);
    }

    New* wrapLoadExtend ( Old, New, Loader ) ( Loader loader, ref void[] src, ref void[] dst )
    {
        return loader.loadExtend!(New)(src);
    }

    New* wrapLoadCopy ( Old, New, Loader ) ( Loader loader, ref void[] src, ref void[] dst )
    {
        return loader.loadCopy!(New)(dst, src);
    }

    New* wrapLoadSlice ( Old, New, Loader ) ( Loader loader, ref void[] src, ref void[] dst )
    {
        return loader.loadSlice!(New)(src, dst);
    }


    /***************************************************************************

        Test the given structs

        Each struct is expected to have the following method:

            static typeof(this) opCall ( size_t i, Dg mem );

        It is used to create instances of that struct with varying values (i
        will change every time). mem is a memory request function that should be
        used if the struct contains arrays to avoid GC memory allocations which
        are measured for testing. Using that memory function makes sure that the
        memory is efficiently reused.

        See also the helper function safe_array to easily allocate new arrays.

        additionally, New has to have

            void compare ( ref Old old, Unittest t )

        to compare with old. It should simply use t.assertLog to make sure all
        values are what the should be.

        Template Params:
            Old = Struct version to write
            New = struct version to read
            Loader = loader to use

        Params:
            t = unittest instance
            iterations = amount of times to read/write this

    ***************************************************************************/

    void test ( Old, New, Loader = StructLoader ) ( Unittest t, size_t iterations )
    {
        scope loader        = new Loader();
        scope struct_buffer = new ConcatBuffer!(void);

        void[] src;
        void[] dst;

        size_t used_memory, free_memory;

        auto load_wrappers =  [&wrapLoad!      (Old, New, Loader),
                               &wrapLoadExtend!(Old, New, Loader),
                               &wrapLoadCopy!  (Old, New, Loader),
                               &wrapLoadSlice! (Old, New, Loader)];

        for ( size_t i = 0; i < iterations; ++i )
        {
            // After 1% of the iterations, memory usage shouldn't grow anymore
            if ( i == cast(size_t) (iterations*0.01) )
            {
                GC.usage(used_memory, free_memory);
            }

            void[] getmem ( size_t s )
            {
                return struct_buffer.add(s);
            }

            Old old = Old(i, &getmem);

            foreach ( wrapper ; load_wrappers )
            {
                StructDumper.dump(src, old);

                wrapper(loader, src, dst).compare(old, t);
            }

            struct_buffer.clear();
        }

        size_t now_used_memory, now_free_memory;
        GC.usage(now_used_memory, now_free_memory);

        t.assertLog(now_used_memory == used_memory, "Unreasonable memory usage!");
    }


    /***************************************************************************

        Helper function to allocate arrays using an allocator function

        Template Params:
            T = type of the array
            V = tuple to get the values of the rest of the array

        Params:
            alloc = function to use to allocate memory
            first = first value of the array
            vals  = further values of the array

        Returns:
            a slice to the array, containing only memory allocated by the alloc
            function

    ***************************************************************************/

    T[] safe_array ( T, V... ) ( Dg alloc, T first, V vals )
    {
        auto ar = (cast(T*)alloc(T.sizeof * vals.length))[0..vals.length+1];

        ar[0] = first;

        foreach ( i, val; vals )
        {
            ar[i+1] = cast(T)vals[i];
        }

        return ar;
    }

    struct NoVersion
    {
        int a,b,c,d;

        int[] arr;
        char[][] o;

        static NoVersion opCall ( size_t i, Dg mem )
        {
            NoVersion n;

            n.a = i;
            n.b = i+1;
            n.c = i+2;
            n.d = i+3;

            n.arr = safe_array(mem, cast(int)i, i+1, i+2, i+3, i+4);
            n.o = safe_array(mem, cast(char[])"one", "two", "three", "four");

            return n;
        }

        void compare ( ref NoVersion n, Unittest t )
        {
            with ( t ) foreach ( i, member; this.tupleof )
            {
                assertLog(member == n.tupleof[i]);
            }
        }
    }

    struct Test0
    {
        static const ubyte StructVersion = 0;

        struct Sub
        {
            int f;
        }

        int none;
        int a;

        Sub[] oi;

        char[][] chars;

        static Test0 opCall ( size_t i, Dg mem )
        {
            Test0 t;

            t.none = i;
            t.a = i+1;
            t.oi = safe_array(mem, Sub(i+1), Sub(i+2), Sub(i+3));
            t.chars = safe_array(mem, cast(char[])"This", "Is", "A",
                                 "Freaking", "String!");

            return t;
        }

        void compare ( ref Test0 n, Unittest t )
        {
            with ( t ) foreach ( i, member; this.tupleof )
            {
                assertLog(member == n.tupleof[i]);
            }
        }
    }

    struct Test1
    {
        static const ubyte StructVersion = 1;
        alias Test0 StructPrevious;

        struct Sub1
        {
            int f;
            int o;

            void convert_o ( ref Test0.Sub s ) { this.o = s.f + 1; }
        }

        int none;
        int a;
        int b;
        Sub1[] oi;
        char[][] chars;

        void convert_b ( ref StructPrevious n )
        {
            this.b = n.none + 5;
        }

        void compare ( ref StructPrevious n, Unittest t )
        {
            with ( t )
            {
                assertLog(none == n.none);
                assertLog(a    == n.a);
                assertLog(b    == n.none + 5);
                assertLog(oi.length   == n.oi.length);

                foreach ( i, o; oi )
                {
                    assertLog(o.f == n.oi[i].f);
                    assertLog(o.o == n.oi[i].f+1);
                }

                assertLog(chars.length   == n.chars.length);

                foreach ( i, o; chars )
                {
                    assertLog(o == n.chars[i]);
                }
            }
        }

        void compare ( ref Test1 n, Unittest t )
        {
            with ( t ) foreach ( i, member; this.tupleof )
            {
                assertLog(member == n.tupleof[i]);
            }
        }

        static Test1 opCall ( size_t i, Dg mem )
        {
            Test1 t;

            t.none = i;
            t.a = i+1;
            t.b = i+2;
            t.oi = safe_array(mem, Sub1(i, i+1), Sub1(i, i+2), Sub1(i, i+3));
            t.chars = safe_array(mem, cast(char[])"This", "Is", "A",
                                 "Freaking", "String", ",", "too!");

            return t;
        }
    }

    struct Test2T ( bool Version )
    {
        static if ( Version )
        {
            static const ubyte StructVersion = 2;
        }

        alias Test1 StructPrevious;

        struct Sub2
        {
            int f;
            int a;

            void convert_a ( ref Test1.Sub1 s ) { this.a = s.o; }
        }

        Sub2[] oi;
        int none;
        int a;
        int b;
        int c;
        char[][] chars;

        void convert_c ( ref StructPrevious f ) { c = f.b+1; }

        void compare ( ref StructPrevious n, Unittest t )
        {
            with ( t )
            {
                assertLog(none == n.none);
                assertLog(a    == n.a);
                assertLog(b    == n.b);
                assertLog(c    == n.b+1);
                assertLog(oi.length   == n.oi.length);

                foreach ( i, o; oi )
                {
                    assertLog(o.f == n.oi[i].f);
                    assertLog(o.a == n.oi[i].o);
                }

                assertLog(chars.length   == n.chars.length);

                foreach ( i, o; chars )
                {
                    assertLog(o == n.chars[i]);
                }
            }
        }

        void compare ( ref Test0 n, Unittest t )
        {
            with ( t )
            {
                assertLog(none == n.none);
                assertLog(a    == n.a);
                assertLog(oi.length   == n.oi.length);

                foreach ( i, o; oi )
                {
                    assertLog(o.f == n.oi[i].f);
                }

                assertLog(chars.length   == n.chars.length);

                foreach ( i, o; chars )
                {
                    assertLog(o == n.chars[i]);
                }
            }
        }

        void compare ( ref typeof(*this) n, Unittest t )
        {
            with ( t ) foreach ( i, member; this.tupleof )
            {
                assertLog(member == n.tupleof[i]);
            }
        }

        static typeof(*this) opCall ( size_t i, Dg mem )
        {
            typeof(*this) t;

            t.none = i;
            t.a = i+1;
            t.b = i+2;
            t.c = i+3;
            t.oi = safe_array(mem, Sub2(i, i+1), Sub2(i, i+2), Sub2(i, i+3));
            t.chars = safe_array(mem, cast(char[])"This", "Is", "A",
                                 "Freaking", "String", "as", "well!");

            return t;
        }
    }

    alias Test2T!(true) Test2;
    alias Test2T!(false) Test2NoV;

}

unittest
{
    const Iterations = 10_000;
    scope t = new Unittest(__FILE__, "StructLoader");

    t.assertLog(!StructVersionBase.canConvertStruct!(Test0), "Can convert struct .. ?");
    t.assertLog(StructVersionBase.canConvertStruct!(Test1), "Can not convert struct");
    t.assertLog(StructVersionBase.canConvertStruct!(Test2), "Can not convert struct");


    test!(Test0, Test0)(t, Iterations);
    test!(Test0, Test1)(t, Iterations);
    test!(Test0, Test2)(t, Iterations);

    test!(Test1, Test1)(t, Iterations);
    test!(Test1, Test2)(t, Iterations);

    test!(Test2, Test2)(t, Iterations);

    test!(NoVersion, NoVersion)(t, Iterations);


    debug ( PerformanceTest )
    {
        StopWatch sw;

        const PerformanceIterations = 10_000;

        sw.start();
        test!(Test2NoV, Test2NoV, StructLoaderCore)(t, PerformanceIterations);
        auto original = sw.stop();

        sw.start();
        test!(Test2, Test2)(t, PerformanceIterations);
        auto new_loader = sw.stop();

        sw.start();
        test!(Test1, Test2)(t, PerformanceIterations);
        auto new_conv = sw.stop();

        sw.start();
        test!(Test0, Test2)(t, PerformanceIterations);
        auto new_conv2 = sw.stop();

        sw.start();
        test!(NoVersion, NoVersion, StructLoaderCore)(t, PerformanceIterations);
        auto orig_no_version = sw.stop();

        sw.start();
        test!(NoVersion, NoVersion)(t, PerformanceIterations);
        auto new_no_version = sw.stop();

        // Those numbers are for the average case, it can very well happen that
        // sometimes a few of those fail. Increase the iteration count to have
        // more reliable results.
        t.assertLog(new_loader <= original*1.1, "Unexpected performance hit!",
                    __LINE__);
        t.assertLog(new_conv <= new_loader*2.5, "Unexpected performance hit!",
                    __LINE__);
        t.assertLog(new_conv2 <= new_conv2*1.4, "Unexpected performance hit!",
                    __LINE__);
        t.assertLog(new_no_version <= orig_no_version*1.05,
                    "Unexpected performance hit!", __LINE__);

        version ( None )
        {
            Trace.formatln("Original loader:     {:d5}", original);
            Trace.formatln("New loader:          {:d5}", new_loader);
            Trace.formatln("New loader + conv:   {:d5}", new_conv);
            Trace.formatln("New loader + conv*2: {:d5}", new_conv2);
            Trace.formatln("Ori loader No Ver:   {:d5}", orig_no_version);
            Trace.formatln("New loader No Ver:   {:d5}", new_no_version);
        }
    }
}
