/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        November 2010: Initial release
    
    authors:        Gavin Norman

    Xslt (Extensible Stylesheet Language Transformations) - enables
    transformation of xml documents into other formats (including differently
    structured xml documents) using a stylsheet language.
    
    See http://en.wikipedia.org/wiki/XSLT

    This module uses the C library libxslt internally, which requires linking
    with:

        -L/usr/lib/libxml2.so.2
        -L/usr/lib/libxslt.so.1

*******************************************************************************/

module ocean.text.xml.Xslt;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import ocean.text.xml.c.LibXml2,
               ocean.text.xml.c.LibXslt;

private import tango.stdc.stdio;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Xslt class

*******************************************************************************/

class Xslt
{
    /***************************************************************************

        Xml structure of original text

    ***************************************************************************/

    private xmlDocPtr original_xml;


    /***************************************************************************

        Xml structure of stylesheet text
    
    ***************************************************************************/

    private xmlDocPtr stylesheet_xml;

    
    /***************************************************************************

        Xml structure of transformed text
    
    ***************************************************************************/

    private xmlDocPtr transformed_xml;

    
    /***************************************************************************

        Transformation stylesheet
    
    ***************************************************************************/

    private xsltStylesheetPtr stylesheet;


    /***************************************************************************

        Constructor. Initialises the required settings of libxml2.
    
    ***************************************************************************/

    public this ( )
    {
        xmlSubstituteEntitiesDefault(1);
        xmlLoadExtDtdDefaultValue = 1;
    }
    

    /***************************************************************************

        Destructor. Frees objects allocated by the C libraries.
    
    ***************************************************************************/

    ~this ( )
    {
        xsltFreeStylesheet(this.stylesheet);
        xmlFreeDoc(this.stylesheet_xml);
        xmlFreeDoc(this.original_xml);
        xmlFreeDoc(this.transformed_xml);
        xsltCleanupGlobals();
        xmlCleanupParser();
    }


    /***************************************************************************

        Transforms a source xml text via the xslt transformation rules given in
        stylesheet_text, and writes the transformed xml as text into a
        destination string.

        Params:
            source = xml to transform
            dest = string to receive transformed xml
            stylesheet_text = xslt transformation stylesheet
    
    ***************************************************************************/

    public void transform ( ref char[] source, ref char[] dest, ref char[] stylesheet_text )
    {
        source.append("\0");
        scope ( exit ) source.length = source.length - 1;

        stylesheet_text.append("\0");
        scope ( exit ) stylesheet_text.length = stylesheet_text.length - 1;

        this.stylesheet_xml = xmlParseDoc(stylesheet_text.ptr);
        this.stylesheet = xsltParseStylesheetDoc(this.stylesheet_xml);
        this.original_xml = xmlParseDoc(source.ptr);
        this.transformed_xml = xsltApplyStylesheet(this.stylesheet, this.original_xml, null);

        this.docToString(this.transformed_xml, dest);
    }

    public alias transform opCall;


    /***************************************************************************

        Dumps an xml document to a string.
        
        Params:
            doc = xml doc to dump
            dest = string to dump into
    
    ***************************************************************************/

    private void docToString ( xmlDocPtr doc, ref char[] dest )
    {
        char* out_buf;
        int length;
        xsltSaveResultToString(&out_buf, &length, this.transformed_xml, this.stylesheet);
        dest = out_buf[0..length];
    }
}

