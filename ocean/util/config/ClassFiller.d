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
               
private import ocean.util.Config; 

private import ocean.util.config.ConfigParser;

debug private  import ocean.util.log.Trace;

/*******************************************************************************

    Configuration settings that are mandatory can be marked as such by
    wrapping them with this template.
    If the variable is not set, the an exception is thrown.

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

    public T value;

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

    public T opCall ( T def = T.init )
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

    public T opAssign ( T val )
    {
        return value = val;
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
              ( char[] group, bool loose = false, Source config = null )
{
    T reference;
    return fill(group, reference, loose, config);
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
        config    = instance of the source to use (defaults to Config)

    Returns:
        an instance filled with values from the configuration file

    See_Also:
        Required, SetInfo

*******************************************************************************/

public T fill ( T : Object, Source = ConfigParser )
              ( char[] group, ref T reference, bool loose = false, 
                Source config = null )
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
            
            if ( !loose ) throw new ConfigException(msg, __FILE__, __LINE__);
            else Trace.formatln("## ## WARNING: ", msg);
        }
    }
    
    readFields!(T)(group, reference, config);

    return reference;
}

/***************************************************************************

    Checks whether T or any of its super classes contain
    a variable called field

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
    bool loose;

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
                instance = fill(key, instance, loose, config);

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
    
    [Example.SecondGroup]
    number = 2
    required_string = SET_AGAIN
    
    [Example.ThirdGroup]
    number = 3
    required_string = SET
    was_this_set = "arrr"
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

        static assert ( IsSupported!(Type), "ClassFiller.readFields: Type " 
                        ~ Type.stringof ~ " is not supported" );
        
        auto key = reference.tupleof[si].stringof["reference.".length .. $];
        
        *found = config.exists(group, key);

        auto name = PureType.stringof;

        if ( name.length >= "Required".length &&
             name[0 .. "Required".length] == "Required" &&
             *found == false )
        {
            throw new ConfigException("Mandatory variable " ~ key ~
                    " not set", __FILE__, __LINE__);
        }

        if (*found)
        {
            *value = config.getStrict!(DynamicArrayType!(Type))(group, key);
        }

        debug (Config) Trace.formatln("Config Debug: {}.{} = {} {}", group,
                             reference.tupleof[si]
                            .stringof["reference.".length  .. $],
                            *value,
                            !*found ? "(builtin)" : "");
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
