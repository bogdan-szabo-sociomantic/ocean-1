module 			ocean.db.tokyocabinet.model.ITokyoCabinet;


protected		import  ocean.db.tokyocabinet.c.tcutil;
protected		import	ocean.text.util.StringC;

protected 		import  tango.stdc.stdlib: free;



abstract class ITokyoCabinet
{
	

	/**************************************************************************
    
	    If p is null, retrieves the current Tokyo Cabinet error code and
	    throws an exception (even if the error code equals TCESUCCESS).
	    
	    Params:
	        p       = not null assertion pointer
	        context = error context description string for message
	    
	***************************************************************************/
	
	protected void tokyoAssert ( void* p, char[] context = "Error" )
	{
	    this.tokyoAssertStrict(!!p, context);
	}
	
	
	
	/**************************************************************************
	
	    If ok == false, retrieves the current Tokyo Cabinet error code and
	    throws an exception if the error code is different from TCESUCCESS.
	    
	    Params:
	        ok      = assert condition
	        context = error context description string for message
	    
	***************************************************************************/
	
	protected void tokyoAssert ( bool ok, char[] context = "Error" )
	{
	    this.tokyoAssert(ok, [], context);
	}
	
	
	
	/**************************************************************************
	
	    If ok == false, retrieves the current Tokyo Cabinet error code and
	    throws an exception (even if the error code equals TCESUCCESS).
	    
	    Params:
	        ok      = assert condition
	        context = error context description string for message
	    
	***************************************************************************/
	
	protected void tokyoAssertStrict ( bool ok, char[] context = "Error" )
	{
	    this.tokyoAssertStrict(ok, [], context);
	}
	
	
	
	/**************************************************************************
	
	    If ok == false, retrieves the current Tokyo Cabinet error code and
	    throws an exception if the error code is different from TCESUCCESS and
	    all error codes in ignore_codes.
	    
	    Params:
	        ok           = assert condition
	        ignore_codes = do not throw an exception on these codes
	        context      = error context description string for message
	    
	***************************************************************************/
	
	protected void tokyoAssert ( bool ok, TCHERRCODE[] ignore_codes, char[] context = "Error" )
	{
	    this.tokyoAssertStrict(ok, ignore_codes ~ TCHERRCODE.TCESUCCESS, context);
	}
	
	
	
	/**************************************************************************
    
	    Retrieves the current Tokyo Cabinet error message string.
	    
	    Returns:
	        current Tokyo Cabinet error message string
	    
	***************************************************************************/
	
	abstract protected char[] getTokyoErrMsg ( );
	
	
	
	/**************************************************************************
    
	    Retrieves the Tokyo Cabinet error message string for errcode.
	    
	    Params:
	        errcode = Tokyo Cabinet error code
	        
	    Returns:
	        Tokyo Cabinet error message string for errcode
	    
	***************************************************************************/
	
	abstract protected char[] getTokyoErrMsg ( TCHERRCODE errcode );
	
	
	
	/**************************************************************************
	
	    If ok == false, retrieves the current Tokyo Cabinet error code and
	    throws an exception if the error code is different from  all error codes
	    in ignore_codes (even if it equals TCESUCCESS).
	    
	    Params:
	        ok           = assert condition
	        ignore_codes = do not throw an exception on these codes
	        context      = error context description string for message
	    
	***************************************************************************/
	
	abstract protected void tokyoAssertStrict ( bool ok, TCHERRCODE[] ignore_codes, char[] context = "Error" );
}