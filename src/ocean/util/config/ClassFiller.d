/*******************************************************************************

    Provides convenient functions to fill the values of a given class

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        November 2011

    authors:        Mathias Baumann

    Provides functions that use a given source (by default the global Config
    instance) to fill the member variables of a provided or newly
    created instance of a given class.

    The provided class can use certain wrappers to add conditions or
    informations to the variable in question. The value of a wrapped variable
    can be accessed using the opCall syntax "variable()"

    Overview of available wrappers:

    * Required  — This variable has to be set in the configuration file
                  Example:  Required!(char[]) nodes_config;
    * MinMax    — This numeric variable has to be within the specified range
                  Example: MinMax!(long, -10, 10) range;
    * Min       — This numeric variable has to be >= the specified value
                  Example: Min!(int, -10) min_range;
    * Max       — This numeric variable has to be <= the specified value
                  Example: Max!(int, 20) max_range;
    * LimitCmp  — This variable must be one of the given values. To compare the
                  config value with the given values, the given function will be
                  used
                  Example:  LimitCmp!(char[], "red", defComp!(char[]),
                                      "red", "green", "blue", "yellow") color;
    * LimitInit — This variable must be one of the given values, it will default
                  to the given value.
                  Example: LimitInit!(char[], "red", "red", "green") color;
    * Limit     — This variable must be one of the given values
                  Example: Limit!(char[], "up", "down", "left", "right") dir;
    * SetInfo   — the 'set' member can be used to query whether this
                  variable was set from the configuration file or not
                  Example: SetInfo!(bool) enable; // enable.set

    Use debug=Config to get a printout of all the configuration options

    Config file for the example below:
    -------
    [Example.FirstGroup]
    number = 1
    required_string = SET
    was_this_set = "there, I set it!"
    limited = 20

    [Example.SecondGroup]
    number = 2
    required_string = SET_AGAIN

    [Example.ThirdGroup]
    number = 3
    required_string = SET
    was_this_set = "arrr"
    limited = 40
    -------

    Usage Example:
    -------
    import Class = ocean.util.config.ClassFiller;
    import ocean.util.Config;
    import ocean.util.log.Trace;

    class ConfigParameters
    {
        int number;
        Required!(char[]) required_string;
        SetInfo!(char[]) was_this_set;
        Required!(MinMax!(size_t, 1, 30)) limited;
        Limit!(char[], "one", "two", "three") limited_set;
        LimitInit!(char[], "one", "one", "two", "three") limited_set_with_default;
    }

    void main ( char[][] argv )
    {
        Config.parse(argv[1]);

        auto iter = Class.iterate!(ConfigParameters)("Example");

        foreach ( name, conf; iter ) try
        {
            // Outputs FirstGroup/SecondGroup/ThirdGroup
            Stdout.formatln("Group: {}", name);
            Stdout.formatln("Number: {}", conf.number);
            Stdout.formatln("Required: {}", conf.required_string());
            if ( conf.was_this_set.set )
            {
                Stdout.formatln("It was set! And the value is {}",
                was_this_set());
            }
            // If limited was not set, an exception will be thrown
            // If limited was set but is outside of the specified
            // range [1 .. 30], an exception will be thrown as well
            Stdout.formatln("Limited: {}", conf.limited());

            // If limited_set is not a value in the given set ("one", "two",
            // "three"), an exception will be thrown
            Stdout.formatln("Limited_set: {}", conf.limited_set());

            // If limited_set is not a value in the given set ("one", "two",
            // "three"), an exception will be thrown, if it is not set, it
            // defaults to "one"
            Stdout.formatln("Limited_set_with_default: {}",
                             conf.limited_set_with_default());
        }
        catch ( Exception e )
        {
            Stdout.formatln("Required parameter wasn't set: {}", e.msg);
        }
    }
    -------


*******************************************************************************/

module ocean.util.config.ClassFiller;


/*******************************************************************************

    Imports

*******************************************************************************/

public  import ocean.core.Exception: assertEx;

public import ocean.util.config.ConfigParser: ConfigException;

private import ocean.core.Traits;

private import tango.core.Exception;

private import tango.core.Traits;

private import ocean.util.Config;

private import ocean.util.config.ConfigParser;

private import ocean.util.log.Trace;

private import tango.util.Convert;

private import tango.core.Traits : DynamicArrayType, isStringType,
                                   isIntegerType, isRealType;

debug ( OceanUnitTest ) private import ocean.text.convert.Layout;

version (UnitTest) private import ocean.core.Test;

/*******************************************************************************

    Whether loose parsing is enabled or not.
    Loose parsing means, that variables that have no effect are allowed.

    States
        false = variables that have no effect cause an exception
        true  = variables that have no effect cause a stderr warning message

*******************************************************************************/

private bool loose_parsing = false;

/*******************************************************************************

    Evaluates to the original type with which a Wrapper Struct was initialised

    If T is not a struct, T itself is returned

    Template Params:
        T = struct or type to find the basetype for

*******************************************************************************/

template BaseType ( T )
{
    static if ( is(typeof(T.value)) )
    {
        alias BaseType!(typeof(T.value)) BaseType;
    }
    else
    {
        alias T BaseType;
    }
}

/*******************************************************************************

    Returns the value of the given struct/value.

    If value is not a struct, the value itself is returned

    Template Params:
        v = instance of a struct the value itself

*******************************************************************************/

BaseType!(T) Value ( T ) ( T v )
{
    static if ( is(T == BaseType!(typeof(v))) )
    {
        return v;
    }
    else
    {
        return Value(v.value);
    }
}

/*******************************************************************************

    Contains methods used in all WrapperStructs to access and set the value
    variable

    Template Params:
        T = type of the value

*******************************************************************************/

template WrapperStructCore ( T, T init = T.init )
{
    /***************************************************************************

        The value of the configuration setting

    ***************************************************************************/

    private T value = init;

    /***************************************************************************

        Returns the value that is wrapped

    ***************************************************************************/

    public BaseType!(T) opCall ( )
    {
        return Value(this.value);
    }

    /***************************************************************************

        Returns the value that is wrapped

    ***************************************************************************/

    public BaseType!(T) opCast ( )
    {
        return Value(this.value);
    }

    /***************************************************************************

        Sets the wrapped value to val

        Params:
            val = new value

        Returns:
            val

    ***************************************************************************/

    public BaseType!(T) opAssign ( BaseType!(T) val )
    {
        return value = val;
    }

    /***************************************************************************

        Calls check_() with the same parameters. If check doesn't throw an
        exception it checks whether the wrapped value is also a struct and if so
        its check function is called.

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

    ***************************************************************************/

    private void check ( bool found, char[] group, char[] name )
    {
        static if ( !is (BaseType!(T) == T) )
        {
            scope(success) this.value.check(found, group, name);
        }

        this.check_(found, group, name);
    }
}

/*******************************************************************************

    Configuration settings that are mandatory can be marked as such by
    wrapping them with this template.
    If the variable is not set, then an exception is thrown.

    The value can be accessed with the opCall method

    Template Params:
        T = the original type of the variable

*******************************************************************************/

struct Required ( T )
{
    mixin WrapperStructCore!(T);

    /***************************************************************************

        Checks whether the checked value was found, throws if not

        Params:
            found = whether the variable was found in the configuration
            group = group the variable appeares in
            name  = name of the variable

        Throws:
            ConfigException

    ***************************************************************************/

    private void check_ ( bool found, char[] group, char[] name )
    {
        if ( !found )
        {
            throw new ConfigException("Mandatory variable " ~ group ~
                                      "." ~ name ~
                                      " not set", __FILE__, __LINE__);
        }
    }
}

/*******************************************************************************

    Configuration settings that are required to be within a certain numeric
    range can be marked as such by wrapping them with this template.

    If the value is outside the provided range, an exception is thrown.

    The value can be accessed with the opCall method

    Template Params:
        T    = the original type of the variable (can be another struct)
        min  = smallest allowed value
        max  = biggest allowed value
        init = default value when it is not given in the configuration file

*******************************************************************************/

struct MinMax ( T, T min, T max, T init = T.init )
{
    mixin WrapperStructCore!(T, init);

     /***************************************************************************

        Checks whether the configuration value is bigger than the smallest
        allowed value and smaller than the biggest allowed value.
        If not, an exception is thrown

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

        Throws:
            ConfigException

    ***************************************************************************/

    private void check_ ( bool found, char[] group, char[] name )
    {
        if ( Value(this.value) < min )
        {
            throw new ConfigException(
                                "Configuration key " ~ group ~ "." ~ name ~ " is smaller "
                                "than allowed minimum of " ~ ctfe_i2a(min),
                                __FILE__, __LINE__);
        }


        if ( Value(this.value) > max )
        {
            throw new ConfigException(
                                "Configuration key " ~ group ~ "." ~ name ~
                                " is bigger than allowed maximum of " ~ ctfe_i2a(max),
                                __FILE__, __LINE__);
        }
    }
}

/*******************************************************************************

    Configuration settings that are required to be within a certain numeric
    range can be marked as such by wrapping them with this template.

    If the value is outside the provided range, an exception is thrown.

    The value can be accessed with the opCall method

    Template Params:
        T    = the original type of the variable (can be another struct)
        min  = smallest allowed value
        init = default value when it is not given in the configuration file

*******************************************************************************/

struct Min ( T, T min, T init = T.init )
{
    mixin WrapperStructCore!(T, init);

     /***************************************************************************

        Checks whether the configuration value is bigger than the smallest
        allowed value. If not, an exception is thrown

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

        Throws:
            ConfigException

    ***************************************************************************/

    private void check_ ( bool found, char[] group, char[] name )
    {
        if ( Value(this.value) < min )
        {
            throw new ConfigException(
                    "Configuration key " ~ group ~ "." ~ name ~ " is smaller "
                    "than allowed minimum of " ~ ctfe_i2a(min),
                    __FILE__, __LINE__);
        }
    }
}


/*******************************************************************************

    Configuration settings that are required to be within a certain numeric
    range can be marked as such by wrapping them with this template.

    If the value is outside the provided range, an exception is thrown.

    The value can be accessed with the opCall method

    Template Params:
        T    = the original type of the variable (can be another struct)
        max  = biggest allowed value
        init = default value when it is not given in the configuration file

*******************************************************************************/

struct Max ( T, T max, T init = T.init )
{
    mixin WrapperStructCore!(T, init);

     /***************************************************************************

        Checks whether the configuration value is smaller than the biggest
        allowed value. If not, an exception is thrown

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

        Throws:
            ConfigException

    ***************************************************************************/

    private void check_ ( bool found, char[] group, char[] name )
    {
        if ( Value(this.value) > max )
        {
            throw new ConfigException(
                    "Configuration key " ~ group ~ "." ~ name ~ " is bigger "
                    "than allowed maximum of " ~ ctfe_i2a(max),
                    __FILE__, __LINE__);
        }
    }
}


/*******************************************************************************

    Default compare function, used with the LimitCmp struct/template

    Params:
        a = first value to compare
        b = second value to compare with

    Returns:
        whether a == b

*******************************************************************************/

bool defComp ( T ) ( T a, T b )
{
    return a == b;
}

/*******************************************************************************

    Configuration settings that are limited to a certain set of values can be
    marked as such by wrapping them with this template.

    If the value is not in the provided set, an exception is thrown.

    The value can be accessed with the opCall method

    Template Params:
        T    = the original type of the variable (can be another struct)
        init = default value when it is not given in the configuration file
        comp = compare function to be used to compare two values from the set
        Set  = tuple of values that are valid

*******************************************************************************/

struct LimitCmp ( T, T init = T.init, alias comp = defComp!(T), Set... )
{
    mixin WrapperStructCore!(T, init);

     /***************************************************************************

        Checks whether the configuration value is within the set of allowed
        values. If not, an exception is thrown

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

         Throws:
            ConfigException

    ***************************************************************************/

    private void check_ ( bool found, char[] group, char[] name )
    {
        if ( found == false ) return;

        foreach ( el ; Set )
        {
            static assert ( is ( typeof(el) : T ),
                    "Tuple contains incompatible types!" );

            if ( comp(Value(this.value), el) )
                return;
        }

        char[] allowed_vals;

        foreach ( el ; Set )
        {
            allowed_vals ~= ", " ~ to!(char[])(el);
        }

        throw new ConfigException(
                "Value '" ~ to!(char[])(Value(this.value)) ~ "' "
                "of configuration key " ~ group ~ "." ~ name ~ " "
                "is not within the set of allowed values "
                "(" ~ allowed_vals[2 ..$] ~ ")",
                __FILE__, __LINE__);
    }
}


unittest
{
    test(is(typeof({LimitCmp!(short, 1, defComp!(short), 0, 1) val; })));
    test(is(typeof({ LimitCmp!(char[], "", defComp!(char[]), "red", "green") val; })));
}

/*******************************************************************************

    Simplified version of LimitCmp that uses default comparison

    Template Params:
        T = type of the value
        init = default initial value if config value wasn't set
        Set = set of allowed values

*******************************************************************************/

template LimitInit ( T, T init = T.init, Set... )
{
    alias LimitCmp!(T, init, defComp!(T), Set) Limit;
}


/*******************************************************************************

    Simplified version of LimitCmp that uses default comparison and default
    initializer

    Template Params:
        T = type of the value
        Set = set of allowed values

*******************************************************************************/

template Limit ( T, Set... )
{
    alias LimitInit!(T, T.init, Set) Limit;
}


/*******************************************************************************

    Adds the information of whether the filler actually set the value
    or whether it was left untouched.

    Template Params:
        T = the original type

*******************************************************************************/

struct SetInfo ( T )
{
    mixin WrapperStructCore!(T);

    /***************************************************************************

        Query method for the value with optional default initializer

        Params:
            def = the value that should be used when it was not found in the
                  configuration

    ***************************************************************************/

    public BaseType!(T) opCall ( BaseType!(T) def = BaseType!(T).init )
    {
        if ( set )
        {
            return Value(this.value);
        }

        return def;
    }

    /***************************************************************************

        Whether this value has been set

    ***************************************************************************/

    public bool set;

     /***************************************************************************

        Sets the set attribute according to whether the variable appeared in
        the configuration or not

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

    ***************************************************************************/

    private void check_ ( bool found, char[] group, char[] name )
    {
        this.set = found;
    }
}


/*******************************************************************************

    Template that evaluates to true when T is a supported type

    Template Params:
        T = type to check for

*******************************************************************************/

public template IsSupported ( T )
{
    static if ( is(T : bool) )
    {
        const IsSupported = true;
    }
    else static if ( isIntegerType!(T) || isRealType!(T) )
    {
        const IsSupported = true;
    }
    else static if ( is(T U : U[])) // If it is an array
    {
        static if ( isStringType!(T) ) // If it is a string
        {
            const IsSupported = true;
        }
        else static if ( isStringType!(U) ) // If it is string of strings
        {
            const IsSupported = true;
        }
        else static if ( isIntegerType!(U) || isRealType!(U) )
        {
            const IsSupported = true;
        }
        else
        {
            const IsSupported = false;
        }
    }
    else
    {
        const IsSupported = false;
    }
}


/*******************************************************************************

    Set whether loose parsing is enabled or not.
    Loose parsing means, that variables that have no effect are allowed.

    Initial value is false.

    Params:
        state =
            default: true
            false: variables that have no effect cause an exception
            true:  variables that have no effect cause a stderr warning message

*******************************************************************************/

public bool enable_loose_parsing ( bool state = true )
{
    return loose_parsing = state;
}


/*******************************************************************************

    Creates an instance of T, and fills it with according values from the
    configuration file. The name of each variable will used to get it
    from the given section in the configuration file.

    Variables can be marked as required with the Required template.
    If it is important to know whether the setting has been set, the
    SetInfo struct can be used.

    Params:
        group     = the group/section of the variable
        config    = instance of the source to use (defaults to Config)

    Returns:
        a new instance filled with values from the configuration file

    See_Also:
        Required, SetInfo

*******************************************************************************/

public T fill ( T : Object, Source = ConfigParser )
              ( char[] group, Source config = null )
{
    T reference;
    return fill(group, reference, config);
}


/*******************************************************************************

    Fill the given instance of T with according values from the
    configuration file. The name of each variable will used to get it
    from the given section in the configuration file.

    If reference is null, an instance will be created.

    Variables can be marked as required with the Required template.
    If it is important to know whether the setting has been set, the
    SetInfo struct can be used.

    Params:
        group     = the group/section of the variable
        reference = the instance to fill. If null it will be created
        loose     = whether to throw when configuration keys exist
                    that aren't used(false) or to output a warning(true)
        config    = instance of the source to use (defaults to Config)

    Returns:
        an instance filled with values from the configuration file

    See_Also:
        Required, SetInfo

*******************************************************************************/

public T fill ( T : Object, Source = ConfigParser )
              ( char[] group, ref T reference, Source config = null )
{
    if ( reference is null )
    {
        reference = new T;
    }

    static if ( is(Source : ConfigParser)) if ( config is null )
    {
        config = Config;
    }

    foreach ( var; config.iterateCategory(group) )
    {
        if ( !hasField(reference, var) )
        {
            auto msg = "Invalid configuration key " ~ group ~ "." ~ var;

            if ( !loose_parsing )
            {
                throw new ConfigException(msg, __FILE__, __LINE__);
            }
            else Trace.formatln("#### WARNING: {}", msg);
        }
    }

    readFields!(T)(group, reference, config);

    return reference;
}

/***************************************************************************

    Checks whether T or any of its super classes contain
    a variable called field

    Params:
        reference = reference of the object that will be checked
        field     = name of the field to check for

    Returns:
        true when T or any parent class has a member named the same as the
        value of field,
        else false

***************************************************************************/

private bool hasField ( T : Object ) ( T reference, char[] field )
{
    foreach ( si, unused; reference.tupleof )
    {
        auto key = reference.tupleof[si].stringof["reference.".length .. $];

        if ( key == field ) return true;
    }

    bool was_found = true;

    // Recurse into super any classes
    static if ( is(T S == super ) )
    {
        was_found = false;

        foreach ( G; S ) static if ( !is(G == Object) )
        {
            if ( hasField!(G)(cast(G) reference, field))
            {
                was_found = true;
                break;
            }
        }
    }

    return was_found;
}

/***************************************************************************

    Class Iterator. Iterates over variables of a category

***************************************************************************/

struct ClassIterator ( T, Source = ConfigParser )
{
    Source config;
    char[] root;

    /***********************************************************************

        Variable Iterator. Iterates over variables of a category

    ***********************************************************************/

    public int opApply ( int delegate ( ref char[] name, ref T x ) dg )
    {
        static if ( is(Source : ConfigParser)) if ( config is null )
        {
            config = Config;
        }

        int result = 0;

        if ( config !is null ) foreach ( key; config )
        {
            scope T instance = new T;

            if ( key.length > root.length && key[0 .. root.length] == root &&
                 key[root.length] == '.' )
            {
                fill(key, instance, config);

                auto name = key[root.length + 1 .. $];
                result = dg(name, instance);

                if (result) break;
            }
        }

        return result;
    }
}

/***************************************************************************

    Creates an iterator that iterates over groups that start with
    a common string, filling an instance of the passed class type from
    the variables of each matching group and calling the delegate.

    TemplateParams:
        T = type of the class to fill
        Source = source to use (defaults to ConfigParser)

    Params:
        root = start of the group name
        config = instance of the source to use (defaults to Config)

    Returns:
        iterator that iterates over all groups matching the pattern

***************************************************************************/

public ClassIterator!(T) iterate ( T, Source = ConfigParser )
                                 ( char[] root, Source config = null )
{
    return ClassIterator!(T, Source)(config, root);
}

/*******************************************************************************

    Converts property to T

    Params:
        property = value to convert
        config = instance of the source to use (defaults to Config)

    Returns:
        property converted to T

*******************************************************************************/

protected void readFields ( T, Source )
                          ( char[] group, T reference, Source config )
{
    static if ( is(Source : ConfigParser)) if ( config is null )
    {
        config = Config;
    }

    assert ( config !is null, "Source is null :(");

    foreach ( si, field; reference.tupleof )
    {
        alias BaseType!(typeof(field)) Type;
        debug bool found = false;

        static assert ( IsSupported!(Type),
                        "ClassFiller.readFields: Type "
                        ~ Type.stringof ~ " is not supported" );

        auto key = reference.tupleof[si].stringof["reference.".length .. $];

        if ( config.exists(group, key) )
        {
            static if ( is(Type U : U[]) && !isStringType!(Type))
            {
                reference.tupleof[si] = config.getListStrict!(DynamicArrayType!(U))(group, key);
            }
            else
            {
                reference.tupleof[si] = config.getStrict!(DynamicArrayType!(Type))(group, key);
            }


            debug (Config) Trace.formatln("Config Debug: {}.{} = {}", group,
                             reference.tupleof[si]
                            .stringof["reference.".length  .. $],
                            Value(reference.tupleof[si]));

            static if ( !is (Type == typeof(field)) )
            {
                reference.tupleof[si].check(true, group, key);
            }
        }
        else
        {
            debug (Config) Trace.formatln("Config Debug: {}.{} = {} (builtin)", group,
                             reference.tupleof[si]
                            .stringof["reference.".length  .. $],
                            Value(reference.tupleof[si]));

            static if ( !is (Type == typeof(field)) )
            {
                reference.tupleof[si].check(false, group, key);
            }
        }
    }

    // Recurse into super any classes
    static if ( is(T S == super ) )
    {
        foreach ( G; S ) static if ( !is(G == Object) )
        {
            readFields!(G)(group, cast(G) reference, config);
        }
    }
}


debug ( OceanUnitTest )
{
    private import ocean.core.Test;

    class DummyParser : ConfigParser
    {
        char[][] categories = ["ROOT.valid", "ROOT-invalid", "ROOT_invalid",
                                "ROOTINVALID"];

        override public int opApply ( int delegate ( ref char[] key ) dg )
        {
            int result;
            foreach ( cat ; categories )
            {
                result = dg(cat);
                if (result) break;
            }

            return result;
        }
    }

    class Dummy {};

    unittest
    {
        auto iter = iterate!(Dummy)("ROOT", new DummyParser);

        foreach ( name, conf; iter )
        {
            test!("==")(name, "valid");
        }


        const config_text =
`
[Section]
string = I'm a string
integer = -300
pi = 3.14

[SectionArray]
string_arr = Hello
             World
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
`;

        auto config_parser = new ConfigParser();

        class SingleValues
        {
            char[] string;
            int integer;
            float pi;
            uint default_value = 99;
        }

        auto single_values = new SingleValues();
        config_parser.parseString(config_text);

        readFields("Section", single_values, config_parser);
        test(single_values.string == "I'm a string",
                                             "classFiller: Wrong string parse");
        test(single_values.integer == -300, "classFiller: Wrong int parse");
        test(single_values.pi == cast(float)3.14,
                                              "classFiller: Wrong float parse");
        test(single_values.default_value == 99,
                                      "classFiller: wrong default value parse");


        class ArrayValues
        {
            char[][] string_arr;
            int[] int_arr;
            ulong[] ulong_arr;
            float[] float_arr;
        }

        auto array_values = new ArrayValues();
        readFields("SectionArray", array_values, config_parser);
        test(array_values.string_arr == ["Hello", "World"],
                                       "classFiller: Wrong string-array parse");
        test(array_values.int_arr == [30, 40, -60, 1111111111, 0x10],
                                          "classFiller: Wrong int-array parse");
        ulong[] ulong_array = [0, 50, ulong.max, 0xa123bcd];
        test(array_values.ulong_arr == ulong_array,
                                        "classFiller: Wrong ulong-array parse");
        float[] float_array = [10.2, -25.3, 90, 0.000000001];
        test(array_values.float_arr == float_array,
                                        "classFiller: Wrong float-array parse");
    }
}
