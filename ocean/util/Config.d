/*******************************************************************************

    Load Configuration from Config File

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        Jan 2009: initial release
                    May 2010: revised version with struct opIndex support

    authors:        Lars Kirchhoff, Thomas Nicolai, David Eckardt, 
                    Gavin Norman, Mathias Baumann

*******************************************************************************/

module ocean.util.Config;



/*******************************************************************************

    Imports

*******************************************************************************/

public         import         ocean.core.Exception: ConfigException, assertEx;

private        import         tango.io.device.File;

private        import         tango.io.stream.Lines;

private        import         tango.text.convert.Integer: toLong;

private        import         tango.text.convert.Float: toFloat;

private        import         tango.text.Util: locate, trim, delimit;

private        import         tango.text.convert.Utf;

private        import         tango.core.Exception;

debug private  import         ocean.util.log.Trace;



/*******************************************************************************
 
    Config reads all properties of the application from an INI style of the
    following format:

    ---

        // --------------------------
        // Config Example
        // --------------------------

        ; Database config parameters
        [DATABASE]
        table1 = "name_of_table1"
        table2 = "name_of_table2"

        ; An example of a multi-value parameter
        fields = "create_time"
                 "update_time"
                 "count"

        ; Logging config parameters
        [LOGGING]
        level = 4
        file = "access.log"

    ---

    The properties defined in the file are read and stored in an internal array,
    which can then be accessed through get and set methods as follows:

    Usage example:

    ---

        // Read config file from disk
        Config.init("etc/my_config.ini");

        // Read a single value
        char[] value = Config.Char["category", "key"];

        // Set a single value
        Config.set("category", "key", "new value");

        // Read a multi-line value
        char[][] values = Config.getList("category", "key");

    ---

    The init() method only needs to be called once, though may be called
    multiple times if the config file needs to be re-read from the file on disk.

    TODO:

    A print function provides a facility to print all config properties at
    once for debugging reasons.

        Config.print;

    If properties have changed within the program it can be written back to
    the INI file with a write function. This function clears the INI file and
    writes all current parameters stored in properties to INI file.

        Config.set("key", "new value");
        Config.write;
    
*******************************************************************************/

/*******************************************************************************

    Configuration settings that are mandatory can be marked as such by 
    wrapping them with this template.
    
    Note: The variable sometimes requires a cast for certain usages when this 
          is used.

    Params:
        T = the original type of the variable

*******************************************************************************/

template Required ( T )
{
    typedef T Required;
}

/*******************************************************************************

    Configuration settings for which it is required to know whether they have
    been set or not can be wrapped in this struct.
    
    Params:
        T = the original type

*******************************************************************************/

struct SetInfo ( T )
{
    /***************************************************************************

        The value of the configuration setting
    
    ***************************************************************************/
        
    T value;

    /***************************************************************************

        Whether this value has been set
    
    ***************************************************************************/

    bool set;

    /***************************************************************************

        Query method for the value with optional default initaliser
        
        Params:
            def = the value that should be used when it was not found in the
                  configuration
    
    ***************************************************************************/

    T opCall ( T def = T.init )
    {
        return set ? value : def;
    }
    
    /***************************************************************************

        Sets value to val
        
        Params:
            val = new value
            
        Returns:
            val
    
    ***************************************************************************/

    T opAssign ( T val )
    {
        return value = val;
    }
}
    
class Config
{         
    /***************************************************************************

        Template that evaluates to true when T is a supported type
        
        Template Params:
            T = type to check for

    ***************************************************************************/
    
    template IsSupported ( T )
    {
        static if ( is(T : bool) )
        {
            const IsSupported = true;
        }
        else static if ( is(T : long) )
        {
            const IsSupported = true;
        }
        else static if ( is(T : real) )
        {
            const IsSupported = true;
        }
        else static if ( is(T U : U[]) && 
                       ( is(U : char) || is(U : wchar) || is(U:dchar)) )
        {
            const IsSupported = true;
        }
        else
        {
            const IsSupported = false;
        }
    }    
    
    /***************************************************************************

        Strips the typedef off T
    
    ***************************************************************************/

    private template StripTypedef ( T )
    {
        static if ( is ( T Orig == typedef ) )
        {
            alias Orig StripTypedef;
        }
        else
        {
            alias T StripTypedef;
        }
    }
    
    /***************************************************************************

        Typeof this alias.
    
    ***************************************************************************/

    public alias typeof(this) This; 

    /***************************************************************************
        
        Config Keys and Properties
    
    ***************************************************************************/
    alias char[] String;
    private String[String][String] properties;


    /***************************************************************************
        
        Config File Location
    
    ***************************************************************************/
    
    private char[] configFile;
    
    /***************************************************************************
        
        Static singleton instance
    
    ***************************************************************************/
      
    static private Config instance = null;
    
    /***************************************************************************
        
         Constructor
    
    ***************************************************************************/
    
    public this ( )
    { }
    
    /***************************************************************************
        
         Constructor
         
         Params:
             config = path to the configuration file
    
    ***************************************************************************/
    
    public this ( char[] config )
    {
        this.parse(config);
    }
    
    /***************************************************************************
        
         Singleton initializer.
         
         Params:
             config = path to the configuration file
    
    ***************************************************************************/
    
    static public void initSingleton ( char[] config = null )
    {
        if ( config is null )
        {
            instance = new Config;
        }
        else
        {
            instance = new Config(config);
        }
    }
    
    /***************************************************************************
        
         Provides access to the singleton instance
         
         Returns:
             the singleton instance
    
    ***************************************************************************/
    
    static public Config opCall ( ) ( )
    in
    {
        assert ( instance !is null );
    }
    body
    {
        return instance;
    }
        
    /***************************************************************************

        Fill the given instance of T with according values from the 
        configuration file. The name of each variable will used to get it 
        from the given section in the configuration file.
        
        If reference is null, an instance will be created.
        
        Variables can be marked as required with the Required template.
        If it is important to know whether the setting has been set, the
        SetInfo struct can be used 
        
        Params:
            group     = the group/section of the variable
            reference = the instance to fill. If null it will be created  

        Returns:
            an instance filled with values from the configuration file
            
        See_Also:
            Required, SetInfo

    ***************************************************************************/
    
    public T opCall ( T : Object ) ( char[] group, T reference = null )
    in
    {
        assert ( instance !is null );
    }
    body
    {
        return get!(T)(group, reference);
    }
         
    /***************************************************************************

        Fill the given instance of T with according values from the 
        configuration file. The name of each variable will used to get it 
        from the given section in the configuration file.
        
        If reference is null, an instance will be created.
        
        Variables can be marked as required with the Required template.
        If it is important to know whether the setting has been set, the
        SetInfo struct can be used 
        
        Params:
            group     = the group/section of the variable
            reference = the instance to fill. If null it will be created  

        Returns:
            an instance filled with values from the configuration file
            
        See_Also:
            Required, SetInfo

    ***************************************************************************/
    
    public T get ( T : Object ) ( char[] group, T reference = null )
    {
        if ( reference is null )
        {
            reference = new T;
        }
        
        readFields!(T)(group, reference);  

        // Recurse into super any classes
        static if ( is(T S == super ) )
        {
            foreach ( G; S ) static if ( !is(G == Object) )
            {
                readFields!(G)(group, cast(G) reference);
            }                            
        }                       
        
        return reference;
    }
    
    /***************************************************************************

        Variable Iterator. Iterates over variables of a category

    ***************************************************************************/

    struct VarIterator
    {
        char[][char[]]* vars;
            
        /***********************************************************************

            Variable Iterator. Iterates over variables of a category

        ***********************************************************************/

        public int opApply ( int delegate ( ref char[] x ) dg )
        {
            int result = 0;
    
            if (vars is null)
            {
                return result;
            }
            
            foreach (key, val; *vars)
            {
                result = dg(key);
    
                if (result) break;
            }
    
            return result;
        }
    }
    
    /***************************************************************************

        Class Iterator. Iterates over variables of a category

    ***************************************************************************/

    struct ClassIterator ( T )
    {
        Config config;
        char[] root;    
        
        /***********************************************************************

            Variable Iterator. Iterates over variables of a category

        ***********************************************************************/

        public int opApply ( int delegate ( ref char[] name, ref T x ) dg )
        {
            int result = 0;
                
            if ( config !is null ) foreach ( key, val; config.properties ) 
            {
                scope T instance = new T;
                
                if ( key.length > root.length && key[0 .. root.length] == root )
                {
                    instance = config.get(key, instance);
                    
                    auto name = key[root.length + 1 .. $];
                    result = dg(name, instance);
        
                    if (result) break;
                }
            }
    
            return result;
        }
    }
    
    public ClassIterator!(T) iterateClasses ( T ) ( char[] root )
    {
        return ClassIterator!(T)(this, root);
    }
        
    /***************************************************************************

        Variable Iterator. Iterates over variables of a category
        
        Params:
            category = category to iterate over
            
        Returns:
            iterator

    ***************************************************************************/

    VarIterator iterateCategory ( char[] category )
    {
        return VarIterator(category in This.properties);
    }
            
    /***************************************************************************

        Iterator. Iterates over categories of the config file

    ***************************************************************************/

    public int opApply ( int delegate ( ref char[] x ) dg )
    {
        int result = 0;

        foreach (key, val; This.properties)
        {
            result = dg(key);

            if (result) break;
        }

        return result;
    }
     
    /***************************************************************************
        
        Read Config File
        
        Reads the content of the configuration file and copies to a static 
        array buffer.
        
        Each property in the ini file belongs to a category. A property has always
        a key and a value associated to the key. The function parses currently 
        three different elements:
        
        i. Categories
        [Example Category]
        
        ii. Comments
        // comments always start with two slashes
        ;  or a semi-colon

        iii. Property
        key = value

        iv. Multi-value property
        key = value1
              value2
              value3

        Usage Example:

        ---
     
            Config.init("etc/config.ini");
     
        ---

        FIXME: this method does a fair bit of 'new'ing and '.dup'ing. If we ever
        need to repeatedly read a config file, this should be reworked.

        Params:
            filePath = string that contains the path to the configuration file
            
    ***************************************************************************/

    public void parse ( char[] filePath = "etc/config.ini" )
    {
        this.configFile = filePath;

        char[] text, category, key = "";
        
        int pos;
        
        bool multiline_first = true;
        
        this.properties = null;
        
        foreach (line; new Lines!(char) (new File(this.configFile)))
        {
            text = trim(line);

            if ( text.length ) // ignore empty lines
            {
                bool slash_comment = text.length >= 2 && text[0 .. 2] == "//";  
                bool semicolon_comment = text[0] == ';';  
                if ( !slash_comment && !semicolon_comment ) // ignore comments
                {
                    pos = locate(text, '['); // category present in line?

                    if ( pos == 0 )
                    {
                        category = text[pos + 1 .. locate(text, ']')].dup;
                        
                        key = "";
                    }
                    else
                    {
                        pos = locate(text, '='); // check for key value pair

                        if (pos < text.length)
                        {
                            key = trim(text[0 .. pos]).dup;

                            text = trim(text[pos + 1 .. $]).dup;

                            This.properties[category][key] = text;
                            multiline_first = !text.length;
                        }
                        else
                        {
                            text = trim(text).dup;
                            
                            if (text.length)
                            {
                                if (!multiline_first)
                                {
                                    This.properties[category][key] ~= '\n';
                                }
                                
                                This.properties[category][key] ~= text;
                                
                                multiline_first = false;
                            }
                        }
                    }
                }
            }
        }
    }    


    /***************************************************************************
        
        Tells whether a config file has been read or not.
       
        Returns:
            true, if configuration is already initalized
            
    ***************************************************************************/
    
    public bool isRead()
    {
        return This.properties.length > 0;
    }


    /***************************************************************************

        Checks if Key exists in Category

        Params:
            category = category to get key from
            key      = name of the property to get

        Returns:
            true if the configuration key exists in this category

    ***************************************************************************/

    public bool exists ( char[] category, char[] key )
    {
        return (category in This.properties) && (key in This.properties[category]);
    }

    
    /***************************************************************************
        
        Strict method to get the value of a config key. If the requested key
        cannot be found, an exception is thrown.

        Template can be instantiated with integer, float or string (char[])
        type.

        Usage Example:
     
        ---     
            const char[] my_config_cat = "options";
            
            char[] my_config_par;
            int    num_threads;
            
            Config.init("etc/config.ini");
            
            my_config_par = Config.get!(char[])(my_config_cat, "my_config_key");
            num_threads   = Config.get!(int)(my_config_cat, "number_of_threads");            
        ---
     
        Params:
            category = category to get key from
            key      = name of the key to get

        Throws:
            if the specified key does not exist

        Returns:
            value of a configuration key, or null if none
            
    ***************************************************************************/
    
    public T get ( T ) ( char[] category, char[] key )
    {
        assertEx!(ConfigException)(exists(category, key), "Critial Error: No configuration key "
                                   "'" ~ category ~ ":" ~ key ~ "' found");
        try
        {
            char[] property = This.properties[category][key];

            return conv!(T)(property);
        }
        catch ( IllegalArgumentException )
        {
            ConfigException("Critial Error: Configuration key '" ~ category ~
            ":" ~ key ~ "' appears not to be of type '" ~ T.stringof ~ "'");
        }
    }
    
    
    /***************************************************************************

        Non-strict method to get the value of a config key into the specified
        output value. The existence or non-existence of the key is returned. If
        the configuration key cannot be found, the output value remains
        unchanged.

        Template can be instantiated with integer, float or string (char[])
        type.

        Usage Example:

        ---
     
            const char[] my_config_cat = "options";
            
            char[] my_config_par = "my_default_value";
            int    num_threads   = 4711;
            
            Config.init("etc/config.ini");
            
            Config.get!(char[])(my_config_cat, my_config_par, "my_config_key");
            Config.get!(int   )(my_config_cat, num_threads, "number_of_threads");
            
        ---

        Params:
            value    = output value
            category = category to get key from
            key      = name of the key to get

        Returns:
            true on success or false if the key could not be found

    ***************************************************************************/
    
    public bool get ( T ) ( ref T value, char[] category, char[] key )
    {
        if ( exists(category, key) )
        {
            value = get!(T)(category, key);
            return true;
        }
        else
        {
            return false;
        }
    }


    /***************************************************************************

        Strict method to get a multi-line value. If the requested key cannot be
        found, an exception is thrown.

        Retrieves the value list of a configuration key with a multi-line value. 
        If the value is a single line, the list has one element.

        Params:
            category = key category name
            key      = key name

        Throws:
            if the specified key does not exist

        Returns:
            list of values

    ***************************************************************************/

    public T[][] getList ( T = char ) ( char[] category, char[] key )
    {
        auto property = This().get!(T[])(category, key);

        return delimit!(T)(property, "\n");
    }


    /***************************************************************************

        Non-strict method to get a multi-line value. The existence or
        non-existence of the key is returned. If the configuration key cannot be
        found, the output list remains unchanged.

        If the value is a single line, the output list has one element.

        Params:
            value    = output list of values, changed only if the key was found
            category = key category name
            key      = key name
        
        Returns:
            true on success or false if the key could not be found
            
    ***************************************************************************/
    
    public bool getList ( T = char ) ( ref T[][] value, char[] category, 
                                              char[] key )
    {
        if ( exists(category, key) )
        {
            value = getList!(T)(category, key);
            return true;
        }
        else
        {
            return false;
        }
    }


    /***************************************************************************
        
        Set Config-Key Property
        
        Usage Example:

        ---
     
            Config.init(`etc/config.ini`);
            
            Config.set(`category`, `key`, `value`);
            
        ---
     
        Params:
            category = category to get key from
            key      = name of the property to get
            value    = value of the property
            
    ***************************************************************************/
    
    public void set ( char[] category, char[] key, char[] value )
    {
        This.properties[category][key] = value;
    }
    
    
    /***************************************************************************
        
        Returns integer value of a configuration key

        TODO: add strictness setting (like Bool[], below) for consistency

        Usage Example:
     
        ---
     
            Config.init("etc/config.ini");
            
            int value = Config.Int["category", "key"];
            
        ---
     
        Params:
            category = category to get key from
            key      = name of the property to get
            
        Returns:
            value of config key
            
    ***************************************************************************/
    
    struct Int
    {
        public static int opIndex (char[] category, char[] key)
        {
            return Config().get!(int)(category, key);
        }
    }
    
    
    /***************************************************************************
        
        Returns float value of a configuration key
        
        TODO: add strictness setting (like Bool[], below) for consistency

        Usage Example:

        ---
     
            Config.init("etc/config.ini");
            
            float value = Config.Float["category", "key"];
            
        ---
     
        Params:
            category = category to get key from
            key      = name of the property to get
            
        Returns:
            value of config key
            
    ***************************************************************************/
    
    struct Float
    {
        public static float opIndex (char[] category, char[] key)
        {
            return Config().get!(float)(category, key);
        }
    }

    
    /***************************************************************************
        
        Returns long value of a configuration key
        
        TODO: add strictness setting (like Bool[], below) for consistency

        Usage Example:
     
        ---
     
            Config.init("etc/config.ini");
            
            long value = Config.Long["category", "key"];
            
        ---
     
        Params:
            category = category to get key from
            key      = name of the property to get
            
        Returns:
            value of config key
            
    ***************************************************************************/
    
    struct Long
    {
        public static long opIndex(char[] category, char[] key)
        {
            return Config().get!(long)(category, key);
        }
    }
    
    /***************************************************************************
        
        Returns value of configuration key as string
        
        TODO: add strictness setting (like Bool[], below) for consistency

        Usage Example:
     
        ---
     
            Config.init("etc/config.ini");
            
            char[] value = Config.Char["category", "key"];
            
        ---
     
        Params:
            category = category to get key from
            key      = name of the property to get
            
        Returns:
            value of config key
            
    ***************************************************************************/
    
    struct Char
    {
        public static T[] opIndex ( T = char ) (char[] category, char[] key)
        {
            return Config().get!(T[])(category, key);
        }
    }


    /***************************************************************************
        
        Returns bool value of configuration key
        
        Usage Example:
     
        ---
     
            Config.init("etc/config.ini");
            
            bool value = Config.Bool["category", "key"];
            
        ---
     
        Params:
            category  = category to get key from
            key       = name of the property to get
            strict    = true: throw exception on unknown value,
                        false: treat unknown value as "false"

        Returns:
            value of config key

    ***************************************************************************/
    
    struct Bool
    {
        public static bool opIndex( char[] category, char[] key, 
                                   bool strict = false )
        {
            if ( strict )
            {
                return Config().get!(bool)(category, key);
            }
            else
            {
                bool b;
                Config().get(b, category, key);
                return b;
            }
        }
    }


    /***************************************************************************

        Converts a string to a boolean value. The following string values are
        accepted:

            false / true, disabled / enabled, off / on, no / yes, 0 / 1

        Params:
            property = string to extract boolean value from

        Throws:
            if the string does not match one of the possible boolen strings

        Returns:
            boolean value interpreted from string

    ***************************************************************************/

    private static bool toBool ( char[] property )
    {
        const char[][2][] BOOL_IDS =
        [
           ["false",    "true"],
           ["disabled", "enabled"],
           ["off",      "on"],
           ["no",       "yes"],
           ["0",        "1"]
        ];

        foreach ( id; BOOL_IDS )
        {
            if (property == id[0]) return false;
            if (property == id[1]) return true;
        }

        throw new IllegalArgumentException("Config.toBool :: invalid boolean value");
    }


    /***************************************************************************

        Converts property to T
        
        Params:
            property = value to convert
            
        Returns:
            property converted to T

    ***************************************************************************/ 
    
    public static T conv ( T ) ( char[] property )
    {
        static if ( is(T : bool) )
        {
            return toBool(property);
        }
        else static if ( is(T : long) )
        {
            return toLong(property);
        }
        else static if ( is(T : real) )
        {
            return toFloat(property);
        }
        else static if ( is(T U : U[]) && 
                       ( is(U : char) || is(U : wchar) || is(U:dchar)) )    
        {
            return fromString8!(U)(property, null);
        }
        else static assert(false, __FILE__ ~ " : get(): type '" ~
                                 T.stringof ~ "' is not supported");
    } 
    
    /***************************************************************************

        Converts property to T
        
        Params:
            property = value to convert
            
        Returns:
            property converted to T

    ***************************************************************************/ 
    
    protected void readFields ( C ) ( char[] group, C reference = null ) 
    {
        foreach ( si, field; reference.tupleof ) 
        { 
            static if ( is ( typeof(field.value) ) )
            {
                alias StripTypedef!(typeof(field.value)) Type;
                alias typeof(field.value) PureType;
                Type* value = cast(Type*)&reference.tupleof[si].value;
                bool* found = &reference.tupleof[si].set;
            }
            else
            {
                alias StripTypedef!(typeof(field)) Type;
                alias typeof(field) PureType;
                Type* value = cast(Type*)&reference.tupleof[si];
                bool found_v;
                bool* found = &found_v;
            }
                        
            static if ( this.IsSupported!(Type) )
            {
                *found = this.get(*value, group, 
                                  reference.tupleof[si]
                                   .stringof["reference.".length  .. $]);
                
                auto name = PureType.stringof;
                
                if ( name.length >= "Required".length &&
                     name[0 .. "Required".length] == "Required" && 
                     *found == false )
                {
                    throw new Exception("Mandatory variable " ~ 
                                        reference.tupleof[si]
                                        .stringof["reference.".length  .. $]
                                                  ~ " not set");
                }                    
                
                debug (Config) Trace.formatln("Config Debug: {}.{} = {} {}", group, 
                                     reference.tupleof[si]
                                    .stringof["reference.".length  .. $], 
                                    *value, 
                                    !*found ? "(builtin)" : "");                    
            }
        }          
    } 
}

