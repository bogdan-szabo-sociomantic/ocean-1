/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        11.09.2012: Initial release
                    02.10.2012: Now uses SimpleSerielizer

    authors:        Mathias Baumann, Hans Bjerkander

    Serielizes/Deserielizes a map and saves/loads it to/from a file.
    Uses SimpleSerielizer to read/write a map from/to a buffered file.

    The function load_0 only exist to give backwards compabaility to files of 
    version 0.

*******************************************************************************/

module ocean.util.container.map.utils.FileSerializer;
import ocean.io.Stdout;


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

    Magic Marker for HashMap files, part of the header

*******************************************************************************/

private const uint MAGIC_MARKER = 0xCA1101AF;


/*******************************************************************************

    Evaluates to a string made of all the types of the struct.
    Does not dive recursivley in to sub-structs

*******************************************************************************/

private template GetUniqueStructString ( S )
{
    static if ( is ( S == struct ) )
        const char[] GetUniqueStructString = GetUniqueStructStringHelper!(typeof(S.tupleof));
    else
        const char[] GetUniqueStructString = S.stringof;
}

/*******************************************************************************

    Helper for GetUniqStructString

*******************************************************************************/

private template GetUniqueStructStringHelper ( T ... )
{
    static if ( T.length > 0 )
        const char[] GetUniqueStructStringHelper = T[0].stringof ~ GetUniqueStructStringHelper!(T[1 .. $]);
    else
        const char[] GetUniqueStructStringHelper = "";
}


/*******************************************************************************

    Struct to be used for creating unique hash

*******************************************************************************/

private struct KeyValueStruct( K, V)
{
    K k;
    V v;
}



/*******************************************************************************

    File header writen at the beginning of a dumped HashMap

*******************************************************************************/

private struct FileHeader ( K, V, ubyte VERSION = 2 )
{
    /***************************************************************************

        Magic Marker, making sure that this file is really what we expect it
        to be

    ***************************************************************************/

    uint marker         = MAGIC_MARKER;

    /***************************************************************************

        Version of the FileHeader. Should be changed for any modification

    ***************************************************************************/

    ubyte versionNumber = VERSION;

    /***************************************************************************

        Hash of the struct types, making sure that the key and value types
        are the same as when this file was saved.

    ***************************************************************************/

    static if ( VERSION < 2 )
    {
        uint hash = StaticFnv1a32!(GetUniqueStructString!(K) ~ "|" ~
                                   GetUniqueStructString!(V));
    }
    else
    {
        ulong hash = TypeHash!(KeyValueStruct!(K,V));
    }
}

/*******************************************************************************

    Global buffered output instance

*******************************************************************************/

private BufferedOutput buffered;

static this ()
{
    buffered = new BufferedOutput(null, 4096);
}


/*******************************************************************************

    Exception thrown when the file that was loaded is incomplete. Will soon be
    unused

*******************************************************************************/

class UnexpectedEndException : Exception
{
    this ( char[] msg, char[] file, size_t line )
    {
        super(msg, file, line);
    }
}



/*******************************************************************************

    Writes a map to a file.

    Params:
        map        = instance of the array map to dump
        file_path  = path to where the map should be dumped to
        check      = function called for each entry. If it returns false,
                     the entry won't be written. Defaults to always true

    Note: This function uses a global BufferdOutput object and is thus
          not thread-safe!

*******************************************************************************/


public void dump ( K, V ) ( Map!(V, K) map, char[] file_path,
                            bool delegate ( K, V ) check = null )
{
    if ( check is null ) check = ( K, V ) { return true; };

    scope file = new File(file_path, File.Style(File.Access.Write,
                                                File.Open.Create,
                                                File.Share.None));
    size_t nr_rec = map.bucket_info.length();

    buffered.output(file);
    buffered.clear();

    FileHeader!(K,V) fh;
    SimpleSerializer.write(buffered, fh);
    SimpleSerializer.write(buffered, nr_rec);

    foreach(key, value; map)
    {
        if ( check(key, value) )
        {
            SimpleSerializer.write!(K)(buffered, key);
            SimpleSerializer.write!(V)(buffered, value);
        }
    }
    buffered.flush();
}

/*******************************************************************************

    This function is to only be used by load, since this is only keept for
    keeping compatibility with files of verison 0. Will soon be removed.

    Initializes cache map and loads dumped map content from the file system

    Throws:
        UnexpectedEndException when the file that was loaded is incomplete.
                               The existing data was loaded none the less
                               and the map can be used.
        Other Exceptions for various kinds of errors (file not found, etc)

    Template Params:
        K = key of the array map
        V = value of the corresponding key

    Params:
        map       = instance of the array map
        file_path = path to the file to load from
        putter    = function called for each entry to insert it into the map,
                    defaults to map.put

    Note: This function allocates a buffered input which has to be collected
          by the GC. As files are usually only read once during startup
          this usually does not pose a problem. None the less, it could
          be modified to use a global buffered input object if desired,
          or take one as a parameter.

*******************************************************************************/

private void load_0 ( K, V ) ( Map!(V, K) map, File file, BufferedInput buffered,
                               void delegate ( K, V ) putter = null )
in
{
    assert (map !is null);
}
body
{
    ubyte[] read;
    K key;
    V value;

    while (true)
    {
        if ( buffered.readable < V.sizeof + K.sizeof )
        {
            buffered.compress();
            buffered.populate();
        }

        read = (cast(ubyte*) &key)[0 .. K.sizeof];


        if (buffered.read(read) == file.Eof)
        {
            break;
        }

        static if ( isArrayType!(V) )
        {
            size_t len = void;
            read = (cast(ubyte*) &len)[0 .. size_t.sizeof];

            if ( buffered.read(read) == file.Eof )
            {
                throw new UnexpectedEndException("Expected length of value "
                                                 "after key instead"
                                                 " of EoF", __FILE__, __LINE__);

                break;
            }

            value.length = len;

            foreach ( ref sv; value )
            {
                read = (cast(ubyte*) &sv)[0 .. ElementTypeOfArray!(V).sizeof];

                if ( buffered.read(read) == file.Eof )
                {
                    throw new UnexpectedEndException("Expected value "
                                                     "instead of EoF",
                                                     __FILE__, __LINE__);

                    break;
                }
            }
        }
        else
        {
            read = (cast(ubyte*) &value)[0 .. V.sizeof];

            if ( buffered.read(read) == file.Eof )
            {
                throw new UnexpectedEndException("Expected value after key instead"
                                                 " of EoF", __FILE__, __LINE__);

                break;
            }
        }
        putter(key, value);
    }
}


/*******************************************************************************

    loads dumped map content from the file system

    Throws:
        Exception when the file has not the expected fileheader and
        other Exceptions for various kinds of errors (file not found, etc)

    Template Params:
        K = key of the array map
        V = value of the corresponding key

    Params:
        map       = instance of the array map
        file_path = path to the file to load from
        putter    = function called for each entry to insert it into the map,
                    defaults to map.put

    Note: This function allocates a buffered input which has to be collected
          by the GC. As files are usually only read once during startup
          this usually does not pose a problem. None the less, it could
          be modified to use a global buffered input object if desired,
          or take one as a parameter.

*******************************************************************************/

public void load ( K, V ) ( Map!(V, K) map, char[] file_path,
                            void delegate ( K, V ) putter = null )
in
{
    assert (map !is null);
}
body
{
    K key;
    V value;
    size_t nr_rec;
    scope file = new File(file_path, File.ReadExisting);
    scope buffered = new BufferedInput(file, 4096 * 10);

    if ( putter is null ) putter = ( K k, V v ) { *map.put(k) = v; };

    FileHeader!(K,V) fh_expected;
    FileHeader!(K,V) fh_actual;

    buffered.compress();
    buffered.populate();

    SimpleSerializer.read(buffered, fh_actual);

    if ( fh_actual.marker != fh_expected.marker )
    {
        throw new Exception("Magic Marker mismatch in file " ~ file_path);
    }
    
    if ( fh_actual.versionNumber != fh_expected.versionNumber )
    {
        if ( fh_actual.versionNumber < 2 )
        {
            FileHeader!(K,V,1) fh1;
            
            // files with version<2 use 4 byte hashes
            buffered.seek(-4, IOStream.Anchor.Current);
            
            if ( fh1.hash != (fh_actual.hash & 0xFFFFFFFF) )
            {
                throw new Exception("Structs " ~ K.stringof ~ ", " ~
                                    V.stringof ~ " in file " ~ file_path ~
                                    " differ from our structs, aborting!");
            }
            
            if ( fh_actual.versionNumber == 0 )
            {
                load_0(map,file, buffered, putter);
                return;
            }
        }
        else
        {
            throw new Exception("Version of file header " ~ file_path ~
                               " does not match our version, aborting!");
        }
    }
    else if ( fh_actual.hash != fh_expected.hash )
    {
        throw new Exception("Structs " ~ K.stringof ~ ", " ~
                            V.stringof ~ " in file " ~ file_path ~
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