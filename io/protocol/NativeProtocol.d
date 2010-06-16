/*******************************************************************************

        copyright:      Copyright (c) 2007 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Jan 2007 : initial release
        
        author:         Kris 

*******************************************************************************/

module ocean.io.protocol.NativeProtocol;

package import  tango.io.stream.Buffered;

private import  ocean.io.protocol.Protocol;

/*******************************************************************************

*******************************************************************************/

class NativeProtocol : Protocol
{
        protected Bin           input;
        protected Bout          output;
        protected bool          prefix_;

        /***********************************************************************

        ***********************************************************************/

        this (IConduit c, bool prefix=true)
        {
                this (new Bin(c), new Bout(c), prefix);
        }

        /***********************************************************************

        ***********************************************************************/

        this (Bin input, Bout output, bool prefix=true)
        {
                this.input = input;
                this.output = output;
                this.prefix_ = prefix;
        }

        /***********************************************************************

        ***********************************************************************/

        Bin bin ()
        {
                return input;
        }

        /***********************************************************************

        ***********************************************************************/

        Bout bout ()
        {
                return output;
        }

        /***********************************************************************

        ***********************************************************************/

        void[] read (void* dst, uint bytes, Type type)
        {
                //auto count = input.read (dst [0 .. bytes]);
                auto count = input.fill (dst [0 .. bytes], true);
                assert (count is bytes);
                return dst [0 .. bytes];
        }
        
        /***********************************************************************

        ***********************************************************************/

        void write (void* src, uint bytes, Type type)
        {
                output.append (src [0 .. bytes]);
        }
        
        /***********************************************************************

        ***********************************************************************/

        void[] readArray (void* dst, uint bytes, Type type, Allocator alloc)
        {
                if (prefix_)
                   {
                   read (&bytes, bytes.sizeof, Type.UInt);
                   return alloc (&read, bytes, type); 
                   }

                return read (dst, bytes, type);
        }
        
        /***********************************************************************

        ***********************************************************************/

        void writeArray (void* src, uint bytes, Type type)
        {
                if (prefix_)
                    write (&bytes, bytes.sizeof, Type.UInt);

                write (src, bytes, type);
        }
}



/*******************************************************************************

*******************************************************************************/

debug (UnitTest)
{
        import tango.io.device.Array;
        import mango.io.protocol.Writer;
        import mango.io.protocol.Reader;
        import mango.io.protocol.NativeProtocol;
        
        void main() {}

        unittest
        {
                auto protocol = new NativeProtocol (new Array(32));
                auto input  = new Reader (protocol);
                auto output = new Writer (protocol);

                char[] foo;
                output ("testing testing 123"c);
                input (foo);
                assert (foo == "testing testing 123");
        }
}

   