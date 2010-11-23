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

private import tango.stdc.stdio,
               tango.stdc.stdlib;

private import tango.core.Exception;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Xslt class

*******************************************************************************/

class Xslt
{
    /***************************************************************************

        Xml structure of original text.

    ***************************************************************************/

    private xmlDocPtr original_xml;


    /***************************************************************************

        Xml structure of stylesheet text.
    
    ***************************************************************************/

    private xmlDocPtr stylesheet_xml;

    
    /***************************************************************************

        Xml structure of transformed text.
    
    ***************************************************************************/

    private xmlDocPtr transformed_xml;

    
    /***************************************************************************

        Transformation stylesheet.
    
    ***************************************************************************/

    private xsltStylesheetPtr stylesheet;


    /***************************************************************************

        Flag set to true when the xml parser has been initialised.
    
    ***************************************************************************/

    private bool xml_parser_initialised;


    /***************************************************************************

        Reusable xml exception
    
    ***************************************************************************/

    private XmlException exception;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.exception = new XmlException("");
    }
    

    /***************************************************************************

        Destructor. Frees objects allocated by the C libraries.
    
    ***************************************************************************/

    ~this ( )
    {
        this.cleanupParser();
        delete this.exception;
    }

    
    /***************************************************************************

        Transforms a source xml text via the xslt transformation rules given in
        stylesheet_text, and writes the transformed xml as text into a
        destination string.

        This method is aliased with opCall.

        Params:
            source = xml to transform
            dest = string to receive transformed xml
            stylesheet_text = xslt transformation stylesheet
    
    ***************************************************************************/

    public void transform ( ref char[] source, ref char[] dest, ref char[] stylesheet_text )
    {
        this.initParser();

        source.append("\0");
        scope ( exit ) source.length = source.length - 1;

        stylesheet_text.append("\0");
        scope ( exit ) stylesheet_text.length = stylesheet_text.length - 1;

        this.throwXmlErrors({ this.stylesheet_xml = xmlParseDoc(stylesheet_text.ptr); });

        this.stylesheet = xsltParseStylesheetDoc(this.stylesheet_xml);

        this.throwXmlErrors({ this.original_xml = xmlParseDoc(source.ptr); });
        this.throwXmlErrors({ this.transformed_xml = xsltApplyStylesheet(this.stylesheet, this.original_xml, null); });

        this.docToString(this.transformed_xml, dest);

        // cleanup used resources
        this.cleanupStylesheet(this.stylesheet);
        this.cleanupXmlDoc(this.original_xml);
        this.cleanupXmlDoc(this.transformed_xml);
    }

    public alias transform opCall;

    
    /***************************************************************************

        Executes a block of code, checks the libxml error status, and throws any
        errors which occurred.
    
        Params:
            dg = code block to execute
            
        Throws:
            throws an XmlException if an error occurred in libxml
    
    ***************************************************************************/

    private void throwXmlErrors ( void delegate ( ) dg )
    {
        dg();

        auto err = xmlGetLastError();
        if ( err )
        {
            formatXmlErrorString(err, this.exception.msg);
            throw this.exception;
        }
    }


    /***************************************************************************

        Dumps an xml document to a string. The C string allocated by the call to
        xsltSaveResultToString is copied into the provided D string, and then
        freed.

        Params:
            doc = xml doc to dump
            dest = string to dump into
    
    ***************************************************************************/

    private void docToString ( xmlDocPtr doc, ref char[] dest )
    {
        char* c_allocated_string;
        int length;
        xsltSaveResultToString(&c_allocated_string, &length, this.transformed_xml, this.stylesheet);

        dest.copy(c_allocated_string[0..length]);

        free(c_allocated_string);
    }


    /***************************************************************************

        Initialises the xml parser with the settings required for xslt.
    
    ***************************************************************************/

    private void initParser ( )
    {
        if ( !this.xml_parser_initialised )
        {
            xmlInitParser();
            xmlSubstituteEntitiesDefault(1);
            xmlLoadExtDtdDefaultValue = 1;
    
            this.xml_parser_initialised = true;
        }
    }


    /***************************************************************************

        Cleans up all resources used by the xml parser & xlst.
    
    ***************************************************************************/

    private void cleanupParser ( )
    {
        if ( this.xml_parser_initialised )
        {
            this.cleanupStylesheet(this.stylesheet);
            this.cleanupXmlDoc(this.original_xml);
            this.cleanupXmlDoc(this.transformed_xml);

            xsltCleanupGlobals();
            xmlCleanupParser();

            this.xml_parser_initialised = false;
        }
    }


    /***************************************************************************

        Cleans up any resources used by the given xslt stylesheet. It is set to
        null.

        Params:
            stylesheet = stylesheet to clean
    
    ***************************************************************************/

    private void cleanupStylesheet ( ref xsltStylesheetPtr stylesheet )
    {
        if ( !(stylesheet is null) )
        {
            xsltFreeStylesheet(stylesheet);
            stylesheet = null;
        }
    }


    /***************************************************************************

        Cleans up any resources used by the given xml document . It is set to
        null.
    
        Params:
            xml_doc = xml document to clean
    
    ***************************************************************************/

    private void cleanupXmlDoc ( ref xmlDocPtr xml_doc )
    {
        if ( !(xml_doc is null) )
        {
            xmlFreeDoc(xml_doc);
            xml_doc = null;
        }
    }
}

