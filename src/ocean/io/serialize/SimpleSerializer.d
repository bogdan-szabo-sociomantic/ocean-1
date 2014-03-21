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

private import ocean.core.Exception: assertEx;

private import tango.core.Exception: IOException;

private import tango.io.model.IConduit: IOStream, InputStream, OutputStream;

debug private import ocean.util.log.Trace;



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
        return transmit(output, data);
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
        return transmitData(output, data[0..bytes]);
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
        return transmitData(output, data);
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
        return transmit(input, data);
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
        return transmitData(input, data[0..bytes]);
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
        return transmitData(input, data);
    }

    /***************************************************************************

        Reads/writes something from/to an io stream. Single elements are
        transmitted straight to the stream, while array types have their length
        transmitted, followed by each element.

        If data is a pointer to a struct or union, it is dereferenced
        automatically.

        Template params:
            Stream = type of stream; must be either InputStream or OutputStream
            T = type of data to transmit

        Params:
            stream = stream to read from / write to
            data = data to transmit

        Returns:
            number of bytes transmitted

        Throws:
            IOException on End Of Flow condition

    ***************************************************************************/

    public size_t transmit ( Stream : IOStream, T ) ( Stream stream, ref T data )
    {
        size_t transmitted = 0;

        static if ( is(T A : A[]) )
        {
            // transmit array length
            static if ( is(Stream : OutputStream) )
            {
                size_t length = data.length;
                transmitted += transmit(stream, length);
            }
            else
            {
                static assert ( is(Stream : InputStream),
                    "stream must be either InputStream or OutputStream, "
                    "not '" ~ Stream.stringof ~ '\'' );

                size_t length;
                transmitted += transmit(stream, length);
                data.length = length;
            }

            // recursively transmit arrays of arrays
            static if ( is(A B == B[]) )
            {
                foreach ( ref d; data )
                {
                    transmitted += transmit(stream, d);
                }
            }
            else
            {
                transmitted += transmitArrayData(stream, data);
            }
        }
        else static if (is (T A == A*) && (is (A == struct) || is (A == union)))
        {
            transmitted += transmitData(stream, data, A.sizeof);
        }
        else
        {
            transmitted += transmitData(stream, cast(void*)&data, T.sizeof);
        }

        return transmitted;
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

    public size_t transmitData ( Stream : IOStream ) ( Stream stream, void* data,
        size_t bytes )
    {
        return transmitData(stream, data[0 .. bytes]);
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

    public size_t transmitData ( Stream : IOStream ) ( Stream stream, void[] data )
    {
        static assert ( !(is(Stream : InputStream) && is(Stream : OutputStream)),
                        "stream is '" ~ Stream.stringof ~  "; please cast it "
                        "either to InputStream or OutputStream" );

        size_t transmitted = 0;

        while (transmitted < data.length)
        {
            static if ( is(Stream : OutputStream) )
            {
                size_t ret = stream.write(data[transmitted .. $]);

                const act = "writing";
            }
            else
            {
                static assert ( is(Stream : InputStream),
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

    public size_t transmitArrayData ( Stream : IOStream, T = T[] )
        ( Stream stream, T array )
    {
        static if ( is(T U : U[]) )
        {
            return transmitData(stream, cast (void*) array.ptr,
                    array.length * U.sizeof);
        }
        else
        {
            static assert(false,
                "transmitArrayData cannot handle non-array type " ~ T.stringof);
        }
    }
}



debug ( OceanUnitTest )
{
    private import ocean.io.Stdout;
    private import tango.io.device.TempFile;

    void test ( T ) ( T write )
    {
        T read;

        scope file = new TempFile;

        SimpleSerializer.write(file, write);
        file.seek(0);

        SimpleSerializer.read(file, read);
        debug ( Verbose ) Stdout.formatln("Wrote {} to conduit, read {}", write, read);
        assert(read == write, "Error serializing " ~ T.stringof);
    }

    unittest
    {
        debug (Verbose) Stdout.formatln("Running ocean.io.serialize.SimpleSerializer unittest");

        uint an_int = 23;
        test(an_int);

        char[] a_string = "hollow world";
        test(a_string);

        char[][] a_string_array = ["hollow world", "journey to the centre", "of the earth"];
        test(a_string_array);

        debug (Verbose) Stdout.formatln("done unittest\n");
    }
}
