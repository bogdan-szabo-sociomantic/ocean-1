/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        11.09.2012: Initial release
                    02.10.2012: Now uses SimpleSerielizer

    authors:        Mathias Baumann, Hans Bjerkander

    Serializes/Deserializes a map and saves/loads it to/from a file.
    Uses SimpleSerializer to read/write a map from/to a buffered file.

    The function load_0 only exist to give backwards compabaility to files of
    version 0.

*******************************************************************************/

module ocean.util.container.map.utils.MapSerializer;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.digest.Fnv1,
               ocean.io.serialize.SimpleSerializer,
               ocean.io.serialize.TypeId,
               ocean.util.container.map.Map;

private import tango.core.Exception: IOException;
private import tango.io.model.IConduit : IOStream;
private import tango.core.Traits,
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

    Throws if you try to load a different struct than you saved

    Usage Example:
    ---
    struct MyValue0
    {
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

    private struct FileHeader ( K, V, ubyte VERSION = 2 )
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

            Hash of the struct types, making sure that the key and value types
            are the same as when this file was saved.

        ***********************************************************************/

        ulong hash = TypeHash!(KeyValueStruct!(K,V));
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

        buffered output instance

    ***************************************************************************/

    private BufferedOutput buffered_output;

    /***************************************************************************

        buffered input instance

    ***************************************************************************/

    private BufferedInput buffered_input;


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
        K key;
        V value;
        size_t nr_rec;

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
            throw new Exception("Version of file header "
                                " does not match our version, aborting!");
        }
        else if ( fh_actual.hash != fh_expected.hash )
        {
            throw new Exception("Structs " ~ K.stringof ~ ", " ~
                                V.stringof ~
                                " differ from our structs, aborting!");
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
            KNew = type of the key to read
            VNew = type of the value to read
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
            t.assertLog(v == *map.get(fromNew(k)), "Loaded item unequal saved item!",
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

    struct TestA
    {
        long i;

        static TestA opCall ( long i )
        {
            TestA t;
            t.i = i*2;
            return t;
        }

        bool compare ( TestA* other )
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

    // Test creation of a SerializingMap instance
    class HashingSerializingMap : SerializingMap!(int,int)
    {
        public this ( size_t n, float load_factor = 0.75 )
        {
            super(n, load_factor);
        }

        mixin StandardHash.toHash!(int);
    }


    test!(hash_t, Test1, hash_t, Test1)(t, Iterations);
    test!(hash_t, Test2, hash_t, Test2)(t, Iterations);

    // Test Arrays
    test!(hash_t, Test2[], hash_t, Test2[])(t, Iterations);

    test!(hash_t, TestA, hash_t, TestA)(t, Iterations);

}

