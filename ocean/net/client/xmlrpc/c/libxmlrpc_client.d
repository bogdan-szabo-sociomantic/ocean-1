/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        15/10/2012: Initial release

    authors:        Hans Bjerkander

    Bindings to the xmlrpc-c library

*******************************************************************************/

module ocean.net.client.xmlrpc.c.libxmlrpc_client;


/*******************************************************************************

    D bindings for the xmlrpc-c C library

*******************************************************************************/

extern ( C )
{
    /***************************************************************************

        Different types supported by xmlrpc

    ***************************************************************************/

    enum xmlrpc_type {
        XMLRPC_TYPE_INT      =  0,
        XMLRPC_TYPE_BOOL     =  1,
        XMLRPC_TYPE_DOUBLE   =  2,
        XMLRPC_TYPE_DATETIME =  3,
        XMLRPC_TYPE_STRING   =  4,
        XMLRPC_TYPE_BASE64   =  5,
        XMLRPC_TYPE_ARRAY    =  6,
        XMLRPC_TYPE_STRUCT   =  7,
        XMLRPC_TYPE_C_PTR    =  8,
        XMLRPC_TYPE_NIL      =  9,
        XMLRPC_TYPE_I8       = 10,
        XMLRPC_TYPE_DEAD     = 0xDEAD
    }


    /***************************************************************************

        the parameters of a client. Nothing we care about

    ***************************************************************************/

    struct xmlrpc_clientparms;


    /***************************************************************************

        the client, its content will only be used internally the c library. Never
        used directly and is sent along with xmlrpc-c function calls.

    ***************************************************************************/

    struct xmlrpc_client;


    /***************************************************************************

        environment struct. fault_occurred == 1 indicates if there have been an
        error. use getFaultCodeDescription to get the description for the fault
        code.

    ***************************************************************************/

    struct xmlrpc_env
    {
        int fault_occurred;
        int fault_code;
        char* fault_string;
    }


    /***************************************************************************

        a value, can be converted, with xmlrpc_decompose_value to a type we can 
        use.

    ***************************************************************************/

    struct _xmlrpc_mem_block
    {
        size_t _size;
        size_t _allocated;
        void*  _block;
    }    
    alias _xmlrpc_mem_block xmlrpc_mem_block;
    
    struct _xmlrpc_value 
    {
        xmlrpc_type _type;
        int _refcount;
    
        
        value _value;
        
        union value
        {
            int i;
            long i8;
            bool b;
            double d;
            /* time_t t */
            void* c_ptr;
        }
        
        xmlrpc_mem_block _block;
    
        xmlrpc_mem_block* _wcs_block;
    }   
    
    
    
//    struct _xmlrpc_value;
    alias _xmlrpc_value xmlrpc_value;


    /***************************************************************************

        Creates a client.

        Params:
            envP         = a pointer to a environment struct
            flags        = build flags. Use 0 for deafault values
            appname      = application name
            appversion   = the application version
            clientparmsP = client parameters, use null for default
            paramsize    = the size of the params(if null then 0)
            clientPP     = a pointer to a pointer to the client struct

    ***************************************************************************/

    void xmlrpc_client_create ( xmlrpc_env* envP, int flags, char* appname,
        char* appversion, xmlrpc_clientparms* clientparmsP, uint parmSize,
        xmlrpc_client** clientPP);


    /***************************************************************************

        Initiates the environment.

        Params:
            envP    = a pointer to a environment struct

    ***************************************************************************/

    void xmlrpc_env_init ( xmlrpc_env* env );


    /***************************************************************************

        Initiates the global constants.

        Params:
            envP    = a pointer to a environment struct

    ***************************************************************************/

    void xmlrpc_client_setup_global_const ( xmlrpc_env* env );


    /***************************************************************************

        Calls the method methodName on server serverUrl with the data ...
        defined by format. For information about the format string see
        http://xmlrpc-c.sourceforge.net/doc/libxmlrpc.html#formatstring

        Params:
            envP       = a pointer to a environment struct
            clientPP   = a pointer to the client struct
            serverUrl  = the url to the server
            methodName = name of the method
            resultPP   = a pointer to a pointer of a xmlrpc value
            format     = format string
            ...        = the data

    ***************************************************************************/

    void xmlrpc_client_call2f ( xmlrpc_env* envP, xmlrpc_client* clientP,
        char* serverUrl, char* methodName, xmlrpc_value** resultPP,
        char* format, ... );


    /***************************************************************************

        Blocks till each call has finished.

        Params:
            envP    = a pointer to a environment struct

    ***************************************************************************/

    void xmlrpc_client_event_loop_finish ( xmlrpc_client* clientP );


    /***************************************************************************

        Destroy client

        Params:
            clientPP   = a pointer to the client struct

    ***************************************************************************/

    void xmlrpc_client_destroy ( xmlrpc_client* clientP );


    /***************************************************************************

        Tear down global const

    ***************************************************************************/

    void xmlrpc_client_teardown_global_const();


    /***************************************************************************

        Frees the values resources.

        Params:
            value = a xmlrpc value

    ***************************************************************************/

    void xmlrpc_DECREF (xmlrpc_value* value);


    /***************************************************************************

        Parse a xmlrpc value defined by the format string. For information
        about the format string see
        http://xmlrpc-c.sourceforge.net/doc/libxmlrpc.html#formatstring

        Params:
            envP     = a pointer to a environment struct
            value    = the value to parse
            format   = format string
            ...      = the parsed data will be saved in to this parameters

    ***************************************************************************/

    void xmlrpc_decompose_value(xmlrpc_env* envP, xmlrpc_value* value, 
        char* format, ...);


    /***************************************************************************

        Retruns the type of a xmlrpc value

        Params:
            value    = the value to find out the type of

    ***************************************************************************/

    xmlrpc_type xmlrpc_value_type (xmlrpc_value* value);


    /***************************************************************************

        Returns the number members of a struct

        Params:
            envP    = a pointer to a environment struct
            value    = a xmlrpc value containing a struct

    ***************************************************************************/

    int xmlrpc_struct_size(xmlrpc_env* env, xmlrpc_value* strct);


    /***************************************************************************

        Get the index member of the struct

        Params:
            envP       = a pointer to a environment struct
            index      = the index element to get
            keyvalP    = the name of the struct member will be saved here.
            valueP     = the value of the struct member will be saved here.

    ***************************************************************************/

    void xmlrpc_struct_read_member(xmlrpc_env* envP, xmlrpc_value* structP,
        uint index, xmlrpc_value** keyvalP, xmlrpc_value** valueP);
    

    /***************************************************************************

        Returns the number members of a array

        Params:
            envP    = a pointer to a environment struct
            value    = a xmlrpc value containing a array

    ***************************************************************************/

    int  xmlrpc_array_size(xmlrpc_env* env, xmlrpc_value* array);


    /***************************************************************************

        Get the index member of the array

        Params:
            envP       = a pointer to a environment struct
            index      = the index element to get
            valueP     = the index element will be saved here.

    ***************************************************************************/

    void xmlrpc_array_read_item(xmlrpc_env* envP, xmlrpc_value* arrayP,
        uint index, xmlrpc_value** valuePP);

    
    /***************************************************************************

        Builds a xmlrpc_value from D-types according to the format string

        Params:
            env       = a pointer to a environment struct
            format    = format string
            ...       = the values to convert to a xmlrpc_value

    ***************************************************************************/
    
    xmlrpc_value* xmlrpc_build_value(xmlrpc_env* env, char* format, ...);
    
    xmlrpc_value* xmlrpc_struct_new(xmlrpc_env* envP);
    
    xmlrpc_value* xmlrpc_int_new(xmlrpc_env* envP, int intValue);
 
    
    void xmlrpc_struct_set_value(xmlrpc_env* env, xmlrpc_value* structP, 
        char* key, xmlrpc_value* valueP);    
       
}


/*******************************************************************************

    Given a fault_code returns a description of it.

    Params:
        fault_code = a fault code

    Returns:
        a string with a description of the error.

*******************************************************************************/

public char[] getFaultCodeDescription(int fault_code)
{
    switch(fault_code)
    {
        case -500:
            return "XMLRPC_INTERNAL_ERROR";
        case -501:
            return "XMLRPC_TYPE_ERROR";
        case -502:
            return "XMLRPC_INDEX_ERROR";
        case -503:
            return "XMLRPC_PARSE_ERROR";
        case -504:
            return "XMLRPC_NETWORK_ERROR";
        case -505:
            return "XMLRPC_NO_SUCH_METHOD_ERROR";
        case -506:
            return "XMLRPC_REQUEST_REFUSED_ERROR";
        case -507:
            return "XMLRPC_REQUEST_REFUSED_ERROR";
        case -508:
            return "XMLRPC_INTROSPECTION_DISABLED_ERROR";
        case -509:
            return "XMLRPC_LIMIT_EXCEEDED_ERROR";
        case -510:
            return "XMLRPC_INVALID_UTF8_ERROR";
        default:
            return "";
    }
}