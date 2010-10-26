/*******************************************************************************

    Simple serializer for reading / writing generic data from / to IOStreams

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        October 2010: Initial release
    
    authors:        Gavin Norman
    
*******************************************************************************/

module ocean.io.serialize.SimpleSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.io.model.IConduit: IOStream, InputStream, OutputStream;

private import tango.core.Exception: IOException;
private import ocean.core.Exception: assertEx;

private import tango.util.log.Trace;

/*******************************************************************************

    Simple serializer struct - just a namespace, all methods are static.

*******************************************************************************/

struct SimpleSerializer
{
static:

    /***************************************************************************

        Writes something to an output stream. Single elements are written
        straight to the output stream, while array types have their length
        written, followed by each element.
    
        Template params:
            T = type of data to write
    
        Params:
            output = output stream to write to
            data = data to write
        
    ***************************************************************************/
    
    public void write ( T ) ( OutputStream output, T data )
    {
        static if ( is(T A == A[]) )
        {
            write(output, data.length);
    
            static if ( is(A B == B[])) // recursively write arrays of arrays
            {
                foreach ( d; data )
                {
                    write(output, d);
                }
            }
            else
            {
                transmit(output, data.ptr, data.length * A.sizeof);
            }
        }
        else
        {
            transmit(output, &data, T.sizeof);
        }
    }


    /***************************************************************************
    
        Reads something from an input stream. Single elements are read straight
        from the input stream, while array types have their length read,
        followed by each element.
    
        Template params:
            T = type of data to read
    
        Params:
            input = input stream to read from
            data = data to read
        
    ***************************************************************************/
    
    public void read ( T ) ( InputStream input, ref T data )
    {
        static if ( is(T A == A[]) )
        {
            size_t length;
            read(input, length);
            data.length = length;

            static if ( is(A B == B[])) // recursively read arrays of arrays
            {
                foreach ( ref d; data )
                {
                    read(input, d);
                }
            }
            else
            {
                transmit(input, data.ptr, data.length * A.sizeof);
            }
        }
        else
        {
            transmit(input, &data, T.sizeof);
        }
    }
    
    /***************************************************************************
    
        Reads/writes data from/to an io stream, populating/consuming
        data[0 .. bytes].
    
        Template params:
            Stream = type of stream; must be either InputStream or OutputStream
    
        Params:
            stream = stream to read from / write to
            data   = pointer to data buffer
            bytes  = data buffer length (bytes)
        
        Returns:
            number of bytes transmitted
        
    ***************************************************************************/

    public size_t transmit ( Stream : IOStream ) ( Stream stream, void* data, size_t bytes )
    {
        return transmit(data[0 .. bytes]);
    }

    /***************************************************************************
    
        Reads/writes data from/to an io stream, populating/consuming data to its
        entirety.

        Template params:
            Stream = type of stream; must be either InputStream or OutputStream
    
        Params:
            stream = stream to read from / write to
            data = pointer to data
            data  = data buffer to be populated/consumed
            bytes = length of data in bytes
        
        Returns:
            number of bytes transmitted
        
        Throws:
            IOException on End Of Flow condition
        
    ***************************************************************************/
    
    public size_t transmit ( Stream : IOStream ) ( Stream stream, void[] data )
    out (n)
    {
        Trace.formatln("transmit " ~ Stream.stringof ~ ": {}", n); 
    }
    body
    {
        static assert ( !(is(Stream : InputStream) && is(Stream : OutputStream)),
                        "stream is '" ~ Stream.stringof ~  "; please cast it "
                        "either to InputStream or OutputStream" );
        
        size_t transmitted = 0;
        
        while (transmitted < data.length)
        {
            static if ( is(Stream == OutputStream) )
            {
                size_t ret = stream.write(data[transmitted .. $]);
                
                const act = "writing";
            }
            else
            {
                static assert ( is(Stream == InputStream),
                                "stream must be either InputStream or OutputStream, "
                                "not '" ~ Stream.stringof ~ '\'' );
                
                size_t ret = stream.read(data[transmitted .. $]);
                
                const act = "reading";
                
            }

            assertEx!(IOException)(ret != stream.Eof, "end of flow while " ~ act);
            
            transmitted += ret;
        }
        
        return transmitted;
    }
}



debug ( OceanUnitTest )
{
    private import tango.util.log.Trace;
    private import tango.io.device.File;

    void test ( T ) ( File file, T write )
    {
        T read;

        file.open("temp", File.WriteCreate);
        SimpleSerializer.write(file, write);
        file.close();

        file.open("temp", File.ReadExisting);
        SimpleSerializer.read(file, read);
        file.close();
        assert(read == write);
    }
    
    unittest
    {
        Trace.formatln("Running ocean.io.serialize.SimpleSerializer unittest");

        scope file = new File();
        scope ( exit ) file.close();

        uint an_int = 23;
        test(file, an_int);

        char[] a_string = "hollow world";
        test(file, a_string);

        char[][] a_string_array = ["hollow world", "journey to the centre", "of the earth"];
        test(file, a_string_array);

        Trace.formatln("done unittest\n");
    }
}

