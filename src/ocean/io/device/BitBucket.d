/*******************************************************************************

        A Conduit that ignores all that is written to it

        copyright:      Copyright (c) 2008. Fawzi Mohamed

        license:        BSD style: $(LICENSE)

        version:        Initial release: July 2008

        author:         Fawzi Mohamed

*******************************************************************************/

module ocean.io.device.BitBucket;

import ocean.transition;

import ocean.io.device.Conduit;

/*******************************************************************************

        A Conduit that ignores all that is written to it and returns Eof
        when read from. Note that write() returns the length of what was
        handed to it, acting as a pure bit-bucket. Returning zero or Eof
        instead would not be appropriate in this context.

*******************************************************************************/

class BitBucket : Conduit
{
        override istring toString () {return "<bitbucket>";}

        override size_t bufferSize () { return 0;}

        override size_t read (void[] dst) { return Eof; }

        override size_t write (Const!(void)[] src) { return src.length; }

        override void detach () { }
}

unittest
{
    auto a=new BitBucket;
    a.write("bla");
    a.flush();
    a.detach();
    a.write("b"); // at the moment it works, disallow?
    uint[4] b=0;
    a.read(b);
    foreach (el;b)
        assert(el==0);
}
