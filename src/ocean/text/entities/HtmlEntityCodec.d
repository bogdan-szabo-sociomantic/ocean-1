/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    author:         Gavin Norman

    Html entity en/decoder.

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

module ocean.text.entities.HtmlEntityCodec;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.text.entities.model.MarkupEntityCodec;

import ocean.text.entities.HtmlEntitySet;

import ocean.text.util.StringReplace;



/*******************************************************************************

    Class to en/decode html entities.

*******************************************************************************/

public alias MarkupEntityCodec!(HtmlEntitySet) HtmlEntityCodec;

