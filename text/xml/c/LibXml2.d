/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        November 2010: Initial release
    
    authors:        Gavin Norman

    D binding for C functions & structures in libxml2.

*******************************************************************************/

module ocean.text.xml.c.LibXml2;



extern ( C )
{
    /***************************************************************************

        Char type definition used by all libxml2 functions.
    
    ***************************************************************************/

    public alias char xmlChar;


    /***************************************************************************

        Xml document struct & pointer type.
    
    ***************************************************************************/

    struct xmlDoc;

    public alias xmlDoc* xmlDocPtr;


    /***************************************************************************

        Set entity substitution on parsing (xslt sets this to 1).

    ***************************************************************************/

    int xmlSubstituteEntitiesDefault ( int val );


    /***************************************************************************

        Set loading of external entities (xslt sets this to 1).
    
    ***************************************************************************/

    int xmlLoadExtDtdDefaultValue;


    /***************************************************************************

        Parses an xml document from a string.
    
    ***************************************************************************/

    xmlDocPtr xmlParseDoc ( xmlChar* cur );


    /***************************************************************************

        Frees any resources allocated for an xml document.
    
    ***************************************************************************/

    void xmlFreeDoc ( xmlDocPtr cur );


    /***************************************************************************

        Cleans up any global xml parser allocations.
    
    ***************************************************************************/

    void xmlCleanupParser ( );
}

