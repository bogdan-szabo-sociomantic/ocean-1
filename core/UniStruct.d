/******************************************************************************

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

module ocean.core.UniStruct;

struct UniStruct ( TypeId, Types ... )
{
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
    in
    {
        assert (type_id == this.type_id_, typeof (*this).stringof ~ ": type id mismatch");
    }
    body
    {
        static if (type_id >= 0)
        {
            return this.tu.get!(type_id)();
        }
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