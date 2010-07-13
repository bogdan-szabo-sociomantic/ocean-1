/*******************************************************************************

    Ngram parser for any given text

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        May 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai, Gavin Norman

    --

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

private		import ocean.text.ling.ngram.NGramSet;

public      import ocean.core.Exception: NgramParserException;


private     import      TextUtil    = tango.text.Util:          contains, substitute, replace, split, trim;
private     import      Utf         = tango.text.convert.Utf:   toString32;
private     import      Unicode     = tango.text.Unicode:       toLower;
private		import		tango.core.Array;

debug
{
	private import tango.util.log.Trace;
}



/*******************************************************************************

    NGramParser class.
    
    Template parameter:
    	Char = character type used internally to store ngrams, texts & stopwords

*******************************************************************************/

public class NGramParser  ( Char )
{
	/***************************************************************************
	
		Check that the template parameter is a character type.
	
	***************************************************************************/

	static assert ( is(Char == dchar) || is(Char == wchar) || is(Char == char),
			"NGramParser: template paramater Char must be one of: {char, wchar, dchar}" );


    /**
     * Ngram map alias
     */
    public alias NGramSet!(Char) NGrams;
    public alias NGrams.NGramArray NGramsArray;

    /**
     * Map with the ngrams of the text and the appropriate frequency
     */
    private     NGrams                ngram_map;
    
    /**
     * Text that should be analysed 
     */
    private     Char[]                 text;
    
    /**
     * Internal array of all words in the text (slices into this.text)
     */
    private     Char[][]               word_token;

    /**
     * Internal array with a list of stop words
     */
    public     Char[][]               stopwords;

    /**
     * Default ngram length
     */
    private     uint                    ngram_len           = 4;



    /**
     * Constructor
     *
     */
    public this ()
    {
    	this.ngram_map = new NGrams();
    }

    /**
     * Parse text and generate the according ngram map
     *
     */
    public void parse ( )
    {
    	this.parse(this.ngram_map);
    }

    /**
     * Parse text and generate the according ngram map
     *
     * Params:
     * 		ngrams = ngrams set which the found ngrams will be added to
     */

    public void parse ( NGrams ngrams )
    {
        /**
         * Removes all unnecessary chars from the given text in order to 
         * create good word matching ngrams.
         */
        this._removeUnwantedChars();

        /**
         * Split the text in separate words by using white spaces as a 
         * delimiter.  
         */
        this._splitWords();

        /**
         * Generate the ngram for each word and count the occurrence of 
         * each found ngram.
         */
        this._createNGramMap(ngrams);        
    }



    /**
     * Set text to analyze
     * 
     * Params:
     *     text = text to analyze
     */
    public void setText ( char[] text )
    {
        try
        {
        	static if ( is(Char == dchar) )
        	{
                this.text = Utf.toString32(text).dup;
        	}
        	else if ( is(Char == wchar) )
        	{
        		this.text = Utf.toString16(text).dup;
        	}
        	else if ( is(Char == char) )
        	{
        		this.text = text.dup;
        	}

            this.text = Unicode.toLower(this.text);
        }
        catch (Exception e)
        {
            throw new NgramParserException("setText: " ~ e.msg);
        }  
    }



    /**
     * Set text to analyze
     * 
     * Params:
     *     text = text to analyze
     */
    public void setText ( Char[] text )
    {
        try
        {
            this.text = Unicode.toLower(text.dup);
        }
        catch (Exception e)
        {
            throw new NgramParserException("setText: " ~ e.msg);
        }
    }



    /**
     * Return the text
     * 
     * Returns:
     *     text
     */
    public Char[] getText ()
    {
        return this.text;
    }
    
        
    
    /**
     * Set the length of ngram  
     * 
     * Params:
     *     ngram_len = length of the ngrams that should be returned
     */
    public void setNGramLength ( uint ngram_len )
    {
        this.ngram_len = ngram_len;
    }



    /**
     * Returns the ngram length
     * 
     * Returns:
     *     returns the ngram length that should be used to generate ngrams 
     */
    public uint getNGramLength ()
    {
        return this.ngram_len;
    }
    
    
    
    /**
     * Sets the stop word array. The passed strings are copied into the
     * this.stopwords array, and are converted to lower case.
     * 
     * Params:
     *     stopwords = array with stop words
     */
    public void setStopWords ( Char[][] stopwords )
    {
        foreach (stopword; stopwords)
        {
            try
            {
                this.stopwords ~= Unicode.toLower(stopword);
            }
            catch (Exception e)
            {
                throw new NgramParserException("setStopWords: " ~ e.msg);
            }  
        }
    }



    /**
     * Sets the stop word array. The passed strings are copied into the
     * this.stopwords array, and are converted to lower case.
     * 
     * Params:
     *     stopwords = array with stop words
     */
    public void setStopWords ( char[][] stopwords )
    {
        foreach (ref stopword; stopwords)
        {
            try 
            {
                this.stopwords ~= Utf.toString32(Unicode.toLower(stopword));
            }
            catch (Exception e)
            {
                throw new NgramParserException("setStopWords: " ~ e.msg);
            }            
        }
    }
        
       
    
    /**
     * Gets all the ngrams which have been analysed from a text.
     * 
     * Params:
     *     map = associative array to copy ngrams into
     */

    public void getNGramMap ( out NGramsArray map )
    {
    	this.getNGramMap(map, this.ngram_map.length);
    }

    
    
    /**
     * Gets the specified number of ngrams which have been analysed from a text.
     * The ngrams are copied, starting with the highest frequency, up to the 
     * specified number.
     * 
     * Params:
     *     map = associative array to copy ngrams into
     *     max_items = number of ngrams to copy
     */

    public void getNGramMap ( out NGramsArray map, uint max_items )
    {
    	if ( this.ngram_map.length > 0 )
        {
        	this.ngram_map.copyHighest(map, max_items);
        }
    }



    /**
     * Gets all the ngrams which have been analysed from a text.
     * 
     * Params:
     *     map = NGramAnalysis!(Char) object to copy ngrams into
     */

    public void getNGramMap ( NGrams map )
    {
    	this.getNGramMap(map, this.ngram_map.length);
    }

    
    
    /**
     * Gets the specified number of ngrams which have been analysed from a text.
     * The ngrams are copied, starting with the highest frequency, up to the 
     * specified number.
     * 
     * Params:
     *     map = NGramAnalysis!(Char) object to copy ngrams into
     *     max_items = number of ngrams to copy
     */

    public void getNGramMap ( NGrams map, uint max_items )
    {
    	map.clear();

    	if ( this.ngram_map.length > 0 )
        {
        	this.ngram_map.copyHighest(map, max_items);
        }
    }



    /**
     * Gets an iterator over the highest frequency n ngrams in the set. The
     * returned ngrams are *not* copied, an iterator struct is returned, which
     * enables foreach iteration over the ngrams.
     * 
     * Params:
     *     max_items = number of ngrams to return
     *      
     * Returns:
     * 		iterator over the highest frequency ngrams in the set
     */

    public NGrams.Iterator getNGramMap ( uint max_items )
    {
    	return this.ngram_map.getHighest(max_items);
    }



    /**
     * Gets the ngram analysis of the last text parsed.
     * 
     * Returns:
     * 		the ngram analysis of the last text parsed
     */

    public NGrams getNGramMap ( )
    {
    	return this.ngram_map;
    }



    /**************************************************************************
    
	    static functions
	
	**************************************************************************/ 

    /**
     * Static instance used by static functions
     */

    protected static typeof(this) instance;



    /**
     * Parses a text, and fills the passed ngrams set with the discovered
     * ngrams.
     * 
     * Params:
     *     out_ngrams = ngrams set to be filled
     *     ngram_length = character length of ngrams
     *     text = text to parse
     */

    public static void parseText ( T ) ( NGrams out_ngrams, uint ngram_length, T[] text )
    {
    	T[][] stopwords;
    	typeof(this).parseText(out_ngrams, ngram_length, text, stopwords);
    }



    /**
     * Parses a text, and fills the passed ngrams set with the discovered
     * ngrams.
     * 
     * Params:
     *     out_ngrams = ngrams set to be filled
     *     ngram_length = character length of ngrams
     *     text = text to parse
     *     stopwords = list of words to ignore
     */

    public static void parseText ( T, S ) ( NGrams out_ngrams, uint ngram_length, T[] text, S[][] stopwords )
    {
    	if ( !typeof(this).instance )
    	{
    		typeof(this).instance = new typeof(this)();
    	}

    	typeof(this).instance.setText(text);
    	typeof(this).instance.setStopWords(stopwords);
    	typeof(this).instance.setNGramLength(ngram_length);
    	typeof(this).instance.parse(out_ngrams);
    }



    /**************************************************************************
    
        private functions
    
    **************************************************************************/ 
        
    /**
     * Create ngram map from the words in the text and saves the ngram in the 
     * global ngram map. for each occurence in of a ngram the count is 
     * incremented for that ngram in the global ngram map.
     */

    private void _createNGramMap ( NGrams ngrams )
    {
    	Char[][] word_n_grams;

    	ngrams.clear();

    	/** 
         * Iterate through all words in the text.
         */
        foreach (word; this.word_token)
        {
        	/**
             * Get the ngrams for the word
             */
            word_n_grams = this._getWordNGrams(word);

            /**
             * Add ngrams to the ngram map and count their occurrence
             */
            foreach (n_gram; word_n_grams)
            {   
            	ngrams.incrementCount(n_gram);
            }
        }
    }



    /**
     * Creates all possible ngrams for a word
     *  
     * Params:
     *     word = word
     *      
     * Returns:
     *     list of ngrams (slices into the passed word)
     */
    private Char[][] _getWordNGrams ( Char[] word ) 
    {
        uint       max_steps, i = 0;
        Char[][]   ngrams;
        
        /**
         * Slice through the word and add each ngram to the ngram array.
         */
        if (word.length >= this.ngram_len)
        {   
            max_steps = word.length - this.ngram_len;
            
            do 
            {                   
                ngrams ~= word[i .. i + this.ngram_len];
                i++;
            }
            while (i<max_steps)
        }    

        return ngrams;        
    }
        
    
    
    /**
     * Removes all unwanted characters from the text,
     * e.g. ; ,& , etc.
     */
    private void _removeUnwantedChars ( )
    {
    	const Char[] unwanted = "0123456789-\n;&(){}[]<>/\\|.,;:!@#$%^&*_-+=`~?\"\'";

        foreach (ref c; this.text)
        {
        	if ( TextUtil.contains(unwanted, c) )
        	{
                 c = ' ';
        	}
        }
    }



    /**
     * Split text in separate words and stores them in global word token array.
     * During the splitting of the words in the text, any words found which are
     * in the stopwords array will not be added to the word list.
     */

    private void _splitWords ()
    {
    	this.word_token.length = 0;

    	foreach(word; TextUtil.split(this.text, cast(Char[])" "))
        {
    		auto NotStopWord = this.stopwords.length;

    		if (word != "" && this.stopwords.find(word) == NotStopWord )
            {
                this.word_token ~= TextUtil.trim(word);
            }
        }
    }
} // NGramParser

