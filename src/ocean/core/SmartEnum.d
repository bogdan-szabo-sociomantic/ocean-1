/*******************************************************************************

    Smart enum template class, encapsulates an enum with a map of its codes
    and descriptions.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        March 2011: Initial release

    authors:        Gavin Norman

    Contains two main mixin templates:

        1. SmartEnum
        2. AutoSmartEnum


    1. SmartEnum
    ----------------------------------------------------------------------------

    Mixin template declaring a class containing an enum with code<->description
    lookup. All methods are static, so that the class can be used without an
    instance.

    This mixin creates classes which contain a real (anonymous) enum, and two
    associative arrays mapping from the enum values to their string descriptions
    and vice versa, allowing two-way lookup between codes <-> descriptions, and
    an implementation of the 'in' operator to tell if a code or description is
    valid.

    This is especially useful for "Const" classes which define a list of command
    or status codes where a kind of reverse lookup is needed, going from a code
    to its name / description (or vice versa).

    The classes also implement a foreach iterator over the values of the enum,
    and several other methods (see SmartEunmCore, below).

    The mixin template takes as parameters the name of the class to be generated
    and a variadic list of SmartEnumValue structs, specifying the names and
    values of the enum's members.

    The SmartEnumValue struct is also a template, which takes as parameter the
    base type of the enum, which must be an integral type (see
    http://www.digitalmars.com/d/1.0/enum.html).

    Note that as the class generated by the mixin template contains only static
    members, it is not necessary to actually instantiate it, only to declare the
    class (as demonstrated in the example below).

    Usage example:

    ---

        import ocean.core.SmartEnum;
        import ocean.io.Stdout_tango;

        alias SmartEnumValue!(int) Code;

        mixin(SmartEnum!("Commands",
            Code("first", 1),
            Code("second", 2)
        ));

        // Getting descriptions of codes
        // (Note that the getter methods work like opIn, returning pointers.)
        Stdout.formatln("Description for code first = {}", *Commands.description(Commands.first));
        Stdout.formatln("Description for code 1 = {}", *Commands.description(1));

        // Getting codes by description
        // (Note that the getter methods work like opIn, returning pointers.)
        Stdout.formatln("Code for description 'first' = {}", *Commands.code("first"));

        // Testing whether codes exist
        Stdout.formatln("1 in enum? {}", !!(1 in Commands));
        Stdout.formatln("first in enum? {}", !!(Commands.first in Commands));

        // Testing whether codes exist by description
        Stdout.formatln("'first' in enum? {}", !!("first" in Commands));
        Stdout.formatln("'third' in enum? {}", !!("third" in Commands));

        // Iteration over enum
        foreach ( code, descr; Commands )
        {
            Stdout.formatln("{} -> {}", code, descr);
        }

    ---


    2. AutoSmartEnum
    ----------------------------------------------------------------------------

    Template to automatically create a SmartEnum from a list of strings. The
    enum's base type is specified, and the enum values are automatically
    numbered, starting at 0.

    Usage example:

    ---

        import ocean.core.SmartEnum;

        mixin(AutoSmartEnum!("Commands", int,
            "first",
            "second"));

    ---

*******************************************************************************/

module ocean.core.SmartEnum;


/*******************************************************************************

    Imports

 *******************************************************************************/

import ocean.transition;

public import ocean.core.Enforce;

import ocean.core.Traits;

import ocean.core.Traits;
import ocean.core.Tuple;

version (UnitTest)
{
    import ocean.core.Test;
}


/// Workaround inability to replace those in string.
version (D_Version2)
{
    private const istring enum_id = "enum";
}
else
{
    private const istring enum_id = "const";
}

/*******************************************************************************

    Abstract base class for SmartEnums. Contains no members, just provided as a
    convenient way of checking that a class is in fact a SmartEnum, using
    is(T : ISmartEnum).

*******************************************************************************/

public abstract class ISmartEnum
{
}



/*******************************************************************************

    Struct template representing a single member of an enum -- containing a
    string for the enum identifier and a code for the corresponding value.

    Template_Params:
        T = base type of enum

*******************************************************************************/

public struct SmartEnumValue ( T )
{
    alias T BaseType;

    istring name;
    T value;
}

unittest
{
    alias SmartEnumValue!(int) _;
}



/*******************************************************************************

    Members forming the core of each class generated by the SmartEnum mixin.
    This template is mixed into each class created by the SmartEnum template.

    Template_Params:
        BaseType = base type of enum

*******************************************************************************/

public template SmartEnumCore ( BaseType )
{
    import ocean.transition;

    /***************************************************************************

        Two way mapping between codes <-> descriptions.

    ***************************************************************************/

    static public TwoWayMap!(BaseType, istring, true) map;


    /***************************************************************************

        Looks up the description of a code.

        Aliased to opIn.

        Params:
            code = code to look up

        Returns:
            pointer to code's description, or null if code not in enum

    ***************************************************************************/

    static public istring* description ( BaseType code )
    {
        return code in map;
    }

    public alias description opIn_r;


    /***************************************************************************

        Looks up the code of a description.

        Aliased to opIn.

        Params:
            description = description to look up

        Returns:
            pointer to description's code, or null if description not in enum

    ***************************************************************************/

    static public BaseType* code ( istring description )
    {
        return description in map;
    }

    public alias code opIn_r;


    /***************************************************************************

        Gets the description of a code.

        Params:
            code = code to look up

        Returns:
            code's description

        Throws:
            if code is not in the map

    ***************************************************************************/

    static public istring opIndex ( BaseType code )
    {
        auto description = code in map;
        enforce(description, "code not found in SmartEnum");
        return *description;
    }


    /***************************************************************************

        Gets the code of a description.

        Params:
            description = description to look up

        Returns:
            description's code

        Throws:
            if description is not in the map

    ***************************************************************************/

    static public BaseType opIndex ( istring description )
    {
        auto code = description in map;
        enforce(code, description ~ " not found in SmartEnum");
        return *code;
    }


    /***************************************************************************

        Looks up the index of a code in the enum (ie code is the nth code in the
        enum). This can be useful if the actual enum codes are not consecutive.

        Params:
            code = code to get index for

        Returns:
            pointer to code's index, or null if code not in enum

    ***************************************************************************/

    static public size_t* indexOf ( BaseType code )
    {
        return map.indexOf(code);
    }


    /***************************************************************************

        Looks up the index of a description in the enum (ie description is for
        the nth code in the enum).

        Params:
            description = description to get index for

        Returns:
            pointer to description's index, or null if description not in enum

    ***************************************************************************/

    static public size_t* indexOf ( istring description )
    {
        return map.indexOf(description);
    }


    /***************************************************************************

        Looks up a code in the enum by its index. (ie gets the nth code in the
        enum).

        Params:
            index = index of code to get

        Returns:
            nth code in enum

        Throws:
            array out of bounds if index is > number of codes in the enum

    ***************************************************************************/

    static public BaseType codeFromIndex ( size_t index )
    {
        return map.keys[index];
    }


    /***************************************************************************

        Looks up a description in the enum by the index of its code. (ie gets
        the description of the nth code in the enum).

        Params:
            index = index of code to get description for

        Returns:
            description of nth code in enum

        Throws:
            array out of bounds if index is > number of codes in the enum

    ***************************************************************************/

    static public istring descriptionFromIndex ( size_t index )
    {
        return map.values[index];
    }


    /***************************************************************************

        foreach iterator over the codes and descriptions of the enum.

    ***************************************************************************/

    static public int opApply ( int delegate ( ref BaseType code, ref istring desc ) dg )
    {
        int res;
        foreach ( code, description; map )
        {
            res = dg(code, description);
        }
        return res;
    }


    /***************************************************************************

        foreach iterator over the codes and descriptions of the enum and their
        indices.

    ***************************************************************************/

    static public int opApply ( int delegate ( ref size_t index, ref BaseType code, ref istring desc ) dg )
    {
        int res;
        foreach ( index, code, description; map )
        {
            res = dg(index, code, description);
        }
        return res;
    }
}

unittest
{
    alias SmartEnumCore!(int) _;
}

/*******************************************************************************

    Wrapper for the ctfe_i2a function (see ocean.core.Traits), allowing it to
    also handle (u)byte & (u)short types.

*******************************************************************************/

public istring CTFE_Int2String ( T ) ( T num )
{
    static if ( is(T == ubyte) )
    {
        return ctfe_i2a(cast(uint)num);
    }
    else static if ( is(T == byte) )
    {
        return ctfe_i2a(cast(int)num);
    }
    else static if ( is(T == ushort) )
    {
        return ctfe_i2a(cast(uint)num);
    }
    else static if ( is(T == short) )
    {
        return ctfe_i2a(cast(int)num);
    }
    else
    {
        return ctfe_i2a(num);
    }
}

unittest
{
    test!("==")(CTFE_Int2String(42), "42"[]);
    test!("==")(CTFE_Int2String(ubyte.init), "0"[]);
    test!("==")(CTFE_Int2String(byte.init), "0"[]);
    test!("==")(CTFE_Int2String(ushort.init), "0"[]);
    test!("==")(CTFE_Int2String(short.init), "0"[]);
}

/*******************************************************************************

    Template to mixin a comma separated list of SmartEnumValues.

    Template_Params:
        T = variadic list of one or more SmartEnumValues

    Generates output of the form:

    ---
        first = 1,
        second = 2,
        last = 100
    ---

*******************************************************************************/

private template EnumValuesList ( T ... )
{
    static if ( T.length == 1 )
    {
        const EnumValuesList = T[0].name ~ "=" ~ CTFE_Int2String(T[0].value);
    }
    else
    {
        const EnumValuesList = T[0].name ~ "=" ~ CTFE_Int2String(T[0].value) ~ "," ~ EnumValuesList!(T[1..$]);
    }
}


/*******************************************************************************

    Template to mixin an enum from a list of SmartEnumValues.

    Template_Params:
        T = variadic list of one or more SmartEnumValues

    Generates output of the form:

    ---
        enum
        {
            first = 1,
            second = 2,
            last = 100
        }
    ---

*******************************************************************************/

private template DeclareEnum ( T ... )
{
    const DeclareEnum = "alias " ~ T[0].BaseType.stringof ~ " BaseType; enum : BaseType {" ~ EnumValuesList!(T) ~ "} ";
}


/*******************************************************************************

    Template to mixin a series of TwoWayMap value initialisations.

    Template_Params:
        T = variadic list of one or more SmartEnumValues

    Generates output of the form:

    ---
        map["first"]=1;
        map["second"]=2;
        map["last"]=100;
    ---

*******************************************************************************/

private template InitialiseMap ( T ... )
{
    static if ( T.length == 1 )
    {
        const InitialiseMap = `map["` ~ T[0].name ~ `"]=` ~ T[0].name ~ ";";
    }
    else
    {
        const InitialiseMap = `map["` ~ T[0].name ~ `"]=` ~ T[0].name ~ ";" ~ InitialiseMap!(T[1..$]);
    }
}


/*******************************************************************************

    Template to mixin a static constructor which initialises and rehashes a
    TwoWayMap.

    Template_Params:
        T = variadic list of one or more SmartEnumValues

    Generates output of the form:

    ---
        static this ( )
        {
            map["first"]=1;
            map["second"]=2;
            map["last"]=100;

            map.rehash;
        }
    ---

*******************************************************************************/

private template StaticThis ( T ... )
{
    const StaticThis = "static this() {" ~ InitialiseMap!(T) ~ "map.rehash;} ";
}


/*******************************************************************************

    Template to find the maximum code from a list of SmartEnumValues.

    Template_Params:
        T = variadic list of one or more SmartEnumValues

*******************************************************************************/

private template MaxValue ( T ... )
{
    static if ( T.length == 1 )
    {
        const MaxValue = T[0].value;
    }
    else
    {
        const MaxValue = T[0].value > MaxValue!(T[1..$]) ? T[0].value : MaxValue!(T[1..$]);
    }
}


/*******************************************************************************

    Template to find the minimum code from a list of SmartEnumValues.

    Template_Params:
        T = variadic list of one or more SmartEnumValues

*******************************************************************************/

private template MinValue ( T ... )
{
    static if ( T.length == 1 )
    {
        const MinValue = T[0].value;
    }
    else
    {
        const MinValue = T[0].value < MinValue!(T[1..$]) ? T[0].value : MinValue!(T[1..$]);
    }
}


/*******************************************************************************

    Template to find the length of the longest description in a list of
    SmartEnumValues.

    Template_Params:
        T = variadic list of one or more SmartEnumValues

*******************************************************************************/

private template LongestName ( T ... )
{
    static if ( T.length == 1 )
    {
        const LongestName = T[0].name.length;
    }
    else
    {
        const LongestName = T[0].name.length > LongestName!(T[1..$]) ? T[0].name.length : LongestName!(T[1..$]);
    }
}


/*******************************************************************************

    Template to find the length of the shortest description in a list of
    SmartEnumValues.

    Template_Params:
        T = variadic list of one or more SmartEnumValues

*******************************************************************************/

private template ShortestName ( T ... )
{
    static if ( T.length == 1 )
    {
        const ShortestName = T[0].name.length;
    }
    else
    {
        const ShortestName = T[0].name.length < ShortestName!(T[1..$]) ? T[0].name.length : ShortestName!(T[1..$]);
    }
}


/*******************************************************************************

    Template to mixin the declaration of a set of constants.

    Template_Params:
        T = variadic list of one or more SmartEnumValues

    Generates output of the form:

    ---
        const length = 3;
        const min = 1;
        const max = 100;
        const min_descr_length = 4;
        const max_descr_length = 6;
    ---

*******************************************************************************/

private template DeclareConstants ( T ... )
{
    const istring DeclareConstants =
        enum_id ~ " length = " ~ ctfe_i2a(T.length) ~ "; " ~
        enum_id ~ " min = " ~ CTFE_Int2String(MinValue!(T)) ~ "; " ~
        enum_id ~ " max = " ~ CTFE_Int2String(MaxValue!(T)) ~ "; " ~
        enum_id ~ " min_descr_length = " ~ ctfe_i2a(ShortestName!(T)) ~ "; " ~
        enum_id ~ " max_descr_length = " ~ ctfe_i2a(LongestName!(T)) ~ "; ";
}


/*******************************************************************************

    Template to mixin code for a mixin template declaring the enum class'
    core members.

    Template_Params:
        T = variadic list of one or more SmartEnumValues

    Generates output of the form:

    ---
        mixin SmartEnumCore!(int);
    ---

*******************************************************************************/

private template MixinCore ( T ... )
{
    const MixinCore = "mixin SmartEnumCore!(" ~ T[0].BaseType.stringof ~ ");";
}


/*******************************************************************************

    Template to mixin a SmartEnum class.

    Template_Params:
        Name = name of class
        T = variadic list of one or more SmartEnumValues

    Generates output of the form:

    ---
        class EnumName : ISmartEnum
        {
            // class contents (see templates above)
        }
    ---

*******************************************************************************/

public template SmartEnum ( istring Name, T ... )
{
    static if ( T.length > 0 )
    {
        const SmartEnum = "class " ~ Name ~ " : ISmartEnum { " ~ DeclareEnum!(T) ~
            DeclareConstants!(T) ~ StaticThis!(T) ~ MixinCore!(T) ~ "}";
    }
    else
    {
        static assert(false, "Cannot create a SmartEnum with no entries!");
    }
}

///
unittest
{
    alias SmartEnumValue!(int) Code;

    mixin (SmartEnum!("Commands",
        Code("first", 1),
        Code("second", 2)
    ));

    test!("==")(*Commands.description(Commands.first), "first"[]);
    test!("==")(*Commands.description(1), "first"[]);

    test!("==")(*Commands.code("first"), Commands.first);
    test!("==")(*Commands.code("second"), 2);

    test((1 in Commands) !is null);
    test((Commands.second in Commands) !is null);
    test((5 in Commands) is null);

    test(("first" in Commands) !is null);
    test(("third" in Commands) is null);

    size_t count;
    foreach ( code, descr; Commands )
        ++count;
    test!("==")(count, 2);
}

/*******************************************************************************

    Template to create a tuple of enum codes from 0 to the length of the passed
    tuple of strings.

    Template_Params:
        BaseType = base type of enum
        i = counter (used recursively)
        Strings = variadic list of descriptions of the enum values

*******************************************************************************/

private template CreateCodes ( BaseType, uint i, Strings ... )
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


/*******************************************************************************

    Template to mixin a SmartEnum class with the codes automatically generated,
    starting at 0.

    Template_Params:
        Name = name of class
        BaseType = base type of enum
        Strings = variadic list of descriptions of the enum values (statically
                  asserted to be istring's)

*******************************************************************************/

public template AutoSmartEnum ( istring Name, BaseType, Strings ... )
{
    static assert ( is(typeof(Strings[0]) : istring), "AutoSmartEnum - please only give immutable strings as template parameters");

    const AutoSmartEnum = SmartEnum!(Name, CreateCodes!(BaseType, 0, Strings));
}

unittest
{
    mixin(AutoSmartEnum!("Name", int, "a", "b", "c"));
    test!("==")(*Name.code("a"), 0);
    test!("==")(*Name.code("b"), 1);
    test!("==")(*Name.code("c"), 2);
}

/*******************************************************************************

    Moved from ocean.core.TwoWayMap

*******************************************************************************/


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Enforce;

import ocean.core.Array_tango : find;

import ocean.core.Traits : isAssocArrayType;

/*******************************************************************************

    Template to create a two way map from an associative array type.

    Template_Params:
        T = associative array map type

*******************************************************************************/

public template TwoWayMap ( T )
{
    static if ( isAssocArrayType!(T) )
    {
        public alias TwoWayMap!(typeof(T.init.values[0]), typeof(T.init.keys[0])) TwoWayMap;
    }
    else
    {
        static assert(false, "'" ~ T.stringof ~ "' isn't an associative array type, cannot create two way map");
    }
}



/*******************************************************************************

    Two way map struct template

    Template_Params:
        A = key type
        B = value type
        Indexed = true to include methods for getting the index of keys or
            values in the internal arrays

    Note: 'key' and 'value' types are arbitrarily named, as the mapping goes
    both ways. They are just named this way for convenience and to present the
    same interface as the standard associative array.

*******************************************************************************/

public struct TwoWayMap ( A, B, bool Indexed = false )
{
    /***************************************************************************

        Ensure that the template is mapping between two different types. Most of
        the methods won't compile otherwise.

    ***************************************************************************/

    static if ( is(A == B) )
    {
        static assert(false, "TwoWayMap only supports mapping between two different types, not " ~ A.stringof ~ " <-> " ~ B.stringof);
    }


    /***************************************************************************

        Type aliases.

    ***************************************************************************/

    public alias A KeyType;
    public alias B ValueType;


    /***************************************************************************

        Associative arrays which store the mappings.

    ***************************************************************************/

    private B[A] a_to_b;
    private A[B] b_to_a;


    /***************************************************************************

        Dynamic arrays storing all keys and values added to the mappings.
        Storing these locally avoids calling the associative array .key and
        .value properties, which cause a memory allocation on each use.

        TODO: maybe this should be optional, controlled by a template parameter

    ***************************************************************************/

    private A[] keys_list;
    private B[] values_list;


    /***************************************************************************

        Optional indices for mapped items.

    ***************************************************************************/

    static if ( Indexed )
    {
        private size_t[A] a_to_index; // A to index in keys_list
        private size_t[B] b_to_index; // B to index in values_list
    }


    /***************************************************************************

        Invariant checking that the length of both mappings should always be
        identical.
        Use -debug=TwoWayMapFullConsistencyCheck to check that the indices of
        mapped items are consistent, too (this check may significantly impact
        performance).

    ***************************************************************************/

    invariant ( )
    {
        assert(this.a_to_b.length == this.b_to_a.length);

        debug ( TwoWayMapFullConsistencyCheck ) static if ( Indexed )
        {
            foreach ( a, b; this.a_to_b )
            {
                assert(this.a_to_index[a] == this.b_to_index[b]);
            }
        }
    }


    /***************************************************************************

        Assigns a set of mappings from an associative array.

        Params:
            assoc_array = associative array to assign

    ***************************************************************************/

    public void opAssign ( B[A] assoc_array )
    {
        this.keys_list.length = 0;
        this.values_list.length = 0;

        this.a_to_b = assoc_array;

        foreach ( a, b; this.a_to_b )
        {
            this.b_to_a[b] = a;

            this.keys_list ~= *(b in this.b_to_a);
            this.values_list ~= *(a in this.a_to_b);
        }

        static if ( Indexed )
        {
            this.updateIndices();
        }
    }

    public void opAssign ( A[B] assoc_array )
    {
        this.keys_list.length = 0;
        this.values_list.length = 0;

        this.b_to_a = assoc_array;

        foreach ( b, a; this.b_to_a )
        {
            this.a_to_b[a] = b;

            this.keys_list ~= *(b in this.b_to_a);
            this.values_list ~= *(a in this.a_to_b);
        }

        static if ( Indexed )
        {
            this.updateIndices();
        }
    }


    /***************************************************************************

        Adds a mapping.

        Params:
            a = item to map to
            b = item to map to

    ***************************************************************************/

    public void opIndexAssign ( A a, B b )
    out
    {
        static if ( Indexed )
        {
            assert(this.a_to_index[a] < this.keys_list.length);
            assert(this.b_to_index[b] < this.values_list.length);
        }
    }
    body
    {
        auto already_exists = !!(a in this.a_to_b);

        this.a_to_b[a] = b;
        this.b_to_a[b] = a;

        if ( !already_exists )
        {
            this.keys_list ~= *(b in this.b_to_a);
            this.values_list ~= *(a in this.a_to_b);
        }

        static if ( Indexed )
        {
            this.updateIndices();
        }
    }

    public void opIndexAssign ( B b, A a )
    out
    {
        static if ( Indexed )
        {
            assert(this.a_to_index[a] < this.keys_list.length);
            assert(this.b_to_index[b] < this.values_list.length);
        }
    }
    body
    {
        auto already_exists = !!(a in this.a_to_b);

        this.a_to_b[a] = b;
        this.b_to_a[b] = a;

        if ( !already_exists )
        {
            this.keys_list ~= *(b in this.b_to_a);
            this.values_list ~= *(a in this.a_to_b);
        }

        static if ( Indexed )
        {
            this.updateIndices();
        }
    }


    /***************************************************************************

        Rehashes the mappings.

    ***************************************************************************/

    public void rehash ( )
    {
        this.a_to_b.rehash;
        this.b_to_a.rehash;

        static if ( Indexed )
        {
            this.updateIndices();
        }
    }


    /***************************************************************************

        opIn_r operator - performs a lookup of an item A in the map
        corresponding to an item B.

        Params:
            b = item to look up

        Returns:
            item of type A corresponding to specified item of type B, or null if
            no mapping exists

    ***************************************************************************/

    public A* opIn_r ( B b )
    {
        return b in this.b_to_a;
    }


    /***************************************************************************

        opIn_r operator - performs a lookup of an item B in the map
        corresponding to an item A.

        Params:
            a = item to look up

        Returns:
            item of type B corresponding to specified item of type A, or null if
            no mapping exists

    ***************************************************************************/

    public B* opIn_r ( A a )
    {
        return a in this.a_to_b;
    }


    /***************************************************************************

        opIndex operator - performs a lookup of an item A in the map
        corresponding to an item B.

        Params:
            b = item to look up

        Throws:
            as per the normal opIndex operator over an associative array

        Returns:
            item of type A corresponding to specified item of type B

    ***************************************************************************/

    public A opIndex ( B b )
    {
        return this.b_to_a[b];
    }


    /***************************************************************************

        opIndex operator - performs a lookup of an item B in the map
        corresponding to an item A.

        Params:
            a = item to look up

        Throws:
            as per the normal opIndex operator over an associative array

        Returns:
            item of type B corresponding to specified item of type A

    ***************************************************************************/

    public B opIndex ( A a )
    {
        return this.a_to_b[a];
    }


    /***************************************************************************

        Returns:
            number of items in the map

    ***************************************************************************/

    public size_t length ( )
    {
        return this.a_to_b.length;
    }


    /***************************************************************************

        Returns:
            dynamic array containing all map elements of type A

    ***************************************************************************/

    public A[] keys ( )
    {
        return this.keys_list;
    }


    /***************************************************************************

        Returns:
            dynamic array containing all map elements of type B

    ***************************************************************************/

    public B[] values ( )
    {
        return this.values_list;
    }


    /***************************************************************************

        foreach iterator over the mapping.

        Note that the order of iteration over the map is determined by the
        elements of type A (the keys).

    ***************************************************************************/

    public int opApply ( int delegate ( ref A a, ref B b ) dg )
    {
        int res;
        foreach ( a, b; this.a_to_b )
        {
            res = dg(a, b);
        }
        return res;
    }


    /***************************************************************************

        foreach iterator over the mapping, including each value's index.

        Note that the order of iteration over the map is determined by the
        elements of type A (the keys).

    ***************************************************************************/

    static if ( Indexed )
    {
        public int opApply ( int delegate ( ref size_t index, ref A a, ref B b ) dg )
        {
            int res;
            foreach ( a, b; this.a_to_b )
            {
                auto index = this.indexOf(a);
                assert(index);

                res = dg(*index, a, b);
            }
            return res;
        }
    }


    /***************************************************************************

        Gets the index of an element of type A in the list of all elements of
        type A.

        Params:
            a = element to look up

        Returns:
            pointer to the index of an element of type A in this.keys_list, or
            null if the element is not in the map

    ***************************************************************************/

    static if ( Indexed )
    {
        public size_t* indexOf ( A a )
        {
            auto index = a in this.a_to_index;
            enforce(index, typeof(this).stringof ~ ".indexOf - element not present in map");
            return index;
        }
    }


    /***************************************************************************

        Gets the index of an element of type B in the list of all elements of
        type B.

        Params:
            b = element to look up

        Returns:
            pointer to the index of an element of type B in this.values_list,
            or null if the element is not in the map

    ***************************************************************************/

    static if ( Indexed )
    {
        public size_t* indexOf ( B b )
        {
            auto index = b in this.b_to_index;
            enforce(index, typeof(this).stringof ~ ".indexOf - element not present in map");
            return index;
        }
    }


    /***************************************************************************

        Updates the index arrays when the mapping is altered.

    ***************************************************************************/

    static if ( Indexed )
    {
        private void updateIndices ( )
        {
            foreach ( a, b; this.a_to_b )
            {
                this.a_to_index[a] = this.keys_list.find(a);
                this.b_to_index[b] = this.values_list.find(b);
            }
        }
    }
}
