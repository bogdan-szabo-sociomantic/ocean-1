/*******************************************************************************

    Load Configuration from Config File

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        Jan 2009: initial release
                    May 2010: revised version with struct opIndex support

    authors:        Lars Kirchhoff, Thomas Nicolai, David Eckardt,
                    Gavin Norman, Mathias Baumann

*******************************************************************************/

module ocean.util.config.ConfigParser;


/*******************************************************************************

    Imports

*******************************************************************************/

public  import ocean.core.Exception: ConfigException, assertEx;

private import tango.io.device.File;

private import tango.io.stream.Lines;

private import tango.text.convert.Integer: toLong;

private import tango.text.convert.Float: toFloat;

private import tango.text.Util: locate, trim, delimit;

private import tango.text.convert.Utf;

private import tango.core.Exception;

private import tango.core.Traits : DynamicArrayType;

debug private import ocean.util.log.Trace;


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
        Config.parse("etc/my_config.ini");

        // Read a single value
        char[] value = Config.Char["category", "key"];

        // Set a single value
        Config.set("category", "key", "new value");

        // Read a multi-line value
        char[][] values = Config.getList("category", "key");

    ---

    The parse() method only needs to be called once, though may be called
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

class ConfigParser
{   
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

            Config.parse("etc/config.ini");

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

        Tells whether the config object has no values loaded.

        Returns:
            true if it doesn't have any values, false otherwise

    ***************************************************************************/

    public bool isEmpty()
    {
        return This.properties.length == 0;
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

            Config.parse("some-config.ini");
            // throws if not found
            auto str = Config.getStrict!(char[])("some-cat", "some-key");
            auto n = Config.getStrict!(int)("some-cat", "some-key");

        ---

        Params:
            category = category to get key from
            key = name of the key to get

        Throws:
            if the specified key does not exist

        Returns:
            value of a configuration key, or null if none

    ***************************************************************************/

    public T getStrict ( T ) ( char[] category, char[] key )
    {
        assertEx!(ConfigException)(exists(category, key), 
                                   "Critial Error: No configuration key "
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

        Alternative form strict config value getter, returning the retrieved
        value via a reference. (The advantage being that the template type can
        then be inferred by the compiler.)

        Template can be instantiated with integer, float or string (char[])
        type.

        Usage Example:

        ---

            Config.parse("some-config.ini");
            // throws if not found
            char[] str;
            int n;

            Config.getStrict(str, "some-cat", "some-key");
            Config.getStrict(n, "some-cat", "some-key");

        ---

        Params:
            value = output for config value
            category = category to get key from
            key = name of the key to get

        Throws:
            if the specified key does not exist

        TODO: perhaps we should discuss removing the other version of
        getStrict(), above? It seems a little bit confusing having both methods,
        and I feel this version is more convenient to use.

    ***************************************************************************/

    public void getStrict ( T ) ( ref T value, char[] category, char[] key )
    {
        value = this.getStrict!(T)(category, key);
    }


    /***************************************************************************

        Non-strict method to get the value of a config key into the specified
        output value. If the config key does not exist, the given default value
        is returned.

        Template can be instantiated with integer, float or string (char[])
        type.

        Usage Example:

        ---

            Config.parse("some-config.ini");
            char[] str = Config.get("some-cat", "some-key", "my_default_value");
            int n = Config.get("some-cat", "some-int", 5);

        ---

        Params:
            category = category to get key from
            key = name of the key to get
            default_value = default value to use if missing in the config

        Returns:
            config value, if existing, otherwise default value

    ***************************************************************************/

    public DynamicArrayType!(T) get ( T ) ( char[] category, char[] key,
            T default_value )
    {
        if ( exists(category, key) )
        {
            return getStrict!(DynamicArrayType!(T))(category, key);
        }
        return default_value;
    }


    /***************************************************************************

        Alternative form non-strict config value getter, returning the retrieved
        value via a reference. (For interface consistency with the reference
        version of getStrict(), above.)

        Template can be instantiated with integer, float or string (char[])
        type.

        Usage Example:

        ---

            Config.parse("some-config.ini");
            char[] str;
            int n;

            Config.get(str, "some-cat", "some-key", "default value");
            Config.get(n, "some-cat", "some-key", 23);

        ---

        Params:
            value = output for config value
            category = category to get key from
            key = name of the key to get
            default_value = default value to use if missing in the config

        TODO: perhaps we should discuss removing the other version of
        get(), above? It seems a little bit confusing having both methods,
        and I feel the reference version is more convenient to use.

    ***************************************************************************/

    public void get ( T ) ( ref T value, char[] category,
        char[] key, T default_value )
    {
        value = this.get(category, key, default_value);
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

    public T[] getListStrict ( T = char[] ) ( char[] category, char[] key )
    {
        auto value = this.getStrict!(T)(category, key);
        T[] r;
        foreach (elem; delimit!(typeof(T[0]))(value, "\n"))
        {
            r ~= elem;
        }
        return r;
    }


    /***************************************************************************

        Non-strict method to get a multi-line value. The existence or
        non-existence of the key is returned. If the configuration key cannot be
        found, the output list remains unchanged.

        If the value is a single line, the output list has one element.

        Params:
            category = key category name
            key      = key name
            default_value = default list to use if missing in the config

        Returns:
            the configured value if found, or default value otherwise

    ***************************************************************************/

    public bool getList ( T = char[] ) ( char[] category, char[] key,
            T[] default_value )
    {
        if ( exists(category, key) )
        {
            return getListStrict!(T)(category, key);
        }
        return default_value;
    }


    /***************************************************************************

        Set Config-Key Property

        Usage Example:

        ---

            Config.parse(`etc/config.ini`);

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
}

