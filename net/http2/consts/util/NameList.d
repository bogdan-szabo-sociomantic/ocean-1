/******************************************************************************

    Name string list generator for HeaderFieldNames and CookieAttributeNames
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
    To be mixed into a struct; creates a NameList member.
    
 ******************************************************************************/

module ocean.net.http2.consts.util.NameList;

/******************************************************************************/             

template NameList ( )
{
    static assert (is (typeof (this.Names)), "no \"Names\"");
    
    /**************************************************************************
    
        NameList member
    
     **************************************************************************/             
    
    static typeof (this.Names.tupleof)[0][(typeof (this.Names.tupleof)).length] NameList; 
    
    /**********************************************************************
    
        Static constructor; populates NameList
    
     **********************************************************************/             
    
    static this ( )
    {
        foreach (i, name; this.Names.tupleof)
        {
            static assert (is (typeof (name) == char[]), typeof (*this).stringof ~ ": Field "  ~ i.stringof ~ 
                           " is not a char[] (but \"" ~ typeof (name).stringof ~ "\")");
            
            assert (name.length, typeof (*this).stringof ~
                                 this.Names.tupleof[i].stringof[this.Names.stringof.length .. $] ~
                                 " is empty");
            
            this.NameList[i] = name;
        }
    }
}