/******************************************************************************

    Template for a union that knows its active field and uses contracts to
    assert that always the active field is read.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        April 2010: Initial release

    authors:        David Eckardt

    Usage:
    ---
        import $(TITLE);

        union MyUnion
        {
            int    x;
            char[] y;
        }

        void main ( )
        {
            SmartUnion!(MyUnion) u;

            u.Active a;             // u.Active is defined as
                                    // enum u.Active {none, x, y}
            a = u.active;           // a is now a.none

            int b = u.x;            // error, u.x has not yet been set
            u.x   = 35;

            a = u.active;           // a is now a.x

            char[] c = u.y          // error, u.y is not the active member
        }
    ---

 ******************************************************************************/

module ocean.core.SmartUnion;

public import ocean.core.Traits : FieldName;
import tango.transition;


/******************************************************************************

    Provides a getter and setter method for each member of U. Additionally an
    "Active" enumerator and an "active" getter method is provided. The "Active"
    enumerator members copy the U member names, the values of that members start
    with 1. The "Active" enumerator has an additional "none" member with the
    value 0. The "active" getter method returns the "Active" enumerator value of
    the type currently set in the union -- this may be "none" if the union is in
    its initial state.

 ******************************************************************************/

struct SmartUnion ( U )
{
    static assert (is (U == union), "SmartUnion: need a union, not \"" ~ U.stringof ~ '"');

    /**************************************************************************

        Holds the actual union U instance and Active enumerator value. To reduce
        the risk of a name collision, this member is named "_".

     **************************************************************************/

    private SmartUnionIntern!(U) _;

    /**************************************************************************

        Active enumerator type alias

        Note: There is a member named "_".

     **************************************************************************/

    alias _.Active Active;

    /**************************************************************************

        Returns:
            Active enumerator value of the currently active member or 0
            (Active.none) if no member has yet been set.

     **************************************************************************/

    Active active ( ) { return this._.active; }

    /**************************************************************************

        Member getter/setter method definitions string mixin

     **************************************************************************/

    //pragma (msg, AllMethods!(U, "", 0));
    mixin (AllMethods!(U, "", 0));

    /// typeof(this) is a pointer in D1, the type in D2.
    version(D_Version2) private alias typeof(this) Type;
    else private alias typeof(*this) Type;
}

/******************************************************************************

    Holds the actual union U instance and Active enumerator value and provides
    templates to generate the code defining the member getter/setter methods and
    the Active enumerator.

 ******************************************************************************/

private struct SmartUnionIntern ( U )
{
    /**************************************************************************

        U instance

     **************************************************************************/

    U u;

    /**************************************************************************

        Number of members in U

     **************************************************************************/

    const N = U.tupleof.length;

    /**************************************************************************

        Active enumerator definition string mixin

     **************************************************************************/

//    pragma(msg,"enum Active{none" ~ MemberList!(0, N, U) ~ "}");
    mixin("enum Active{none" ~ MemberList!(0, N, U) ~ "}");

    /**************************************************************************

        Memorizes which member is currently active (initially none which is 0)

     **************************************************************************/

    Active active;
}

/*******************************************************************************

    Evaluates to a ',' separated list of the names of the members of U.

    Template params:
        i   = U member start index

    Evaluates to:
        a ',' separated list of the names of the members of U

*******************************************************************************/

private template MemberList ( uint i, size_t len, U )
{
    static if ( i == len )
    {
        const MemberList = "";
    }
    else
    {
        const MemberList = "," ~ FieldName!(i, U) ~ MemberList!(i + 1, len, U);
    }
}


/*******************************************************************************

    Evaluates to code defining a getter, a setter and a static opCall()
    initializer method, where the name of the getter/setter method is
    pre ~ ".u." ~ the name of the i-th member of U.

    The getter/setter methods use pre ~ ".active" which must be the Active
    enumerator:
        - the getter uses an 'in' contract to make sure the active member is
          accessed,
        - the setter method sets pre ~ ".active" to the active member.

    Example: For
    ---
        union U {int x; char y;}
    ---

    ---
        mixin (Methods!("my_smart_union", 1).both);
    ---
    evaluates to
    ---
        // Getter for my_smart_union.u.y. Returns:
        //     my_smart_union.u.y

        char[] y()
        in
        {
            assert(my_smart_union.active == my_smart_union.active.y,
                   "UniStruct: \"y\" not active");
        }
        body
        {
            return my_smart_union.u.y;
        }

        // Setter for my_smart_union.u.y. Params:
        //     y = new value for y
        // Returns:
        //     y

        char[] y(char[] y)
        {
           my_smart_union.active = my_smart_union.active.y;
           return my_smart_union.u.y = y;
        }
    ---

    Methods.get and Methods.set evaluate to only the getter or setter
    method, respectively.

    Template params:
        pre = prefix for U instance "u"
        i   = index of U instance "u" member

    Evaluates to:
        get  = getter method for the U member
        set  = setter method for the U member
        opCall = static SmartUnion initialiser with the value set to the U
            member

*******************************************************************************/

private template Methods ( U, uint i )
{
    const member = FieldName!(i, U);

    const member_access = "_.u." ~ member;

    const type = "typeof(" ~ member_access ~ ")";

    const get = type ~ ' ' ~  member ~ "() "
        ~ "in { assert(_.active == _.active." ~ member ~ ", "
        ~ `"SmartUnion: '` ~ member ~ `' not active"); } `
        ~ "body { return " ~ member_access ~ "; }";

    const set = type ~ ' ' ~  member ~ '(' ~ type ~ ' ' ~ member ~ ")"
        ~ "{ _.active = _.active." ~ member ~ ";"
        ~ "return " ~ member_access ~ '=' ~ member ~ "; }";

    const ini = "static Type opCall(" ~ type ~ ' ' ~ member ~ ")"
        ~ "{ Type su; su." ~ member ~ '=' ~ member ~ "; return su; }";

    const all = get ~ '\n' ~ set ~ '\n' ~ ini;
}

/*******************************************************************************

    Evaluates to code defining a getter and setter method for each U member.

    Template params:
        u_pre = prefix for U instance "u"
        pre   = method definition code prefix, code will be appended to pre
        i     = U instance "u" member start index

    Evaluates to:
        code defining a getter and setter method for each U member

*******************************************************************************/

private template AllMethods ( U, cstring pre, uint i)
{
    static if (i < U.tupleof.length)
    {
        const AllMethods =
            AllMethods!(U, pre ~ '\n' ~ Methods!(U, i).all, i + 1);
    }
    else
    {
        const AllMethods = pre;
    }
}
