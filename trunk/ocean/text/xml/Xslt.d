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

    Checks the libxml error status and throws an exception if an error occurred.
    
    Params:
        exception = exception instance to throw

    Throws:
        throws passed exception if an error occurred in libxml

*******************************************************************************/

private void throwXmlErrors ( Exception exception )
{
    auto err = xmlGetLastError();
    if ( err )
    {
        formatXmlErrorString(err, exception.msg);
        throw exception;
    }
}



/*******************************************************************************

    Xslt stylesheet class. Can be initialised once and used for multiple xslt
    transformations.

*******************************************************************************/

class XsltStylesheet
{
    /***************************************************************************

        Reusable xml exception

    ***************************************************************************/

    private XmlException exception;


    /***************************************************************************

        Xml structure of stylesheet text.

    ***************************************************************************/

    private xmlDocPtr stylesheet_xml;


    /***************************************************************************

        Transformation stylesheet.

    ***************************************************************************/

    private xsltStylesheetPtr stylesheet;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.exception = new XmlException("");
    }


    /***************************************************************************

        Destructor -- deallocates any C-allocated data.

    ***************************************************************************/

    ~this ( )
    {
        this.cleanup();
    }


    /***************************************************************************

        Sets the xslt text.

        Params:
            xslt = text of xslt

    ***************************************************************************/

    public void set ( ref char[] xslt )
    {
        this.cleanup();

        xslt.append("\0");
        scope ( exit ) xslt.length = xslt.length - 1;

        this.stylesheet_xml = xmlParseDoc(xslt.ptr);
        throwXmlErrors(this.exception);

        this.stylesheet = xsltParseStylesheetDoc(this.stylesheet_xml);
        throwXmlErrors(this.exception);
    }


    /***************************************************************************

        Frees the C-allocated buffers associated with this stylesheet. The
        stylesheet xml is automatically freed as well.

    ***************************************************************************/

    private void cleanup ( )
    {
        if ( this.stylesheet !is null )
        {
            xsltFreeStylesheet(this.stylesheet);
            this.stylesheet = null;
        }
    }
}



/*******************************************************************************

    Xslt result class. Stores the result of an xslt transformation.

    The result is a C-allocated string, which this class wraps with a D string
    (a slice of the C string) and manages, ensuring that it is freed when
    appropriate.

*******************************************************************************/

public class XsltResult
{
    /***************************************************************************

        Slice of the C-allocated result string.
    
    ***************************************************************************/

    private char[] str;


    /***************************************************************************

        Destructor. Makes sure the C string is freed.

    ***************************************************************************/

    ~this ( )
    {
        this.cleanup();
    }


    /***************************************************************************

        Gets the slice to the C-allocated string.

    ***************************************************************************/

    public char[] opCall ( )
    {
        return this.str;
    }


    /***************************************************************************

        Sets the result string. (Called by XsltProcessor.transform().)

        Params:
            xml = pointer to an xml document
            stylesheet = xslt stylesheet

    ***************************************************************************/

    package void set ( xmlDocPtr xml, XsltStylesheet stylesheet )
    {
        this.cleanup();

        char* c_allocated_string;
        int length;
        xsltSaveResultToString(&c_allocated_string, &length, xml, stylesheet.stylesheet);

        this.str = c_allocated_string[0..length];
    }


    /***************************************************************************

        Frees the C-allocated string if one has been set.

    ***************************************************************************/

    private void cleanup ( )
    {
        if ( this.str.ptr !is null )
        {
            free(this.str.ptr);
            this.str = typeof(this.str).init;
        }
    }
}



/*******************************************************************************

    Xslt processor class -- takes an XsltStylesheet object defining a set of
    transformation rules, and an xml string. Runs the transformation over the
    xml string and fills in an XsltResult object.

*******************************************************************************/

public class XsltProcessor
{
    /***************************************************************************

        Xml structure of original text.

    ***************************************************************************/

    private xmlDocPtr original_xml;

    
    /***************************************************************************

        Xml structure of transformed text.
    
    ***************************************************************************/

    private xmlDocPtr transformed_xml;


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
    }

    
    /***************************************************************************

        Transforms a source xml text via the xslt transformation rules given in
        stylesheet_text, and writes the transformed xml as text into a
        destination string.

        This method is aliased with opCall.

        Params:
            source = xml to transform
            result = result instance to receive transformed xml
            stylesheet = xslt transformation stylesheet instance

    ***************************************************************************/

    public void transform ( ref char[] source, XsltResult result, XsltStylesheet stylesheet )
    in
    {
        assert(stylesheet.stylesheet !is null, typeof(this).stringof ~ ".transform: xslt stylesheet not initialised");
    }
    body
    {
        scope ( failure )
        {
            // clean everything to ensure it's fresh next time this method is called
            this.cleanupParser();
        }

        this.initParser();

        source.append("\0");
        scope ( exit ) source.length = source.length - 1;

        this.original_xml = xmlParseDoc(source.ptr);
        throwXmlErrors(this.exception);

        this.transformed_xml = xsltApplyStylesheet(stylesheet.stylesheet, this.original_xml, null);
        throwXmlErrors(this.exception);

        result.set(this.transformed_xml, stylesheet);

        // cleanup used resources
        cleanupXmlDoc(this.original_xml);
        cleanupXmlDoc(this.transformed_xml);
    }

    public alias transform opCall;

    
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
            cleanupXmlDoc(this.original_xml);
            cleanupXmlDoc(this.transformed_xml);

            xsltCleanupGlobals();
            xmlCleanupParser();

            this.xml_parser_initialised = false;
        }
    }


    /***************************************************************************

        Cleans up any resources used by the given xml document. It is set to
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

