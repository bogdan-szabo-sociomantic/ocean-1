/******************************************************************************

    Use ocean.core SmartUnion instead

    Union providing type-based member access and automatic type checking

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        August 2010: Initial release

    authors:        David Eckardt

    Description:

        The UniStruct is a struct containing two data members:

            - an union and
            - an enumerator that tells which union member is currently set.

        The UniStruct furthermore contains set() and get() methods. set()
        automatically sets the union member that matches the type of the
        provided argument and sets the enumerator to the type of the union
        member that was set. get() asserts that the type of the provided
        argument matches the enumerator value and outputs the value of the
        currently set union member.

        The TypeId template parameter is the type identifier enumerator.
        The Types template parameter is the list of types which should be
        contained by the union.

        TypeId must cover the range of 0 .. Types.length - 1. It may contain
        more values, even negative ones, which are ignored.

 ******************************************************************************/

deprecated module ocean.core.UniStruct;

/*******************************************************************************

    Imports

*******************************************************************************/

import tango.core.Traits;


/*******************************************************************************

    UniStructException

*******************************************************************************/

class UniStructException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static void opCall ( Args ... ) ( Args args )
    {
        throw new UniStructException(args);
    }
}


struct UniStruct ( Types ... )
{
    /***************************************************************************

        Template that returns the upper case version of the provided character

    ***************************************************************************/

    template upper (char a)
    {
        static if (a <= 'z' && a >='a')
        {
            const char upper =  a-32;
        }
        else
        {
            const char upper = a;
        }
    }

    /***************************************************************************

        Checks whether the string is a valid symbol name for enum

    ***************************************************************************/

    template validSymbols(char[] Check)
    {
        static if (Check.length > 0 &&
                  Check[0] != ' ' &&
                  Check[0] != '(' &&
                  Check[0] != ')')
        {
            const validSymbols = validSymbols!(Check[1..$]);
        }
        else static if (Check.length > 0)
        {
            const validSymbols = false;
        }
        else
        {
            const validSymbols = true;
        }
    }

    /***************************************************************************

        template that creates a comma separated list as string
        of the provided tuple values

    ***************************************************************************/

    template createList (MyTypes...)
    {
        static if (MyTypes.length > 0)
        {
            static if(validSymbols!(MyTypes[0].stringof))
            {
                const char[] createList = upper!(MyTypes[0].stringof[0])
                         ~MyTypes[0].stringof[1 .. $]
                     ~ ", " ~ createList!(MyTypes[1..$]);
            }
            else
            {
                const char[] createList = MyTypes[0].mangleof ~ ", " ~ createList!(MyTypes[1..$]);
            }
        }
        else
        {
            const char[] createList =  "";
        }

    }

    /***************************************************************************

        Mixin of an auto-generated enum of the types, first letter is always
        upper case to avoid conflicts with basic datatypes (int -> Int)

    ***************************************************************************/

    mixin("enum TypeId { "~createList!(Types)~" }");

    /**************************************************************************

         Type customized union template

         Template parameter:
             Types = list of types of the union members

     **************************************************************************/

    static union TUnion ( Types ... )
    {
        /**********************************************************************

             Members (tuple)

         **********************************************************************/

        Types items;

        /**********************************************************************

            Sets the id-th member

            Template parameter:
                id = id of the member to set (one of 0 .. Types.length - 1)

            Params:
                item = value to set the id-th member to

            Returns:
                provided member id

        **********************************************************************/

        size_t set ( size_t id ) ( Types[id] item )
        {
            this.items[id] = item;

            return id;
        }

        /**********************************************************************

            Gets the value of the id-th member

            Template parameter:
                id = id of the member to set (one of 0 .. Types.length - 1)

            Returns:
                value of id-th member

        **********************************************************************/

        Types[id] get ( size_t id ) ( )
        {
            return this.items[id];
        }

        /**********************************************************************

            Evaluates to the type of the id-th member

            Template parameter:
                id = id to get the corresponding member type of

            Evaluates to:
                type of the id-th member

        **********************************************************************/

        template Type ( size_t id )
        {
            alias Types[id] Type;
        }

        /**********************************************************************

            Evaluates to the id of the member that has type Type.

            Template parameter:
                Type = Type of the member that has the id to get

            Evaluates to:
                id of the member that has type Type

        **********************************************************************/

        template Id ( Type, size_t id = 0 )
        {
            static if (id < Types.length)
            {
                static if (is (Types[id] == Type))
                {
                    const Id = id;
                }
                else
                {
                    const Id = Id!(Type, id + 1);
                }
            }
            else static assert (false, typeof (*this).stringof ~ ": unsupported type '" ~ Type.stringof ~ '\'');
        }
    } // TUnion

    /**************************************************************************

        Union instance

    **************************************************************************/

    private TUnion!(Types) tu;

    /**************************************************************************

        Union instance type alias

    **************************************************************************/

    alias typeof (tu) TU;

    /**************************************************************************

        Type enumerator

        Tells which union member is currently set.

    **************************************************************************/

    private TypeId type_id_;

    /**************************************************************************

        Sets the the internal union member corresponding to type_id.

        Template parameter:
            type_id = type id of the internal union member to set

        Params:
            item = value to set the union member to

    **************************************************************************/

    void set ( TypeId type_id ) ( Types[type_id] item )
    {
        this.type_id_ = cast (TypeId) this.tu.set!(type_id)(item);
    }

    /**************************************************************************

        Sets the internal union member whose type matches the type of item.

        Params:
            item = value to set the union member to

    **************************************************************************/

    void set ( Type ) ( Type item )
    {
        this.set!(Id!(Type))(item);
    }

    /**************************************************************************

        Returns  the value of the internal union member that corresponds to
        type_id.
        Asserts that type_id matches the id of the union member that has most
        recently been set.

        Template parameter:
            type_id = type id of the internal union member to get the value from

        Returns:
            value of the internal union member that corresponds to type_id

    **************************************************************************/

    Type!(type_id) get ( TypeId type_id ) ( )
    {
        if(type_id != this.type_id_)
            throw new UniStructException(typeof (*this).stringof ~ ": type id mismatch");

        static if (type_id >= 0)
        {
           return this.tu.get!(type_id)();
        }
    }

    /***************************************************************************

        Provides a (slightly modified) visitor-pattern accessor.

        Visit will return whatever the called delegate returns.

        Usage:
        ---
        UniStruct!(float,int) example;

        example.set(4999);

        // This will output "Value is an int : 4999"
        example.visit(
          (float val) { Stdout.formatln("Value is a float: {}",val); },
          (int   val) { Stdout.formatln("Value is an int : {}",val); });

        // You don't need to provide a method for every datatype,
        // but it will throw if you provided no delegate for the current type
        example.visit(
          (int   val) { Stdout.formatln("Value is an int : {}",val); });

        ---
            Params:
                delegates = one or more delegates, passed as varargs,
                            that take one of the UniStruct types as parameter

    ***************************************************************************/

    ReturnTypeOf!(Tuple[0]) visit ( Tuple ... ) ( Tuple delegates )
    {
        foreach (i,type; Tuple)
        {
            foreach ( paraTypes; ParameterTupleOf!(type))
            {
                const Id = Id!(paraTypes);

                if (Id == this.type_id_)
                {
                    return delegates[i](this.tu.get!(Id));
                }
            }
        }
        throw new UniStructException("No delegate fits");
    }

    /**************************************************************************

        Outputs the value of the internal union member whose type matches the
        type of item.
        Asserts that the type matches the type of the union member that has most
        recently been set.

        Params:
            item = destination for the value of the internal union member that
                   matches the type

        Returns:
            type id of the internal union member of which the value has been
            got from

    **************************************************************************/

    TypeId get ( Type ) ( out Type item )
    {
        const Id = Id!(Type);

        item = this.get!(Id)();

        return Id;
    }

    /**************************************************************************

        Returns the current type id. That is, the type id of the internal union
        member that has most recently been set.

        Returns:
            current type id

    **************************************************************************/

    TypeId type_id ( )
    {
        return this.type_id_;
    }

    /**************************************************************************

       Evaluates to the type that corresponds to type_id, if type_id is in the
       range of 0 .. Types.length, or to void otherwise

       Template parameter:
           type_id = type ID to get the corresponding type for

       Evaluates to:
           type corresponding to type_id, if type_id is in the range of
           0 .. Types.length, or to void otherwise

    **************************************************************************/

    template Type ( TypeId type_id )
    {
        static if (0 <= type_id && type_id < Types.length)
        {
            alias Types[type_id] Type;
        }
        else
        {
            alias void Type;
        }
    }

    /**************************************************************************

        Evaluates to the type ID that corresponds to Type.

        Template parameter:
            Type = type to get the corresponding ID for

        Evaluates to:
            type ID corresponding to Type

     **************************************************************************/

    template Id ( Type )
    {
        const Id = cast (TypeId) TU.Id!(Type);
    }
}

version (UnitTest)
{
    class Empty { int me; this(int a) { me = a; } };
}

unittest
{
    UniStruct!(int,float,Object) test;

    test.set!(float)(46);
    assert(test.type_id() == test.TypeId.Float);

    test.visit((float me) { assert(me == 46.0); } );

    test.set(34);
    assert(test.type_id == test.TypeId.Int);


    test.visit((float me) { assert(false); },
               (  int me) { assert(me == 34); });

    test.set!(Object)(new Empty(3));
    assert((cast(Empty)test.get!(test.TypeId.Object)()).me == 3);

    test.set!(test.TypeId.Int)(cast(int)19.0);

    {
        bool catched=false;
        try test.get!(test.TypeId.Float)();
        catch (UniStructException e) catched = true;
        assert(catched);
    }

    int tmp = void;
    test.get(tmp);
    assert(tmp == 19);


}

