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

public  import ocean.core.Exception: assertEx;

private import ocean.io.Stdout;

private import tango.io.device.File;

private import tango.io.stream.Lines;

private import tango.io.stream.Format;

private import tango.text.convert.Integer: toLong;

private import tango.text.convert.Float: toFloat;

private import tango.text.Util: locate, trim, delimit, splitLines;

private import tango.text.convert.Utf;

private import tango.core.Exception;

private import tango.core.Traits : DynamicArrayType;

debug private import ocean.util.log.Trace;


/******************************************************************************

    ConfigException

*******************************************************************************/

class ConfigException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static void opCall ( Args ... ) ( Args args )
    {
        throw new ConfigException(args);
    }
}


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
        char[][] values = Config.getListStrict("category", "key");

    ---

    The parse() method only needs to be called once, though may be called
    multiple times if the config file needs to be re-read from the file on disk.

    TODO:

    If properties have changed within the program it can be written back to
    the INI file with a write function. This function clears the INI file and
    writes all current parameters stored in properties to INI file.

        Config.set("key", "new value");
        Config.write;

*******************************************************************************/

class ConfigParser
{
    /***************************************************************************

        Variable Iterator. Iterates over variables of a category

    ***************************************************************************/

    public struct VarIterator
    {
        char[][char[]]* vars;


        /***********************************************************************

            Variable Iterator. Iterates over variables of a category

        ***********************************************************************/

        public int opApply ( int delegate ( ref char[] x ) dg )
        {
            int result = 0;

            if ( vars is null )
            {
                return result;
            }

            foreach ( key, val; *vars )
            {
                result = dg(key);

                if ( result ) break;
            }

            return result;
        }
    }


    /***************************************************************************

        Current category being parsed

    ***************************************************************************/

    public char[] category;


    /***************************************************************************

        Current key being parsed

    ***************************************************************************/

    public char[] key;


    /***************************************************************************

        Current value being parsed

    ***************************************************************************/

    public char[] value;


    /***************************************************************************

        True if we are at the first multiline value when parsing

    ***************************************************************************/

    public bool multiline_first = true;


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

        Params:
            category = category to iterate over

        Returns:
            iterator

    ***************************************************************************/

    public VarIterator iterateCategory ( char[] category )
    {
        return VarIterator(category in this.properties);
    }


    /***************************************************************************

        Iterator. Iterates over categories of the config file

    ***************************************************************************/

    public int opApply ( int delegate ( ref char[] x ) dg )
    {
        int result = 0;

        foreach ( key, val; this.properties )
        {
            result = dg(key);

            if ( result ) break;
        }

        return result;
    }


    /***************************************************************************

        Reset the parser internal state

    ***************************************************************************/

    public void resetParser ( )
    {
        this.value = "";
        this.category = "";
        this.key = "";
        this.multiline_first = true;
    }


    /***************************************************************************

        Read Config File

        Reads the content of the configuration file and copies to a static
        array buffer.

        Each property in the ini file belongs to a category. A property always
        has a key and a value associated with the key. The function parses the
        following different elements:

        i. Categories
        [Example Category]

        ii. Comments
        // comments start with two slashes,
        ;  a semi-colon
        #  or a hash

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

        Params:
            filePath = string that contains the path to the configuration file
            clean_old = true if old values should be cleared before starting

    ***************************************************************************/

    public void parse ( char[] filePath = "etc/config.ini",
            bool clean_old = true )
    {
        this.configFile = filePath;

        if ( clean_old )
        {
            this.resetParser();
            this.properties = null;
        }

        foreach ( line; new Lines!(char) (new File(this.configFile)) )
        {
            this.parseLine(line);
        }
    }


    /***************************************************************************

        Parse a string

        See parse() for details on the parsed syntax.

        Usage Example:

        ---

            Config.parseString(
                "[section]\n"
                "key = value1\n"
                "      value2\n"
                "      value3\n"
            );

        ---

        Params:
            str = string to parse

    ***************************************************************************/

    public void parseString ( char[] str )
    {
        foreach ( line; splitLines(str) )
        {
            this.parseLine(line);
        }
    }


    /***************************************************************************

        Parse a line

        See parse() for details on the parsed syntax. This method only makes
        sense to do partial parsing of a string.

        Usage Example:

        ---

            Config.parseLine("[section]");
            Config.parseLine("key = value1\n");
            Config.parseLine("      value2\n");
            Config.parseLine("      value3\n");

        ---

        FIXME: this method does a fair bit of 'new'ing and '.dup'ing. If we ever
        need to repeatedly read a config file, this should be reworked.

        Params:
            line = line to parse

    ***************************************************************************/

    public void parseLine ( char[] line )
    {
        this.value = trim(line);

        if ( this.value.length ) // ignore empty lines
        {
            bool slash_comment     = this.value.length >= 2 && this.value[0 .. 2] == "//";
            bool hash_comment      = this.value[0] == '#';
            bool semicolon_comment = this.value[0] == ';';

            if ( !slash_comment && !semicolon_comment && !hash_comment ) // ignore comments
            {
                int pos = locate(this.value, '['); // category present in line?

                if ( pos == 0 )
                {
                    this.category = this.value[pos + 1 .. locate(this.value, ']')].dup;

                    this.key = "";
                }
                else
                {
                    pos = locate(this.value, '='); // check for key value pair

                    if ( pos < this.value.length )
                    {
                        this.key = trim(this.value[0 .. pos]).dup;

                        this.value = trim(this.value[pos + 1 .. $]).dup;

                        this.properties[this.category][this.key] = this.value;
                        multiline_first = !this.value.length;
                    }
                    else
                    {
                        this.value = trim(this.value).dup;

                        if ( this.value.length )
                        {
                            if ( ! multiline_first )
                            {
                                this.properties[this.category][this.key] ~= '\n';
                            }

                            this.properties[this.category][this.key] ~= this.value;

                            multiline_first = false;
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
        return this.properties.length == 0;
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
        return (category in this.properties) && (key in this.properties[category]);
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
                                   "Critical Error: No configuration key "
                                   "'" ~ category ~ ":" ~ key ~ "' found");
        try
        {
            char[] property = this.properties[category][key];

            return conv!(T)(property);
        }
        catch ( IllegalArgumentException )
        {
            ConfigException("Critical Error: Configuration key '" ~ category ~
            ":" ~ key ~ "' appears not to be of type '" ~ T.stringof ~ "'");
        }

        assert(0);
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
        auto value = this.getStrict!(char[])(category, key);
        T[] r;
        foreach ( elem; delimit(value, "\n") )
        {
            r ~= this.conv!(T)(elem);
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
        this.properties[category][key] = value;
    }


    /***************************************************************************

         Prints the current configuration to the given formatted text stream.

         Note that no guarantees can be made about the order of the categories
         or the order of the key-value pairs within each category.

         Params:
             output = formatted text stream in which to print the configuration
                      (defaults to Stdout)

    ***************************************************************************/

    public void print ( FormatOutput!(char) output = Stdout )
    {
        foreach ( key, val; this.properties )
        {
            output.formatln("{} = {}\n", key, val);
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
            if ( property == id[0] ) return false;
            if ( property == id[1] ) return true;
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

    private static T conv ( T ) ( char[] property )
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



/*******************************************************************************

    Unittest

*******************************************************************************/


private import ocean.util.Unittest;

unittest
{
    scope t = new Unittest(__FILE__, "ConfigParserTest");

    scope Config = new ConfigParser();

    with (t)
    {
        auto str =
`
[Section1]
multiline = a
# unittest comment
b
; comment with a different style in multiline
c
// and the ultimative comment
d
int_arr = 30
          40
          -60
          1111111111
          0x10
ulong_arr = 0
            50
            18446744073709551615
            0xa123bcd
float_arr = 10.2
            -25.3
            90
            0.000000001
bool_arr = true
           false
`;


        Config.parseString(str);

        scope l = Config.getListStrict("Section1", "multiline");

        assertLog(l.length == 4, "Multiline value has more elements than"
                                 "expected", __LINE__);

        assertLog(l[0] == "a" && l[1] == "b" && l[2] == "c" && l[3] == "d",
                "Multiline value was not parsed as expected", __LINE__);

        scope ints = Config.getListStrict!(int)("Section1", "int_arr");
        assertLog(ints == [30, 40, -60, 1111111111, 0x10], "Wrong multi-line "
                                                 "int-array parsing", __LINE__);

        scope ulong_arr = Config.getListStrict!(ulong)("Section1", "ulong_arr");
        ulong[] ulong_array = [0, 50, ulong.max, 0xa123bcd];
        assertLog(ulong_arr == ulong_array, "Wrong multi-line ulong-array "
                                            "parsing", __LINE__);

        scope float_arr = Config.getListStrict!(float)("Section1", "float_arr");
        float[] float_array = [10.2, -25.3, 90, 0.000000001];
        assertLog(float_arr == float_array, "Wrong multi-line float-array "
                                            "parsing", __LINE__);

        scope bool_arr = Config.getListStrict!(bool)("Section1", "bool_arr");
        bool[] bool_array = [true, false];
        assertLog(bool_arr == bool_array, "Wrong multi-line bool-array "
                                          "parsing", __LINE__);

        debug ( ConfigParser )
        {
            Config.print();
        }

        Config.resetParser();
    }
}

