/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    author:         David Eckardt, Gavin Norman

    Template class for xml / html / xhtml / etc (markup language) entity
    en/decoders, which share basically the same entity encoding scheme, only
    differing in the exact entities which must be encoded. (The html entities
    are a superset of the xml entities, for example.)

    See here for details:

    http://en.wikipedia.org/wiki/List_of_XML_and_HTML_character_entity_references

    Example usage:

    ---

        import ocean.text.entities.HtmlEntityCodec;

        scope entity_codec = new HtmlEntityCodec;

        char[] test = "hello & world © &szlig;&nbsp;&amp;#x230;'";

        if ( entity_codec.containsUnencoded(test) )
        {
            char[] encoded;
            entity_codec.encode(test, encoded);
        }

    ---

*******************************************************************************/

module ocean.text.entities.model.MarkupEntityCodec;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import ocean.text.entities.model.IEntityCodec;
private import ocean.text.entities.model.IEntitySet;

private import ocean.text.utf.UtfString;

private import ocean.text.util.StringSearch;

private import Utf = tango.text.convert.Utf;

private import Math = tango.math.Math: min;

private import Integer = tango.text.convert.Integer: toInt;




/*******************************************************************************

    Class to en/decode xml / html style entities.

*******************************************************************************/

public class MarkupEntityCodec ( E : IEntitySet ) : IEntityCodec!(E)
{
    /***************************************************************************

        This alias.

    ***************************************************************************/

    public alias typeof(this) This;


    /***************************************************************************

        Buffers for each character type, used by the utf8 encoder in the methods
        charTo() & dcharTo().

    ***************************************************************************/

    private char[] char_buffer;

    private wchar[] wchar_buffer;

    private dchar[] dchar_buffer;


    /***************************************************************************

        Buffer used when formatting an entity.

    ***************************************************************************/

    private char[] entity_buf;


    /***************************************************************************

        Encode any unencoded entities in the input string.

        Params:
            text = string to encode
            encoded = output string

        Returns:
            encoded output string

    ***************************************************************************/

    public char[] encode ( char[] text, ref char[] encoded )
    {
        return this.encode_(text, encoded);
    }

    public wchar[] encode ( wchar[] text, ref wchar[] encoded )
    {
        return this.encode_(text, encoded);
    }

    public dchar[] encode ( dchar[] text, ref dchar[] encoded )
    {
        return this.encode_(text, encoded);
    }


    /***************************************************************************

        Decode any encoded entities in the input string.

        Params:
            text = string to decode
            decoded = output string

        Returns:
            decoded output string

    ***************************************************************************/

    public char[] decode ( char[] text, ref char[] decoded )
    {
        return this.decode_(text, decoded);
    }

    public wchar[] decode ( wchar[] text, ref wchar[] decoded )
    {
        return this.decode_(text, decoded);
    }

    public dchar[] decode ( dchar[] text, ref dchar[] decoded )
    {
        return this.decode_(text, decoded);
    }


    /***************************************************************************

        Checks whether the input string contains any unencoded entities.

        Params:
            text = string to check

        Returns:
            true if one or more unencoded entities are found

    ***************************************************************************/

    public bool containsUnencoded ( char[] text )
    {
        return this.containsUnencoded_(text);
    }

    public bool containsUnencoded ( wchar[] text )
    {
        return this.containsUnencoded_(text);
    }

    public bool containsUnencoded ( dchar[] text )
    {
        return this.containsUnencoded_(text);
    }


    /***************************************************************************

        Checks whether the input string contains any encoded entities.

        Params:
            text = string to check

        Returns:
            true if one or more encoded entities are found

    ***************************************************************************/

    public bool containsEncoded ( char[] text )
    {
        return this.containsEncoded_(text);
    }

    public bool containsEncoded ( wchar[] text )
    {
        return this.containsEncoded_(text);
    }

    public bool containsEncoded ( dchar[] text )
    {
        return this.containsEncoded_(text);
    }


    /***************************************************************************

        Checks whether the input string begins with an unencoded entity.

        Note: a full string has to be passed (not just a single character), as
        '&' is an unencoded entity, but "&amp;" is not - these cases are not
        distinguishable from just the 1st character.

        Params:
            text = string to check

        Returns:
            true if the first character in the input string is an unencoded
            entity

    ***************************************************************************/

    public bool isUnencodedEntity ( Char ) ( Char[] text )
    {
        static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
                This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);

        auto c = UtfString!(Char, true).extract(text);

        if ( c in this.entities )
        {
            if ( c == '&' )
            {
                // The following characters must form a valid character code
                auto entity = this.sliceEncodedEntity(text);
                if ( entity.length )
                {
                    auto decoded_entity = this.decodeEntity(entity);
                    return decoded_entity == InvalidUnicode;
                }
                else
                {
                    return true;
                }
            }
            else
            {
                return true;
            }
        }
        else
        {
            return false;
        }
    }


    /***************************************************************************

        Checks whether the input string begins with an encoded entity.

        Params:
            text = string to check
            exact_match = if true, the encoded entity must fill the entire input
                string

        Returns:
            true if the string begins with an encoded entity

    ***************************************************************************/

    public bool isEncodedEntity ( Char ) ( Char[] text, bool exact_match = false )
    {
        static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
                This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);

        auto entity = this.sliceEncodedEntity(text);
        if ( !entity.length )
        {
            return false;
        }

        return exact_match ? entity.length == text.length : true;
    }


    /***************************************************************************

        Converts an encoded entity to a unicode character. The entity may be
        either:
            - a numeric character reference (eg "&#xE1;" for 'á'), or
            - a named ISO8859-1/15 (Latin 1/9) entity (eg "&szlig;" for 'ß').

        Params:
            entity = entity content to convert; trailing '&' and terminating ';'
                are expected

        Throws:
            asserts that the passed entity is > 2 characters long, and has a '&'
            in the first position and a ';' in the last

        Returns:
            the unicode character or InvalidUnicode on failure

    ***************************************************************************/

    public dchar decodeEntity ( Char ) ( Char[] entity )
    in
    {
        assert(this.isEncodedEntity(entity, true), This.stringof ~ ".decodeEntity - invalid character entity");
    }
    body
    {
        static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
                This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);

        dchar unicode = InvalidUnicode;

        if ( entity.length )
        {
            UtfString!(Char, true) utf_str = { entity };
            auto c = utf_str[1];
            if (c == '#')
            {
                unicode = this.decodeNumericCharacterRef(entity);
            }
            else
            {
                unicode = this.decodeCharacterEntity(entity);
            }
        }

        return unicode;
    }


    /***************************************************************************

        Internal method for encoding any unencoded entities in a string.

        Params:
            text = string to encode
            encoded = encoded output string

        Returns:
            encoded output string

    ***************************************************************************/

    protected Char[] encode_ ( Char ) ( Char[] text, ref Char[] encoded )
    {
        static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
                This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);

        encoded.length = 0;

        size_t last_special_char;
        size_t i;
        while ( i < text.length )
        {
            Char[] process = text[i..$];

            size_t width;
            auto c = UtfString!(Char, true).extract(process, width);

            if ( this.isUnencodedEntity(process) )
            {
                encoded.append(text[last_special_char..i]);

                this.appendEncodedEntity(encoded, c);

                last_special_char = i + width;
            }

            i += width;
        }

        encoded.append(text[last_special_char..$]);
        return encoded;
    }


    /***************************************************************************

        Internal method for decoding any encoded entities in a string.

        Params:
            text = string to decode
            decoded = decoded output string

        Returns:
            decoded output string

    ***************************************************************************/

    protected Char[] decode_ ( Char ) ( Char[] text, ref Char[] decoded )
    {
        static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
                This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);

        decoded.length = 0;

        size_t last_special_char = 0;
        size_t i = 0;
        while ( i < text.length )
        {
            if ( text[i] == '&')
            {
                auto entity = this.sliceEncodedEntity(text[i..$]);
                if ( entity.length )
                {
                    decoded.append(text[last_special_char..i]);

                    dchar unicode = this.decodeEntity(entity);
                    if ( unicode != InvalidUnicode )
                    {
                        decoded.append(this.dcharTo!(Char)(unicode));
                    }

                    i += entity.length;
                    last_special_char = i;
                    continue;
                }
            }
            ++i;
        }

        decoded.append(text[last_special_char..$]);
        return decoded;
    }


    /***************************************************************************

        Internal method for checking whether the passed string contains any
        unencoded entities.

        Params:
            text = string to check

        Returns:
            true if any unencoded entities are found

    ***************************************************************************/

    protected bool containsUnencoded_ ( Char ) ( Char[] text )
    {
        static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
                This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);

        UtfString!(Char) utf_str = { text };
        foreach ( i, c; utf_str )
        {
            if ( this.isUnencodedEntity(text[i..$]) )
            {
                return true;
            }
        }

        return false;
    }


    /***************************************************************************

        Internal method for checking whether the passed string contains any
        encoded entities.

        Params:
            text = string to check

        Returns:
            true if any encoded entities are found

    ***************************************************************************/

    protected bool containsEncoded_ ( Char ) ( Char[] text )
    {
        static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
                This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);

        UtfString!(Char) utf_str = { text };
        foreach ( i, c; utf_str )
        {
            auto entity = this.sliceEncodedEntity(text[i..$]);
            if ( entity.length )
            {
                return true;
            }
        }

        return false;
    }


    /***************************************************************************

        Appends an encoded entity to a string (in the form "&entity_name;").

        Params:
            text = string to append to
            c = unicode character for entity to append

        Returns:
            appended string

    ***************************************************************************/

    protected Char[] appendEncodedEntity ( Char ) ( ref Char[] text, dchar c )
    {
        static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
                This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);

        auto name = this.entities.getName(c);
        if ( name.length )
        {
            text.append(this.charTo!(Char)(this.entities.getEncodedEntity(c, this.entity_buf)));
        }

        return text;
    }


    /***************************************************************************

        Parses content to see if it's an encoded entity string. The criteria
        are:

         a) length of "entity" is at least 3,
         b) character 0 is '&',
         c) a ';' between characters 1 and 16,
         d) no white space character or '&' before the first ';'.
         e) first ';' is after character 2

        If "entity" complies with all of these, slice from the '&' to the ';' is
        returned, otherwise null.

        Params:
             entity = HTML entity string to parse

        Returns:
             The entity if parsing was successfull or null on failure.

    ***************************************************************************/

    protected Char[] sliceEncodedEntity ( Char ) ( Char[] text )
    {
        static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
                This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);

        if ( text.length <= 2 )                             // a) criterion
        {
            return "";
        }

        Char[] entity;
        UtfString!(Char, true) utf_str = { text };
        foreach ( i, c; utf_str )
        {
            if ( i == 0 )
            {
                if ( c != '&' )                                // b) criterion
                {
                    break;
                }
            }
            else
            {
                if ( c == '&' || this.isSpace(c) )            // d) criterion
                {
                    break;
                }

                if ( c == ';' )
                {
                    if ( i < 2 )                            // e) criterion
                    {
                        break;
                    }

                    entity = text[0 .. i + 1];
                    break;
                }
            }
        }

        return entity;
    }


    /***************************************************************************

        Checks whether the given character is a space.

        Params:
            c = character to check

        Returns:
            true if the character is a space

    ***************************************************************************/

    protected bool isSpace ( Char ) ( Char c )
    {
        static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
                This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);

        dchar unicode = c;
        StringSearch!(true) str_search;
        return !!str_search.isSpace(unicode);
    }


    /***************************************************************************

        Converts an encoded entity to a unicode character.

        Params:
            entity = entity content to convert; including leading '&' and
                terminating ';'

        Returns:
            the unicode character or InvalidUnicode on failure

    ***************************************************************************/

    protected dchar decodeCharacterEntity ( Char ) ( Char[] entity )
    in
    {
        assert(entity.length >= 2, "character entity too short");
        assert(entity[0] == '&' && entity[$ - 1] == ';', "invalid character entity");
    }
    body
    {
        static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
                This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);

        return this.entities.getUnicode(entity[1 .. $ - 1]);
    }


    /***************************************************************************

        Converts an encoded numeric character reference entity to a unicode
        character. Numeric character references are either:

             &#<decimal Unicode>;
        or
             &#x<hexadecimal Unicode>;

        (case insensitive)

        Examples:

             Entity      Character       Unicode hex (dec)
             "&#65;"     'A'             0x41 (65)
             "&#xE1;"    'á'             0xE1 (225)
             "&#Xf1;"    'ñ'             0xF1 (241)

        Params:
            entity = entity content to convert; including leading "&#" and
                terminating ';'

        Returns:
            the unicode character or InvalidUnicode on failure

    ***************************************************************************/

    protected dchar decodeNumericCharacterRef ( Char ) ( Char[] entity )
    in
    {
        assert(entity.length >= 2, "character entity too short");
        assert(entity[0] == '&' && entity[$ - 1] == ';', "invalid character entity");
    }
    body
    {
        static assert(is(Char == char) || is(Char == wchar) || is(Char == dchar),
                This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof);

        dchar unicode = InvalidUnicode;

        try
        {
            // Get the first character after the '&'
            auto c = entity[2];

            // hexadecimal
            if ( c == 'x' || c == 'X' )
            {
                unicode = cast(dchar) Integer.toInt(entity[3 .. $ - 1], 16);
            }
            // decimal
            else
            {
                unicode = cast(dchar) Integer.toInt(entity[2 .. $ - 1], 10);
            }
        }
        catch {}

        return unicode;
    }


    /***************************************************************************

        Converts from a unicode dchar to an array of the specified character
        type, doing utf8 encoding if applicable.

        Params:
            unicode = unicode character to convert

        Returns:
            converted character string

    ***************************************************************************/

    private Char[] dcharTo ( Char ) ( dchar unicode )
    {
        dchar[1] str;
        str[0] = unicode;
        return this.dcharTo!(Char)(str);
    }


    /***************************************************************************

        Converts from a unicode dchar[] to an array of the specified character
        type, doing utf8 encoding if applicable.

        Params:
            unicode = unicode string to convert

        Returns:
            converted character string

    ***************************************************************************/

    private Char[] dcharTo ( Char ) ( dchar[] unicode )
    {
        static if ( is(Char == char) )
        {
            return super.dcharTo!(Char)(unicode, this.char_buffer);
        }
        else static if ( is(Char == wchar) )
        {
            return super.dcharTo!(Char)(unicode, this.wchar_buffer);
        }
        else static if ( is(Char == dchar) )
        {
            return super.dcharTo!(Char)(unicode, this.dchar_buffer);
        }
        else
        {
            static assert(false, typeof(this).stringof ~ ".dcharTo - method template can only handle char types");
        }
    }


    /***************************************************************************

        Converts from a single char to an array of the specified character type.

        Params:
            text = character to convert

        Returns:
            converted character string

    ***************************************************************************/

    private Char[] charTo ( Char ) ( char text )
    {
        dchar[1] str;
        str[0] = text;
        return this.charTo!(Char)(str);
    }


    /***************************************************************************

        Converts from a utf8 char array to an array of the specified character
        type.

        Params:
            text = string to convert

        Returns:
            converted character string

    ***************************************************************************/

    private Char[] charTo ( Char ) ( char[] text )
    {
        static if ( is(Char == char) )
        {
            return super.charTo!(Char)(text, this.char_buffer);
        }
        else static if ( is(Char == wchar) )
        {
            return super.charTo!(Char)(text, this.wchar_buffer);
        }
        else static if ( is(Char == dchar) )
        {
            return super.charTo!(Char)(text, this.dchar_buffer);
        }
        else
        {
            static assert(false, typeof(this).stringof ~ ".charTo - method template can only handle char types");
        }
    }
}

