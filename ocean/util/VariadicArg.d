/*******************************************************************************
    
    Check and cast argument list of variadic functions.
   
    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        October 2009: Initial release

    author:        David Eckardt

    --
    
    Usage:
    
    Example 1: Using the getArgs() static method:
    
    ---
    
        import $(TITLE);
        
        void myfunc( ... )
        {
              
            // This function expects to be called as "int myfunc(int, float, char[])"
                 
            int i;
            float f;
            char[] str;
            
            VariadicArg.getArgs(_arguments, _argptr, i, f, str);
                  
            // i, f and str now contain the values on success. On failure an
            // exeption was thrown.
         }

    
    
    ---
    
    Example 2: Using an instance of VariadicArg:
    
    ---

    import $(TITLE);
    
    int myfunc( ... )
    {
          
        // This function expects to be called as "int myfunc(int, float, char[])"
             
        int i;
        float f;
        char[] str;
          
        bool err = false;
        
        VariadicArg varg = new VariadicArg(_arguments, _argptr);
              
        // Call getArg() repeatedly to fill i, f and str with the
        // values from the variable argument list.
        // Each time getArg() returns the index of the retrieved
        // argument starting with 1 on success, or 0 on error. 
              
        err |= !varg.getArg(i);
        err |= !varg.getArg(f);
        err |= !varg.getArg(str);
              
        if (err) return -1;
              
        // ...
     }

	---
	
*******************************************************************************/

module core.util.VariadicArg;

/*******************************************************************************

	Class for handling and accessing CLI arguments   

	
	@author  David Eckardt <david.eckardt () sociomantic () com>	        
	@package ocean.util
	@link    http://www.sociomantic.com

*******************************************************************************/

class VariadicArg
{

	/***************************************************************************
    
        properties

     **************************************************************************/
       
    private uint       index = 0;
    private uint       total = 0;
    private TypeInfo[] arguments;
    private void*      argptr;
    
    
    
    /***************************************************************************

		Constructor
     
     	Params:
			arguments 	= variable arguments list typeinfo
			argptr     	= variable arguments list data
			
     **************************************************************************/
    
    this ( TypeInfo[] arguments, void* argptr )
    {
        this.index     = 0;
        this.total     = arguments.length;
        this.argptr    = argptr;
        this.arguments = arguments;
    }
    
    /***************************************************************************
     
		Checks if there is a next argument in the list. If yes, then checks if
		the next argument has type T. If yes, then calls va_arg() to pop it
		from the variable arguments list and store its value in x.

		Params:
			x = The variable to store the value of next argument.
		
		Returns:
			The index of the current argument starting with 1 on success, or 0 
			on type mismatch or end of list reached.

     **************************************************************************/
    
    public uint getArg ( T ) ( ref T x )
    {
        bool ok = true;
        
        ok &= (this.index < this.total);
        
        if (ok)
        {
            if (this.arguments[this.index] == typeid(T))
            {
                x = *(cast (T*) this.argptr);
                
                this.argptr += T.sizeof;
                
                this.index++;
            }
        }

        return ok ? this.index : 0;
    }
    
    /***************************************************************************
    
        Converts the variable arguments given by arguments and argptr to argptr_out.
        Number and types of expected arguments are given by number and types of
        argptr_out.
        Throws an exception on type mismatch.
        
        Params:
            arguments = list of typeids of variable arguments
            argptr     = variable arguments data
            argptr_out = output parameters to store values of variable arguments
            
     **************************************************************************/
    
    public static void getArgs ( Types ... ) ( TypeInfo[] arguments, void* argptr, out Types args_out )
    {
        assert (Types.length == arguments.length, "Variable argument list length mismatch");
        
        foreach (i, T; Types)
        {
            assert (arguments[i] == typeid (T),
                    "Variable argument type mismatch: expected '" ~ T.stringof ~
                    "' but got '" ~ arguments[i].toString ~ '\'');
            
            args_out[i] = *(cast (T*) argptr);
            
            argptr += T.sizeof;
        }
    }
}
