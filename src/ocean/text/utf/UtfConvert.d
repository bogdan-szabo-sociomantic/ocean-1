/*******************************************************************************

    UTF conversion

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        December 2009: Initial release

    author:         David Eckardt

    --

    UTF conversion from UTF8/16/32 to UTF8/16/32. Build on top of
    tango.text.convert.Utf and provides the following advantages:

    - destination is forced to be an existing object and resized before
      conversion to avoid heap activity
    - "fromUtf#" and "toUtf#" for # in {8, 16, 32}
    - capability of null-conversion within the same type (e.g. UTF32 to UTF32)
    - generic conversion template
    - class holding conversion result buffer

    Note: Since tango.text.Utf of the current version  0.99.8 provides support
    for a maximum of 4 byte per character, the output string is resized to this
    length before conversion.

    Type/encoding correspondences:

         char -- UTF-8
        wchar -- UTF-16
        dchar -- UTF-32

    --

    Usage:

    Example 1: Using the static UtfConvert method

    ---

        import ocean.text.utf.UtfConvert;

        char[]  result_c;                           // UTF8  source string
        wchar[] result_w;                           // UTF16 source string
        dchar[] result_d;                           // UTF32 source string

        char[]  hello_c = "Hello UTF8 World!";      // UTF8  result string
        wchar[] hello_w = "Hello UTF16 World!";     // UTF16 result string
        dchar[] hello_d = "Hello UTF32 World!";     // UTF32 result string

        UtfConvert(hello_c, result_d);              // UTF8 to UTF32
        UtfConvert(hello_d, result_w);              // UTF32 to UTF16
        UtfConvert(hello_c, result_c);              // UTF8 to UTF8: hello_c is copied
                                                    // to result_c (duplicated not sliced)

    ---

    Example 2: Using the Utf class

    ---

        import ocean.text.utf.UtfConvert;

        char[]  hello = "Hello UTF8 World!";        // UTF8 source string

        dchar[] result;                             // UTF32 destination string

        auto utf = new UtfConvert!(char, dchar);    // instantiate an UTF8 to UTF32 converter

        result = utf(hello);

    ---

    TODO: When conversion from UTF-8 is added to GlibUnicode, use GlibUnicode
          methods in convertUtf instead of Tango

 ******************************************************************************/

deprecated module ocean.text.utf.UtfConvert;

/*******************************************************************************

     Imports

 ******************************************************************************/

import ocean.text.utf.GlibUnicode;

import Utf = tango.text.convert.Utf: toString, toString16, toString32;

import ocean.text.util.StringReplace;


/*******************************************************************************

    Utf class

    S: source type
    T: target type

 ******************************************************************************/

class UtfConvert ( S, T )
{
    /**************************************************************************

        Tells whether this is a noop instance because whether S and T are the
        same type

     **************************************************************************/

    const NoOp = is (S == T);

    static if (NoOp)
    {
        /**********************************************************************

            Converts UTF input string of type S[] to an UTF string of type T[].

            Params:
                input: input content

            Returns:
                input content

         **********************************************************************/

        // noop conversion for S == T

        T[] opCall ( S[] input )
        {
            return input;
        }
    }
    else
    {
        /**********************************************************************

            Initial string buffer size: 4096 characters

         **********************************************************************/

        const InitialBufferSize = 4096;

        /**********************************************************************

            String buffer for conversion

         **********************************************************************/

        T[] buf;

        /**********************************************************************

             Constructor

         **********************************************************************/

        public this ( )
        {
            this.buf = new T[this.InitialBufferSize];
        }


        /**********************************************************************

             Converts UTF input string of type S[] to an UTF string of type T[].

             Params:
                  input = input string

             Returns:
                  resulting string

         **********************************************************************/

        T[] opCall ( S[] input )
        {
            return convertUtf(input, this.buf);
        }


        /**********************************************************************

             Destructor

         **********************************************************************/

        private ~this ( )
        {
            delete this.buf;
        }
    }
}


/******************************************************************************

     Converts UTF string "input" to UTF string "converted".

     Params:
          input     = source string
          converted = buffer for target string

     Returns:
          target string

 ******************************************************************************/
public static T[] convertUtf ( S, T, bool noop_dup = true ) ( S[] input, ref T[] converted )
{
    static if (is (T == S))
    {
        static if (noop_dup)
        {
            converted = input.dup;
        }
        else
        {
            converted = input;
        }
    }
    else
    {
        converted.length = input.length  * (4 / T.sizeof);

        static if (is (T == char))
        {
            converted = Utf.toString(input, converted);
        }
        else static if (is (T == wchar))
        {
            converted = Utf.toString16(input, converted);
        }
        else static if (is (T == dchar))
        {
            converted = Utf.toString32(input, converted);
        }
        else static assert (false, "convertUtf(): destination type '"
                                   ~ T.stringof ~ "' not supported "
                                   "(character types only)");
    }

    return converted;
}

/******************************************************************************

    Composes an Unicode character from two UTF-8 bytes

    (Taken from tango.text.convert.Utf.toString())

    Params:
        lb = lower byte
        ub = upper byte

    Returns:
        composed Unicode character

 ******************************************************************************/

public static Char composeUtf8Char ( Char ) ( Char lb, Char ub )
{
    return (((lb & 0x1F) << 6) | (ub & 0x3F));
}

/******************************************************************************

    FixUtf8 class

 ******************************************************************************/

class FixUtf8
{
    /**************************************************************************

        Template instance alias

     **************************************************************************/

    private alias   StringReplace!(true)    StringReplace_;

    /**************************************************************************

        Character type alias

     **************************************************************************/

    private alias   StringReplace_.Char     Wchar;

    /**************************************************************************

        This alias for chainable methods

     **************************************************************************/

    private alias   typeof (this)           This;

    /**************************************************************************

        Magic character for malcoded UTF8 detection

     **************************************************************************/

    public const Wchar[] Utf8MagicChars = [0xC2, 0xC3, 0xC4, 0xC5]; // "ÂÃÄÅ"

    /**************************************************************************

        StringReplace instance

     **************************************************************************/

    private StringReplace_ stringReplace;


    private Wchar[] content;

    /**************************************************************************

        Constructor

     **************************************************************************/

    this ( )
    {
        this.stringReplace = new StringReplace_;

        this.content       = new Wchar[0];
    }


    /**************************************************************************

        Scans content for malcoded Unicode characters and replaces them by the
        correct ones.

        Notes:
        - The character replacement is done in-place and changes the length of
          "input": The length is decreased by the number of malcoded characters
          found (two malcoded characters form one correct character).

        - The search/replace rule is as follows: "input" is scanned for
          characters with the value 0xC3 ('Ã'). If that character is followed by
          a character with a value of 0x80 or above, the character and its
          follower are considered two erroneously Unicode coded raw bytes and the
          UTF-8 character that consists of these two bytes is composed.

        Example:

          String with malcoded characters:
            "AbrahÃ£o, JosÃ© Jorge dos Santos; Instituto AgronÃ´mico do ParanÃ¡"

          Resulting string:
             "Abrahão, José Jorge dos Santos; Instituto Agronômico do Paraná"

        Params:
            content = UTF-8 encoded text content to process

        Returns:
            this instance

     **************************************************************************/

    public This opCall ( Char ) ( ref Char[] content )
    {
        static if (is (Char == Wchar))
        {
            this.stringReplace.replaceDecodeCharSet(content, this.Utf8MagicChars, &this.decodeUtf8);
        }
        else
        {
            this.content = convertUtf(content, this.content);

            this.stringReplace.replaceDecodeCharSet(this.content, this.Utf8MagicChars, &this.decodeUtf8);

            content = convertUtf(this.content, content);
        }

        return this;
    }

    /**************************************************************************

        Composes an UTF-8 character from content[0 .. 1] and puts it to
        replacement, if content[1] has a value above 128.

        Params:
            content     = content string to get the characters from
            replacement = one-character replacement string output

        Returns:
            number of characters replaced in content (2 if the composition was
            done or 0 otherwise)

     **************************************************************************/

    private size_t decodeUtf8 ( Wchar[] content, out Wchar[] replacement )
    {
        size_t replaced = 0;

        if (content.length >= 2)
        {
            auto lo = content[0],
                 up = content[1];

            if (up & 0x80)
            {
                replacement = [composeUtf8Char(lo, up)];

                replaced = 2;
            }
        }

        return replaced;
    }

    /**************************************************************************

        Destructor

     **************************************************************************/

    private ~this ( )
    {
        delete this.stringReplace;
        delete this.content;
    }
}
