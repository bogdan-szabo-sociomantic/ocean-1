/*******************************************************************************

    Load Configuration from Config File

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        Jan 2009: initial release
                    May 2010: revised version with struct opIndex support

    authors:        Lars Kirchhoff, Thomas Nicolai, David Eckhardt, Gavin Norman

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

debug private  import         tango.util.log.Trace;



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

class Config
{
    /***************************************************************************

        Typeof this alias.
    
    ***************************************************************************/

    public alias typeof(this) This; 


    /***************************************************************************

        Private constructor -- prevents instantiation of this class. All methods
        are static.

    ***************************************************************************/

    private this ( ) {}


    /***************************************************************************

        Everything from here on is static.
    
    ***************************************************************************/

    static:


    /***************************************************************************
        
        Config Keys and Properties
    
    ***************************************************************************/
    
    private char[][char[]][char[]]       properties;


    /***************************************************************************
        
        Config File Location
    
    ***************************************************************************/
    
    private char[]                       configFile;


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
       
        Returns:
            true, if configuration could be read
            
    ***************************************************************************/

    public bool init ( char[] filePath = "etc/config.ini" )
	{
        This.configFile = filePath;

        char[] text, category, key = "";
        
        int pos;
        
        bool multiline_first = true;
        
        This.properties = null;
    
        try
        {
            foreach (line; new Lines!(char) (new File(This.configFile)))
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
        catch (Exception e)
        {
            ConfigException(e.msg);
        }

        return true;
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

            static if ( is(T : bool) )
            {
                return This.toBool(property);
            }
            else static if ( is(T : long) )
            {
                return toLong(property);
            }
            else static if ( is(T : real) )
            {
                return toFloat(property);
            }
            else static if ( is(char[] T : T[]) || is(wchar[] T : T[]) || is(dchar[] T : T[]) )
            {
                return fromString8!(T)(property, null);
            }
            else static assert(false, __FILE__ ~ " : get(): type '" ~
                                     T.stringof ~ "' is not supported");
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
        auto property = This.get!(T[])(category, key);

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
            return Config.get!(int)(category, key);
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
            return Config.get!(float)(category, key);
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
            return Config.get!(long)(category, key);
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
            return Config.get!(T[])(category, key);
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
                return Config.get!(bool)(category, key);
            }
            else
            {
                bool b;
                Config.get(b, category, key);
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

    private bool toBool ( char[] property )
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
}

