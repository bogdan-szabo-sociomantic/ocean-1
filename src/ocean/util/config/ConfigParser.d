/*******************************************************************************

    Load Configuration from Config File

    copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.config.ConfigParser;


/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array : copy;

public  import ocean.core.Exception : enforce;

private import ocean.io.Stdout;

private import tango.io.device.File;

private import tango.io.stream.Lines;

private import tango.io.stream.Format;

private import tango.text.convert.Integer: toLong;

private import tango.text.convert.Float: toFloat;

private import tango.text.convert.Format;

private import tango.text.Util: locate, trim, delimit, lines;

private import tango.text.convert.Utf;

private import tango.core.Exception;

private import tango.core.Traits : DynamicArrayType;



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
        Config.parseFile("etc/my_config.ini");

        // Read a single value
        char[] value = Config.Char["category", "key"];

        // Set a single value
        Config.set("category", "key", "new value");

        // Read a multi-line value
        char[][] values = Config.getListStrict("category", "key");

    ---

    The parseFile() method only needs to be called once, though may be called
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
        ValueNode[char[]]* vars;


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
        /***********************************************************************

          Current category being parsed

        ***********************************************************************/

        char[] category;


        /***********************************************************************

          Current key being parsed

        ***********************************************************************/

        char[] key;


        /***********************************************************************

          Current value being parsed

        ***********************************************************************/

        char[] value;


        /***********************************************************************

          True if we are at the first multiline value when parsing

        ***********************************************************************/

        bool multiline_first = true;
    }

    private ParsingContext context;


    /***************************************************************************

        Structure representing a single value node in the configuration.

    ***************************************************************************/

    private struct ValueNode
    {
        /***********************************************************************

            The actual value.

        ***********************************************************************/

        char[] value;


        /***********************************************************************

            Flag used to allow a config file to be parsed, even when a different
            configuration has already been parsed in the past.

            At the start of every new parse, the flags of all value nodes in an
            already parsed configuration are set to false. If this value node is
            found during the parse, its flag is set to true. All new value nodes
            added will also have the flag set to true. At the end of the parse,
            all value nodes that have the flag set to false are removed.

        **********************************************************************/

        bool present_in_config;
    }


    /***************************************************************************

        Config Keys and Properties

    ***************************************************************************/

    alias char[] String;
    private ValueNode[String][String] properties;


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
        this.parseFile(config);
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

            Config.parseFile("etc/config.ini");

        ---

        Params:
            filePath = string that contains the path to the configuration file
            clean_old = true if the existing configuration should be overwritten
                        with the result of the current parse, false if the
                        current parse should only add to or update the existing
                        configuration. (defaults to true)

    ***************************************************************************/

    public void parseFile ( char[] filePath = "etc/config.ini",
                            bool clean_old = true )
    {
        this.configFile = filePath;

        auto get_line = new Lines!(char) (new File(this.configFile));

        this.parseIter(get_line, clean_old);
    }

    deprecated alias parseFile parse;


    /***************************************************************************

        Parse a string

        See parseFile() for details on the parsed syntax.

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
            clean_old = true if the existing configuration should be overwritten
                        with the result of the current parse, false if the
                        current parse should only add to or update the existing
                        configuration. (defaults to true)

    ***************************************************************************/

    public void parseString ( char[] str, bool clean_old = true )
    {
        int get_line ( int delegate ( ref char[] x ) dg )
        {
            int result = 0;

            foreach ( ref line; lines(str) )
            {
                result = dg(line);

                if ( result ) break;
            }

            return result;
        }

        this.parseIter(&get_line, clean_old);
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
            category = category in which to look for the key
            key      = key to be checked

        Returns:
            true if the configuration key exists in this category

    ***************************************************************************/

    public bool exists ( char[] category, char[] key )
    {
        return ((category in this.properties) &&
                (key in this.properties[category]));
    }


    /***************************************************************************

        Strict method to get the value of a config key. If the requested key
        cannot be found, an exception is thrown.

        Template can be instantiated with integer, float or string (char[])
        type.

        Usage Example:

        ---

            Config.parseFile("some-config.ini");
            // throws if not found
            auto str = Config.getStrict!(char[])("some-cat", "some-key");
            auto n = Config.getStrict!(int)("some-cat", "some-key");

        ---

        Params:
            category = category to get key from
            key = key whose value is to be got

        Throws:
            if the specified key does not exist

        Returns:
            value of a configuration key, or null if none

    ***************************************************************************/

    public T getStrict ( T ) ( char[] category, char[] key )
    {
        enforce!(ConfigException)(
            exists(category, key),
            Format("Critical Error: No configuration key '{}:{}' found",
                   category, key)
        );
        try
        {
            auto value_node = this.properties[category][key];

            return conv!(T)(value_node.value);
        }
        catch ( IllegalArgumentException )
        {
            throw new ConfigException(
                          Format("Critical Error: Configuration key '{}:{}' "
                                 "appears not to be of type '{}'",
                                 category, key, T.stringof));
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

            Config.parseFile("some-config.ini");
            // throws if not found
            char[] str;
            int n;

            Config.getStrict(str, "some-cat", "some-key");
            Config.getStrict(n, "some-cat", "some-key");

        ---

        Params:
            value = output for config value
            category = category to get key from
            key = key whose value is to be got

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

            Config.parseFile("some-config.ini");
            char[] str = Config.get("some-cat", "some-key", "my_default_value");
            int n = Config.get("some-cat", "some-int", 5);

        ---

        Params:
            category = category to get key from
            key = key whose value is to be got
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

            Config.parseFile("some-config.ini");
            char[] str;
            int n;

            Config.get(str, "some-cat", "some-key", "default value");
            Config.get(n, "some-cat", "some-key", 23);

        ---

        Params:
            value = output for config value
            category = category to get key from
            key = key whose value is to be got
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
            category = category to get key from
            key = key whose value is to be got

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
            category = category to get key from
            key = key whose value is to be got
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

            Config.parseFile(`etc/config.ini`);

            Config.set(`category`, `key`, `value`);

        ---

        Params:
            category = category to be set
            key      = key to be set
            value    = value of the property

    ***************************************************************************/

    public void set ( char[] category, char[] key, char[] value )
    {
        if ( category == "" || key == "" || value == "" )
        {
            return;
        }

        if ( this.exists(category, key) )
        {
            (this.properties[category][key]).value = value;
        }
        else
        {
            ValueNode value_node = { value, true };

            this.properties[category][key] = value_node;
        }
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
        foreach ( category, key_value_pairs; this.properties )
        {
            output.formatln("{}", category);

            foreach ( key, value_node; key_value_pairs )
            {
                output.formatln("    {} = {}", key, value_node.value);
            }
        }
    }


    /***************************************************************************

        Actually performs parsing of the lines of a config file or a string.
        Each line to be parsed is obtained via an iterator.

        Template Params:
            I = type of the iterator that will supply lines to be parsed

        Params:
            iter = iterator that will supply lines to be parsed
            clean_old = true if the existing configuration should be overwritten
                        with the result of the current parse, false if the
                        current parse should only add to or update the existing
                        configuration.

    ***************************************************************************/

    private void parseIter ( I ) ( I iter, bool clean_old )
    {
        this.clearParsingContext();

        if ( clean_old )
        {
            this.clearAllValueNodeFlags();
        }

        foreach ( ref char[] line; iter )
        {
            this.parseLine(line);
        }

        this.saveFromParsingContext();

        this.pruneConfiguration();

        this.clearParsingContext();
    }


    /***************************************************************************

        Converts a string to a boolean value. The following string values are
        accepted:

            false / true, disabled / enabled, off / on, no / yes, 0 / 1

        Params:
            property = string to extract boolean value from

        Throws:
            if the string does not match one of the possible boolean strings

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

        throw new IllegalArgumentException(
                                      "Config.toBool :: invalid boolean value");
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
        else static assert(false,
                           Format("{} : get(): type '{}' is not supported",
                                  __FILE__, T.stringof));
    }


    /***************************************************************************

        Saves the current contents of the context into the configuration.

    ***************************************************************************/

    private void saveFromParsingContext ( )
    {
        auto ctx = &this.context;

        if ( ctx.category.length == 0 ||
             ctx.key.length == 0 ||
             ctx.value.length == 0 )
        {
            return;
        }

        if ( this.exists(ctx.category, ctx.key) )
        {
            ValueNode * value_node = &this.properties[ctx.category][ctx.key];

            if ( value_node.value != ctx.value )
            {
                value_node.value.copy(ctx.value);
            }

            value_node.present_in_config = true;
        }
        else
        {
            ValueNode value_node = { ctx.value.dup, true };

            this.properties[ctx.category.dup][ctx.key.dup] = value_node;
        }

        ctx.value.length = 0;
    }


    /***************************************************************************

        Clears the 'present_in_config' flags associated with all value nodes in
        the configuration.

    ***************************************************************************/

    private void clearAllValueNodeFlags ( )
    {
        foreach ( category, key_value_pairs; this.properties )
        {
            foreach ( key, ref value_node; key_value_pairs )
            {
                value_node.present_in_config = false;
            }
        }
    }


    /***************************************************************************

        Prunes the configuration removing all keys whose value nodes have the
        'present_in_config' flag set to false. Also removes all categories that
        have no keys.

    ***************************************************************************/

    private void pruneConfiguration ( )
    {
        char[][] keys_to_remove;
        char[][] categories_to_remove;

        // Remove obsolete keys

        foreach ( category, ref key_value_pairs; this.properties )
        {
            foreach ( key, value_node; key_value_pairs )
            {
                if ( ! value_node.present_in_config )
                {
                    keys_to_remove ~= key;
                }
            }

            foreach ( key; keys_to_remove )
            {
                key_value_pairs.remove(key);
            }

            keys_to_remove.length = 0;
        }

        // Remove categories that have no keys

        foreach ( category, key_value_pairs; this.properties )
        {
            if ( key_value_pairs.length == 0 )
            {
                categories_to_remove ~= category;
            }
        }

        foreach ( category; categories_to_remove )
        {
            this.properties.remove(category);
        }
    }


    /***************************************************************************

        Clears the current parsing context.

    ***************************************************************************/

    private void clearParsingContext ( )
    {
        auto ctx = &this.context;

        ctx.value.length    = 0;
        ctx.category.length = 0;
        ctx.key.length      = 0;
        ctx.multiline_first = true;
    }


    /***************************************************************************

        Parse a line

        See parseFile() for details on the parsed syntax. This method only makes
        sense to do partial parsing of a string.

        Usage Example:

        ---

            Config.parseLine("[section]");
            Config.parseLine("key = value1\n");
            Config.parseLine("      value2\n");
            Config.parseLine("      value3\n");

        ---

        Params:
            line = line to parse

    ***************************************************************************/

    private void parseLine ( char[] line )
    {
        auto ctx = &this.context;

        line = trim(line);

        if ( line.length == 0 )
        {
            // Ignore empty lines.
            return;
        }

        bool slash_comment = line.length >= 2 && line[0 .. 2] == "//";
        bool hash_comment = line[0] == '#';
        bool semicolon_comment = line[0] == ';';

        if ( slash_comment || semicolon_comment || hash_comment )
        {
            // Ignore comment lines.
            return;
        }

        int pos = locate(line, '['); // category present in line?

        if ( pos == 0 )
        {
            this.saveFromParsingContext();

            auto cat = line[pos + 1 .. locate(line, ']')];

            // XXX: This code should be adapted to remove the warning at some
            //      point (introduced on Tue Oct 21 18:07:51 CEST 2014)
            auto trimmed_cat = trim(cat);

            if ( trimmed_cat != cat && this._warn_trimmed_categories )
            {
                Stderr.yellow;
                Stderr.formatln("Warning: Category name '{}' will be " ~
                        "trimmed, becoming '{}' instead.", cat, trimmed_cat);
                Stderr.formatln("         Please update your configuration " ~
                        "file to omit the spaces for now, until this " ~
                        "warning is disabled.");
                Stderr.default_colour.flush;
            }

            ctx.category.copy(trimmed_cat);

            ctx.key.length = 0;
        }
        else
        {
            pos = locate(line, '='); // check for key value pair

            if ( pos < line.length )
            {
                this.saveFromParsingContext();

                ctx.key.copy(trim(line[0 .. pos]));

                ctx.value.copy(trim(line[pos + 1 .. $]));

                ctx.multiline_first = !ctx.value.length;
            }
            else
            {
                if ( ! ctx.multiline_first )
                {
                    ctx.value ~= '\n';
                }

                ctx.value ~= line;

                ctx.multiline_first = false;
            }
        }
    }

    // XXX: This should be removed at some point, it was introduced on
    //      Tue Oct 21 18:07:51 CEST 2014 to warn about trimmed categories while
    //      parsing lines. Should only be disabled (set to false) to silence
    //      output during tests.
    public bool _warn_trimmed_categories = true;
}



/*******************************************************************************

    Unittest

*******************************************************************************/

version ( UnitTest )
{
    private import ocean.core.Test;
    private import tango.core.Memory;
}

unittest
{
    struct ConfigSanity
    {
        uint num_categories;

        char[][] categories;

        char[][] keys;
    }

    void parsedConfigSanityCheck ( ConfigParser config, ConfigSanity expected,
                                   char[] test_name )
    {
        auto t = new NamedTest(test_name);
        char[][] obtained_categories;
        char[][] obtained_keys;

        t.test(config.isEmpty == (expected.num_categories == 0),
               "emptiness error");

        foreach ( category; config )
        {
            obtained_categories ~= category;

            foreach ( key; config.iterateCategory(category) )
            {
                obtained_keys ~= key;
            }
        }

        t.test(obtained_categories.length == expected.num_categories,
               "mismatch in number of categories");

        t.test(obtained_categories.sort == expected.categories.sort,
               "mismatch in categories");

        t.test(obtained_keys.sort == expected.keys.sort,
               "mismatch in keys");
    }

    scope Config = new ConfigParser();

    // XXX: This should be removed at some point, it was introduced on
    //      Tue Oct 21 18:07:51 CEST 2014 to skip the warning about trimmed
    //      categories while parsing lines in tests.
    Config._warn_trimmed_categories = false;

    /***************************************************************************

        Section 1: unit-tests to confirm correct parsing of config files

    ***************************************************************************/

    auto str1 =
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
    ConfigSanity str1_expectations =
        { 1,
          [ "Section1" ],
          [ "multiline", "int_arr", "ulong_arr", "float_arr", "bool_arr" ]
        };

    Config.parseString(str1);
    parsedConfigSanityCheck(Config, str1_expectations, "basic string");

    scope l = Config.getListStrict("Section1", "multiline");

    test(l.length == 4, "Incorrect number of elements in multiline");

    test(l[0] == "a" && l[1] == "b" && l[2] == "c" && l[3] == "d",
         "Multiline value was not parsed as expected");

    scope ints = Config.getListStrict!(int)("Section1", "int_arr");
    test(ints == [30, 40, -60, 1111111111, 0x10],
         "Wrong multi-line int-array parsing");

    scope ulong_arr = Config.getListStrict!(ulong)("Section1", "ulong_arr");
    ulong[] ulong_array = [0, 50, ulong.max, 0xa123bcd];
    test(ulong_arr == ulong_array, "Wrong multi-line ulong-array parsing");

    scope float_arr = Config.getListStrict!(float)("Section1", "float_arr");
    float[] float_array = [10.2, -25.3, 90, 0.000000001];
    test(float_arr == float_array, "Wrong multi-line float-array parsing");

    scope bool_arr = Config.getListStrict!(bool)("Section1", "bool_arr");
    bool[] bool_array = [true, false];
    test(bool_arr == bool_array, "Wrong multi-line bool-array parsing");

    try
    {
        scope w_bool_arr = Config.getListStrict!(bool)("Section1", "int_arr");
    }
    catch ( IllegalArgumentException e )
    {
        test((e.msg == "Config.toBool :: invalid boolean value"),
             "invalid conversion to bool was not reported as a problem");
    }

    // Manually set a property (new category).
    Config.set("Section2", "set_key", "set_value");

    char[] new_val;
    Config.getStrict(new_val, "Section2", "set_key");
    test(new_val == "set_value", "New value not added correctly");

    // Manually set a property (existing category, new key).
    Config.set("Section2", "another_set_key", "another_set_value");

    Config.getStrict(new_val, "Section2", "another_set_key");
    test(new_val == "another_set_value", "New value not added correctly");

    // Manually set a property (existing category, existing key).
    Config.set("Section2", "set_key", "new_set_value");

    Config.getStrict(new_val, "Section2", "set_key");
    test(new_val == "new_set_value", "New value not added correctly");

    // Check if the 'exists' function works as expected.
    test( Config.exists("Section1", "int_arr"), "exists API failure");
    test(!Config.exists("Section420", "int_arr"), "exists API failure");
    test(!Config.exists("Section1", "key420"), "exists API failure");

    ConfigSanity new_str1_expectations =
        { 2,
          [ "Section1", "Section2" ],
          [ "multiline", "int_arr", "ulong_arr", "float_arr", "bool_arr",
            "set_key", "another_set_key" ]
        };
    parsedConfigSanityCheck(Config, new_str1_expectations, "modified string");

    // Whitespaces handling

    char[] white_str =
`
[ Section1 ]
key = val
`;
    ConfigSanity white_str_expectations =
        { 1,
          [ "Section1" ],
          [ "key" ]
        };

    Config.parseString(white_str);
    parsedConfigSanityCheck(Config, white_str_expectations, "white spaces 1");

    white_str =
`
[Section1 ]
key = val
`;
    Config.parseString(white_str);
    parsedConfigSanityCheck(Config, white_str_expectations, "white spaces 2");

    white_str =
`
[	       Section1]
key = val
`;
    Config.parseString(white_str);
    parsedConfigSanityCheck(Config, white_str_expectations, "white spaces 3");

    white_str =
`
[Section1]
key =		   val
`;
    Config.parseString(white_str);
    parsedConfigSanityCheck(Config, white_str_expectations, "white spaces 4");

    white_str =
`
[Section1]
key	     = val
`;
    Config.parseString(white_str);
    parsedConfigSanityCheck(Config, white_str_expectations, "white spaces 5");

    white_str =
`
[Section1]
	  key	     = val
`;
    Config.parseString(white_str);
    parsedConfigSanityCheck(Config, white_str_expectations, "white spaces 6");

    white_str =
`
[	       Section1   ]
	  key	     =		       val
`;
    Config.parseString(white_str);
    parsedConfigSanityCheck(Config, white_str_expectations, "white spaces 6");

    // Parse a new configuration

    auto str2 =
`
[German]
one = eins
two = zwei
three = drei
[Hindi]
one = ek
two = do
three = teen
`;
    ConfigSanity str2_expectations =
        { 2,
          [ "German", "Hindi" ],
          [ "one", "two", "three", "one", "two", "three" ],
        };

    Config.parseString(str2);
    parsedConfigSanityCheck(Config, str2_expectations, "new string");


    /***************************************************************************

        Section 2: unit-tests to check memory usage

    ***************************************************************************/

    // Test to ensure that an additional parse of the same configuration does
    // not allocate at all.

    size_t memused1, memused2, memfree;

    Config.parseString(str2);
    GC.usage(memused1, memfree);
    Config.parseString(str2);
    GC.usage(memused2, memfree);
    test!("==")(memused1, memused2);

    debug ( ConfigParser )
    {
        const num_parses = 200;

        // Repeated parsing of the same configuration.

        Stdout.blue.formatln("Memory analysis of repeated parsing of the same "
                             "configuration").default_colour;

        GC.usage(memused1, memfree);
        Stdout.formatln("before parsing  : memused = {}", memused1);

        Config.parseString(str1);

        GC.usage(memused2, memfree);
        Stdout.formatln("after parse # 1 : memused = {} (additional mem "
                        "consumed = {})", memused2, (memused2 - memused1));

        memused1 = memused2;

        for (int i = 2; i < num_parses; ++i)
        {
            Config.parseString(str1);
        }

        GC.usage(memused2, memfree);
        Stdout.formatln("after parse # {} : memused = {} (additional mem "
                        "consumed = {})", num_parses, memused2,
                        (memused2 - memused1));
        Stdout.formatln("");
    }

    Config.clearParsingContext();
}

