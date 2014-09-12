/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        November 2010: Initial release

    authors:        Gavin Norman

    D binding for C functions & structures in libxslt.

*******************************************************************************/

module ocean.text.xml.c.LibXslt;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.text.xml.c.LibXml2;

private import tango.stdc.stdio;



extern ( C )
{
    /***************************************************************************

        Xslt stylesheet struct & pointer type.

    ***************************************************************************/

    struct xsltStylesheet;

    public alias xsltStylesheet* xsltStylesheetPtr;


    /***************************************************************************

        Read a stylesheet from a parsed xml document (see
        ocean.text.xml.c.LibXml2.xmlParseDoc).

    ***************************************************************************/

    xsltStylesheetPtr xsltParseStylesheetDoc ( xmlDocPtr doc );


    /***************************************************************************

        Read a stylesheet from a file.

    ***************************************************************************/

    xsltStylesheetPtr xsltParseStylesheetFile ( xmlChar* filename );


    /***************************************************************************

        Applies a stylesheet to a parsed xml doc.

    ***************************************************************************/

    xmlDocPtr xsltApplyStylesheet ( xsltStylesheetPtr style, xmlDocPtr doc, char** params = null );


    /***************************************************************************

        Saves a processed xml doc to a file. TODO (if we need it).

    ***************************************************************************/

//    int xsltSaveResultToFile ( FILE* file, xmlDocPtr result, xsltStylesheetPtr style );


    /***************************************************************************

        Saves a processed xml doc to a string. A new string is malloced and the
        provided pointer is set to point to the resulting chunk of memory.

    ***************************************************************************/

    int xsltSaveResultToString ( xmlChar** doc_txt_ptr, int* doc_txt_len, xmlDocPtr result, xsltStylesheetPtr style );


    /***************************************************************************

        Frees any resources allocated for a stylesheet.

    ***************************************************************************/

    void xsltFreeStylesheet ( xsltStylesheetPtr style );


    /***************************************************************************

        Cleans up any global xslt allocations.

    ***************************************************************************/

    void xsltCleanupGlobals ( );
}

