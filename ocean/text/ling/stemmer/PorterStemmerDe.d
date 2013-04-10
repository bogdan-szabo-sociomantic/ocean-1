/*******************************************************************************

    Simple PorterStemmer for german words

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        May 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai

    --

    Description:

    --

    Usage:

    --

    Configuration parameter:

    --

    Requirements:

    --

    Additional information:

    http://snowball.tartarus.org/algorithms/german/stemmer.html
    http://snowball.tartarus.org/texts/r1r2.html
    http://snowball.tartarus.org/texts/glossary.html

********************************************************************************/

module      core.text.ling.stemmer.PorterStemmerDe;



/*******************************************************************************

            imports

*******************************************************************************/

private     import      TextUtil = tango.text.Util : containsPattern, split, substitute;

private     import      tango.io.Stdout;



class PorterStemmerDe
{
    /**
     * vowels chars
     */
    const       char[]      vowels          = ['a', 'e', 'i', 'o', 'u', 'y', 'ä', 'ö', 'ü'];

    /**
     * Consonants for a valid s-ending of a word
     */
    const       char[]      valid_s_end     = ['b', 'd', 'f', 'g', 'h', 'k', 'l', 'm', 'n', 'r', 't'];

    /**
     * Consonants for a valid st-ending of a word
     */
    const       char[]      valid_st_end    = ['b', 'd', 'f', 'g', 'h', 'k', 'l', 'm', 'n', 't'];


    const       char[][]    suffixes_1      = ["ern", "er", "es", "em", "en", "e"];

    const       char[][]    suffixes_2      = ["est", "en", "er"];

    const       char[][]    d_suffixes      = ["isch", "heit", "lich", "keit", "end", "ung", "ig", "ik"];

    /**
     * Buffer for original word
     */
    private     char[]      buffer;

    /**
     * Current length of the buffer
     */
    private     uint        buffer_len;

    /**
     * R1 position
     */
    private     uint        r1;

    /**
     * R2 position
     */
    private     uint        r2;



    /**
     * Constructor
     */
    public this () {}



    /**
     * Destructor
     */
    public ~this() {}



    /**
     * Start stemming
     *
     * Params:
     *     word = string that contains the word to stem
     *     start =
     *     word_length = length of the word
     * Returns:
     */
    public char[] stem ( char[] word, int start, int word_length )
    {
        this.buffer = word;

        if (word_length < 2)
        {
            return this.buffer;
        }

        this._step0;
        this._step1ab();
        this._step2ab();
        this._step3();

        return this.buffer;
    }



    /**
     * Prepare word string
     *    1. replace ß with ss
     *    2. replace accent chars
     *    3. find R1 and R2 regions
     *    4. set buffer_len
     */
    private void _step0 ()
    {
        this.buffer = TextUtil.substitute(this.buffer.dup, "ß", "ss");
        this._replaceAccents();

        // Buffer length is set here because accent characters have
        // and need to be removed before actual buffer length can be
        // set
        this.buffer_len = this.buffer.length;

        this._markRegions();
    }



    /**
     * Remove first stage of suffixes
     *
     */
    private void _step1ab ()
    {
        /**
         * Check for suffix 1 types (a)
         */
        this._removeSuffix(this.suffixes_1);

        /**
         * Check for a valid s ending (b)
         */
        if (this._hasValidSEnding())
        {
            this.buffer_len--;
            this.buffer = this.buffer[0 .. this.buffer_len];
        }

        // Stdout.formatln(this.buffer);
    }



    /**
     * Remove second stage of suffixes
     *
     */
    private void _step2ab ()
    {
        /**
         * remove suffix type 2 (a)
         */
        this._removeSuffix(this.suffixes_2);

        /**
         * Check for a valid st ending (b)
         */
        if (this._hasValidStEnding())
        {
            if ((this.buffer_len - 2) > 3)
            {
                this.buffer_len -= 2;
                this.buffer = this.buffer[0 .. this.buffer_len];
            }
        }

        // Stdout.formatln(this.buffer);
    }



    /**
     * Remove d-suffixes
     *
     */
    private void _step3()
    {
        uint    s_len, start_suffix;
        char[]  d_suffix;

        d_suffix = this._hasDSuffix();

        if (d_suffix)
        {
            s_len           = d_suffix.length;
            start_suffix    = this.buffer_len - s_len;

            if (d_suffix == "end" || d_suffix == "ung")
            {
                if (start_suffix >= this.r2)
                {
                    this.buffer_len = start_suffix;
                }
            }


            if (d_suffix == "ig" || d_suffix == "ik" || d_suffix ==  "isch")
            {
                if (start_suffix >= this.r2)
                {
                    if (this.buffer[start_suffix-1] != 'e')
                    {
                        this.buffer_len = start_suffix;
                    }
                }
            }

            if (d_suffix == "lich" || d_suffix == "heit")
            {
                if (start_suffix >= this.r2)
                {
                    this.buffer_len = start_suffix;
                }

                if (this.buffer[start_suffix-2 .. start_suffix] == "en" ||
                    this.buffer[start_suffix-2 .. start_suffix] == "er")
                {
                    if (start_suffix >= this.r1)
                    {
                        this.buffer_len = start_suffix;
                    }
                }
            }

            if (d_suffix == "keit")
            {
                if (start_suffix >= this.r2)
                {
                    this.buffer_len = start_suffix;
                }

                if (this.buffer[start_suffix-4 .. start_suffix] == "lich")
                {
                    if (start_suffix >= this.r2)
                    {
                        this.buffer_len = start_suffix;
                    }
                }

                if (this.buffer[start_suffix-2 .. start_suffix] == "ig")
                {
                    if (start_suffix >= this.r2)
                    {
                        this.buffer_len = start_suffix;
                    }
                }
            }

            this.buffer = this.buffer[0 .. this.buffer_len];
        }

        // Stdout.formatln(this.buffer);
    }



    /**
     * Replace german accent vowels
     *
     */
    private void _replaceAccents()
    {
        this.buffer = TextUtil.substitute(this.buffer.dup, "ä", "a");
        this.buffer = TextUtil.substitute(this.buffer.dup, "ö", "o");
        this.buffer = TextUtil.substitute(this.buffer.dup, "ü", "u");

        // Stdout.formatln(this.buffer);
    }




    /**
     * Removes a suffix (type 1 or 2) if it is found at the end of
     * the word.
     *
     * Params:
     *     defined_suffixes = array with the defined suffixes
     */
    private void _removeSuffix ( char[][] defined_suffixes )
    {
        uint    s_len, start_suffix;
        char[]  word_end;

        foreach (suffix; defined_suffixes)
        {
            s_len           = suffix.length;
            start_suffix    = this.buffer_len - s_len;
            word_end        = this.buffer[start_suffix .. $];

            if (word_end == suffix)
            {
                if (start_suffix >= this.r1)
                {
                    this.buffer_len = start_suffix;
                    this.buffer = this.buffer[0 .. this.buffer_len];
                    break;
                }
            }
        }
    }




    /**
     * Returns d-suffix if any is found in the word
     *
     * Returns:
     *     string with the d-suffix if found.
     */
    private char[] _hasDSuffix ()
    {
        uint    s_len, start_suffix;
        char[]  word_end;

        foreach (suffix; this.d_suffixes)
        {
            s_len           = suffix.length;

            if (s_len < this.buffer_len)
            {
                start_suffix    = this.buffer_len-s_len;
                word_end        = this.buffer[start_suffix .. $];

                if (word_end == suffix)
                {
                    return suffix;
                }
            }
        }

        return null;
    }



    /**
     * Check if word has a valid s-ending
     *
     * Returns:
     *    true, if a valid s-ending is found
     */
    private bool _hasValidSEnding ()
    {
        char ending       = this.buffer[this.buffer_len - 1];
        char pre_ending   = this.buffer[this.buffer_len - 2];

        if (ending == 's')
        {
            foreach (end; this.valid_s_end)
            {
                if (pre_ending == end)
                {
                    return true;
                }
            }
        }
        return false;
    }



    /**
     * Check if word has a valid st-ending
     *
     * Returns:
     *    true, if a valid st-ending is found
     */
    private bool _hasValidStEnding ()
    {
        char[]  ending      = this.buffer[this.buffer_len - 2 .. $];
        char    pre_ending  = this.buffer[this.buffer_len - 3];

        if (ending == "st")
        {
            foreach (end; this.valid_st_end)
            {
                if (pre_ending == end)
                {
                    return true;
                }
            }
        }
        return false;
    }



    /**
     * Find R1 and R2 region
     *
     * http://snowball.tartarus.org/texts/r1r2.html
     */
    private void _markRegions ()
    {
        /**
         * set r1 and r2 to maximum
         */
        this.r1 = this.buffer_len;
        this.r2 = this.buffer_len;

        /**
         * look for R1
         */
        for (uint i=0; i<this.buffer_len; i++)
        {
            if (i!=0)
            {
                if (!(this._isVowel(i)) && this._isVowel(i-1))
                {
                    this.r1 = i + 1;

                    /**
                     * Region before r1 needs to have at least 3 letters
                     */
                    if (this.r1>=3)
                    {
                        break;
                    }
                }
            }
        }

        /**
         * Look for R2
         */
        for (uint j=0; j<(this.buffer_len-this.r1); j++)
        {
            if (j!=0)
            {
                if(!(this._isVowel(j+this.r1)) && this._isVowel(j+this.r1-1))
                {
                    this.r2 = j + this.r1 + 1;
                    break;
                }
            }
        }

        // Stdout.formatln("{} {}" , this.r1, this.r2);
    }



    /**
     * Returns true, if char in buffer is a vowel
     */
    private bool _isVowel ( uint pos )
    {
        foreach (vowel; this.vowels)
        {
            if (this.buffer[pos] == vowel)
            {
                return true;
            }
        }

        return false;
    }

} // PorterStemmerDe
