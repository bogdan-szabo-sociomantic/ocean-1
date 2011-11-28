/******************************************************************************
    
    Module for the conversion between strings in C and D. Needed for C library 
    bindings. 
    
    --

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        October 2010: Initial release

    author:         David Eckardt

    --
    
    Description:
    
    --
    
    Usage:
    
    ---
        
        char[] text;
        
        char* cText = StringC.toCString(text);        
        char[] text = StringD.toDString(cText);
                
    ---

    FIXME: the functions here are not memory safe, they need to be re-written to
    accept ref char[].
    
 ******************************************************************************/


module ocean.text.util.StringC;


private import  tango.stdc.string: strlen, wcslen;
private import  tango.stdc.wctype: wchar_t;


class StringC
{
    /**************************************************************************
     
        Wide character type alias (platform dependent)
     
     **************************************************************************/
    
	public alias wchar_t Wchar;
	
    /**************************************************************************
    
        Null terminators
     
     **************************************************************************/

	public static const char  Term  = '\0';
    public static const Wchar Wterm = '\0';
    
    /**************************************************************************
	
	    Converts str to a C string, that is, a null terminator is appended if
	    not present.
	    
	    Params:
	        str = input string
	    
	    Returns:
	        C compatible (null terminated) string
	    
     ***************************************************************************/
    
    public static char* toCstring ( char[] str )
    {
        bool term = str.length? !!str[$ - 1] : true;
        
        return (term ? str ~ this.Term : str).ptr;
    }
    
    
    
	/**************************************************************************
	
	    Converts str to a C string, that is, a null terminator is appended if
	    not present.
	    
	    Params:
	        str = input string
	    
	    Returns:
	        C compatible (null terminated) string
	    
	***************************************************************************/
	
	public static Wchar* toCstring ( Wchar[] str )
	{
	    bool term = str.length? !!str[$ - 1] : true;
	    
	    return (term ? str ~ this.Wterm : str).ptr;
	}
	
	
	
	/**************************************************************************
	
	    Converts str to a D string: str is sliced from beginning to its null
	    terminator.
	    
	    Params:
	        str = C compatible input string (pointer to first element of null
	              terminated string)
	    
	    Returns:
	        C compatible (null terminated) string
	    
	 ***************************************************************************/
	
	public static char[] toDString ( char* str )
	{
	    return str? str[0 .. strlen(str)] : "";
	}	
    
	/**************************************************************************
	
	    Converts str to a D string: str is sliced from beginning to its null
	    terminator.
	    
	    Params:
	        str = C compatible input string (pointer to first element of null
	              terminated string)
	    
	    Returns:
	        C compatible (null terminated) string
	    
	***************************************************************************/
	
	public static Wchar[] toDString ( Wchar* str )
	{
	    return str? str[0 .. wcslen(str)] : "";
	}	
}