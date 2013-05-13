/*******************************************************************************

    Ngram parser for any given text

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        May 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai, Gavin Norman

    --

    TODO: update description, usage & unittest

    TODO: support for split word processing including inter-word boundary ngrams
    is complicated by the fact that the NGramSet just stores its ngrams as
    slices into the source text. To support this feature we'd need to be able to
    add ngrams *outside* of the source text...

    Description:

    The ngram parser creates all ngrams for a given text and returns the ngrams
    together with the frequency of each ngram within the document. The source
    text is copied into the object, where it has all punctuation and digits
    removed and is then split into words. Ngrams are then derived from each word
    in turn.

    It uses the class NGramAnalysis to store the results of a parsing, and
    objects of that class can be retrieved from the NGramParser and compared.

    Optionally, a list of stopwords can be set. The ngram parser will not parse
    any words in the stopwords list.

    --

    Example usage:

    ---

        import ocean.text.ling.ngram.NGramParser;
        import ocean.text.ling.ngram.NGramSet;
        import tango.util.log.Trace;

        // Text that should be parsed.
        char[] text = "Raum vs aufmerksamkeitsbezogene Therapie ...";

        // Number of ngrams that should be returned. The ngram map is sorted
        // by the ngram count. ngrams with the highest count are on top.
        // ngrams with the highest number will be returned first.
        uint max_number_ngrams   = 200;

        alias NGramParser!(dchar) Parser;
        auto parser = new Parser;
        parser.setText(text);
        parser.parse();

        foreach (ngram, freq; parser.getNGramMap(max_number_ngrams))
        {
            Trace.formatln("{} {}", ngram, freq);
        }

    ---

    The class can also be used statically to parse texts with a single function
    call, filling in a provided NGramsSet object with the ngrams in the text:

    ---

        import ocean.text.ling.ngram.NGramParser;
        import ocean.text.ling.ngram.NGramAnalysis;
        import tango.util.log.Trace;

        // Text that should be parsed.
        char[] text = "Raum vs aufmerksamkeitsbezogene Therapie ...";

        // Number of ngrams that should be returned. The ngram map is sorted
        // by the ngram count. ngrams with the highest count are on top.
        // ngrams with the highest number will be returned first.
        uint max_number_ngrams   = 200;

        // Parsing trigrams
        uint ngram_size = 3;

        alias NGramParser!(dchar) Parser;
        scope ngrams = new Parser.NGrams;
        Parser.parseText(ngrams, ngram_size, text);

        foreach (ngram, freq; ngrams.getHighest(max_number_ngrams))
        {
            Trace.formatln("{} {}", ngram, occurrence);
        }

    ---

*******************************************************************************/

module      ocean.text.ling.ngram.NGramParser;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.text.ling.ngram.NGramSet;

private import TextUtil = tango.text.Util: contains, substitute, replace, split, trim;

private import Unicode = tango.text.Unicode;

private import Utf = tango.text.convert.Utf;

private import tango.core.Array;

private import ocean.core.Array;

private import tango.stdc.string: memmove;

private import tango.text.UnicodeData;

debug
{
    private import tango.util.log.Trace;
}

/******************************************************************************

    NgramParserException

*******************************************************************************/

class NgramParserException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static void opCall ( Args ... ) ( Args args )
    {
        throw new NgramParserException(args);
    }
}

/*******************************************************************************

    NGramParser class - just a namespace, all methods are static.

*******************************************************************************/

public class NGramParser
{
    /***************************************************************************

        Private constructor to prevent instantiation.

    ***************************************************************************/

    private this ( )
    {
    }

    static:

    /***************************************************************************

        Apostrophe characters, which are converted to ' during processing.

    ***************************************************************************/

    public const dchar[] apostrophes = "'‘’`’";


    /***************************************************************************

        Debug info output switch

    ***************************************************************************/

    public bool debug_trace = false;


    /***************************************************************************

        Split text into separate words and stores them in the output words
        array.

        Params:
            text = text to split
            words = output array of words (slices into text)

        Throws:
            asserts that the passed text has been normalized (see the
            normalizeText methods)

    ***************************************************************************/

    public void splitWords ( dchar[] text, ref dchar[][] words, dchar[][] stopwords )
    in
    {
        assert(isNormalized(text), typeof(this).stringof ~ ".splitWords - text isn't normalized");
    }
    body
    {
        auto check_stopwords = stopwords.length > 0;

        words.length = 0;

        foreach ( word; TextUtil.split(text, " "d) )
        {
            if ( word != "" )
            {
                auto NotStopWord = stopwords.length;
                if ( !check_stopwords || (check_stopwords && stopwords.find(word) == NotStopWord) )
                {
                    words.length = words.length + 1;
                    words[$ - 1] = TextUtil.trim(word);
                }
            }
        }
    }


    /***************************************************************************

        Parses a text, and fills the passed ngrams set with the discovered
        ngrams.

        Params:
            out_ngrams = ngrams set to be filled
            ngram_length = character length of ngrams
            text = text to parse
            words = list of arrays used to split the text into words

    ***************************************************************************/

    public void parseText ( NGramSet out_ngrams, uint ngram_length, dchar[] text )
    {
        parseText(out_ngrams, ngram_length, [text]);
    }


    /***************************************************************************

        Parses a list of texts, and fills the passed ngrams set with the
        discovered ngrams.

        Params:
            out_ngrams = ngrams set to be filled
            ngram_length = character length of ngrams
            texts = texts to parse

        Throws:
            asserts that the passed texts have been normalized (see the
            normalizeText methods)

    ***************************************************************************/

    public void parseText ( NGramSet out_ngrams, uint ngram_length, dchar[][] texts )
    in
    {
        assert(ngram_length >= 1, typeof(this).stringof ~ ".parseText - ngram_length == 0 !?");
        assert(isNormalized(texts), typeof(this).stringof ~ ".parseText - text isn't normalized");
    }
    body
    {
        out_ngrams.clear();
        getNGrams(out_ngrams, ngram_length, texts);
    }


    /***************************************************************************

        Checks whether a text has been normalized. Normalized text:

            1. Contains no characters which should be stripped.
            2. Contains no upper case characters.

        Params:
            text = text to check

        Returns:
            true if the text is normalized

    ***************************************************************************/

    public bool isNormalized ( dchar[] text )
    {
        foreach ( c; text )
        {
            if ( c != '\'' && c != ' ' )
            {
                if ( stripCharacter(c) || Unicode.isUpper(c) )
                {
                    debug Trace.formatln("{} ({}) should be stripped", c, cast(uint)c);
                    return false;
                }
            }
        }

        return true;
    }


    /***************************************************************************

        Checks whether a list of texts have been normalized.

        Params:
            texts = list of texts to check

        Returns:
            true if all texts are normalized

    ***************************************************************************/

    public bool isNormalized ( dchar[][] texts )
    {
        foreach ( text; texts )
        {
            if ( !isNormalized(text) )
            {
                return false;
            }
        }
        return true;
    }


    /***************************************************************************

        Normalizes text for ngram parsing. Text is converted to dchar, ignored
        characters are removed, upper case characters are converted to lower
        case, and consecutive whitespace characters are skipped. Stopwords are
        also removed.

        Template params:
            T = type of input array element

        Params:
            input = text to normalize
            output = output for normalized text
            working = required intermediary buffer
            stopwords = list of stopwords to remove

    ***************************************************************************/

    public void normalizeText ( T ) ( T[] input, ref dchar[] output, ref dchar[] working, dchar[][] stopwords = [] )
    {
        auto dchar_input = convertToDChar(input, working);

        if ( stopwords.length )
        {
            normalizeCharacters(dchar_input, output);
            removeStopWords(output, working, stopwords);
            compressWhitespace(working, output);
        }
        else
        {
            normalizeCharacters(dchar_input, working);
            compressWhitespace(working, output);
        }
    }


    /***************************************************************************

        Processes a text, splitting it into words (by space characters), then
        copying any non-stopwords into the output buffer.

        Params:
            input = text to process
            output = output for processed text
            stopwords = list of words to remove from input text

    ***************************************************************************/

    public void removeStopWords ( dchar[] input, ref dchar[] output, dchar[][] stopwords )
    {
        output.length = 0;

        debug uint count, stop;
        foreach ( word; TextUtil.split(input, " "d) )
        {
            if ( word.length )
            {
                debug count++;
                auto NotStopWord = stopwords.length;
                if ( stopwords.find(word) == NotStopWord )
                {
                    output.append(word, " "d);
                }
                else debug stop++;
            }
        }

        debug if ( debug_trace && stopwords.length )
        {
            Trace.formatln("Stopwording reduced word count from {} to {} ({}% reduction)", count, count - stop, (cast(float)stop / cast(float)count) * 100);
        }
    }


    /***************************************************************************

        Processes an input text, normalizing each character in turn and writing
        the result to the output text buffer.

        Params:
            input = text to process
            output = output for processed text

    ***************************************************************************/

    private void normalizeCharacters ( dchar[] input, ref dchar[] output )
    {
        output.length = input.length; // good guess

        size_t write_pos;
        foreach ( c; input )
        {
            appendToString(output, normalizeCharacter(c), write_pos);
        }
    }


    /***************************************************************************

        Processes an input text, removing consecutive whitespace characters and
        writing the result to the output text buffer.

        Params:
            input = text to process
            output = output for processed text

    ***************************************************************************/

    private void compressWhitespace ( dchar[] input, ref dchar[] output )
    {
        output.length = input.length; // good guess

        if ( !input.length )
        {
            return;
        }

        size_t read_pos, write_pos;

        while ( read_pos < input.length - 1 )
        {
            // skip whitespace characters
            bool got_whitespace;
            while ( read_pos < input.length && Unicode.isWhitespace(input[read_pos]) )
            {
                got_whitespace = true;
                read_pos++;
            }

            // replace them all with a single space
            if ( got_whitespace )
            {
                appendToString(output, " "d, write_pos);
            }

            // copy non-whitespace characters
            size_t word_start = read_pos;
            while ( read_pos < input.length && !Unicode.isWhitespace(input[read_pos]) )
            {
                read_pos++;
            }

            if ( read_pos - word_start > 0 )
            {
                appendToString(output, input[word_start .. read_pos], write_pos);
            }
        }
    }


    /***************************************************************************

        Copies a source string into a destination string, writing at the
        specified write position. The destination string is expanded as
        necessary.

        Params:
            dest = string to write to
            src = string to copy
            write_pos = position to write to

    ***************************************************************************/

    private void appendToString ( ref dchar[] dest, dchar[] src, ref size_t write_pos )
    {
        // make sure there's space in output
        auto expand = write_pos + src.length - dest.length;
        if ( expand > 0 )
        {
            dest.length = dest.length + expand;
        }

        dest[write_pos .. write_pos + src.length] = src[];
        write_pos += src.length;
    }


    /***************************************************************************

        Converts a string to dchar (unicode characters).

        Params:
            input = string to convert
            output = output for converted string

    ***************************************************************************/

    private dchar[] convertToDChar ( dchar[] input, ref dchar[] output )
    {
        return input;
    }

    private dchar[] convertToDChar ( char[] input, ref dchar[] output )
    {
        try
        {
            output = Utf.toString32(input, output);
        }
        catch ( Exception e )
        {
            throw new NgramParserException(typeof(this).stringof ~ ".convertToDChar: " ~ e.msg);
        }

        return output;
    }


    /***************************************************************************

        Normalizes a character for ngram parsing. Ignored characters are
        converted to a single space, weird apostrophes are converted to ', and
        upper case characters are converted to lower case.

        Params:
            c = character to normalize

        Returns:
            string containing normalized character (will always be a slice into
            a constant string)

        Note: this methods returns a string (rather than a single dchar) as in
        some rare cases a single upper case character can convert to more than
        one lower case character.

        Note: the apostrophe normalization takes place for the benefit of
        stopwording in languages like english and french where many common words
        (ie stopwords) contain apostrophes which must be successfully matched.
        (For example: "don't", "isn't", etc in english.)

    ***************************************************************************/

    private dchar[] normalizeCharacter ( dchar c )
    {
        if ( TextUtil.contains(apostrophes, c) )
        {
            return "'"d;
        }
        else if ( stripCharacter(c) )
        {
            return " "d;
        }
        else if ( Unicode.isLetter(c) )
        {
            return unicodeToLower(c);
        }
        else
        {
            return [c];
        }
    }


    /***************************************************************************

        Checks whether a character should be ignored (replaced with a space).
        The check is based on a set of unicode categories, defining digits,
        punctuation, etc throughout the whole unicode range.

        Params:
            c = character to check

        Returns:
            true if the character should be stripped

    ***************************************************************************/

    private bool stripCharacter ( dchar c )
    {
        UnicodeData *ud;
        if ( (ud = getUnicodeData(c)) == null )
        {
            return false; // Must return false to not strip hiragana, hangul, etc
        }

        with ( UnicodeData.GeneralCategory ) switch ( ud.generalCategory )
        {
            case Nd: //  Number, Decimal Digit
            case Nl: //  Number, Letter
            case No: //  Number, Other
            case Pc: //  Punctuation, Connector
            case Pd: //  Punctuation, Dash
            case Ps: //  Punctuation, Open
            case Pe: //  Punctuation, Close
            case Pi: //  Punctuation, Initial quote (may behave like Ps or Pe depending on usage)
            case Pf: //  Punctuation, Final quote (may behave like Ps or Pe depending on usage)
            case Po: //  Punctuation, Other
            case Sm: //  Symbol, Math
            case Sc: //  Symbol, Currency
            case Sk: //  Symbol, Modifier
            case So: //  Symbol, Other
            case Zs: //  Separator, Space
            case Zl: //  Separator, Line
            case Zp: //  Separator, Paragraph
            case Cc: //  Other, Control
            case Cf: //  Other, Format
            case Cs: //  Other, Surrogate
            case Co: //  Other, Private Use
            case Cn: //  Other, Not Assigned (no characters in the file have this property)
            case SpecialMapping: // Special Bit for detection of specialMappings
                return true;

            default:
                return false;
        }

    }


    /***************************************************************************

        Converts a unicode character to lower case.

        (Adapted from tango.text.Unicode : toLower)

        Params:
            c = character to convert

        Returns:
            one or more characters representing the lower case version of the
            input character

    ***************************************************************************/

    private dchar[] unicodeToLower ( dchar c )
    {
        UnicodeData* d = getUnicodeData(c);
        if ( d !is null )
        {
            if ( ((*d).generalCategory & UnicodeData.GeneralCategory.SpecialMapping) )
            {
                SpecialCaseData* s = getSpecialCaseData(c);
                debug assert(s !is null);

                if( (*s).lowerCaseMapping !is null )
                {
                    return (*s).lowerCaseMapping;
                }
            }
            else
            {
                return [(*d).simpleLowerCaseMapping];
            }
        }
        else
        {
            return [c];
        }
    }


    /***************************************************************************

        Processes a list of texts, extracting ngrams from each.

        Params:
            ngrams = ngram set which will be filled with ngrams
            ngram_length = character length of ngrams
            texts = array of texts to process

    ***************************************************************************/

    private void getNGrams ( NGramSet ngrams, uint ngram_length, dchar[][] texts )
    {
        foreach ( text; texts )
        {
            getNGrams(ngrams, ngram_length, text);
        }
    }


    /***************************************************************************

        Processes a text, extracting ngrams from it.

        Params:
            ngrams = ngram set which will be filled with ngrams
            ngram_length = character length of ngrams
            text = text to process

    ***************************************************************************/

    private void getNGrams ( NGramSet ngrams, uint ngram_length, dchar[] text )
    {
        if ( text.length >= ngram_length )
        {
            uint i;
            uint max_steps = (text.length - ngram_length) + 1;

            do
            {
                auto ngram = text[i .. i + ngram_length];
                ngrams.addOccurrence(ngram);

                i++;
            }
            while ( i < max_steps );
        }
    }


    /***************************************************************************

        Checks whether a string contains only unicode whitespace characters.

        Params:
            text = text to check

        Returns:
            true if the string contains only unicode whitespace characters

    ***************************************************************************/

    private bool isWhitespace ( dchar[] text )
    {
        foreach ( c; text )
        {
            if ( !Unicode.isWhitespace(c) )
            {
                return false;
            }
        }
        return true;
    }
}



debug ( OceanUnitTest )
{
    import tango.core.Array;
    import tango.util.log.Trace;

    unittest
    {
        Trace.formatln("Running ocean.text.ling.ngram.NGramParser unittest");

        const char[] text = "hello this is a test text";
        const uint ngram_size = 3; // trigrams

        scope ngrams = new NGramSet();
        dchar[] normalized, normalized2, working;
        NGramParser.normalizeText(text, normalized, working);
        NGramParser.parseText(ngrams, ngram_size, normalized);

        // Check that all the ngrams found actually exist in the source text
        dchar[] unicode_text = Utf.toString32(text);
        foreach ( dchar[] ngram, uint freq; ngrams )
        {
            const size_t NotFound = text.length;
            assert(unicode_text.find(ngram) != NotFound, "NGramParser unittest: Error, ngram not found in source text.");
        }

        // Check that the source text is an exact match of itself
        assert(ngrams.distance(ngrams) == 0.0, "NGramParser unittest: Error, ngram set does not match itself.");

        // Check that a text with no ngrams in common is completely different
        const char[] text2 = "hail not too big";
        scope ngrams2 = new NGramSet();
        NGramParser.normalizeText(text, normalized2, working);
        NGramParser.parseText(ngrams, ngram_size, normalized2);
        assert(ngrams.distance(ngrams2) == 1.0, "NGramParser unittest: Error, ngram set comparison against a totally different ngram set didn't return total difference.");

        Trace.formatln("\nDone unittest\n");
    }
}

