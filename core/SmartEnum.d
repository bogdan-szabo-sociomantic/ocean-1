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
 */



public import ocean.core.TwoWayMap;
public import ocean.core.Exception;

private import tango.core.Traits;
private import tango.core.Tuple;



// Just for the sake of being able to tell if a class is a SmartEnum or not,
// using is(T : ISmartEnum).

public abstract class ISmartEnum
{
}



public struct SmartEnumValue ( T )
{
    alias T BaseType;

    char[] name;
    T value;
}



// This template is mixed-in to the SmartEnum class, right at the bottom of the module.
// (The rest is all string mixins.)
private template SmartEnumMethods ( char[] Name, BaseType )
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

    
    static public BaseType opIndex ( char[] description )
    {
        auto code = description in map;
        assertEx(code, description ~ " not found in SmartEnum " ~ Name);
        return *code;
    }
    
    static public char[] opIndex ( BaseType code )
    {
        auto description = code in map;
        assertEx(description, "code not found in SmartEnum " ~ Name);
        return *description;
    }
    
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


private char[] CTFE_Int2String ( T ) ( T num )
{
    static if ( is(T == ubyte) )
    {
        return ctfe_i2a(cast(uint)num);
    }
    else static if ( is(T == byte) )
    {
        return ctfe_i2a(cast(int)num);
    }
    else
    {
        return ctfe_i2a(num);
    }
}


private template EnumValuesList ( T ... )
{
    static if ( T.length == 1 )
    {
        const char[] EnumValuesList = T[0].name ~ "=" ~ CTFE_Int2String(T[0].value);
    }
    else
    {
        const char[] EnumValuesList = T[0].name ~ "=" ~ CTFE_Int2String(T[0].value) ~ "," ~ EnumValuesList!(T[1..$]);
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
        "static const min = " ~ CTFE_Int2String(MinValue!(T)) ~ "; " ~
        "static const max = " ~ CTFE_Int2String(MaxValue!(T)) ~ "; " ~
        "static const min_descr_length = " ~ ctfe_i2a(ShortestName!(T)) ~ "; " ~
        "static const max_descr_length = " ~ ctfe_i2a(LongestName!(T)) ~ "; ";
}


private template MixinMethods ( char[] Name, T ... )
{
    const char[] MixinMethods = `mixin SmartEnumMethods!("` ~ Name ~ `", ` ~ T[0].BaseType.stringof ~ ");";
}


public template SmartEnum ( char[] Name, T ... )
{
    static if ( T.length > 0 )
    {
        const char[] SmartEnum = "class " ~ Name ~ " : ISmartEnum { " ~ DeclareEnum!(T) ~ DeclareMap!(T) ~ DeclareConstants!(T) ~
            StaticThis!(T) ~ MixinMethods!(Name, T) ~ "}";
    }
    else
    {
        static assert(false, "Cannot create a SmartEnum with no entries!");
    }
}





template CreateCodes ( BaseType, uint i, Strings ... )
{
    static if ( Strings.length == 1 )
    {
        alias Tuple!(SmartEnumValue!(BaseType)(Strings[0], i)) CreateCodes; 
    }
    else
    {
        alias Tuple!(SmartEnumValue!(BaseType)(Strings[0], i), CreateCodes!(BaseType, i + 1, Strings[1 .. $])) CreateCodes;
    }
}


public template AutoSmartEnum ( char[] Name, BaseType, Strings ... )
{
    static assert ( is(typeof(Strings[0]) : char[]), "AutoSmartEnum - please only give char[]s as template parameters");

    const char[] AutoSmartEnum = SmartEnum!(Name, CreateCodes!(BaseType, 0, Strings));
}

