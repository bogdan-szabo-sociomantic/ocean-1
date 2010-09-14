/*******************************************************************************

    Ngram parser for any given text

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        May 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai, Gavin Norman

    --

    TODO: update description, usage & unittest

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

        import ocean.text.ngram.NGramParser;
        import ocean.text.ngram.NGramSet;
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

        import ocean.text.ngram.NGramParser;
        import ocean.text.ngram.NGramAnalysis;
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

module      ocean.text.ngram.NGramParser;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.text.ling.ngram.NGramSet;

public import ocean.core.Exception: NgramParserException;

private import TextUtil = tango.text.Util: contains, substitute, replace, split, trim;

private import Unicode = tango.text.Unicode: toLower;

private import tango.core.Array;

private import ocean.core.Array;

private import tango.stdc.string: memmove;

private import tango.text.UnicodeData;

debug
{
	private import tango.util.log.Trace;
}



/*******************************************************************************

    NGramParser class.
    
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

        Characters which are ignored during ngram parsing.

    ***************************************************************************/

    public const dchar[] ignored_chars = "0123456789-\n;&(){}[]<>/\\|.,;:!@#$%^&*_-+=`~?\"\'";


	/***************************************************************************

	    Parses a text, and fills the passed ngrams set with the discovered
	    ngrams.
	
	    Params:
	        out_ngrams = ngrams set to be filled
	        ngram_length = character length of ngrams
	        text = text to parse
            words = list of arrays used to split the text into words

	***************************************************************************/

    public void parseText ( NGramSet out_ngrams, uint ngram_length, dchar[] text, ref dchar[][] words )
    {
        dchar [][] stopwords;
        parseText(out_ngrams, ngram_length, text, words, stopwords);
    }


	/***************************************************************************

	    Parses a text, and fills the passed ngrams set with the discovered
	    ngrams.
	
	    Params:
	        out_ngrams = ngrams set to be filled
	        ngram_length = character length of ngrams
	        text = text to parse
            words = list of arrays used to split the text into words
	        stopwords = list of words to ignore

        Throws:
            asserts that the passed text and stopwords array have both been
            normalized (see the normalizeText methods)

	***************************************************************************/

    public void parseText ( NGramSet out_ngrams, uint ngram_length, dchar[] text, ref dchar[][] words, dchar [][] stopwords )
    in
    {
        assert(isNormalized(text), typeof(this).stringof ~ ".parseText - text isn't normalized");
        assert(isNormalized(stopwords), typeof(this).stringof ~ ".parseText - stopwords aren't normalized");
    }
    body
    {
        splitWords(text, words, stopwords);

        out_ngrams.clear();
        getNGrams(out_ngrams, ngram_length, words);        
    }


    /***************************************************************************

        Checks whether a text has been normalized. Normalized text:

            1. Contains no ignored characters.
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
            if ( TextUtil.contains(ignored_chars, c) || Unicode.isUpper(c) )
            {
                return false;
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
        characters are removed, and upper case characters are converted to lower
        case.

        Template params:
            T = type of input array element

        Params:
            input = text to normalize
            output = output for normalized text
            working = required intermediary buffer
    
    ***************************************************************************/

    public void normalizeText ( T ) ( T[] input, ref dchar[] output, ref dchar[] working )
    {
        typeof(this).convertToDChar(input, working);

        size_t write_pos;

        output.length = working.length; // good guess

        foreach ( c; working )
        {
            dchar[] converted;

            // replace ignored characters with a space
            if ( TextUtil.contains(ignored_chars, c) )
            {
                converted = " "d;
            }
            else
            {
                // convert to lower case
                converted = unicodeToLower(c);
            }

            // make sure there's space in output
            auto need_space = write_pos + converted.length - output.length;
            if ( need_space > 0 )
            {
                output.length = output.length + need_space;
            }

            // write character(s)
            output[write_pos .. write_pos + converted.length] = converted[];
            write_pos += converted.length;
        }
    }


    /***************************************************************************

        Normalizes a list of texts for ngram parsing.
    
        Template params:
            T = type of input list array element
    
        Params:
            input = texts to normalize
            output = output for normalized texts
            working = required intermediary buffer
    
    ***************************************************************************/

    public void normalizeText ( T ) ( T[][] input, ref dchar[][] output, ref dchar[] working )
    {
        output.length = input.length;
    
        foreach ( i, str; input )
        {
            normalizeText(str, output[i]);
        }
    }


    /***************************************************************************

        Converts a string to dchar (unicode characters).
    
        Params:
            input = string to convert
            output = output for converted string
    
    ***************************************************************************/

    private void convertToDChar ( dchar[] input, ref dchar[] output )
    {
        output.copy(input);
    }
    
    private void convertToDChar ( char[] input, ref dchar[] output )
    {
        try
        {
            output = Utf.toString32(input, output);
        }
        catch (Exception e)
        {
            throw new NgramParserException(typeof(this).stringof ~ ".setText: " ~ e.msg);
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
        UnicodeData** d = (c in unicodeData);
        if ( d !is null )
        {
            if ( ((*d).generalCategory & UnicodeData.GeneralCategory.SpecialMapping) )
            {
                SpecialCaseData** s = (c in specialCaseData);
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

        Split text into separate words and stores them in the output words
        array. During the splitting of the words in the text, any words found
        which are in the (optional) stopwords array will not be added to the
        word list.

        Params:
            text = text to split
            words = output array of words (slices into text)
            stopwords = words to ignore
    
    ***************************************************************************/
    
    private void splitWords ( dchar[] text, ref dchar[][] words, dchar[][] stopwords )
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
        // TODO: word start/end modes

        uint i;
        
        // Slice through the word and add each ngram to the ngram array.
        if ( text.length >= ngram_length )
        {
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
		NGramParser.parseText(ngrams, ngram_size, text);

		// Check that all the ngrams found actually exist in the source text
		dchar[] unicode_text = Utf.toString32(text);
		foreach ( ngram, freq; ngrams )
		{
			const size_t NotFound = text.length;
			assert(unicode_text.find(ngram) != NotFound, "NGramParser unittest: Error, ngram not found in source text.");
		}

		// Check that the source text is an exact match of itself
		assert(ngrams.distance(ngrams) == 0.0, "NGramParser unittest: Error, ngram set does not match itself.");

		// Check that a text with no ngrams in common is completely different
		const char[] text2 = "hail not too big";
		scope ngrams2 = new NGramSet();
		NGramParser.parseText(ngrams, ngram_size, text);
		assert(ngrams.distance(ngrams2) == 1.0, "NGramParser unittest: Error, ngram set comparison against a totally different ngram set didn't return total difference.");

		Trace.formatln("\nDone unittest\n");
	}
}




/+
class Categorizer
{
    NGramSet training_docs;

    /* Train:

        For each document:
           1. Split into words (?) - does this step add anything apart from processing complexity?
           2. Split into ngrams
           3. Count frequency of each ngram

        For all docs:
           1. Calculate the IDF for each ngram in all docs
               inverse document frequency = number of docs in which ngram occurs / total number of docs
           2. Remove ngrams for which IDF > X
              (X = magic value, 0.5 perhaps? = an ngram which appears in less than half the docs
              = ngrams which significantly identify the doc)
     */

    void train ( char[][] files )
    {
        this.training_docs.length = files.length;
        foreach ( i, file; files )
        {
            char[] file_content;
            // load file content into file_content
            this.training_docs[i].parse(file_content);
        }

        // Select the most significant ngrams in each training doc
        // Remove non-significant ngrams
    }
    
    uint categorize ( char[] text )
    {
        foreach ( training_doc; this.training_docs )
        {
            
        }
    }
}
+/

