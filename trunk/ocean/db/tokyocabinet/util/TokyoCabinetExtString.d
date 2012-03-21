/******************************************************************************

    Tokyo Cabinet Extensible Strings

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)
    
    version:        May 2010: Initial release
                    
    author:         David Eckardt
    
 ******************************************************************************/

module ocean.db.tokyocabinet.util.TokyoCabinetExtString;

/******************************************************************************

    Imports
    
 ******************************************************************************/

private import ocean.db.tokyocabinet.c.util.tcxstr: TCXSTR,
                                                    tcxstrnew, tcxstrnew3,
                                                    tcxstrdel, tcxstrclear,
                                                    tcxstrdup, tcxstrcat,
                                                    tcxstrptr, tcxstrsize;

/******************************************************************************

    TokyoCabinetExtString class

 ******************************************************************************/

class TokyoCabinetExtString
{
    /**************************************************************************
    
        This alias for chainable methods
        
    ***************************************************************************/

    alias typeof (this) This;
    
    /**************************************************************************
    
        Tokyo Cabinet extensible string object
        
    ***************************************************************************/

    private TCXSTR* xstr;
    
    /**************************************************************************
    
        Constructor
        
    ***************************************************************************/

    public this ( )
    {
        this.xstr = tcxstrnew();
    }
    
    /**************************************************************************
    
        Constructor
        
        Params:
            asiz = initial size (bytes)
        
     ***************************************************************************/
    
    public this ( int asiz )
    {
        this.xstr = tcxstrnew3(asiz);
    }
    
    /**************************************************************************
    
        Copy constructor
        
        Params:
            xstr = existing Tokyo Cabinet extensible string object
        
    ***************************************************************************/

    public this ( TCXSTR* xstr )
    {
        this.xstr = xstr;
    }
    
    /**************************************************************************
    
        Returns the native Tokyo Cabinet extensible string object
        
        Returns:
            native Tokyo Cabinet extensible string object
        
    ***************************************************************************/

    public TCXSTR* getNative ( )
    {
        return this.xstr;
    }
    
    /**************************************************************************
    
        Returns the string content of this instance
        
        Returns:
            string content of this instance
        
    ***************************************************************************/

    public char[] toString ( )
    {
        return (cast (char*) tcxstrptr(this.xstr))[0 .. this.getLength()];
    }
    
    /**************************************************************************
    
        Duplicates this instance
        
        Returns:
            duplicate of this instance
        
    ***************************************************************************/

    public This dup ( )
    {
        return new This(tcxstrdup(this.xstr));
    }
    
    /**************************************************************************
    
        Appends str to current string content
        
        Params:
            str = string to append
        
        Returns:
            this instance
        
    ***************************************************************************/

    public This opCatAssign ( char[] str )
    {
        tcxstrcat(this.xstr, str.ptr, str.length);
        
        return this;
    }
    
    /**************************************************************************
    
        Returns the length of string content
        
        Returns:
            length of string content
        
    ***************************************************************************/

    public int getLength ( )
    {
        return tcxstrsize(this.xstr);
    }
    
    /**************************************************************************
    
        Clears the string content
        
        Returns:
            this instance
        
    ***************************************************************************/

    public This clear ( )
    {
        tcxstrclear(this.xstr);
        
        return this;
    }
    
    /**************************************************************************
    
        Destructor
        
    ***************************************************************************/

    private ~this ( )
    {
        tcxstrdel(this.xstr);
    }
}