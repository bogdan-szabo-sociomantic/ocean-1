/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        15/10/2012: Initial release

    authors:        Hans Bjerkander

    Wrapper to the xmlrpc-c client library. Makes synchronous xmlrpc calls to
    servers.

    Usage exampel:

    auto x = new Xmlrpc("xmlrpcexample","version12",
        "http://xmlrpc-c.sourceforge.net/api/sample.php");

    alias x.Value Value;
    Value v;
    
    char[] error_str;
    
    int i1 = 300, i2 = 288;
    v = x.call ( "sample.sumAndDifference","(ii)", i1 ,i2 );
    if ( v == null )
    {
        Stdout.formatln("{}", x.getFaultString(error_str));
        return 1;
    }
        
    int sum, diff;
    char[] string_value;
    char[] sum_name = "sum", diff_name="difference";
    
    
    void structRec (char[] key, Value v)
    {
        if ( key == "sum" )
        {
            x.parseValue(v, sum);
        }
        else if ( key == "difference" )
        {
            x.parseValue(v, diff);
        }
        else if ( key == "somestring" )
        {
            char[] str;
            x.parseValue(v, str);
            //you need to manually free str, a easy way is to do like this:
            string_value = str.dup;
            free(str.ptr);
            //now you can leave everything to the gc
        }
        else if ( key == "idontlikethisvalue" )
        {
            //v will not free itself so if you don't care about it us freeValue
            x.freeValue(v);
        }
        else
        {
            Stderr.formatln("Unknown key: {}",key);
        }
    }
    
    if ( !x.parseStructValue(v, &structRec) )
    {
        Stdout.formatln("{}", x.getFaultString(error_str));
        return 1;
    }
    
    Stdout.formatln("{0}+{1}={2}, {0}-{1}={3}", i1, i2, sum, diff );    
    
    TODO:
        it would be nice if parse


*******************************************************************************/

module ocean.net.client.xmlrpc.Xmlrpc;


/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.net.client.xmlrpc.c.libxmlrpc_client;
private import ocean.io.Stdout;
private import ocean.core.Array : append;

private import tango.core.Traits;

private import tango.stdc.string : strlen;
private import tango.stdc.stdlib : free;
private import tango.stdc.time;

public class Xmlrpc
{
    /***************************************************************************

        public alias for a xmlrpc value;

    ***************************************************************************/

    public alias xmlrpc_value* Value;


    /***************************************************************************

        Enviroment variable, use to see if there were an error and what kind.

    ***************************************************************************/

    private alias xmlrpc_env Enviroment;
    private Enviroment env;


    /***************************************************************************

        The xmlrpc client

    ***************************************************************************/

    private alias xmlrpc_client* Client;
    private Client client;


    /***************************************************************************

        The adress to the server as a c-string

    ***************************************************************************/

    private const char* server_url;


    /***************************************************************************

        Initiates the library and creates a client. Makes sure that the
        parameters are \0 terminated.

        Params:
            appName    = the applictaions name
            appVer     = the applications version
            server_url = the server url

    ***************************************************************************/

    this ( char[] appName, char[] appVer, char[] server_url )
    {
        assert(isNullTerminated(appName), "appName not null-terminated" );
        assert(isNullTerminated(appVer), "appVer not null-terminated");
        assert(isNullTerminated(server_url), "server_url not null-terminated");

        this.server_url = server_url.ptr;

        xmlrpc_env_init(&this.env);
        xmlrpc_client_setup_global_const(&this.env);
        xmlrpc_client_create(&this.env, 0, appName.ptr, appVer.ptr, null, 0,
            &this.client);
    }


    /***************************************************************************

        Destroys the client and frees resources

    ***************************************************************************/

    ~this ( )
    {
        xmlrpc_client_event_loop_finish(this.client);
        xmlrpc_client_destroy(this.client);
        xmlrpc_client_teardown_global_const();
    }


    /***************************************************************************

        Make a call to the server with the method_name with the data args
        defined by the format. Make sure to remember to free the result with
        freeValue or parse*. For information about the format string see
        http://xmlrpc-c.sourceforge.net/doc/libxmlrpc.html#formatstring

        Params:
            method_name = the method name to call
            format      = the format of the data
            args        = the data (int, bool, double, char[], time_t)

    ***************************************************************************/


    public Value call ( T ... ) ( char[] method_name, char[] format, ref T args )
    in
    {
        assert(isNullTerminated(method_name), "method_name not null-terminated");
        assert(isNullTerminated(format), "format not null-terminated" );
    }
    body
    {
        char*[T.length] c_strings;
        Value result;

        foreach ( i, a; args )
        {
            static if ( is(typeof(a) == char[]) )
            {
                assert(args[i].ptr, "char[] "~args[i].stringof ~ " can't be null");
                args[i] ~= "\0";
                c_strings[i] = args[i].ptr;
            }
        }
        scope ( exit )
        {
            foreach ( i, a; args )
            {
                static if ( is(typeof(a) == char[]) )
                {
                    args[i].length = args[i].length - 1;
                }
            }
        }

        static if ( T.length > 0 )
        {
            mixin(ClientCall!(T));
        }
        else
        {
            xmlrpc_client_call2f(&this.env, this.client, this.server_url,
                method_name.ptr, &result, format.ptr, args );
        }

        return this.faultOccurred()? null: result;
    }


    /***************************************************************************

        frees the value.

        Params:
            value   = a xmlrpc value

    ***************************************************************************/

    public void freeValue( Value value )
    {
        xmlrpc_DECREF(value);
    }


    /***************************************************************************

        Important, if a parameter is char[], remember to free it when done with
        it since the GC will not do it for you.
    
        For some reason, decompose wont work with structs( it should according 
        the manual). Use parseStructValue instead.

        Params:
            value   = a xmlrpc value
            args        = the data (int, bool, double, char[], time_t)

        Returns:
            true of the parsing went ok

    ***************************************************************************/


    public bool parseValue (T ...) (Value value, ref T args )
    {
        char*[T.length] c_strings;

        foreach ( i, a; args )
        {
            static assert ( Type!(T[0]).length, T[i].stringof ~ " is not supported");
                        
            static if ( is(typeof(a) == char[]) )
            {
                c_strings[i] = args[i].ptr;
            }
        }
        auto format = Format!(T);
        
        mixin(DecomposeValue!(T));

        foreach ( i, a; args )
        {
            static if ( is(typeof(a) == char[]) )
            {
                args[i] = c_strings[i][0 .. strlen(c_strings[i])];
            }
        }

        if ( this.faultOccurred ) return false;
        xmlrpc_DECREF(value);

        return !this.faultOccurred;
    }


    /***************************************************************************

        Returns the type of the value

        Params:
            value   = a xmlrpc value
            format  = a format string

        Returns:
            true of the parsing went ok

    ***************************************************************************/

    public xmlrpc_type getType ( Value value )
    {
        return xmlrpc_value_type(value);
    }


    /***************************************************************************

        Parses a struct from strct and sends each member name value to putter.

        Params:
            strct  = a xmlrpc value containing a struct
            putter = a delegate which will be called for each
                      (member name, value) found.

        Returns:
            true of the parsing went ok

    ***************************************************************************/

    public bool parseStructValue (Value strct, void delegate (char[] k,Value v) putter )
    in
    {
        assert(strct , "Can't read from an empty value!");
        assert(putter, "The putter function can't be null!");
    }
    body
    {
        int nr = xmlrpc_struct_size(&this.env, strct);
        if ( this.faultOccurred ) return false;

        Value key,val;

        for(uint i;i< nr;i++)
        {
            xmlrpc_struct_read_member(&this.env, strct,i, &key, &val);

            if ( this.faultOccurred ) return false;

            char* cstr;
            xmlrpc_decompose_value(&this.env, key, "s", &cstr);

            if ( this.faultOccurred ) return false;

            putter(cstr?cstr[0 .. strlen(cstr)]:null, val);
            free(cstr);
        }

        xmlrpc_DECREF(strct);
        return true;
    }


    /***************************************************************************

        Parses an array from arr and sends each value to putter

        Params:
            arr    = a xmlrpc value containing an array
            putter = a delegate which will be called for each value found.

        Returns:
            true of the parsing went ok

    ***************************************************************************/

    public bool parseArrayValue (Value arr, void delegate (int i, Value v) putter )
    in
    {
        assert(arr   , "Can't read from an empty value!");
        assert(putter, "The putter function can't be null!");
    }
    body
    {
        int nr = xmlrpc_array_size(&this.env, arr);
        if ( this.faultOccurred ) return false;

        for(uint i;i< nr;i++)
        {
            Value val;
            xmlrpc_array_read_item(&this.env, arr, i, &val);

            if ( this.faultOccurred ) return false;

            putter(i, val);
        }
        xmlrpc_DECREF(arr);
        return true;
    }


    /***************************************************************************

        Returns the last errors fault description.

        Params:
            str = the error will be saved here
    
        Returns:
            the parameter

    ***************************************************************************/

    public char[] getFaultString(ref char[] str)
    {
        return str.append(getFaultCodeDescription(env.fault_code),
           env.fault_string?env.fault_string[0 .. strlen(env.fault_string)]:"");
    }


    /***************************************************************************

        Checks if a fault occurred

        Returns:
            true if a fault occurred

    ***************************************************************************/

    private bool faultOccurred ( )
    {
        return cast(bool) this.env.fault_occurred;
    }


    /***************************************************************************

        Convert the Tuple member i to a argument, if string use a cstring instead

    ***************************************************************************/

    private template Arg ( size_t i, bool addr, T )
    {
        static if ( is(T == char[]) )
        {
            const char[] Arg = Addr!(addr) ~ "c_strings[" ~ i.stringof ~ "]";
        }
        else
        {
            const char[] Arg = Addr!(addr) ~ "args[" ~ i.stringof ~ "]";
        }
    }


    /***************************************************************************

        addr ? "&" : ""

    ***************************************************************************/

    private template Addr (bool addr)
    {
        static if ( addr)
        {
            const char[] Addr = "&";
        }
        else
        {
            const char[] Addr = "";
        }

    }


    /***************************************************************************

        Convert the Tuple to a argument list

    ***************************************************************************/

    private template Args ( size_t i, bool addr, T ... )
    {
        static if ( i < T.length - 1 )
        {
            const char[] Args = Arg!(i, addr, T[i]) ~ ", " ~ Args!(i + 1, addr, T);
        }
        else
        {
            const char[] Args = Arg!(i, addr, T[i]);
        }
    }


    /***************************************************************************

        templete for mixin, use to call xmlrpc_client_call if some of the last
        arguments are dstrings, use the equelevent cstring

    ***************************************************************************/

    private template ClientCall ( T ...)
    {
        const char[] ClientCall = "xmlrpc_client_call2f(&this.env, this.client, "
            "this.server_url,method_name.ptr, &result, format.ptr, " ~
            Args!(0, false, T) ~ ");";
    }


    /***************************************************************************

        templete for mixin, use to call xmlrpc_decompose_value with the last
        arguments as address and for each dstring use equelevent cstring

    ***************************************************************************/

    private template DecomposeValue ( T ...)
    {
        const char[] DecomposeValue = "xmlrpc_decompose_value(&this.env,value,"
            "format.ptr, "~Args!(0, true,T)~ ");";
    }


    /***************************************************************************

        Returns if the value of pos vp is a struct member name. Could have 
        potential use if decompose_value starts to work with structs.
        0, "{s:i}" => true
        1, "{s:i}" => false

    ***************************************************************************/

    private template IsStructMemName(size_t vp, char[] format)
    {
        static assert(format.length, "Looking for a to high value?");
        static if ( vp == 0)
        {
            static if ( format[0] == ',' || format[0] == '{')
            {
                const bool IsStructMemName = true;
            }
            else
            {
                const bool IsStructMemName = false;
            }
        }
        else
        {
            static if ( format[0] == ',' || format[0] == '{' ||
                        format[0] == '(' || format[0] == ':')
            {
                const bool IsStructMemName = IsStructMemName!(vp,format[1 .. $]);
            }
            else
            {
                const bool IsStructMemName = IsStructMemName!(vp-1,format[1 .. $]);
            }
        }
    }



    /***************************************************************************

        Creates a format string

    ***************************************************************************/
    
    private template Format(T ...)
    {
        static if ( T.length == 1 )
        {
            const char[] Format = Type!(T[0]);
        }
        else
        {
            const char[] Format = "("~FormatHelper!(T)~")";
        }
    }    
        
    
    private template FormatHelper(T ...)
    {
        static if ( T.length == 0 )
        {
            const char[] FormatHelper = "";
        }       
        else 
        {
            const char[] FormatHelper = Type!(T[0]) ~ FormatHelper!(T[1 .. $]);
        }
    }    
    

    /***************************************************************************

        Converts a type to a xmlrpc type string for creating a format string

    ***************************************************************************/    
    
    private template Type ( T )
    {
        static if ( is( T == char[] ) )
        {
            const char[] Type = "s";
        }
        else static if ( is( T == time_t) )
        {
            const char[] Type = "t";
        }        
        else static if ( is( T == int) )
        {
            const char[] Type = "i";
        }
        else static if ( is( T == bool ) )
        {
            const char[] Type = "b";
        }
        else static if ( is( T == double ) )
        {
            const char[] Type = "d";
        }
        else
        {
            static assert(false, T.stringof ~ " is not supported");
        }        
    }
     

    /***************************************************************************

        Does the format contain a struct?

        Params:
            format = a format string

        Returns:
            true if format contains a struct

    ***************************************************************************/

    private bool structInFormat(char[] format)
    {
        foreach ( c; format )
        {
            if ( c == '{' ) return true;
        }
        return false;
    }


    /***************************************************************************

        Is the string null terminated

        Params:
            str = the string

        Returns:
            true if string null terminated   = a xmlrpc value

    ***************************************************************************/

    private bool isNullTerminated(char[] str)
    {
        return str.ptr[str.length] == '\0';
    }
}