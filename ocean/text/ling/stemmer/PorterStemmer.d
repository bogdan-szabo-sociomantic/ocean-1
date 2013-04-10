/*******************************************************************************

    PorterStemmer interface for the different language versions of the stemmer

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        May 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai

    --

    Description:

    --

    Usage:

    ---

    import ocean.text.ling.stemmer.PorterStemmer;

    auto stemmer = new PorterStemmer();
    char[] toStem = "agreed";
    char[] stemmed = stemmer.stem( toStem, 0, toStem.length - 1, "en" );

    char[] toStem = "käuflich"
    char[] stemmed = stemmer.stem( toStem, 0, toStem.length - 1, "de" );

    ---

    --

    Configuration parameter:

    --

    Requirements:

    --

    Additional information:

********************************************************************************/

module      text.ling.stemmer.PorterStemmer;



/*******************************************************************************

            imports

*******************************************************************************/

private     import      ocean.text.ling.stemmer.PorterStemmerEn,
                        ocean.text.ling.stemmer.PorterStemmerDe;



/*******************************************************************************

        PorterStemmer class

        @author  Lars Kirchhoff <lars.kirchhoff () sociomantic () com>
        @author  Thomas Nicolai <thomas.nicolai () sociomantic () com>
        @package ocean.text.stemmer
        @link    http://www.sociomantic.com

*******************************************************************************/

class PorterStemmer
{

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
     *     locale = language code for the stemmer that should be used
     *
     * Returns:
     */
    public char[] stem ( char[] word, int start, int word_length, char[] locale = "en" )
    {
        switch (locale)
        {
            case "de":
                auto stemmer = new PorterStemmerDe();
                return stemmer.stem(word, start, word_length);
                break;

            case "en":
                auto stemmer = new PorterStemmerEn();
                return stemmer.stem(word, start, word_length);
                break;
        }

        return null;
    }

} // PorterStemmer
