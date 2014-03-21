/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        November 2010: Initial release

    authors:        Gavin Norman, Don Clugston

    D binding for C functions & structures in libxml2.

*******************************************************************************/

module ocean.text.xml.c.LibXml2;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import tango.stdc.string;

private import tango.stdc.stdarg;



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

    extern int xmlLoadExtDtdDefaultValue;


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

    /***************************************************************************

        Signature of the function to use when there is an error and no
        parsing or validity context available

        Params:
            ctx = a parsing context
            msg = the message
            ... = the extra arguments of the varags to format the message

    ***************************************************************************/

    public alias void  function ( void * ctx, char * msg, ... ) xmlGenericErrorFuncPtr;

    /***************************************************************************

        Reset the handler and the error context for out of context error messages.

        The provided handler will be called for subsequent error
        messages while not parsing or validating. The handler will recieve ctx
        as the first argument.

        Params:
            ctx =  the new error handling context. For the default handler,
                   this is the FILE * to print error messages to.
            handler = the new handler, or null to use the default handler

    ***************************************************************************/

    void  xmlSetGenericErrorFunc ( void *ctx, xmlGenericErrorFuncPtr handler );
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
