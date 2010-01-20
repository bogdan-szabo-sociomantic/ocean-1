/******************************************************************************

        Uncompresses Content
        
        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Feb 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        This module uncompresses content based on an input stream, buffer or 
        string. This module uses automatic gzdetect of encoding type within
        the zlib library and returns a char[].
        
        --
        
        Compile Instructions:
        
        Please add buildflags=-L/usr/lib/libpcre.so to your dsss.conf
                
        --
        
        Usage:
        
        Simple usage:
        
        ---

            auto comp = new Uncompress();

            try 
            {
                auto content = comp.decode(gzip_content);
                Stdout(content).newline;
            }
            catch (Exception e)
            {
                Stdout("Error on Encoding");
            }
                
        ---
        
        If lots of data needs to be decompressed, please instantiate this class as 
        class property and call decode within the appropriate method. Additionally
        you can add the prefered encoding type if it is known. Otherwise ZlibStream 
        will try guess to guess the encoding. 
        
        ---
            
            auto    comp        = new Uncompress();
            char[]  encoding    = "gzip";
            
            try 
            {
                auto content = comp.decode(gzip_content, encoding);
                Stdout(content).newline;
            }
            catch (Exception e)
            {
                Stdout("Error on Encoding");
            }
            
        ---
         
        --        
        
        Related:
        
            http://www.zlib.net/
        
            Memory leak bugfix in decode functions:
            http://www.dsource.org/projects/tango/forums/topic/788 
       
            
            
 ******************************************************************************/

module ocean.compress.Uncompress;



/******************************************************************************

            imports

 ******************************************************************************/

private     import      tango.io.compress.ZlibStream: ZlibInput, ZlibOutput;

private     import      tango.io.device.Array;

private     import      tango.io.model.IConduit: InputStream, OutputStream;

private     import      Integer = tango.text.convert.Integer: toInt;

private     import      tango.math.Math: min;


private     import      tango.util.log.Trace;
private     import      tango.io.Stdout;


/******************************************************************************

    Uncompress

 ******************************************************************************/

class Uncompress
{
    /**************************************************************************

        Compression/uncompression encoding enumeration aliases
        
        Encoding: compression encoding; denominates whether output data should
                  be encoded as Gzip or Zlib or not encoded at all.
        
        Decoding: uncompression encoding; denominates whether input data are
                  expected to be Gzip or Zlib or not encoded at all or encoding
                  should be detected.
        
         
        
     **************************************************************************/
    
    public alias ZlibOutput.Encoding Encoding;
    public alias ZlibInput.Encoding  Decoding;
    
    /**************************************************************************

        Default Encoding/Decoding constants
        
     **************************************************************************/

    const       Encoding DEFAULT_ENCODING               = Encoding.Zlib;
    const       Decoding DEFAULT_DECODING               = Decoding.Guess;
    
    /**************************************************************************

        Encoding/Decoding properties
        
     **************************************************************************/

    private     Encoding encoding                       = this.DEFAULT_ENCODING; // Store the encoding
    private     Decoding decoding                       = this.DEFAULT_DECODING; // Store the encoding
    private     ZlibOutput.Level    level               = ZlibOutput.Level.Normal;
    
    /**************************************************************************

        Buffer size constants
        
     **************************************************************************/

    const       uint                UNCOMPRESS_BUF_SIZE = 1024*1024;    // Initial Buffer size for uncompressed content
    const       uint                GROW_UB_SIZE        = 32*1024;      // Size that is used to allocate new memory in case of buffer grow
    const       uint                CHUNK_SIZE          = 4*1024;       // Chunk size for reading from ZlibStream  
    const       uint                INPUT_BUF_SIZE      = 64 * 1024;    // Initial input buffer size    
    const       uint                GROW_IB_SIZE        = 1024;         // Size of which the input buffer will grow 
    
    /**************************************************************************

        I/O buffers
        
     **************************************************************************/

    private     ubyte[CHUNK_SIZE]   chunk;                              // Chunk that is used to read the uncompressed data from ZlibStream
    private     Array               input_buffer;                       // Input stream buffer used in case of a char[] input
    private     Array               output_buffer;                      // Output stream buffer that is used to store the uncompressed data
    
    /**************************************************************************

        Zlib I/O filters
        
     **************************************************************************/

    private     ZlibInput           decomp;                             // global ZlibStream object
    private     ZlibOutput          comp;                               // global ZlibStream object
    
    /**************************************************************************

        Gzip signature
        
     **************************************************************************/

    const       ubyte[]             GZIP_SIGNATURE      = [0x1F, 0x8B];
    
    /**************************************************************************

        EnumIds struct
        
        Holds an enumerator value and string identifiers associated to the value
        
     **************************************************************************/
    
    private struct EnumIds ( E )
    {
        E        code;
        char[][] ids;
        
        bool opIn_r ( char[] id_in )
        {
            foreach (id; this.ids)
            {
                if (id == id_in) return true;
            }
            
            return false;
        }
    }
    
    /**************************************************************************

        Enumerator/option identification string constants
        
        These constants determine the option identifier strings accepted by
        setEncoding(), setDecoding() and setLevel()  
        
     **************************************************************************/

    public static const EnumIds!(Encoding)[] encodings =
    [
         {this.DEFAULT_ENCODING,    [""]},
         {Encoding.None,            ["none", "off", "false", "no"]},
         {Encoding.Gzip,            ["gzip"]},
         {Encoding.Zlib,            ["zlib"]}
     ];
    
    public static const EnumIds!(Decoding)[] decodings =
    [
         {this.DEFAULT_DECODING,    [""]},
         {Decoding.None,            ["none", "off", "false", "no"]},
         {Decoding.Guess,           ["guess", "auto", "on", "true", "yes"]},
         {Decoding.Gzip,            ["gzip"]},
         {Decoding.Zlib,            ["zlib"]}
     ];
    
    public static const EnumIds!(ZlibOutput.Level)[] levels =
    [
        {ZlibOutput.Level.Normal, ["", "normal", "auto", "on", "true", "yes"]},
        {ZlibOutput.Level.None,   ["none", "off", "false", "no"]},
        {ZlibOutput.Level.Fast,   ["fast", "min"]},
        {ZlibOutput.Level.Best,   ["best", "max"]}
    ];
        
    /*******************************************************************************

         Public Methods

     *******************************************************************************/
    
    /**************************************************************************
     
          Constructor 
     
     **************************************************************************/
    
    public this () {}
   
    /**************************************************************************
    
        Compresses Stream
         
        Params:
            stream_in    = uncompressed input stream conduit
            stream_out   = compressed output stream conduit
         
        Returns:
            number of input bytes, or 0 if none
    
     **************************************************************************/
    
    //  Template with 'T = void' is to avoid collisions of overloaded method.
    
    public size_t encode ( T = void ) ( InputStream stream_in, OutputStream stream_out )
    {
        size_t total = 0;
        size_t size  = 0;
        size_t s;
    
        try 
        {
            this.initZlibStreamOutput(stream_out);
            
            s = stream_in.read(this.chunk);
            
            while (s != stream_in.Eof)
            {
                size = s;
                total += size;
                
                Stderr.formatln("{} {}", size, total);
                
                this.comp.write(this.chunk[0 .. size]);
                
                s = stream_in.read(this.chunk);
            }
            
            this.comp.commit();
        }
        catch (Exception e)
        {
            UncompressException("Uncompress Error: " ~ e.msg);
        }
        
        return total;
    }
    
     /**************************************************************************
    
        Uncompresses Stream
        
        FIXME: Gzip signature detection with streams (unget functionality)
        
        Params:
            stream_in    = compressed input stream conduit
            stream_out   = uncompressed output stream conduit
        
        Returns:
            number of output bytes, or 0 if none
    
     **************************************************************************/

    // Template with 'T = void' is to avoid collisions of overloaded method.
    
    public size_t decode ( T = void ) ( InputStream stream_in, OutputStream stream_out )
    {
        bool do_decode = true;
        
        size_t total = 0;
        size_t size  = 0;
        size_t s;
        
        try
        {
            /*
            if (this.decoding == Decoding.Guess)
            {
                do_decode = this.detectGzip(stream_in, stream_out, total);
            }
            */
            
            if (do_decode)
            {
                s = this.initZlibStreamInput(stream_in).read(this.chunk);
                
                while (s != stream_in.Eof)
                {
                    size = s;
                    total += size;
                    
                    Stderr.formatln("{} {}", size, total);
                    
                    stream_out.write(this.chunk[0 .. size]);
                    
                    s = this.decomp.read(this.chunk);
                }
            }
            else
            {
                stream_out.copy(stream_in);
                
                // FIXME: "total" should be set to the number of bytes passed to stream_out
            }
        }
        catch (Exception e)
        {
            UncompressException("Uncompress Error: " ~ e.msg);
        }
        
        return total;
    }
    
    /**************************************************************************
    
        Compresses Buffered Input Stream. Output data is duplicated (copy on
        write).
        
        Params:
            stream_in    = compressed input buffer stream
            output       = return buffer
            
     **************************************************************************/
    
    public size_t encode ( T ) ( InputStream stream_in, out T[] buffer_out )
    {
        cast (void) this.assertByteType!(T, ".encode()", "buffer_out");
        
        size_t total = this.encode(stream_in, this.initOutputBuffer());
        
        buffer_out = cast (T[]) this.output_buffer.slice(total).dup;
        
        return total;
    }
    
    
    /**************************************************************************
    
        Compresses content. Output data is duplicated (copy on write).
        
        Params:
             compressed  = compressed string
             output      = return buffer
             
     **************************************************************************/
    
    
    public size_t encode ( S, T ) ( S[] buffer_in, out T[] buffer_out )
    {   
        cast (void) this.assertByteType!(S, ".encode()", "buffer_in");
        
        return this.encode(this.initInputBuffer().append(buffer_in), buffer_out);
    }
    
    /**************************************************************************
    
        Uncompresses Buffered Input Stream. Output data is duplicated (copy on
        write).
        
        Params:
            stream_in    = compressed input buffer stream
            output       = return buffer
            
    **************************************************************************/
    
    public size_t decode ( T ) ( InputStream stream_in, out T[] buffer_out )
    {
        cast (void) this.assertByteType!(T, ".decode()", "buffer_out");
        
        size_t total;
        
        total = this.decode(stream_in, this.initOutputBuffer());
        
        buffer_out = cast (T[]) this.output_buffer.slice(total).dup;
        
        return total;
    }
    
    
    /**************************************************************************
    
        Uncompresses content. Output data is duplicated (copy on write).
        
        Params:
             compressed  = compressed string
             output      = return buffer
             
        Returns:
            number of uncompressed bytes, or 0 if none
             
     **************************************************************************/


    public size_t decode ( S, T ) ( S[] buffer_in, out T[] buffer_out )
    {   
        cast (void) this.assertByteType!(S, ".decode()", "buffer_in");
        
        bool do_decode = true;
        
        if (this.decoding == Decoding.Guess)
        {
            do_decode = this.detectGzip(buffer_in);
        }
        
        if (do_decode)
        {
            return this.decode(this.initInputBuffer().append(buffer_in), buffer_out);
        }
        else
        {
            buffer_out = buffer_in.dup;
            
            return buffer_out.length;
        }
    }
    
    /**************************************************************************
    
        Uncompresses content. Output data is duplicated (copy on write).
        
        Params:
             compressed  = compressed string
             output      = return buffer
             encoding     = encoding [auto, zlib, gzip, none]
             
        Returns:
            number of uncompressed bytes, or 0 if none
             
     **************************************************************************/


    public size_t decode ( S, T ) ( S[] buffer_in, out T[] buffer_out, char[] encoding )
    {
        return this.setEncoding(encoding).decode(buffer_in, buffer_out);
    }
    
    /**************************************************************************
    
        Uncompresses Stream
         
        Params:
            stream_in    = compressed input stream conduit
            stream_out   = uncompressed output stream conduit
            encoding     = encoding [auto, zlib, gzip, deflate]
         
        Returns:
            number of uncompressed bytes, or 0 if none
    
     **************************************************************************/

    // Template with 'T = void' is to avoid collisions of overloaded method.
    
    public size_t decode ( T = void ) ( InputStream stream_in, OutputStream stream_out, char[] encoding )
    {
        return this.setEncoding(encoding).decode(stream_in, stream_out);
    }
    
    /**************************************************************************
    
        Uncompresses Buffered Input Stream. Uncompresses content. Output data
        is duplicated (copy on write).
        
        Params:
            stream_in    = compressed input buffer stream
            output       = return buffer
            encoding     = encoding [auto, zlib, gzip, none]
            
        Returns:
            number of uncompressed bytes, or 0 if none
            
    **************************************************************************/


    
    public size_t decode ( T ) ( InputStream stream_in, out T[] output, char[] encoding )
    {
        return this.setEncoding(encoding).decode(stream_in, output);
    }
    
    
    
    /**************************************************************************
     
         Close the buffer
     
     **************************************************************************/
    
    public void close()
    {
        this.input_buffer.close();
        this.output_buffer.close();
    }
    
    /**************************************************************************
        
        Determines if "content" (most likely) contains gzipped data by
        comparing the first two bytes against the gzip signature.
        
        Params:
             content = content to examine
             
        Returns:
             true if content data appear to be gzipped or false otherwise
             
     **************************************************************************/
    
    public static bool detectGzip ( T ) ( T[] content )
    {
        cast (void) assertByteType!(T, ".detectGzip()", "content");
        
        ubyte[] sign = (cast (ubyte[]) content)[0 .. min(this.GZIP_SIGNATURE.length, content.length)];
        
        return (sign == this.GZIP_SIGNATURE);
    }
    
    /**************************************************************************
    
        Compares the first bytes of stream_in to the Gzip signature and puts
        them to stream_out.
         
        Params:
            stream_in    = compressed input stream conduit
            stream_out   = uncompressed output stream conduit
         
        Returns:
            true on match or false otherwise
    
     **************************************************************************/
    
    public static bool detectGzip ( T = void ) ( InputStream stream_in, OutputStream stream_out, ref size_t total )
    {
        size_t s;
        
        bool is_gzip = false;
        
        ubyte[this.GZIP_SIGNATURE.length] gz_sign;
        
        s = stream_in.read(gz_sign);                // try to read Gzip signature to gz_sign
        
        if (s != stream_in.Eof)                     // EOF while reading Gzip signature
        {
            total += s;
            
            stream_out.write(gz_sign[0 .. s]);      // write gz_sign to output
            
            is_gzip = detectGzip(gz_sign);     // check gz_sign for Gzip signature
        }
        
        return is_gzip;
    }
    
    /**************************************************************************
      
          Set compression encoding.
          If an invalid code is supplied, and accept_invalid is
               - true, the encoding is set to the default value as defined in
                       DEFAULT_ENCODING;
               - false, an exception is thrown.
       
          Params:
              code           = encoding identifier string
              accept_invalid = Set to true to set to default encoding on invalid
                               code or to false to throw an exception in this
                               case.
              
          Returns:
              this instance
          
     **************************************************************************/
    
    public typeof (this) setEncoding ( Encoding code, bool accept_invalid = false )
    {
        bool ok = accept_invalid;
        
        if (!ok) foreach (encoding; this.encodings)
        {
            ok = (encoding.code == code);
            
            if (ok) break;
        }
        
        assert (ok, typeof (this).stringof ~ ": invalid encoding option");
        
        this.encoding = code;
        
        return this;
    }
    
    
    /**************************************************************************
      
          Set decompression encoding.
          If an invalid code is supplied, and accept_invalid is
               - true, the encoding is set to the default value as defined in
                       DEFAULT_ENCODING;
               - false, an exception is thrown.
       
          Params:
              code           = encoding identifier string
              accept_invalid = Set to true to set to default encoding on invalid
                               code or to false to throw an exception in this
                               case.
              
          Returns:
              this instance
          
     **************************************************************************/
    
    public typeof (this) setDecoding ( Decoding code, bool accept_invalid = false )
    {
        bool ok = accept_invalid;
        
        if (!ok) foreach (decoding; this.decodings)
        {
            ok = (decoding.code == code);
            
            if (ok) break;
        }
        
        assert (ok, typeof (this).stringof ~ ": invalid decoding option");
        
        this.decoding = code;
        
        return this;
    }
    
    
    /**************************************************************************
    
        Set decompression encoding.
        
        If an unknown identifier string is supplied, and accept_unknown is
             - true, the encoding is set to the default value as defined in
                     DEFAULT_ENCODING;
             - false, an exception is thrown.
     
        Params:
            id             = encoding identifier string
            accept_unknown = Set to true to set to default encoding on unknown
                             identifier string or to false to throw an exception
                             in this case.
            
        Returns:
            this instance
        
     **************************************************************************/
    
    public typeof (this) setDecoding ( char[] id, bool accept_unknown = false )
    {
        this.decoding = this.getDecodingFromId(id, accept_unknown);
        
        return this;
    }
    
    
    /**************************************************************************
    
        Set compression encoding.
        
        If an unknown identifier string is supplied, and accept_unknown is
             - true, the encoding is set to the default value as defined in
                     DEFAULT_ENCODING;
             - false, an exception is thrown.
     
        Params:
            id             = encoding identifier string
            accept_unknown = Set to true to set to default encoding on unknown
                             identifier string or to false to throw an exception
                             in this case.
            
        Returns:
            this instance
        
    **************************************************************************/

    public typeof (this) setEncoding ( char[] id, bool accept_unknown = false )
    {
        this.encoding = this.getEncodingFromId(id, accept_unknown);
        
        return this;
    }
    
    
    /**************************************************************************
    
        Set compression level.
        
        The compression level may be an integer value from -1 to 9 where -1
        denotes the default compression level, 0 no, 1 lowest/fastest and 9
        highest/slowest compression.
        
        If an invalid code is supplied, and accept_unknown is
             - true, the compression level is set to the default level;
             - false, an exception is thrown.
        
        Params:
            code           = compression level code
            accept_unknown = Set to true to set to default compression level
                             on unknown identifier string or to false to throw
                             an exception in this case.
            
        Returns:
            this instance
        
    **************************************************************************/

    public typeof (this) setLevel ( ZlibOutput.Level code, bool accept_unknown = false )
    {
        this.level = this.normalizeLevel(code, accept_unknown);
        
        return this;
    }
    
    
    /**************************************************************************
    
        Get encoding option code from identifier string.
        
        If an unknown identifier string is supplied, and accept_unknown is
             - true, the encoding is set to the default value as defined in
                     DEFAULT_ENCODING;
             - false, an exception is thrown.
     
        Params:
            id             = encoding option identifier string
            accept_unknown = Set to true to set to default encoding on unknown
                             identifier string or to false to throw an exception
                             in this case.
            
        Returns:
            encoding option code
        
     **************************************************************************/
    
    public static Encoding getEncodingFromId ( char[] id, bool accept_unknown = false )
    out (r)
    {
        Stderr.formatln("{} {}", id, r);
    }
    body
    {
        foreach (encoding; this.encodings)
        {
            if (id in encoding) return encoding.code;
        }
        
        assert (accept_unknown, typeof (this).stringof ~
                ": unknown encoding identifier '" ~ id ~ '\'');
        
        return this.DEFAULT_ENCODING;
    }
    
    /**************************************************************************
    
        Get decoding option code from identifier string.
        
        If an unknown identifier string is supplied, and accept_unknown is
             - true, the encoding is set to the default value as defined in
                     DEFAULT_ENCODING;
             - false, an exception is thrown.
     
        Params:
            id             = encoding option identifier string
            accept_unknown = Set to true to set to default encoding on unknown
                             identifier string or to false to throw an exception
                             in this case.
            
        Returns:
            encoding option code
        
    **************************************************************************/

    public static Decoding getDecodingFromId ( char[] id, bool accept_unknown = false )
    out (r)
    {
        Stderr.formatln("{} {}", id, r);
    }
    body
    {
        foreach (decoding; this.decodings)
        {
            if (id in decoding) return decoding.code;
        }
        
        assert (accept_unknown, typeof (this).stringof ~
                                ": unknown decoding identifier '" ~ id ~ '\'');
        
        return this.DEFAULT_DECODING;
    }
    
    /**************************************************************************
    
        Get compression level code from identifier string.
        
        The compression level identifier string may be a string containing the
        decimal representation of an integer value from -1 to 9 where -1 denotes
        the default compression level, 0 no, 1 lowest/fastest and 9
        highest/slowest compression.
        
        If an unknown identifier string is supplied, and accept_unknown is
             - true, the encoding is set to the default value as defined in
                     DEFAULT_ENCODING;
             - false, an exception is thrown.
     
        Params:
            id             = compression level identifier string
            accept_unknown = Set to true to set to default compression level
                             on unknown identifier string or to false to throw
                             an exception in this case.
            
        Returns:
            compression level code
        
    **************************************************************************/

    public static ZlibOutput.Level getLevelFromId ( char[] id, bool accept_unknown = false )
    out (r)
    {
        Stderr.formatln("{} {}", id, r);
    }
    body
    {
        ZlibOutput.Level code; 
        
        foreach (level; this.levels)
        {
            if (id in level) return level.code;
        }
        
        try
        {
            code = cast (typeof (code)) Integer.toInt(id);
        }
        catch (Exception e)
        {
            if (accept_unknown)
            {
                return ZlibOutput.Level.Normal;
            }
            else
            {
                e.msg = typeof (this).stringof ~
                        ": invalid encoding identifier '" ~ id ~ "' (" ~ e.msg ~ ')';
                
                throw e;
            }
        }
        
        return normalizeLevel(code, accept_unknown);
    }
    
    
    /**************************************************************************
    
        Normalize compression level to a valid value.
        
        The compression level may be an integer value from -1 to 9 where -1
        denotes the default compression level, 0 no, 1 lowest/fastest and 9
        highest/slowest compression.
        
        If an invalid code is supplied, and nevermind is
             - true, the default compression level value is returned;
             - false, an exception is thrown.
        
        Params:
            code           = 
            accept_unknown = Set to true to set to default compression level
                             on unknown identifier string or to false to throw
                             an exception in this case.
            
        Returns:
            normalized compression level
        
    **************************************************************************/

    private static ZlibOutput.Level normalizeLevel ( ZlibOutput.Level code, bool nevermind )
    {
        bool in_range = ((code >= ZlibOutput.Level.min) && (ZlibOutput.Level.max >= code));
        
        assert (in_range || nevermind, typeof (this).stringof ~ "compression level parameter out of range");
        
        return in_range? code : ZlibOutput.Level.Normal;
    }
    
    
    /**************************************************************************
      
      Initialize ZlibStream input to read from a new input stream
      
          Params:
              stream_in    = compressed input buffer stream
              
     **************************************************************************/ 
    
    private ZlibInput initZlibStreamInput ( InputStream stream_in )
    {
        if (this.decomp)
        {   
            this.decomp.reset(stream_in, this.decoding);
        }
        else 
        {         
            this.decomp = new ZlibInput(stream_in, this.decoding);
        }
        
        return this.decomp;
    }
    
    
    /**************************************************************************
    
        Initialize ZlibStream output to write to a new output stream
        
            Params:
                stream_out    = compressed output buffer stream
                
   **************************************************************************/ 
  
    private ZlibOutput initZlibStreamOutput ( OutputStream stream_out )
    {
        if (this.comp)
        {   
            this.comp.reset(stream_out, this.level, this.encoding);
        }
        else 
        {         
            this.comp = new ZlibOutput(stream_out, this.level, this.encoding);
        }
        
        return this.comp;
    }
    
    /**************************************************************************
    
        Initialize input buffer
     
    **************************************************************************/
    
    private typeof (input_buffer) initInputBuffer ( )
    {   
      if (this.input_buffer)
      {
          this.input_buffer.clear(); // Clear input buffer       
      }
      else 
      {
          // Create input buffer for ZlibStream to consume
          this.input_buffer = new Array(this.INPUT_BUF_SIZE, this.GROW_IB_SIZE);
      }
      
      return this.input_buffer;
    }
    
    
    
    /**************************************************************************
    
        Initialize output buffer 
    
    **************************************************************************/
    
    private typeof (output_buffer) initOutputBuffer ()
    {   
      if (this.output_buffer)
      {
          this.output_buffer.clear(); // Clear output buffer
      }
      else 
      {
          // Create output buffer for ZlibStream to consume
          this.output_buffer = new Array(this.UNCOMPRESS_BUF_SIZE, this.GROW_UB_SIZE);            
      }
      
      return this.output_buffer;
    }


    /**************************************************************************
    
        Assert T is a single byte type or void 
    
    **************************************************************************/

    template assertByteType ( T, char[] context, char[] item )
    {
        const assertByteType = ((T.sizeof == 1) || is (T == void));
        
        static assert (assertByteType,
                       typeof (this).stringof ~ context ~ ": '" ~ item ~
                       "' must be array of single byte type or void, not '" ~
                       T.stringof ~ '\'');
    }
}


/******************************************************************************

    UncompressException

 ******************************************************************************/

class UncompressException : Exception
{
    this ( char[] msg )
    {
        super(msg);
    }
    
    private static void opCall ( char[] msg ) 
    { 
        throw new UncompressException(msg); 
    }
}