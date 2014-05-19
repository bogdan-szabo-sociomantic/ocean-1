/*******************************************************************************

    Contains extensions for Map based classes to dump the contents of maps to a
    file or to read from a file into a map. Includes struct versioning support.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        11.09.2012: Initial release
                    02.10.2012: Now uses SimpleSerielizer

    authors:        Mathias Baumann, Hans Bjerkander

    This module provides you with several ways to load/dump a map from/into a
    file:

    * Using the specialized version SerializingMap of the class Map
    * Using the provided MapExtension mixin to extend a map yourself
    * Using the class MapSerializer to use the load/dump functions directly

    See documentation of class MapSerializer for more details

*******************************************************************************/

module ocean.util.container.map.utils.MapSerializer;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.digest.Fnv1,
               ocean.io.serialize.StructLoader,
               ocean.io.serialize.StructDumper,
               ocean.io.serialize.SimpleSerializer,
               ocean.io.serialize.TypeId,
               ocean.io.serialize.model.StructVersionBase,
               ocean.util.container.map.Map,
               ocean.core.Traits : ContainsDynamicArray;

private import tango.core.Exception    : IOException;
private import tango.io.model.IConduit : IOStream;

private import tango.core.Traits,
               tango.core.Tuple,
               tango.io.stream.Buffered,
               tango.io.device.File;

/*******************************************************************************

    Specialized version of class Map that includes serialization capabilities
    using the MapExtension mixin

    Everything else is identical to the class Map, that means you still need to
    implement your own hashing functionality.

    Template Params:
        V = type of the value
        K = type of the key

*******************************************************************************/

abstract class SerializingMap ( V, K ) : Map!(V, K)
{
    /***************************************************************************

        Mixin extensions for serialization

    ***************************************************************************/

    mixin MapExtension!(K, V);

    /***************************************************************************

        Constructor.

        Same as the Constructor of Map, but additionally initializes the
        serializer.

    ***************************************************************************/

    protected this ( size_t n, float load_factor = 0.75 )
    {
        this.serializer = new MapSerializer;
        super(n, load_factor);
    }

    /***************************************************************************

        Constructor.

        Same as the Constructor of Map, but additionally initializes the
        serializer.

    ***************************************************************************/

    protected this ( IAllocator allocator, size_t n, float load_factor = 0.75 )
    {
        this.serializer = new MapSerializer;
        super(allocator, n, load_factor);
    }
}

/*******************************************************************************

    Template meant to be used with mixin in classes that inherit from the class
    Map.

    Extends the class with a load() and dump() function. The mixed in class has
    to initialize the member 'serializer' in its constructor.

    See SerializingMap for an usage example

    Template Params:
        K = key type of the map
        V = value type of the map

*******************************************************************************/

template MapExtension ( K, V )
{
    /***************************************************************************

        Delegate used to check whether a given record should be dumped or loaded

    ***************************************************************************/

    alias bool delegate ( K, V ) CheckDg;

    /***************************************************************************

        Instance of the serializer, needs to be initialized in the class
        constructor

    ***************************************************************************/

    const protected MapSerializer serializer;

    /***************************************************************************

        Loads a file into the map

        Params:
            file_path = path to the file

    ***************************************************************************/

    public void load ( char[] file_path )
    {
        this.serializer.load!(K, V)(this, file_path);
    }

    /***************************************************************************

        Loads a file into the map

        Params:
            file_path = path to teh file
            check     = function called for every entry, should return true if
                        it should be loaded

    ***************************************************************************/

    public void load ( char[] file_path, CheckDg check  )
    {
        void add ( ref K k, ref V v )
        {
            if (check(k,v)) *this.put(k) = v;
        }

        this.serializer.loadDg!(K, V)(file_path, &add);
    }

    /***************************************************************************

        Dumps a map into a file

        Params:
            file_path = path to the file

    ***************************************************************************/

    public void dump ( char[] file_path )
    {
        this.serializer.dump!(K, V)(this, file_path);
    }

    /***************************************************************************

        Writes a map to a file.

        Params:
            file_path = path to where the map should be dumped to
            check     = function called for each key/value to confirm that it
                        should be dumped

     ***************************************************************************/

    public void dump ( char[] file_path, CheckDg check )
    {
        void adder ( void delegate ( K, V ) add )
        {
            foreach ( k, v; this ) if ( check(k,v) )
            {
                add(k, v);
            }
        }

        this.serializer.dumpDg!(K, V)(file_path, &adder);
    }
}

/*******************************************************************************

    Offers functionality to load/dump the content of Maps (optionally of
    anything actually, using the delegate version of the dump/load functions).

    Features include backwards compability with auto-conversion to the requested
    struct version. It makes use of the same functions that the
    StructLoader/StructDumper use for the conversion.

    This means that structs used with this function should have the static const
    member StructVersion as well as an alias to the old version (if one exists)
    called "StructPrevious" (this is identical to the requirements for vesioned
    struct in the StructDumper/Loader.

    If you have a map saved in the old version (2) and at the same time updated
    the struct definition of that map, you can still take advantage of the
    auto-conversion functionality if you simply define the old struct version as
    version 0 and your current one as version 1. The loader is smart enough to
    figure out the old version by hash and converts it to the newer one.

    Usage Example:
    ---
    struct MyValue0
    {
        static const StructVersion = 0;
        int my_value;
    }

    auto serializer = new MapSerializer;
    auto myMap = new HashMap!(MyValue0)(10);

    // Assume code to fill map with values here
    //...
    //

    serializer.dump(myMap, "version0.map");

    // Later...

    serilizer.load(myMap, "version0.map");


    // Now, if you have changed the struct, create a new version of it

    struct MyValue1
    {
        static const StructVersion = 1;
        int my_value;

        int my_new_value;

        void convert_my_new_value ( ref MyValue0 old )
        {
            this.my_new_value = old.my_value * 2;
        }
    }

    // This is our map with the new version
    auto myNewMap = new HashMap!(MyValue1)(10);

    // Load old version
    serializer.load(myNewMap, "version0.map");

    // .. use map as desired.

    // You can do the same thing with the key in case it is a struct.
    ---
*******************************************************************************/

class MapSerializer
{
    /***************************************************************************

        Magic Marker for HashMap files, part of the header

     ***************************************************************************/

    private const uint MAGIC_MARKER = 0xCA1101AF;

    /***************************************************************************

        Exception thrown when the file that was loaded is incomplete. Will soon
        be unused

    ***************************************************************************/

    class UnexpectedEndException : Exception
    {
        this ( char[] msg, char[] file, size_t line )
        {
            super(msg, file, line);
        }
    }

    /***************************************************************************

        Helper template for version handling.
        Takes a tuple of types and changes the type and position index to what
        ever it has as .StructPrevious member.

        Only works with tuples of length 2

        Template Params:
            index = index of the type that will be made into StructPrevious
            T...  = tuple of the types

    ***************************************************************************/

    template AddStructPrevious ( ubyte index, T... )
    {
        static assert ( T.length == 2 );
        static assert ( index <= 1 );

        static if ( index == 0 )
        {
            alias Tuple!(T[0].StructPrevious, T[1]) AddStructPrevious;
        }
        else
        {
            alias Tuple!(T[0], T[1].StructPrevious) AddStructPrevious;
        }
    }

    /***************************************************************************

        Takes a type tuple and transforms it into the same type tuple but with
        the types being pointers to the original types.

        Template Params:
            T... = tuple to convert

    ***************************************************************************/

    template AddPtr ( T... )
    {
        static if ( T.length > 0 )
        {
            alias Tuple!(T[0]*, AddPtr!(T[1..$])) AddPtr;
        }
        else
        {
            alias T AddPtr;
        }
    }

    /***************************************************************************

        Struct to be used for creating unique hash

    ***************************************************************************/

    private struct KeyValueStruct( K, V)
    {
        K k;
        V v;
    }

    /***************************************************************************

        File header writen at the beginning of a dumped HashMap

    ***************************************************************************/

    private struct FileHeader ( K, V, ubyte VERSION = 3 )
    {
        /***********************************************************************

            Magic Marker, making sure that this file is really what we expect it
            to be

        ***********************************************************************/

        uint marker         = MAGIC_MARKER;

        /***********************************************************************

            Version of the FileHeader. Should be changed for any modification

        ***********************************************************************/

        ubyte versionNumber = VERSION;

        /***********************************************************************

            Hash or Version of the struct types, making sure that the key and
            value types are the same as when this file was saved.

        ***********************************************************************/

        static if ( VERSION <= 2 &&
                    !is ( K == class) && !is (V == class) &&
                    !is ( K == interface) && !is (V == interface) )
        {
            ulong hash = TypeHash!(KeyValueStruct!(K,V));
        }

        static if ( VERSION == 3 )
        {
            static if ( StructVersionBase.hasVersion!(K)() )
            {
                ubyte key_version = StructVersionBase.getStructVersion!(K)();
            }

            static if ( StructVersionBase.hasVersion!(V)() )
            {
                ubyte value_version = StructVersionBase.getStructVersion!(V)();
            }

            static if ( !StructVersionBase.hasVersion!(K)() &&
                        !StructVersionBase.hasVersion!(V)() &&
                        !is ( K == class) && !is (V == class) &&
                        !is ( K == interface) && !is (V == interface) )
            {
                ulong hash = TypeHash!(KeyValueStruct!(K,V));
            }
        }
    }

    /***************************************************************************

        Delegate used to put values in a map

    ***************************************************************************/

    template PutterDg ( K, V )
    {
        alias void delegate ( ref K, ref V ) PutterDg;
    }

    /***************************************************************************

        Delegate used to add new values from a map

    ***************************************************************************/

    template AdderDg ( K, V )
    {
        alias void delegate ( void delegate ( K, V ) ) AdderDg;
    }

    /***************************************************************************

        Pair of buffers used for conversion

    ***************************************************************************/

    struct BufferPair
    {
        void[] first, second;
    }

    /***************************************************************************

        buffered output instance

    ***************************************************************************/

    private BufferedOutput buffered_output;

    /***************************************************************************

        buffered input instance

    ***************************************************************************/

    private BufferedInput buffered_input;

    /***************************************************************************

        Struct Version functions & logic

    ***************************************************************************/

    const private StructVersionBase struct_version;

    /***************************************************************************

        Temporary buffers to convert value structs

    ***************************************************************************/

    private BufferPair value_convert_buffer;

    /***************************************************************************

        Temporary buffers to convert key structs

    ***************************************************************************/

    private BufferPair key_convert_buffer;

    /***************************************************************************

        Writing buffer for the StructDumper

    ***************************************************************************/

    private void[] dump_buffer;

    /***************************************************************************

        StructLoader, only used for conversions

    ***************************************************************************/

    const private StructLoader loader;


    /***************************************************************************

        Constructor

        Params:
            buffer_size = optional, size of the input/output buffers used for
                          reading/writing

    ***************************************************************************/

    this ( size_t buffer_size = 64 * 1024 )
    {
        this.buffered_output = new BufferedOutput(null, buffer_size);
        this.buffered_input  = new BufferedInput(null, buffer_size);

        this.struct_version  = new StructVersionBase;
        this.loader          = new StructLoader;
    }


    /***************************************************************************

        Writes a map to a file.

        Params:
            map        = instance of the array map to dump
            file_path  = path to where the map should be dumped to

    ***************************************************************************/

    public void dump ( K, V ) ( Map!(V, K) map, char[] file_path )
    {
        void adder ( void delegate ( K, V ) add )
        {
            foreach ( k, v; map )
            {
                add(k, v);
            }
        }

        this.dumpDg!(K, V)(file_path, &adder);
    }


    /***************************************************************************

        Writes a map to a file.

        Params:
            file_path = path to where the map should be dumped to
            adder     = function called with a delegate that can be used to add
                        elements that are to be dumped. Once that delegate
                        returns, the rest will be written.

    ***************************************************************************/

    public void dumpDg ( K, V ) ( char[] file_path, AdderDg!(K, V) adder )
    {
        scope file = new File(file_path, File.Style(File.Access.Write,
                                                    File.Open.Create,
                                                    File.Share.None));

        this.buffered_output.output(file);
        this.buffered_output.clear();

        this.dumpInternal!(K,V)(this.buffered_output, adder);
    }


    /***************************************************************************

        Internal dump function

        Template Params:
            K = Key type of the map
            V = Value type of the map

        Params:
            buffered = stream to write to
            adder    = function called with a delegate that can be used to add
                       elements that aare to be dumped. Once the delegate
                       returns the writing process will be finalized

    ***************************************************************************/

    private void dumpInternal ( K, V ) ( BufferedOutput buffered,
                                         AdderDg!(K, V) adder )
    {
        size_t nr_rec = 0;

        FileHeader!(K,V) fh;

        SimpleSerializer.write(buffered, fh);
        // Write dummy value first
        SimpleSerializer.write(buffered, nr_rec);

        void addKeyVal ( K key, V val )
        {
            SimpleSerializer.write!(K)(buffered, key);
            SimpleSerializer.write!(V)(buffered, val);
            nr_rec++;
        }

        scope(exit)
        {
            buffered.flush();

            // Write actual length now
            buffered.seek(fh.sizeof);
            SimpleSerializer.write(buffered, nr_rec);

            buffered.flush();
        }

        adder(&addKeyVal);
    }


    /***************************************************************************

        loads dumped map content from the file system

        Does not support structs with dynamic arrays yet.

        Throws:
            Exception when the file has not the expected fileheader and
            other Exceptions for various kinds of errors (file not found, etc)

        Template Params:
            K = key of the array map
            V = value of the corresponding key

        Params:
            map       = instance of the array map
            file_path = path to the file to load from

    ***************************************************************************/

    public void load ( K, V ) ( Map!(V, K) map, char[] file_path )
    {
        void putter ( ref K k, ref V v ) { *map.put(k) = v; }

        this.loadDg!(K, V)(file_path, &putter);
    }


    /***************************************************************************

        Loads dumped map content from the file system

        Does not support structs with dynamic arrays yet.

        Throws:
            Exception when the file has not the expected fileheader and
            other Exceptions for various kinds of errors (file not found, etc)

        Template Params:
            K = key of the array map
            V = value of the corresponding key

        Params:
            file_path = path to the file to load from
            putter    = function called for each entry to insert it into the map

    ***************************************************************************/

    public void loadDg ( K, V ) ( char[] file_path, PutterDg!(K, V) putter )
    {
        scope file = new File(file_path, File.ReadExisting);

        this.buffered_input.input(file);

        loadInternal!(K,V)(this.buffered_input, putter);
    }


    /***************************************************************************

        Loads dumped map content from a input stream

        Does not support structs with dynamic arrays yet.

        Throws:
            Exception when the file has not the expected fileheader and
            other Exceptions for various kinds of errors (file not found, etc)

        Template Params:
            K = key of the array map
            V = value of the corresponding key

        Params:
            buffered  = input stream to read from
            putter    = function called for each entry to insert it into the map

    ***************************************************************************/

    private void loadInternal ( K, V ) ( BufferedInput buffered,
                                         PutterDg!(K, V) putter )
    {
        FileHeader!(K,V) fh_expected;
        FileHeader!(K,V) fh_actual;

        fh_actual.versionNumber = ubyte.max;

        buffered.seek(0);
        buffered.compress();
        buffered.populate();

        SimpleSerializer.read(buffered, fh_actual);

        if ( fh_actual.marker != fh_expected.marker )
        {
            throw new Exception("Magic Marker mismatch");
        }
        else if ( fh_actual.versionNumber != fh_expected.versionNumber )
        {
            if ( fh_actual.versionNumber == 2 )
            {
                return this.loadOld!(K,V)(buffered, putter);
            }

            throw new Exception("Version of file header "
                                " does not match our version, aborting!");
        }

        bool conv;

        // Code for converting from older Key/Value structs
        static if ( is ( typeof ( fh_expected.key_version ) ) )
        {
            conv = this.handleVersion!(MapSerializer.loadInternal, 0, K, V)
                            (fh_actual.key_version, fh_expected.key_version,
                             this.key_convert_buffer, putter, buffered);

            if ( conv ) return;
        }

        static if ( is ( typeof ( fh_expected.value_version ) ) )
        {
            conv = this.handleVersion!(MapSerializer.loadInternal, 1, K, V)
                           (fh_actual.value_version, fh_expected.value_version,
                            this.value_convert_buffer, putter, buffered);

            if ( conv ) return;
        }

        static if ( is ( typeof ( fh_expected.hash ) ) )
        {
            if ( fh_expected.hash != fh_actual.hash )
            {
                throw new Exception("File struct differ from struct used to "
                                    "load!", __FILE__, __LINE__);
            }
        }

        K key;
        V value;
        size_t nr_rec;

        if ( buffered.readable < nr_rec.sizeof )
        {
            buffered.compress();
            buffered.populate();
        }
        SimpleSerializer.read(buffered, nr_rec);

        for ( ulong i=0; i < nr_rec;i++ )
        {
            if ( buffered.readable < V.sizeof + K.sizeof )
            {
                buffered.compress();
                buffered.populate();
            }

            SimpleSerializer.read!(K)(buffered, key);
            SimpleSerializer.read!(V)(buffered, value);
            putter(key, value);
        }
    }


    /***************************************************************************

        Checks if a struct needs to be converted and converts it if required

        Template Params:
            loadFunc = function to use to load older version of the struct
            index    = index of the type in the tuple that should be
                       checked/converted
            T...     = tuple of key/value types

        Params:
            actual   = version that was found in the data
            expected = version that is desired
            buffer   = conversion buffer to use
            putter   = delegate to use to put the data into the map
            buffered = buffered input stream

        Returns:
            true if conversion happened, else false

        Throws:
            if conversion failed

    ***************************************************************************/

    private bool handleVersion ( alias loadFunc, size_t index, T... )
                               ( StructVersionBase.Version actual,
                                 StructVersionBase.Version expected,
                                 ref BufferPair buffer,
                                 void delegate ( ref T ) putter,
                                 BufferedInput buffered )
    {
        if ( actual < expected )
        {
            return this.tryConvert!(true, MapSerializer.loadInternal, index, T)
                                   (buffer, putter, buffered);
        }

        return false;
    }


    /***************************************************************************

        Checks if a struct needs to be converted and converts it if required

        Template Params:
            throw_if_unable = if true, an exception is thrown if we can't
                              convert this struct
            loadFunc = function to use to load older version of the struct
            index    = index of the type in the tuple that should be
                       checked/converted
            T...     = tuple of key/value types

        Params:
            buffer   = conversion buffer to use
            putter   = delegate to use to put the data into the map
            buffered = buffered input stream

        Returns:
            true if a conversion happened, false if we can't convert it and
            throw_if_unable is false

        Throws:
            if throw_if_unable is true and we couldn't convert it

    ***************************************************************************/

    private bool tryConvert ( bool throw_if_unable, alias loadFunc,
                              size_t index, T... )
                            ( ref BufferPair buffer,
                              void delegate ( ref T ) putter,
                              BufferedInput buffered )
    {
        static assert ( T.length == 2 );

        const other = index == 1 ? 0 : 1;

        static if ( StructVersionBase.canConvertStruct!(T[index])() )
        {
            alias AddStructPrevious!(index, T) TWithPrev;

            void convPut ( ref TWithPrev keyval )
            {
                auto buf = &keyval[index] is buffer.first.ptr ?
                                &buffer.second : &buffer.first;

                AddPtr!(T) res;

                res[index] = this.struct_version.
                        convertStructFromPrevious!(TWithPrev[index], T[index])
                                                  (this.loader, keyval[index],
                                                   *buf);
                res[other] = &keyval[other];

                putter(*res[0], *res[1]);
            }

            loadFunc!(TWithPrev)(buffered, &convPut);

            return true;
        }
        else static if ( throw_if_unable )
        {
            throw new Exception("Cannot convert to new version!");
        }
        else
        {
            return false;
        }
    }


    /***************************************************************************

        Previous load function, kept so that old versions can still be loaded

        Template Params:
            K = type of the key
            V = type of the value

        Params:
            buffered = stream to read from
            putter   = delegate used to write loaded records to the map

    ***************************************************************************/

    private void loadOld ( K, V ) ( BufferedInput buffered,
                                    void delegate ( ref K, ref V ) putter )
    {
        K key;
        V value;
        size_t nr_rec;

        FileHeader!(K,V,2) fh_expected;
        FileHeader!(K,V,2) fh_actual;

        buffered.seek(0);
        buffered.compress();
        buffered.populate();

        SimpleSerializer.read(buffered, fh_actual);

        if ( fh_actual.marker != fh_expected.marker )
        {
            throw new Exception("Magic Marker mismatch");
        }
        else if ( fh_actual.versionNumber != fh_expected.versionNumber )
        {
            throw new Exception("Version of file header "
                                " does not match our version, aborting!");
        }
        else static if ( is ( typeof ( fh_expected.hash ) ) )
        if ( fh_actual.hash != fh_expected.hash )
        {
            bool conv;

            // convert from a previous key struct to the current
            conv = this.tryConvert!(false, MapSerializer.loadOld, 0, K, V)
                (this.key_convert_buffer, putter, buffered);

            if ( conv ) return;

            // convert from a previous value struct to the current
            conv = this.tryConvert!(false, MapSerializer.loadOld, 1, K, V)
                                   (this.value_convert_buffer, putter, buffered);

            if ( conv ) return;

            throw new Exception("Unable to convert structs " ~ K.stringof ~ ", " ~
                                V.stringof ~
                                " to our structs, aborting!");
        }

        if ( buffered.readable < nr_rec.sizeof )
        {
            buffered.compress();
            buffered.populate();
        }
        SimpleSerializer.read(buffered, nr_rec);

        for ( ulong i=0; i < nr_rec;i++ )
        {

            if ( buffered.readable < V.sizeof + K.sizeof )
            {
                buffered.compress();
                buffered.populate();
            }

            SimpleSerializer.read!(K)(buffered, key);
            SimpleSerializer.read!(V)(buffered, value);
            putter(key, value);
        }
    }
}


/*******************************************************************************

    Unittests

*******************************************************************************/

version ( UnitTest )
{
    import ocean.io.device.MemoryDevice,
           ocean.io.digest.Fnv1,
           ocean.util.Unittest,
           ocean.util.container.map.model.StandardHash,
           ocean.util.container.map.Map,
           ocean.util.container.map.HashMap;

    import tango.core.Traits;

    /***************************************************************************

        Slightly specialized version of Map that would simply take the raw value
        of structs to hash them

    ***************************************************************************/

    class StructhashMap (V, K) : Map!(V, K)
    {
        /***********************************************************************

            Constructor

            Params:
                n = amount of expected elements

        ***********************************************************************/

        public this ( size_t n )
        {
            super(n);
        }

        /***********************************************************************

            Dumb and easy toHash method.

            Simply takes the key and passes it directly to fnv1a.

            Parameters:
                key = key of which the hash is desired

            Returns:
                hash of the key

        ***********************************************************************/

        public override hash_t toHash ( K key )
        {
            return Fnv1a.fnv1(key);
        }

    }

    /***************************************************************************

        Dump function that dumps in the old format, to test whether we can still
        read it (and convert it)

        Template Params:
            K = type of key
            V = type of value

        Params:
            buffered = output stream to write to
            adder    = delegate called with a delegate that can be used to add
                       values

    ***************************************************************************/

    void dumpOld ( K, V ) ( BufferedOutput buffered,
                            MapSerializer.AdderDg!(K, V) adder )
    {
        size_t nr_rec = 0;

        MapSerializer.FileHeader!(K,V,2) fh;

        SimpleSerializer.write(buffered, fh);
        // Write dummy value for now
        SimpleSerializer.write(buffered, nr_rec);

        void addKeyVal ( K key, V val )
        {
            SimpleSerializer.write!(K)(buffered, key);
            SimpleSerializer.write!(V)(buffered, val);
            nr_rec++;
        }

        scope(exit)
        {
            buffered.flush();

            // Write actual length now
            buffered.seek(fh.sizeof);
            SimpleSerializer.write(buffered, nr_rec);

            buffered.flush();
        }

        adder(&addKeyVal);
    }

    /***************************************************************************

        Test writing & loading of the given combination of struct types on a
        virtual file

        Depending on the exact combinations, the key structs should offer the
        following methods:

        * compare ( <other_key_struct> * ) - compare the two structs
        * K old() - convert this struct to the older one

        The value structs should offer only a compare function.

        Template Params:
            K = type of the key to write
            V = type of the value to write
            KNew = type of the key to read, automatic conversion will happen
            VNew = type of the value to read, automatic conversion will happen
            custom_dump = optional, custom code to use for dumping the data.
                          The code is expected to define a variable
                          "header_size" containing the size of the header

        Params:
            t = reference to the current unittest instance
            iterations = amount of elements to put in the map

    ***************************************************************************/

    void test ( K, V, KNew, VNew, char[] custom_dump = "" )
              ( Unittest t, size_t iterations )
    {
        const ValueArraySize = 200;

        scope array = new MemoryDevice;
        scope map   = new StructhashMap!(V, K)(iterations);
        scope serializer = new MapSerializer;

        // helper to get a key from size_t
        K initKey ( size_t i )
        {
            static if ( is ( K == struct ) )
            {
                return K(i);
            }
            else
            {
                return i;
            }
        }

        // helper to get old key from new key
        K fromNew ( KNew k )
        {
            static if ( is ( K == struct ) )
            {
                return k.old();
            }
            else
            {
                return k;
            }
        }

        V initVal ( size_t i )
        {
            static if ( isDynamicArrayType!(V) )
            {
                alias ElementTypeOfArray!(V) VA;

                auto r = new VA[ValueArraySize];

                foreach ( ref e; r )
                {
                    e = VA(i);
                }

                return r;
            }
            else return V(i);
        }

        // Fill test map
        for ( size_t i = 0; i < iterations; ++i )
        {
            *map.put(initKey(i)) = initVal(i);
        }

        void adder ( void delegate ( K, V ) add )
        {
            foreach ( k, v; map )
            {
                add(k, v);
            }
        }

        // Dump test map (to memory)
        static if ( custom_dump.length > 0 )
        {
            mixin(custom_dump);
        }
        else
        {
            serializer.buffered_output.output(array);
            serializer.dumpInternal!(K, V)(serializer.buffered_output, &adder);

            auto header_size = MapSerializer.FileHeader!(K, V).sizeof;
        }

        // Check size of dump
        static if ( isDynamicArrayType!(V) )
        {
            t.assertLog(array.bufferSize() ==
                        (K.sizeof + size_t.sizeof +
                            ElementTypeOfArray!(V).sizeof * ValueArraySize) *
                                iterations + header_size + size_t.sizeof,
                    "Written size is not the expected value!", __LINE__);
        }
        else t.assertLog(array.bufferSize() == (K.sizeof + V.sizeof) *
                    iterations + header_size + size_t.sizeof,
                    "Written size is not the expected value!", __LINE__);


        // Check load function
        size_t amount_loaded = 0;
        void checker ( ref KNew k, ref VNew v )
        {
            amount_loaded++;
            static if ( isDynamicArrayType!(VNew) )
            {
                foreach ( i, el; v )
            t.assertLog(el.compare(&(*map.get(fromNew(k)))[i]), "Loaded item unequal saved item!",
                      __LINE__);
            } else
            t.assertLog(v.compare(map.get(fromNew(k))), "Loaded item unequal saved item!",
                      __LINE__);
        }

        array.seek(0);
        serializer.buffered_input.input(array);
        serializer.loadInternal!(KNew, VNew)(serializer.buffered_input, &checker);

        t.assertLog(amount_loaded == map.bucket_info.length, "Amount of loaded "
                  "items unequal amount of written items!", __LINE__);
    }
}

unittest
{
    const Iterations = 10_000;

    scope Unittest t = new Unittest(__FILE__, "MapSerialier");

    const old_load_code =
          `scope bufout = new BufferedOutput(array, 2048);
           bufout.seek(0);
           dumpOld!(K, V)(bufout, &adder);

           auto header_size = MapSerializer.FileHeader!(K, V, 2).sizeof;`;

    struct TestNoVersion
    {
        long i;

        static TestNoVersion opCall ( long i )
        {
            TestNoVersion t;
            t.i = i*2;
            return t;
        }

        bool compare ( TestNoVersion* other )
        {
            return i == other.i;
        }
    }

    struct Test1
    {
        static const StructVersion = 0;

        long i;
    }

    struct Test2
    {
        static const StructVersion = 1;
        alias Test1 StructPrevious;

        long i;
        long o;
        void convert_o ( ref Test1 t ) { this.o = t.i+1; }

        bool compare ( Test1* old )
        {
            return old.i == i && old.i+1 == o;
        }

        bool compare ( Test2* old )
        {
            return *old == *this;
        }
    }

    struct OldStruct
    {
        static const StructVersion = 0;

        int old;

        bool compare ( OldStruct * o )
        {
            return *o == *this;
        }
    }

    struct NewStruct
    {
        static const StructVersion = 1;
        alias OldStruct StructPrevious;

        int old;

        int a_bit_newer;
        void convert_a_bit_newer ( )
        {
            this.a_bit_newer = old+1;
        }

        bool compare ( OldStruct* old )
        {
            return old.old == this.old &&
                   old.old+1 == a_bit_newer;
        }
    }

    struct OldKey
    {
        static const StructVersion = 0;

        int old2;

        bool compare ( OldKey * o )
        {
            return *o == *this;
        }

        OldKey old ( )
        {
            return *this;
        }
    }

    struct NewKey
    {
        static const StructVersion = 1;
        alias OldKey StructPrevious;

        int old1;

        void convert_old1 ( ref OldKey o )
        {
            old1 = o.old2;
        }

        int newer;

        void convert_newer ( ref OldKey o )
        {
            newer = o.old2+1;
        }

        bool compare ( OldKey * oldk )
        {
            return oldk.old2 == old1 && oldk.old2+1 == newer;
        }

        OldKey old ( )
        {
            return OldKey(old1);
        }
    }

    struct NewerKey
    {
        static const StructVersion = 2;
        alias NewKey StructPrevious;

        int old1;
        int wops;

        void convert_wops ( ref NewKey k )
        {
            wops = k.old1;
        }

        bool compare ( NewKey * n )
        {
            return n.old1 == old1 && wops == n.old1;
        }

        OldKey old ( )
        {
            return OldKey(old1);
        }
    }

    struct NewerStruct
    {
        static const StructVersion = 2;
        alias NewStruct StructPrevious;

        int old;
        long of;

        void convert_of ( ref NewStruct n )
        {
            of = n.a_bit_newer;
        }

        bool compare ( OldStruct * olds )
        {
            return olds.old == old;
        }
    }

    // Test creation of a SerializingMap instance
    class HashingSerializingMap : SerializingMap!(int,int)
    {
        public this ( size_t n, float load_factor = 0.75 )
        {
            super(n, load_factor);
        }

        mixin StandardHash.toHash!(int);
    }


    // Test same and old version
    test!(hash_t, Test1, hash_t, Test2)(t, Iterations);
    test!(hash_t, Test2, hash_t, Test2)(t, Iterations);

    // Test Arrays
    test!(hash_t, Test2[], hash_t, Test2[])(t, Iterations);

    // Test unversioned structs
    test!(hash_t, TestNoVersion, hash_t, TestNoVersion)(t, Iterations);

    // Test old versions
    test!(hash_t, TestNoVersion, hash_t, TestNoVersion, old_load_code)(t, Iterations);

    // Test conversion of old files to new ones
    test!(hash_t, OldStruct, hash_t, NewStruct, old_load_code)(t, Iterations);

    // Test conversion of old files with
    // different key versions to new ones
    test!(OldKey, OldStruct, OldKey, OldStruct, old_load_code)(t, Iterations);
    test!(OldKey, OldStruct, NewKey, OldStruct, old_load_code)(t, Iterations);
    test!(OldKey, OldStruct, NewKey, OldStruct, old_load_code)(t, Iterations);
    test!(OldKey, OldStruct, NewKey, NewStruct, old_load_code)(t, Iterations);
    test!(OldKey, OldStruct, NewerKey, NewStruct, old_load_code)(t, Iterations);
    test!(OldKey, OldStruct, NewerKey, NewerStruct,old_load_code)(t, Iterations);
}

