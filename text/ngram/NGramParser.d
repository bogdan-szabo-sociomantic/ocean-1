/*******************************************************************************

    Ngram parser for any given text

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        May 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai

    --
    
    Description:
    
    The ngram parser creates all ngrams for a given text and returns the ngrams 
    together with the frequency of each ngram within the document.
      
    -- 
    
    Usage:
    
    ---
    
        import  ocean.text.ngram.NGramParser;
        
        // Text that should be parsed.
        char[] text = "Raum vs aufmerksamkeitsbezogene Therapie ...";
        
        // Number of ngrams that should be returned. The ngram map is sorted 
        // by the ngram count. ngrams with the highest count are on top.
        // ngrams with the highest number will be returned first.
        uint max_number_ngrams   = 200; 
        
        auto parser = new NGramParser();
        
        parser.setText(text);    
        parser.parse();
        
        auto map = parser.getNGramMap(max_number_ngrams);
        
        foreach (ngram, occurrence; map)
        {
            Stdout.formatln("{} {}", ngram, occurrence);         
        }
        
    ---
    
    --
    
    Configuration parameter:
     
    --

    Requirements:
    
    --

    Additional information: 

********************************************************************************/

module      ocean.text.ngram.NGramParser;



/*******************************************************************************

            imports

*******************************************************************************/

private     import      TextUtil    = tango.text.Util:          contains, substitute, replace, split, trim;
private     import      Utf         = tango.text.convert.Utf:   toString32;
private     import      Unicode     = tango.text.Unicode:       toLower;

private     import      ocean.text.TextTrimData;



/*******************************************************************************

        NGramParser class
        
        @author  Lars Kirchhoff <lars.kirchhoff () sociomantic () com>
        @author  Thomas Nicolai <thomas.nicolai () sociomantic () com>        
        @package ocean.text.ngram
        @link    http://www.sociomantic.com           

*******************************************************************************/

public class NGramParser  
{
    
    /**
     * Ngram map alias
     */
    alias       uint[dchar[]]           NGramMap;
    
    /**
     * HashMap with the ngrams of the text and the appropriate 
     */
    private     NGramMap                ngram_map;
    
    /**
     * Text that should be analysed 
     */
    private     dchar[]                 text;
    
    /**
     * Internal array of all words in the text 
     */
    //private     HashSet!(dchar[])       word_token;
    private     dchar[][]               word_token;
    
    /**
     * Internal array with a list of stop words
     */
    private     dchar[][]               stopwords;
    
    /**
     * Default ngram length
     */
    private     uint                    ngram_len           = 4;
    
    
    
    /**
     * Constructor
     *
     */
    public this () {}

    
        
    /**
     * Parse text and generate the according ngram map
     *
     */
    public void parse ()
    {
        this.ngram_map = this.ngram_map.init;
        
        /*
         *  Needs to be instantiated again, because clear and reset lead to
         *  segmentation fault. 
         */
        this.word_token = this.word_token.init;
        
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
         * Removes all unnecessary stop words from the word token list 
         */
        //this._removeStopWords();
        
        /**
         * Generate the ngram for each word and count the occurrence of 
         * each found ngram.
         */
        this._createNGramMap();        
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
            this.text = Unicode.toLower(Utf.toString32(text.dup));
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
    public void setText ( dchar[] text )
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
    public dchar[] getText ()
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
     * Sets the stop word array. As the list can become quite huge it is passed
     * as reference. So be aware that the stop words list could be change in 
     * runtime.
     * 
     * Params:
     *     stopwords = array with stop words  
     */
    public void setStopWords ( inout dchar[][] stopwords )
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
     * Sets the stop word array. As the list can become quite huge it is passed
     * as reference. So be aware that the stop words list could be change in 
     * runtime.
     * 
     * Params:
     *     stopwords = array with stop words  
     */
    public void setStopWords ( inout char[][] stopwords )
    {
        foreach (stopword; stopwords)
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
     * Returns the ngram map, which includes all ngrams of the text together
     * with the frequency of their occurence. Only these ngrams with the 
     * highest count will be returned. If the maximum number is higher as 
     * the number of ngrams in the text, then all ngrams are returned 
     * 
     * Params:
     *     max_items = number of items that should be returned
     * 
     * Returns:
     *     ngram map (uint[dchar[]] = score[ngram])   
     */    
    public void getNGramMap ( inout uint[dchar[]] sorted_map, uint max_items = 200 )
    {   
        sorted_map = null;
        
        if (this.ngram_map.length > 0)
        {   
            this._sort(sorted_map, max_items);
        }
        
        return null;
    }
    
    
    
    
    /**************************************************************************
    
        private functions
    
    **************************************************************************/ 
        
    /**
     * Create ngram map from the words in the text and saves the ngram in the 
     * global ngram map. for each occurence in of a ngram the count is 
     * incremented for that ngram in the global ngram map.
     */
    private void _createNGramMap ()
    {   
        dchar[][]   word_n_grams;
      
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
                this.ngram_map[n_gram]++;                
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
     *     list of ngrams
     */
    private dchar[][] _getWordNGrams ( dchar[] word ) 
    {
        uint        word_len, max_steps, i = 0;
        dchar[][]   ngrams;        
        
        /**
         * Get the word length after UTF converting, because otherwise we run 
         * out of the ArrayIndex.
         */
        word_len = word.length;
        
        /**
         * Slice through the word and add each ngram to the ngram array.
         */        
        if (word_len >= this.ngram_len)
        {   
            max_steps = word_len - this.ngram_len;
            
            do 
            {                   
                ngrams ~= word[i .. i + this.ngram_len].dup;
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
    private void _removeUnwantedChars ()
    {
        dchar[] digits = "0123456789";
        dchar   hyphen = '-';
        dchar   linebr = '\n';
        
        foreach (ref s; this.text)
        {
            if ( TextUtil.contains(TextTrimData.CHARS_2STRIP, s) || 
                 TextUtil.contains(digits, s) || 
                 s == hyphen || s == linebr 
                 )
                 s = ' ';
        }
    }
    
 
    
    /**
     * Split text in separat words and stores them in global word token array.      
     */
    private void _splitWords ()
    {   
        foreach(word; TextUtil.split(this.text, cast(dchar[])" "))
        {
            if (word != "")
            {
                this.word_token ~= TextUtil.trim(word).dup;
            }
        }
    }
    
    
    
    /**
     * Remove stop words from the input text before ngram generation 
     *
     * TODO: Performs poorly and is a possible memory leak
     */
    private void _removeStopWords()
    {           
        if (this.stopwords !is null)
        {
            foreach (ref s; this.word_token)
            {
                if (this.stopwords.contains(s))
                {   
                    s = null;
                }
            }
        }
    }
    
    
    
    /**
     * Sorts the ngram map by count value and returns only the items with the 
     * highest count value until max_items limit is reached.  
     * 
     * Params:
     *     ngram_map = ngram map with ngrams and their count 
     *     max_items = number of items that should be returned at maximum
     *      
     * Returns:
     *     a ngram map with a maximum number of items defined by max_items 
     */
    private void _sort ( inout uint[dchar[]] sorted_map , uint max_items = 200 )    
    {
        dchar[]     next_ngram;
        uint        max_ngram_count, i;
        
        if (this.ngram_map.length > 0)
        {
            while (i < max_items)
            {            
                next_ngram      = "";
                max_ngram_count = 0;
                i++;
                
                foreach (ngram, count; this.ngram_map)
                {   
                    if (max_ngram_count < count)
                    {             
                        next_ngram = ngram;
                        max_ngram_count = count;
                    }
                }
               
                sorted_map[next_ngram] = max_ngram_count;               
                this.ngram_map.remove(next_ngram);
            }        
        }
    }
    
} // NgramParser



/*******************************************************************************
    
    NgramParserException        

*******************************************************************************/

class NgramParserException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }

    private:
        static void opCall(char[] msg) { throw new NgramParserException(msg); }

} // NgramParserException