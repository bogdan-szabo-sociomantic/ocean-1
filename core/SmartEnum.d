module ocean.core.SmartEnum;

// TODO: tidy up and finalize
// TODO: replace StringEnum with SmartEnum


/* 
 * SmartEnum mixin template - creates enums with value <-> description mapping
 * at compile time.
 * 
 * Everything in the class is statically defined and can be used without an
 * instance.
 * 
 * TODO
 * 1. AutoSmartEnum, which doesn't need numbers to be given. (Can work the same
 *    as AutoStringEnum.)
 */



public import ocean.core.TwoWayMap;

private import tango.core.Traits;



public struct SmartEnumValue ( T )
{
    alias T BaseType;

    char[] name;
    T value;
}



// This is template mixed-in to the SmartEnum class, right at the bottom of the module.
// (The rest is all string mixins.)
private template SmartEnumMethods ( BaseType )
{
    static public char[]* description ( BaseType code )
    {
        return code in map;
    }

    public alias description opIn_r;

    static public BaseType* code ( char[] description )
    {
        return description in map;
    }

    public alias code opIn_r;

    static public size_t* indexOf ( BaseType code )
    {
        return map.indexOf(code);
    }

    static public size_t* indexOf ( char[] description )
    {
        return map.indexOf(description);
    }

    static public BaseType codeFromIndex ( size_t index )
    {
        return map.values[index];
    }

    static public char[] descriptionFromIndex ( size_t index )
    {
        return map.keys[index];
    }

    static public int opApply ( int delegate ( ref BaseType value, ref char[] name ) dg )
    {
        int res;
        foreach ( description, code; map )
        {
            res = dg(code, description);
        }
        return res;
    }

    static public int opApply ( int delegate ( ref size_t index, ref BaseType value, ref char[] name ) dg )
    {
        int res;
        foreach ( index, description, code; map )
        {
            res = dg(index, code, description);
        }
        return res;
    }
}


private template EnumValuesList ( T ... )
{
    static if ( T.length == 1 )
    {
        const char[] EnumValuesList = T[0].name ~ "=" ~ ctfe_i2a(T[0].value);
    }
    else
    {
        const char[] EnumValuesList = T[0].name ~ "=" ~ ctfe_i2a(T[0].value) ~ "," ~ EnumValuesList!(T[1..$]);
    }
}


private template DeclareEnum ( T ... )
{
    const char[] DeclareEnum = "alias " ~ T[0].BaseType.stringof ~ " BaseType; enum : BaseType {" ~ EnumValuesList!(T) ~ "} ";
}


private template InitialiseMap ( T ... )
{
    static if ( T.length == 1 )
    {
        const char[] InitialiseMap = `map["` ~ T[0].name ~ `"]=` ~ T[0].name ~ ";";
    }
    else
    {
        const char[] InitialiseMap = `map["` ~ T[0].name ~ `"]=` ~ T[0].name ~ ";" ~ InitialiseMap!(T[1..$]);
    }
}


private template StaticThis ( T ... )
{
    const char[] StaticThis = "static this() {" ~ InitialiseMap!(T) ~ "map.rehash;} ";
}


private template DeclareMap ( T ... )
{
    const char[] DeclareMap = "static TwoWayMap!(char[], " ~ T[0].BaseType.stringof ~ ", true) map; ";
}


private template MaxValue ( T ... )
{
    static if ( T.length == 1 )
    {
        const typeof(T[0].value) MaxValue = T[0].value;
    }
    else
    {
        const typeof(T[0].value) MaxValue = T[0].value > MaxValue!(T[1..$]) ? T[0].value : MaxValue!(T[1..$]);
    }
}


private template MinValue ( T ... )
{
    static if ( T.length == 1 )
    {
        const typeof(T[0].value) MinValue = T[0].value;
    }
    else
    {
        const typeof(T[0].value) MinValue = T[0].value < MinValue!(T[1..$]) ? T[0].value : MinValue!(T[1..$]);
    }
}


private template LongestName ( T ... )
{
    static if ( T.length == 1 )
    {
        const size_t LongestName = T[0].name.length;
    }
    else
    {
        const size_t LongestName = T[0].name.length > LongestName!(T[1..$]) ? T[0].name.length : LongestName!(T[1..$]);
    }
}


private template ShortestName ( T ... )
{
    static if ( T.length == 1 )
    {
        const size_t ShortestName = T[0].name.length;
    }
    else
    {
        const size_t ShortestName = T[0].name.length < ShortestName!(T[1..$]) ? T[0].name.length : ShortestName!(T[1..$]);
    }
}


private template DeclareConstants ( T ... )
{
    const char[] DeclareConstants =
        "static const length = " ~ ctfe_i2a(T.length) ~ "; " ~
        "static const min = " ~ ctfe_i2a(MinValue!(T)) ~ "; " ~
        "static const max = " ~ ctfe_i2a(MaxValue!(T)) ~ "; " ~
        "static const min_descr_length = " ~ ctfe_i2a(ShortestName!(T)) ~ "; " ~
        "static const max_descr_length = " ~ ctfe_i2a(LongestName!(T)) ~ "; ";
}


private template MixinMethods ( T ... )
{
    const char[] MixinMethods = "mixin SmartEnumMethods!(" ~ T[0].BaseType.stringof ~ ");";
}


public template SmartEnum ( char[] Name, T ... )
{
    static if ( T.length > 0 )
    {
        const char[] SmartEnum = "class " ~ Name ~ " { " ~ DeclareEnum!(T) ~ DeclareMap!(T) ~ DeclareConstants!(T) ~
            StaticThis!(T) ~ MixinMethods!(T) ~ "}";
    }
    else
    {
        static assert(false, "Cannot create a SmartEnum with no entries!");
    }
}

