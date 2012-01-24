/*******************************************************************************

    Provides convenient functions to fill the values of a given class

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        November 2011

    authors:        Mathias Baumann

    Provides functions that use a given source (by default the global Config 
    instance) to fill the member variables of a provided or newly 
    created instance of a given class.
    
    The provided class can use certain wrappers to mark variables as
    required or to get the information whether the variable was set from
    the source or left untouched.
    
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
    }
    
    void main ( char[][] argv )
    {
        Config.parse(argv[1]);
        
        try 
        {
            auto conf = Class.fill!(ConfigParameters)("EXAMPLE_GROUP");
            
            Stdout.formatln("Number: {}", conf.number);
            Stdout.formatln("Required: {}", conf.required_string);
            if ( conf.was_this_set.set )
            {
                Stdout.formatln("It was set! And the value is {}", 
                was_this_set());
            }
        }
        catch ( Exception e )
        {
            Stdout.formatln("Required parameter wasn't set: {}", e.msg);
        }
    }
    -------
    
    Use debug=Config to get a printout of all the configuration options

*******************************************************************************/

module ocean.util.config.ClassFiller;


/*******************************************************************************

    Imports

*******************************************************************************/

public  import ocean.core.Exception: ConfigException, assertEx;
               
private import tango.core.Exception;

private import tango.core.Traits;

private import ocean.util.Config; 

private import ocean.util.config.ConfigParser;

private import ocean.util.log.Trace;

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

    Params:
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

    Params:
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

    Configuration settings that are mandatory can be marked as such by
    wrapping them with this template.
    If the variable is not set, then an exception is thrown.

    The value can be accessed with the opCall method

    Params:
        T = the original type of the variable

*******************************************************************************/

struct Required ( T )
{
    /***************************************************************************

        The value of the configuration setting, can be a WrapperStruct

    ***************************************************************************/

    private T value;

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

        Checks whether the checked value was found, throws if not

    ***************************************************************************/

    private void check ( bool found, char[] group, char[] name )
    {
        if ( !found )
        {
            throw new ConfigException("Mandatory variable " ~ group ~ 
                                      "." ~ name ~
                                      " not set", __FILE__, __LINE__);
        }
        
        static if ( !is (BaseType!(T) == T) )
        {
            this.value.check(found, group, name);
        }
    }
}

/*******************************************************************************

    Configuration settings that are required to be within a certain numeric
    range can be marked as such by wrapping them with this template.

    If the value is outside the provided range, an exception is thrown.

    The value can be accessed with the opCall method

    Params:
        T    = the original type of the variable (can be another struct)
        min  = smallest allowed value
        max  = biggest allowed value
        init = default value when it is not given in the configuration file


*******************************************************************************/

struct MinMax ( T, T min, T max, T init = T.init )
{
    /***************************************************************************

        The value of the configuration setting

    ***************************************************************************/

    private T value = init;
   
    /***************************************************************************

        Sets the wrapped value to val

        Params:
            val = new value

        Returns:
            val

    ***************************************************************************/

    public BaseType!(T) opCall ( )
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

        Checks whether the configuration value is bigger than the smallest 
        allowed value and smaller than the biggest allowed value. 
        If not, an exception is thrown

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

    ***************************************************************************/

    private void check ( bool found, char[] group, char[] name )
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
        
        static if ( !is (BaseType!(T) == T) )
        {
            this.value.check(found, group, name);
        }
    }
}

/*******************************************************************************

    Configuration settings that are required to be within a certain numeric
    range can be marked as such by wrapping them with this template.

    If the value is outside the provided range, an exception is thrown.

    The value can be accessed with the opCall method

    Params:
        T    = the original type of the variable (can be another struct)
        min  = smallest allowed value
        init = default value when it is not given in the configuration file


*******************************************************************************/

struct Min ( T, T min, T init = T.init )
{        
    /***************************************************************************

        The value of the configuration setting

    ***************************************************************************/

    private T value = init;

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

        Sets the wrapped value to val

        Params:
            val = new value

        Returns:
            val

    ***************************************************************************/

    public BaseType!(T) opCall ( )
    {
        return Value(this.value);
    }    
            
     /***************************************************************************

        Checks whether the configuration value is bigger than the smallest 
        allowed value. If not, an exception is thrown

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

    ***************************************************************************/

    private void check ( bool found, char[] group, char[] name )
    {
        if ( Value(this.value) < min )
        {
            throw new ConfigException(
                    "Configuration key " ~ group ~ "." ~ name ~ " is smaller "
                    "than allowed minimum of " ~ ctfe_i2a(min),
                    __FILE__, __LINE__);
        }            
                
        static if ( !is (BaseType!(T) == T) )
        {
            this.value.check(found, group, name);
        }
    }
}

/*******************************************************************************

    Configuration settings that are required to be within a certain numeric
    range can be marked as such by wrapping them with this template.

    If the value is outside the provided range, an exception is thrown.

    The value can be accessed with the opCall method

    Params:
        T    = the original type of the variable (can be another struct)
        min  = smallest allowed value
        max  = biggest allowed value
        init = default value when it is not given in the configuration file


*******************************************************************************/

struct Max ( T, T max )
{
    /***************************************************************************

        The value of the configuration setting

    ***************************************************************************/

    private T value;

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

        Sets the wrapped value to val

        Params:
            val = new value

        Returns:
            val

    ***************************************************************************/

    public BaseType!(T) opCall ( )
    {
        return Value(this.value);
    }  
    
     /***************************************************************************

        Checks whether the configuration value is smaller than the biggest
        allowed value. If not, an exception is thrown

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

    ***************************************************************************/

    private void check ( bool found, char[] group, char[] name )
    {
        if ( Value(this.value) > max )
        {
            throw new ConfigException(
                    "Configuration key " ~ group ~ "." ~ name ~ " is bigger "
                    "than allowed maximum of " ~ ctfe_i2a(max),
                    __FILE__, __LINE__);
        }

        static if ( !is (BaseType!(T) == T) )
        {
            this.value.check(found, group, name);
        }
    }
}

/*******************************************************************************

    Adds the information of whether the filler actually set the value
    or whether it was left untouched.

    Params:
        T = the original type

*******************************************************************************/

struct SetInfo ( T )
{    
    /***************************************************************************

        The value of the configuration setting

    ***************************************************************************/

    private T value;

    /***************************************************************************

        Whether this value has been set

    ***************************************************************************/

    public bool set;

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

        Sets the set attribute according to whether the variable appeared in
        the configuration or not

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

    ***************************************************************************/

    private void check ( bool found, char[] group, char[] name )
    {
        this.set = found;
                
        static if ( !is (BaseType!(T) == T) )
        {
            this.value.check(found, group, name);
        }
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


/*******************************************************************************

    Strips the typedef off T

*******************************************************************************/

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
        loose     = true, output a warning for invalid variables
                    false, throw an exception for invalid variables
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

            if ( key.length > root.length && key[0 .. root.length] == root )
            {
                instance = fill(key, instance, config);

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
        }
        catch ( Exception e )
        {
            Stdout.formatln("Required parameter wasn't set: {}", e.msg);
        }        
    }
    -------
    
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
            reference.tupleof[si] = config.getStrict!(DynamicArrayType!(Type))(group, key);

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
