/*******************************************************************************

    Simple serializer for reading / writing generic data from / to IOStreams

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        October 2010: Initial release
    
    authors:        Gavin Norman

    Usage example, writing:
    
    ---

        private import ocean.io.serialize.SimpleSerializer;

        scope file = new File("myfile.dat", File.WriteCreate);

        char[] some_data = "data to be written to the file first";
        char[][] more_data = ["second", "third", "fourth", "etc"];

        SimpleSerializer.write(file, some_data);
        SimpleSerializer.write(file, more_data);

    ---

    Usage example, reading:

    ---

        private import ocean.io.serialize.SimpleSerializer;

        scope file = new File("myfile.dat", File.ReadExisting);

        char[] some_data;
        char[][] more_data;

        SimpleSerializer.read(file, some_data);
        SimpleSerializer.read(file, more_data);

    ---

*******************************************************************************/

module ocean.io.serialize.SimpleSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.io.model.IConduit: IOStream, InputStream, OutputStream;

private import tango.core.Exception: IOException;
private import ocean.core.Exception: assertEx;

debug private import tango.util.log.Trace;

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
        If data is a pointer to a struct or union, it is dereferenced
        automatically.
    
        Template params:
            T = type of data to write
    
        Params:
            output = output stream to write to
            data = data to write
        
        Returns:
            number of bytes transmitted
        
        Throws:
            IOException on End Of Flow condition
        
    ***************************************************************************/
    
    public size_t write ( T ) ( OutputStream output, T data )
    {
        size_t written = 0;
        
        static if ( is(T A == A[]) )
        {
            written += write(output, data.length);
    
            static if ( is(A B == B[])) // recursively write arrays of arrays
            {
                foreach ( d; data )
                {
                    written += write(output, d);
                }
            }
            else
            {
                written += transmitArrayData(output, data);
            }
        }
        else static if (is (T A == A*) && (is (A == struct) || is (A == union)))
        {
            written += writeData(output, data, A.sizeof);
        }
        else
        {
            written += writeData(output, &data, T.sizeof);
        }
        
        return written;
    }


    /***************************************************************************
    
        Reads something from an input stream. Single elements are read straight
        from the input stream, while array types have their length read,
        followed by each element.
        If data is a pointer to a struct or union, it is dereferenced
        automatically.
    
        Template params:
            T = type of data to read
    
        Params:
            input = input stream to read from
            data = data to read
        
        Returns:
            number of bytes transmitted
        
        Throws:
            IOException on End Of Flow condition
        
    ***************************************************************************/
    
    public size_t read ( T ) ( InputStream input, ref T data )
    {
        size_t read_ = 0;
        
        static if ( is(T A == A[]) )
        {
            size_t length;
            read_ += read(input, length);
            data.length = length;

            static if ( is(A B == B[])) // recursively read arrays of arrays
            {
                foreach ( ref d; data )
                {
                    read_ += read(input, d);
                }
            }
            else
            {
                read_ += transmitArrayData(input, data);
            }
        }
        else static if (is (T A == A*) && (is (A == struct) || is (A == union)))
        {
            read_ += readData(input, data, A.sizeof);
        }
        else
        {
            read_ += readData(input, &data, T.sizeof);
        }
        
        return read_;
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
        
        Throws:
            IOException on End Of Flow condition
        
    ***************************************************************************/

    public size_t transmit ( Stream : IOStream ) ( Stream stream, void* data, size_t bytes )
    {
        return transmit(stream, data[0 .. bytes]);
    }

    /***************************************************************************
    
        Reads/writes data from/to an io stream, populating/consuming data to its
        entirety.

        Template params:
            Stream = type of stream; must be either InputStream or OutputStream
    
        Params:
            stream = stream to read from / write to
            data = pointer to data buffer
            bytes = length of data in bytes
        
        Returns:
            number of bytes transmitted
        
        Throws:
            IOException on End Of Flow condition
        
    ***************************************************************************/
    
    public size_t transmit ( Stream : IOStream ) ( Stream stream, void[] data )
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
    
    /***************************************************************************
    
        Writes data to output, consuming the data buffer content to its
        entirety.
    
        Params:
            output = stream to write to
            data = pointer to data buffer
            bytes = length of data in bytes
        
        Returns:
            number of bytes transmitted
        
        Throws:
            IOException on End Of Flow condition
        
    ***************************************************************************/

    public size_t writeData ( OutputStream output, void* data, size_t bytes )
    {
        return transmit(output, data, bytes);
    }
    
    /***************************************************************************
    
        Reads data from input, populating the data buffer to its entirety.
    
        Params:
            input = stream to read from
            data = pointer to data buffer
            bytes = length of data in bytes
        
        Returns:
            number of bytes transmitted
        
        Throws:
            IOException on End Of Flow condition
        
    ***************************************************************************/

    public size_t readData ( InputStream input, void* data, size_t bytes )
    {
        return transmit(input, data, bytes);
    }
    
    /***************************************************************************
    
        Writes data to output, consuming the data buffer content to its
        entirety.
    
        Params:
            output = stream to write to
            data = data buffer
        
        Returns:
            number of bytes transmitted
        
        Throws:
            IOException on End Of Flow condition
        
    ***************************************************************************/

    public size_t writeData ( OutputStream output, void[] data )
    {
        return transmit(output, data);
    }
    
    /***************************************************************************
    
        Reads data from input, populating the data buffer to its entirety.
    
        Params:
            input = stream to read from
            data = data buffer
        
        Returns:
            number of bytes transmitted
        
        Throws:
            IOException on End Of Flow condition
        
    ***************************************************************************/

    public size_t readData ( InputStream input, void[] data )
    {
        return transmit(input, data);
    }
    
    /***************************************************************************
    
        Reads/writes the content of array from/to stream, populating array to
        its entirety.
    
        Params:
            stream = stream to read from/write to
            array = array to transmit
        
        Returns:
            number of bytes transmitted
        
        Throws:
            IOException on End Of Flow condition
        
    ***************************************************************************/

    public size_t transmitArrayData ( Stream : IOStream, T = T[] ) ( Stream stream, T array )
    {
        return transmit(stream, cast (void*) array.ptr, array.length * (*array.ptr).sizeof);
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

