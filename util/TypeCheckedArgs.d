/*******************************************************************************
    
    Check and cast C-style va_args variable CLI argument lists.
   
    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        October 2009: Initial release

    author:        David Eckardt

    --
    
    Usage:
    
    ---

    import core.util.TypeCheckedArgs;
    
    int myfunc( TypeInfo[] argtypes, void* args )
    {
          
        // This function expects to be called as "int myfunc(int, float, char[])"
             
        int i;
        float f;
        char[] str;
          
        bool err = false;
        
        TypeCheckedArgs tcargs = new TypeCheckedArgs(argtypes, args);
              
        // Call getArg() repeatedly to fill i, f and str with the
        // values from the variable argument list.
        // Each time getArg() returns the index of the retrieved
        // argument starting with 1 on success, or 0 on error. 
              
        err |= !tcargs.getArg!(int)(i);
        err |= !tcargs.getArg!(float)(f);
        err |= !tcargs.getArg!(char[])(str);
              
        if (err) return -1;
              
        // ...
     }

	---
	
*******************************************************************************/

module core.util.TypeCheckedArgs;


/*******************************************************************************

		imports

 ******************************************************************************/

private import 	stdarg = tango.stdc.stdarg;



/*******************************************************************************

	Class for handling and accessing CLI arguments   

	
	@author  David Eckardt <david.eckardt () sociomantic () com>	        
	@package ocean.util
	@link    http://www.sociomantic.com

*******************************************************************************/

class TypeCheckedArgs
{

	/***************************************************************************
    
        properties

     **************************************************************************/
       
    private int        index;
    private int        total;
    private void*      args;
    private TypeInfo[] argtypes;
    
    
    
    /***************************************************************************

		Constructor
     
     	Params:
			argtypes 	= variable arguments list typeinfo
			args     	= variable arguments list data
			
     **************************************************************************/
    
    this ( TypeInfo[] argtypes, void* args )
    {
        this.index    = 0;
        this.total    = argtypes.length;
        this.args     = args;
        this.argtypes = argtypes;
    }
    
    
    
    /***************************************************************************
     
		Checks if there is a next argument in the list. If yes, then checks if
		the next argument has type T. If yes, then calls va_arg() to pop it
		from the variable arguments list and store its value in x.

		Params:
			x = The variable to store the value of next argument.
		
		Returns:
			The index of the current argument starting with 1 on success,
			or 0 on type mismatch or end of list reached.

     **************************************************************************/
    
    public int getArg ( T ) ( ref T x )
    {
        bool ok = true;
        
        ok &= (this.index < this.total);
        
        if (ok)
        {
            if (argtypes[this.index] == typeid(T))
            {
                x = stdarg.va_arg!(T)(this.args);
                this.index++;
            }
        }

        return ok? this.index: 0;
    }
}
