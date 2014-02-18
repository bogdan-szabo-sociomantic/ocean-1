/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        18/10/2012: Initial release

    authors:        Gavin Norman

    Mixin for an enum class with the following features:
        * Contains an enum, called E, with members specified by an associative
          array passed to the enum mixin.
        * Contains a constant char[][], called names, with the names of all enum
          members.
        * Contains a constant int[], called values, with the values of all enum
          members.
        * Implements an interface, IEnum, with common shared methods: opIn (for
          enum names (strings) and values (ints)), opApply (over names &
          values), length (number of enum members), min & max (enum values).
        * One enum class can be inherited from another, using standard class
          inheritance. The enum members, as well as the values and names arrays,
          in a derived enum class extend those of the super class.
        * A static opCall() method which returns a singleton instance of the
          class. The ability to get a singleton instance of an enum class is
          useful as it can be passed to functions which expect an instance of
          an enum base class, or the IEnum interface, allowing enum classes to
          be used in an abstract manner.

    Usage example:

    ---

        import ocean.core.Enum;

        // Simple enum class - note that the EnumBase mixin requires the class
        // to implement IEnum
        class BasicCommands : IEnum
        {
            // Note: the [] after the first string ensures that the associative
            // array is of type int[char[]], not int[char[3]].
            mixin EnumBase!(["Get"[]:1, "Put":2, "Remove":3]);
        }

        // Inherited enum class
        class ExtendedCommands : BasicCommands
        {
            mixin EnumBase!(["GetAll"[]:4, "RemoveAll":5]);
        }

        // Check for a few names. (Note that the singleton instance of the enum
        // class is passed, using the static opCall method.)
        assert("Get" in BasicCommands());
        assert("Get" in ExtendedCommands());
        assert(!("GetAll" in BasicCommands()));
        assert("GetAll" in ExtendedCommands());

        // Example of abstract usage of enum classes
        import ocean.io.Stdout;

        void printEnumMembers ( IEnum e )
        {
            foreach ( n, v; e )
            {
                Stdout.formatln("{}: {}", n, v);
            }
        }

        // Note that the singleton instance of the enum class is passed, using
        // the static opCall method
        printEnumMembers(BasicCommands());
        printEnumMembers(ExtendedCommands());

    ---

    TODO: does it matter that the enum values are always int? We could add a
    template parameter to specify the base type, but I think it'd be a shame to
    make things more complex. IEnum would have to become a template then.

*******************************************************************************/

module ocean.core.Enum;



/*******************************************************************************

    Interface defining the basic functionality of an enum class.

*******************************************************************************/

public interface IEnum
{
    /***************************************************************************

        Aliases for the types of an enum class' names & values.

    ***************************************************************************/

    public alias char[] Name;
    public alias int Value;


    /***************************************************************************

        Looks up an enum member's name from its value.

        Params:
            v = value to look up

        Returns:
            pointer to corresponding name, or null if value doesn't exist in
            enum

    ***************************************************************************/

    public Name* opIn_r ( Value v );


    /***************************************************************************

        Looks up an enum member's value from its name.

        Params:
            n = name to look up

        Returns:
            pointer to corresponding value, or null if name doesn't exist in
            enum

    ***************************************************************************/

    public Value* opIn_r ( Name n );


    /***************************************************************************

        Returns:
            the number of members in the enum

    ***************************************************************************/

    public size_t length ( );


    /***************************************************************************

        Returns:
            the lowest value in the enum

    ***************************************************************************/

    Value min ( );


    /***************************************************************************

        Returns:
            the highest value in the enum

    ***************************************************************************/

    Value max ( );


    /***************************************************************************

        foreach iteration over the names and values in the enum.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Name name, ref Value value ) dg );


    /***************************************************************************

        foreach iteration over the names and values in the enum and their
        indices.

    ***************************************************************************/

    public int opApply (
        int delegate ( ref size_t i, ref Name name, ref Value value ) dg );
}


/*******************************************************************************

    Template which evaluates to a string containing the code for a list of enum
    members, as specified by the first two members of the passed tuple, which
    must be an array of strings and an array of integers, respectively. The
    strings specify the names of the enum members, and the integers their
    values.

    Template params:
        T = tuple:
            T[0] must be an array of strings
            T[1] must be an array of ints
        (Note that the template accepts a tuple purely as a workaround for the
        compiler's inability to handle templates which accept values of types
        such as char[][] and int[].)

*******************************************************************************/

private template EnumValues ( size_t i, T ... )
{
    static assert(T.length == 2);
    static assert(is(typeof(T[0]) : char[][]));
    static assert(is(typeof(T[1]) : int[]));

    static if ( i == T[0].length - 1 )
    {
        const char[] EnumValues = T[0][i] ~ "=" ~ T[1][i].stringof;
    }
    else
    {
        const char[] EnumValues = T[0][i] ~ "=" ~ T[1][i].stringof ~ ","
            ~ EnumValues!(i + 1, T);
    }
}


/*******************************************************************************

    Template which evaluates to a size_t corresponding to the index in the type
    tuple T which contains a class implementing the IEnum interface. If no such
    type exists in T, then the template evaluates to T.length.

    Template params:
        i = recursion index over T
        T = type tuple

*******************************************************************************/

private template SuperClassIndex ( size_t i, T ... )
{
    static if ( i == T.length )
    {
        const size_t SuperClassIndex = i;
    }
    else
    {
        static if ( is(T[i] == class) && is(T[i] : IEnum) )
        {
            const size_t SuperClassIndex = i;
        }
        else
        {
            const size_t SuperClassIndex = SuperClassIndex!(i + 1, T);
        }
    }
}


/*******************************************************************************

    Template mixin to add enum functionality to a class.

    Note that the [0..$] which is used in places in this method is a workaround
    for various weird compiler issues / segfaults.

    Template params:
        T = tuple:
            T[0] must be an associative array of type int[char[]]
        (Note that the template accepts a tuple purely as a workaround for the
        compiler's inability to handle templates which accept associative array
        values.)

    TODO: adapt to accept *either* an AA or a simple list of names (for an
    auto-enum with values starting at 0).

*******************************************************************************/

public template EnumBase ( T ... )
{
    /***************************************************************************

        Ensure that the class into which this template is mixed is an IEnum.

    ***************************************************************************/

    static assert(is(typeof(this) : IEnum));


    /***************************************************************************

        Ensure that the tuple T contains a single element which is of type
        int[char[]].

    ***************************************************************************/

    static assert(T.length == 1);
    static assert(is(typeof(T[0].keys) : char[][]));
    static assert(is(typeof(T[0].values) : int[]));


    /***************************************************************************

        Constants determining whether this class is derived from another class
        which implements IEnum.

    ***************************************************************************/

    static if ( is(typeof(this) S == super) )
    {
        private const super_class_index = SuperClassIndex!(0, S);

        private const is_derived_enum = super_class_index < S.length;
    }
    else
    {
        private const is_derived_enum = false;
    }


    /***************************************************************************

        Constant arrays of enum member names and values.

        If the class into which this template is mixed has a super class which
        is also an IEnum, the name and value arrays of the super class are
        concatenated with those in the associative array in T[0].

    ***************************************************************************/

    static if ( is_derived_enum )
    {
        static private const names =
            S[super_class_index].names[0..$] ~ T[0].keys[0..$];
        static private const values =
            S[super_class_index].values[0..$] ~ T[0].values[0..$];
    }
    else
    {
        static private const names = T[0].keys;
        static private const values = T[0].values;
    }

    static assert(names.length == values.length);


    /***************************************************************************

        The actual enum, E.

    ***************************************************************************/

    mixin("enum E {" ~ EnumValues!(0, names[0..$], values[0..$]) ~ "}");


    /***************************************************************************

        Internal maps from names <-> values. The maps are filled in the static
        constructor.

    ***************************************************************************/

    static protected Value[Name] n_to_v;
    static protected Name[Value] v_to_n;

    static this ( )
    {
        foreach ( i, n; names )
        {
            n_to_v[n] = values[i];
        }
        n_to_v.rehash;

        foreach ( i, v; values )
        {
            v_to_n[v] = names[i];
        }
        v_to_n.rehash;
    }


    /***************************************************************************

        Protected constructor, prevents external instantiation. (Use the
        singleton instance returned by opCall().)

    ***************************************************************************/

    protected this ( )
    {
        static if ( is_derived_enum )
        {
            super();
        }
    }


    /***************************************************************************

        Singleton instance of this class (used to access the IEnum methods).

    ***************************************************************************/

    private alias typeof(this) This;

    static private This inst;


    /***************************************************************************

        Returns:
            class singleton instance

    ***************************************************************************/

    static public This opCall ( )
    {
        if ( !inst )
        {
            inst = new This;
        }
        return inst;
    }


    /***************************************************************************

        Looks up an enum member's name from its value.

        Params:
            v = value to look up

        Returns:
            pointer to corresponding name, or null if value doesn't exist in
            enum

    ***************************************************************************/

    public Name* opIn_r ( Value v )
    {
        return v in v_to_n;
    }


    /***************************************************************************

        Looks up an enum member's value from its name.

        Params:
            n = name to look up

        Returns:
            pointer to corresponding value, or null if name doesn't exist in
            enum

    ***************************************************************************/

    public Value* opIn_r ( Name n )
    {
        return n in n_to_v;
    }


    /***************************************************************************

        Returns:
            the number of members in the enum

    ***************************************************************************/

    public size_t length ( )
    {
        return names.length;
    }


    /***************************************************************************

        Returns:
            the lowest value in the enum

    ***************************************************************************/

    public Value min ( )
    {
        return E.min;
    }


    /***************************************************************************

        Returns:
            the highest value in the enum

    ***************************************************************************/

    public Value max ( )
    {
        return E.max;
    }


    /***************************************************************************

        foreach iteration over the names and values in the enum.

        Note that the iterator passes the enum values as type Value (i.e. int),
        rather than values of the real enum E. This is in order to keep the
        iteration functionality in the IEnum interface, which knows nothing of
        E.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Name name, ref Value value ) dg )
    {
        int res;
        foreach ( i, n; names )
        {
            res = dg(n, values[i]);
            if ( res ) break;
        }
        return res;
    }


    /***************************************************************************

        foreach iteration over the names and values in the enum and their
        indices.

        Note that the iterator passes the enum values as type Value (i.e. int),
        rather than values of the real enum E. This is in order to keep the
        iteration functionality in the IEnum interface, which knows nothing of
        E.

    ***************************************************************************/

    public int opApply (
        int delegate ( ref size_t i, ref Name name, ref Value value ) dg )
    {
        int res;
        foreach ( i, n; names )
        {
            res = dg(i, n, values[i]);
            if ( res ) break;
        }
        return res;
    }
}



/*******************************************************************************

    Unit test.

    Tests:
        * All IEnum interface methods.
        * Enum class inheritance.

*******************************************************************************/

debug ( OceanUnitTest )
{
    /***************************************************************************

        Runs a series of asserts to check that the specified enum type contains
        members with the specified names and values. The name and value lists
        are assumed to be in the same order (i.e. names[i] corresponds to
        values[i]).

        Template params:
            E = enum type to check

        Params:
            names = list of names expected to be in the enum
            values = list of values expected to be in the enum

    ***************************************************************************/

    void checkEnum ( E : IEnum ) ( char[][] names, int[] values )
    in
    {
        assert(names.length == values.length);
        assert(names.length);
    }
    body
    {
        // Internal name/value lists
        assert(E.names == names);
        assert(E.values == values);

        // Lookup by name
        foreach ( i, n; names )
        {
            assert(n in E());
            assert(*(n in E()) == values[i]);
        }

        // Lookup by value
        foreach ( i, v; values )
        {
            assert(v in E());
            assert(*(v in E()) == names[i]);
        }

        // length
        assert(E().length == names.length);

        // Check min & max
        int min = int.max;
        int max = int.min;
        foreach ( v; values )
        {
            if ( v < min ) min = v;
            if ( v > max ) max = v;
        }
        assert(E().min == min);
        assert(E().max == max);

        // opApply 1
        size_t i;
        foreach ( n, v; E() )
        {
            assert(n == names[i]);
            assert(v == values[i]);
            i++;
        }

        // opApply 2
        foreach ( i, n, v; E() )
        {
            assert(n == names[i]);
            assert(v == values[i]);
        }
    }

    class Enum1 : IEnum
    {
        mixin EnumBase!(["a"[]:1, "b":2, "c":3]);
    }

    class Enum2 : Enum1
    {
        mixin EnumBase!(["d"[]:4, "e":5, "f":6]);
    }

    unittest
    {
        checkEnum!(Enum1)(["a", "b", "c"], [1, 2, 3]);
        checkEnum!(Enum2)(["a", "b", "c", "d", "e", "f"], [1, 2, 3, 4, 5, 6]);
    }
}

