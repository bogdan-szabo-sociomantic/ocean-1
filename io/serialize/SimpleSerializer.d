/*******************************************************************************

    Simple serializer for reading / writing generic data from / to IOStreams

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        October 2010: Initial release
    
    authors:        Gavin Norman
    
*******************************************************************************/

module io.serialize.SimpleSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.io.model.IConduit;



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
                transmit(output, cast(void*)data.ptr, data.length * A.sizeof);
            }
        }
        else
        {
            transmit(output, cast(void*)&data, T.sizeof);
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
                transmit(input, cast(void*)data.ptr, data.length * A.sizeof);
            }
        }
        else
        {
            transmit(input, cast(void*)&data, T.sizeof);
        }
    }


    /***************************************************************************
    
        Reads / writes data from / to an io stream.

        Template params:
            Stream = type of stream
    
        Params:
            stream = stream to read from / write to
            data = pointer to data
            bytes = length of data in bytes
        
    ***************************************************************************/
    
    private void transmit ( Stream : IOStream ) ( Stream stream, void* data, size_t bytes )
    {
        size_t ret;
        do
        {
            static if ( is(Stream == OutputStream) )
            {
                ret = stream.write(data[0..bytes]);
            }
            else
            {
                ret = stream.read(data[0..bytes]);
            }

            if ( ret != IOStream.Eof )
            {
                data += ret;
                bytes -= ret;
            }
        }
        while ( bytes > 0 && ret != IOStream.Eof );
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

