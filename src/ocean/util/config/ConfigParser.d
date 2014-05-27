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

        Immediate context of the current line being parsed

    ***************************************************************************/

    private struct ParsingContext
    {
        /***************************************************************************

          Current category being parsed

         ***************************************************************************/

        char[] category;


        /***************************************************************************

          Current key being parsed

         ***************************************************************************/

        char[] key;


        /***************************************************************************

          Current value being parsed

         ***************************************************************************/

        char[] value;


        /***************************************************************************

          True if we are at the first multiline value when parsing

         ***************************************************************************/

        bool multiline_first = true;
    }

    private ParsingContext context;


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
        auto ctx = &this.context;

        ctx.value           = "";
        ctx.category        = "";
        ctx.key             = "";
        ctx.multiline_first = true;
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
        auto ctx = &this.context;

        ctx.value = trim(line);

        if ( ctx.value.length == 0 )
        {
            // Ignore empty lines.
            return;
        }

        bool slash_comment = ctx.value.length >= 2 && ctx.value[0 .. 2] == "//";
        bool hash_comment = ctx.value[0] == '#';
        bool semicolon_comment = ctx.value[0] == ';';

        if ( slash_comment || semicolon_comment || hash_comment )
        {
            // Ignore comment lines.
            return;
        }

        int pos = locate(ctx.value, '['); // category present in line?

        if ( pos == 0 )
        {
            ctx.category = ctx.value[pos + 1 .. locate(ctx.value, ']')].dup;

            ctx.key = "";
        }
        else
        {
            pos = locate(ctx.value, '='); // check for key value pair

            if ( pos < ctx.value.length )
            {
                ctx.key = trim(ctx.value[0 .. pos]).dup;

                ctx.value = trim(ctx.value[pos + 1 .. $]).dup;

                this.properties[ctx.category][ctx.key] = ctx.value;
                ctx.multiline_first = !ctx.value.length;
            }
            else
            {
                ctx.value = trim(ctx.value).dup;

                if ( ctx.value.length )
                {
                    if ( ! ctx.multiline_first )
                    {
                        this.properties[ctx.category][ctx.key] ~= '\n';
                    }

                    this.properties[ctx.category][ctx.key] ~= ctx.value;

                    ctx.multiline_first = false;
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

version ( UnitTest )
{
    private import ocean.util.Unittest;

    private import tango.core.Memory;
}

unittest
{
    scope t = new Unittest(__FILE__, "ConfigParserTest");

    scope Config = new ConfigParser();

    with (t)
    {
        /***********************************************************************

            Section 1: unit-tests to confirm correct parsing of config files

        ***********************************************************************/

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

        assertLog(Config.isEmpty == false,
                  "Config is incorrectly marked as being empty", __LINE__);

        scope l = Config.getListStrict("Section1", "multiline");

        assertLog(l.length == 4,
                  "Incorrect number of elements in multiline", __LINE__);

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

        try
        {
            scope w_bool_arr = Config.getListStrict!(bool)("Section1",
                                                           "int_arr");
        }
        catch ( IllegalArgumentException e )
        {
            assertLog((e.msg == "Config.toBool :: invalid boolean value"),
                      "invalid conversion to bool "
                      "was not reported as a problem", __LINE__);
        }

        // Manually set a property (new category).
        Config.set("Section2", "set_key", "set_value");

        char[] new_val;
        Config.getStrict(new_val, "Section2", "set_key");
        assertLog(new_val == "set_value",
                  "New value not added correctly", __LINE__);

        // Manually set a property (existing category, new key).
        Config.set("Section2", "another_set_key", "another_set_value");

        Config.getStrict(new_val, "Section2", "another_set_key");
        assertLog(new_val == "another_set_value",
                  "New value not added correctly", __LINE__);

        // Manually set a property (existing category, existing key).
        Config.set("Section2", "set_key", "new_set_value");

        Config.getStrict(new_val, "Section2", "set_key");
        assertLog(new_val == "new_set_value",
                  "New value not added correctly", __LINE__);

        // Check if the 'exists' function works as expected.
        assertLog( Config.exists("Section1", "int_arr"),
                  "exists API failure", __LINE__);
        assertLog(!Config.exists("Section420", "int_arr"),
                  "exists API failure", __LINE__);
        assertLog(!Config.exists("Section1", "key420"),
                  "exists API failure", __LINE__);

        debug ( ConfigParser )
        {
            Config.print();
        }


        /***********************************************************************

            Section 2: unit-tests to confirm correct working of iterators

        ***********************************************************************/

        char[][] expected_categories = [ "Section1",
                                         "Section2" ];
        char[][] expected_keys = [ "multiline",
                                   "int_arr",
                                   "ulong_arr",
                                   "float_arr",
                                   "bool_arr",

                                   "set_key",
                                   "another_set_key" ];
        char[][] obtained_categories;
        char[][] obtained_keys;

        foreach ( category; Config )
        {
            obtained_categories ~= category;

            foreach ( key; Config.iterateCategory(category) )
            {
                obtained_keys ~= key;
            }
        }

        assertLog(obtained_categories.sort == expected_categories.sort,
                  "category iteration failure", __LINE__);
        assertLog(obtained_keys.sort == expected_keys.sort,
                  "key iteration failure", __LINE__);


        /***********************************************************************

            Section 3: unit-tests to check memory usage

            this entire section is inside a conditional compilation block as it
            does console output meant for human interpretation

        ***********************************************************************/

        debug ( ConfigParser )
        {
            const num_parses = 200;

            // Repeated parsing of the same configuration.

            Stdout.blue.formatln("Memory analysis of repeated parsing of the "
                                 "same configuration").default_colour;

            size_t memused1, memused2, memfree;

            GC.usage(memused1, memfree);
            Stdout.formatln("before parsing  : memused = {}", memused1);

            Config.parseString(str);

            GC.usage(memused2, memfree);
            Stdout.formatln("after parse # 1 : memused = {} (additional mem "
                            "consumed = {})", memused2, (memused2 - memused1));

            memused1 = memused2;

            for (int i = 2; i < num_parses; ++i)
            {
                Config.parseString(str);
            }

            GC.usage(memused2, memfree);
            Stdout.formatln("after parse # {} : memused = {} (additional mem "
                            "consumed = {})", num_parses, memused2,
                            (memused2 - memused1));
            Stdout.formatln("");
        }

        Config.resetParser();
    }
}

