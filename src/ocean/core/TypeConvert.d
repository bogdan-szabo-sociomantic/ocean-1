/*******************************************************************************

    copyright: Copyright (c) 2015 sociomantic labs. All rights reserved

    Functions to help with type conversion.

*******************************************************************************/

module ocean.core.TypeConvert;


/*******************************************************************************

    Imports

*******************************************************************************/

version ( UnitTest ) import ocean.core.Test;


/*******************************************************************************

    Casts an object of one class to another class. Using this function is safer
    than a plain cast, as it also statically ensures that the variable being
    cast from is a class or an interface.

    Template params:
        To = type to cast to (must be a class)
        From = type to cast from (must be a class or interface)

    Params:
        value = object to be cast to type To

    Returns:
        input parameter cast to type To. The returned object may be null if the
        From cannot be downcast to To

*******************************************************************************/

public To downcast ( To, From ) ( From value )
{
    static assert(is(To == class));
    static assert(is(From == class) || is(From == interface));

    return cast(To)value;
}

version ( UnitTest )
{
    class A { }
    class B : A { }
    interface I { }
    class C : I { }
}

unittest
{
    // Basic type does not compile
    static assert(!is(typeof({ int i; downcast!(Object)(i); })));

    // Pointer to object does not compile
    static assert(!is(typeof({ Object* o; downcast!(Object)(o); })));

    // Object compiles
    static assert(is(typeof({ Object o; downcast!(Object)(o); })));

    // Interface compiles
    static assert(is(typeof({ I i; downcast!(Object)(i); })));

    // Downcast succeeds for derived class
    {
        A a = new B;
        B b = downcast!(B)(a);
        test!("!is")(cast(void*)b, null);
    }

    // Downcast succeeds for derived interface
    {
        I i = new C;
        C c = downcast!(C)(i);
        test!("!is")(cast(void*)c, null);
    }

    // Downcast fails for non-derived class
    {
        A a = new B;
        C c = downcast!(C)(a);
        test!("is")(cast(void*)c, null);
    }

    // Downcast fails for non-derived interface
    {
        I i = new C;
        B b = downcast!(B)(i);
        test!("is")(cast(void*)b, null);
    }
}


/*******************************************************************************

    Explicit cast function -- both from and to types must be specified by the
    user and are statically ensured to be correct. This extra security can help
    prevent refactoring errors.

    Usage:
    ---
        int i;
        float f = castFrom!(int).to!(float)(i);
    ---

    Template params:
        From = type to cast from
        To = type to cast to
        T = type of value being cast (statically checked to be == From)

    Params:
        value = value to be cast to type To

    Returns:
        input parameter cast to type To

*******************************************************************************/

template castFrom ( From )
{
    To to ( To, T ) ( T value )
    {
        static assert(
            is(From == T),
            "the value to cast is not of specified type '" ~ From.stringof ~
            "', it is of type '" ~ T.stringof ~ "'"
        );

        static assert(
            is(typeof(cast(To)value)),
            "can't cast from '" ~ From.stringof ~ "' to '" ~ To.stringof ~ "'"
        );

        return cast(To)value;
    }
}

unittest
{
    // Mismatched From does not compile
    static assert(!is(typeof({ int x; castFrom!(float).to!(char)(x); })));

    // Mismatched but implicitly castable From does not compile
    static assert(!is(typeof({ double x; castFrom!(float).to!(char)(x); })));

    // Illegal cast does not compile
    static assert(!is(typeof({ void* p; castFrom!(void*).to!(int[30])(p); })));

    // Valid case compiles
    static assert(is(typeof({ int x; castFrom!(int).to!(float)(x); })));
}
