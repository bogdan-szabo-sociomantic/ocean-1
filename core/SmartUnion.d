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

/******************************************************************************

    Provides a getter and setter method for each member of U. Additionally an
    "Active" enumerator and an "active" getter method is provided. The "Active"
    enumerator members copy the U member names, the values of that members start
    with 1. The "Actve" enumerator has an additional "none" member with the
    value 0. The "active" getter method returns

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
    
    pragma (msg, _.AllMethods!("_"));
    mixin (_.AllMethods!("_"));
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

        Required for V.tupleof[i].stringof[4 .. $] to work
    
     **************************************************************************/

    typedef U V;
    
    /**************************************************************************

        Evaluates to the name of the i-th member of U.
        
        Template params:
            i = U member index
        
        Evaluates to:
            the name of the i-th member of U
        
     **************************************************************************/

    template Member ( uint i )
    {
        const Member = V.tupleof[i].stringof[4 .. $];                           // V.tupleof[i].stringof is "(V).{name}"
    }
    
    /**************************************************************************

        Appends a ',' separated list of the names of the members of U to pre.
        
        Template params:
            pre = prefix, the name list will appended to pre
            i   = U member start index
        
        Evaluates to:
            a ',' separated list of the names of the members of U to pre
        
     **************************************************************************/

    template MemberList ( char[] pre = "", uint i = 0 )
    {
        static if (i < N)
        {
            const MemberList = MemberList!(pre ~ ',' ~ Member!(i), i + 1);
        }
        else
        {
            const MemberList = pre;
        }
    }
    
    /**************************************************************************

        Active enumerator definition string mixin
        
     **************************************************************************/

    const EnumCode = MemberList!("enum Active{none") ~ '}';
    
    pragma (msg, EnumCode);
    
    mixin (EnumCode);
    
    /**************************************************************************

        Memorizes which member is currently active (initially none which is 0)
        
     **************************************************************************/

    Active active;
    
    /**************************************************************************

        Evaluates to code defining a getter and/or a setter method where name of
        each method is pre ~ ".u." ~ the name of the i-th member of U.
        Both methods use pre ~ ".active" which must be the Active enumerator:
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
            
            typeof (my_smart_union.u.y) y()
            in
            {
                assert(this.my_smart_union.active == this.my_smart_union.active.y,
                       "UniStruct: \"y\" not active");
            }
            body
            {
                return this.my_smart_union.u.y;
            }
            
            // Setter for my_smart_union.u.y. Params:
            //     y = new value for y
            // Returns:
            //     y
            
            typeof (my_smart_union.u.y) y(typeof (my_smart_union.u.y) y)
            {
                this.my_smart_union.u.y = y;
                this.my_smart_union.active = this.my_smart_union.active.y;
                return y;
            }
        ---
        .
        
        Methods.get and Methods.set evaluate to only the getter or setter
        method, respectively.
        
        Template params:
            pre = prefix for U instance "u"
            i   = index of U instance "u" member
        
        Evaluates to:
            get  = getter method for the U member
            set  = setter method for the U member
            both = both getter and setter method for the U member
        
     **************************************************************************/

    template Methods ( char[] u_pre, uint i )
    {
        const member = Member!(i);
        
        const member_access = u_pre ~ ".u." ~ member;
        
        const type = "typeof(" ~ member_access ~ ')';
        
        const get = type ~ ' ' ~  member ~ "() "
                    "in {assert(this." ~ u_pre ~ ".active==this." ~ u_pre ~ ".active." ~ member ~ ","
                    "\"UniStruct: \\\"" ~ member ~ "\\\" not active\");} "
                    "body {return this." ~ member_access ~ ";}";

        
        const set = type ~ ' ' ~  member ~ '(' ~ type ~ ' ' ~ member ~ ')' ~ " "
                    "{this." ~ member_access ~ '=' ~ member ~ "; "
                    "this." ~ u_pre ~ ".active=this." ~ u_pre ~ ".active." ~ member ~ "; "
                    "return " ~ member ~ ";}";
        
        const both = get ~ '\n' ~ set;
    }
    
    /**************************************************************************

        Evaluates to code defining a getter and setter method for each U member.
        
        Template params:
            u_pre = prefix for U instance "u"
            pre   = method definition code prefix, code will be appended to pre
            i     = U instance "u" member start index
        
        Evaluates to:
            code defining a getter and setter method for each U member
        
     **************************************************************************/

    template AllMethods ( char[] u_pre, char[] pre = "", uint i = 0 )
    {
        static if (i < N)
        {
            const AllMethods = AllMethods!(u_pre, pre ~ '\n' ~ Methods!(u_pre, i).both, i + 1);
        }
        else
        {
            const AllMethods = pre;
        }
    }
}
