/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        November 2010: Initial release
    
    authors:        Gavin Norman

    D binding for C functions & structures in libxml2.

*******************************************************************************/

module ocean.text.xml.c.LibXml2;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import tango.stdc.string;



/*******************************************************************************

    D bindings for C library

*******************************************************************************/

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

        Initialises the xml parser
    
    ***************************************************************************/
    
    void xmlInitParser ( );
    
    
    /***************************************************************************
    
        Cleans up any global xml parser allocations.
    
    ***************************************************************************/
    
    void xmlCleanupParser ( );


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

        Xml error level enum
    
    ***************************************************************************/

    enum xmlErrorLevel
    {
        XML_ERR_NONE = 0,
        XML_ERR_WARNING = 1,    // A simple warning
        XML_ERR_ERROR = 2,      // A recoverable error
        XML_ERR_FATAL = 3       // A fatal error
    }


    /***************************************************************************

        Xml error struct & pointer type
    
    ***************************************************************************/

    struct xmlError
    {
        int domain;             // What part of the library raised this error
        int code;               // The error code, e.g. an xmlParserError
        char* message;          // human-readable informative error messag
        xmlErrorLevel level;    // how consequent is the error
        char* file;             // the filename
        int line;               // the line number if available
        char* str1;             // extra string information
        char* str2;             // extra string information
        char* str3;             // extra string information
        int int1;               // extra number information
        int int2;               // column number of the error or 0 if N/A
        void* ctxt;             // the parser context if available
        void* node;             // the node in the tree
    }

    public alias xmlError* xmlErrorPtr;


    /***************************************************************************

        Gets a pointer to the error struct for the last command
    
    ***************************************************************************/

    xmlErrorPtr xmlGetLastError ( );
}



/*******************************************************************************

    Helper function to format a D string with an error report.

    Params:
        err = libxml2 error structure
        string = output string

*******************************************************************************/

public void formatXmlErrorString ( xmlErrorPtr err, ref char[] string )
{
    char[] dstr ( char* cstr )
    {
        if ( cstr )
        {
            return cstr[0..strlen(cstr)];
        }
        else
        {
            return "";
        }
    }

    string.concat("Xml parsing error: ", dstr(err.message));
}

