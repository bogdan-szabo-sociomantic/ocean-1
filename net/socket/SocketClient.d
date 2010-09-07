/*******************************************************************************

    Socket client
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        May 2010: Initial release
    
    authors:        Gavin Norman

	An abstract class containing the base implementation for a client to a
	socket-based API server.

	The main SocketClient class uses two helper classes:
		SocketClientConst: defines the list of commands and status codes which
		exist in the API. This is also an abstract class, and needs to be
		implemented along with each class derived from SocketClient.

		SocketRetry: Socket-specific retry class, which only catches exceptions
		of type SocketException or IOException. This allows socket clients to
		throw and handle their own exceptions (for example for fatal errors)
		within retry loops. The retry callback method of SocketRetry is set (in
		the SocketClient constructor) to a method which disconnects and
		reconnects the socket on each iteration of the retry loop.

*******************************************************************************/

module net.socket.SocketClient;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.net.socket.SocketProtocol;

private import tango.core.Exception;

private import ocean.io.Retry;

debug private import tango.util.log.Trace;



/*******************************************************************************

	Abstract SocketClientConst class.
	
	Defines the status and command codes used by a socket client implementation.

	Each socket client class should also implement this class, which should
	specify the commands which are valid for that API.
	
	Derived classes should override the initCodeDescriptions method, and add the
	appropriate command to the code_descriptions list. They should also
	implement a constructor which either calls super() or manually calls the
	initCodeLists method.
	
	Note that derived classes are required to implement a singleton pattern,
	with an 'instance' method which returns a static global instance. This can
	be easily achieved with the Singleton mixin defined in SocketClientConst.

*******************************************************************************/

abstract class SocketClientConst
{

    /***************************************************************************
    
        Initialises the list of command codes descriptions with extra codes
        needed by a dervied class.
        
    ***************************************************************************/

    abstract protected void initCodeDescriptions ( );


    /***************************************************************************
    
        Abstract method to return the name of the api.
    
    ***************************************************************************/

    abstract public char[] apiName ( );


    /***************************************************************************

	    Singleton template, to be used as a mixin by derived classes, which need
	    singleton behaviour so that the constants can be accessed without an
        object reference.

		(This is done as a template mixin as it's not possible to put static 
		functionality in a base class which can then be overridden, but still
		remain static, in deriving classes. If these members were simply static
        members of the base class, then there'd only be a single gloabl instance
        shared by all derived classes - which isn't what we want here.)

	***************************************************************************/

	template Singleton ( T )
	{
        static protected T global;


        /***************************************************************************
        
            Creates the static instance of this class.
        
        ***************************************************************************/
    
        static this ( )
        {
            global = new T;
        }


        /***************************************************************************
        
            Returns:
                static instance of this class.
        
        ***************************************************************************/
        
        static public T instance()
		{
			return global;
		}


        /***************************************************************************
        
            Outputs the list of command descriptions to Trace.
        
        ***************************************************************************/

        static public void traceCommands ( )
        {
            Trace.formatln("{} command descriptions:", T.instance().apiName());
            foreach ( code_descr; T.instance().code_descriptions )
            {
                if ( code_descr.type == CodeType.CommandCode )
                {
                    Trace.formatln("  {}", code_descr.description);
                }
            }
        }
    }


	/***************************************************************************
	
	    Code Definition. Code is the base type of command and status codes.
	
	***************************************************************************/
	
	public alias uint Code;


    /***************************************************************************
    
        Code types enum. Defines the different types of codes.
    
    ***************************************************************************/

    enum CodeType : ubyte
    {
        CommandCode = 0, // default value
        StatusCode
    }


	/***************************************************************************
	
	    A description of a code - its value, type, and a string describing it.
	    
	***************************************************************************/

	public struct CodeDescr
	{
		Code code;
		char[] description;
        CodeType type;
	}


	/***************************************************************************
	
	    Status codes definition
	
	***************************************************************************/
	
	public enum Status : Code
	{
	    Ok            			= 200,
	    Error        			= 500,
	    PutOnReadOnly			= 501,
	}


	/***************************************************************************

    	List of valid codes & descriptions

	 ***************************************************************************/

	CodeDescr[] code_descriptions;
	

	/***************************************************************************
	
	    Associative array to lookup a code by its description
	
	***************************************************************************/

	Code[char[]] codes_by_description;
	

	/***************************************************************************
	
	    Associative array to lookup a code's description
	
	***************************************************************************/

	char[][Code] descriptions_by_code;


	/***************************************************************************
	
	    Checks if a code is valid.
	    
	    Returns:
	    	true if the code passed is valid
	
	***************************************************************************/

	public bool isValidCode ( Code code)
	{
		return (code in this.descriptions_by_code) != null;
	}


    /***************************************************************************
    
        Initialises the list of command codes descriptions with the default
        status codes for this base class.
        
    ***************************************************************************/

    protected void appendBaseCodeDescriptions ( )
    {
        this.code_descriptions ~= [
            CodeDescr(Status.Ok,                "OK",                                   CodeType.StatusCode),
            CodeDescr(Status.Error,             "Internal Error",                       CodeType.StatusCode),
            CodeDescr(Status.PutOnReadOnly,     "Attempted to put on read-only server", CodeType.StatusCode)
        ];
    }


	/***************************************************************************
	
		Initialises the lookup lists of command codes & descriptions.
		
		Derived classes should override this method, calling the super class
		and then appending their own code descriptions to the list.
	
	***************************************************************************/

	protected void initCodeLists ( )
	{
		this.code_descriptions.sort;

		foreach ( code_descr; this.code_descriptions )
        {
			this.descriptions_by_code[code_descr.code] = code_descr.description;
			this.codes_by_description[code_descr.description] = code_descr.code;
        }
	}


	/***************************************************************************
	
		Constructor.
		Initialises the list of command codes descriptions.
	
	***************************************************************************/
	
	public this ( )
	{
        this.initCodeDescriptions();
        this.appendBaseCodeDescriptions();
		this.initCodeLists();
	}
}



/*******************************************************************************

	Abstract SocketClient class.
	
	Provides the building-block methods for reading from and writing to a socket
	based server.
	
	Template params:
		Const = the set of constants used by the class, must be derived from
			SocketClientConst.

*******************************************************************************/

abstract class SocketClient ( Const : SocketClientConst )
{
	static assert ( is ( typeof (Const.instance) ), "Template argument Const must implement an 'instance' method" );


	/***************************************************************************
    
		Socket
	
	***************************************************************************/
	
	protected SocketProtocol socket;
	
	
    /***************************************************************************
    
		Retry object, used to loop over read & write operations until they
		succeed
	
	***************************************************************************/
	
	public SocketRetry retry;


    /***************************************************************************
    
	    Static functions for looking up command & status code descriptions
	
	***************************************************************************/
	
	public struct Codes
	{
	    /**********************************************************************
	    
		    Code by description via indexing
		
		 **********************************************************************/
		
		static Const.Code opIndex ( char[] description )
		{
		    assert (description in Const.instance().codes_by_description, "Unknown API command description");
		    
		    return Const.instance().codes_by_description[description];
		}
		
		
		/**********************************************************************
		
		   Description by code via indexing
		
		 **********************************************************************/
		
		static char[] opIndex ( Const.Code code )
		{
		    assert (code in Const.instance().descriptions_by_code, "Unknown API command code");
		    
		    return Const.instance().descriptions_by_code[code];
		}
		
		
		/**********************************************************************
		
		    Tells whether description is a known command description via 'in'
		
		 **********************************************************************/
		
		static bool opIn_r ( char[] description )
		{
		    return !!(description in Const.instance().codes_by_description);
		}
		
		
		/**********************************************************************
		
		    Tells whether code is a known command code via 'in'
		
		 **********************************************************************/
		
		static bool opIn_r ( Const.Code code )
		{
		    return !!(code in Const.instance().descriptions_by_code);
		}
	
	
		/***********************************************************************
		
		    Outputs a list of all commands to Trace.
		
		***********************************************************************/
	
		debug static void list ( )
		{
			Trace.formatln("Valid {} command / status codes:", Const.instance().apiName());
	        foreach ( code_descr; Const.instance().code_descriptions )
	        {
	            Trace.formatln("   {} = {}", code_descr.code, code_descr.description);
	        }
		}
	}


	/***************************************************************************

	    Batch receiver structure template for iteration over a bulk request
	    result list.
	    
	    The iteration this struct provides is over key/value data.
	    
	    Template params:
	    	RequestType = the type of the data sent to initiate the request
	    		(usually keys)
	    	KeyType = the data type of the keys which will be received
	    	ValueType = the data type of the values which will be received
	
	***************************************************************************/

	struct BatchReceiverKV ( RequestType, KeyType, ValueType )
	{
		/***********************************************************************

			Alias for the type of the opApply delegate

		***********************************************************************/

		alias int delegate ( ref KeyType key, ref ValueType item ) ProcessDg;


		/***********************************************************************

			The command to be sent to the server to initiate the batch
			operation.

		***********************************************************************/

		Const.Code command;


		/***********************************************************************

			A reference to the SocketClient object which is to receive data sent
			from the server by the batch operation. (This reference is needed as
			the socket client contains the methods which do the actual reading
			and writing to the socket.)

		***********************************************************************/

		SocketClient client;


		/***********************************************************************

			The data to be sent to the server along with the command, defining
			the batch operation. (Usually a list of keys.)
	
		***********************************************************************/

		RequestType request;
	

		/***********************************************************************

			opApply method. Initiates the batch operation and passes the
			received key/value pairs to the opApply delegate.

		***********************************************************************/

		int opApply ( ProcessDg dg )
	    {
	    	assert(this.client, "SocketClient not set");

	    	KeyType key;
		    ValueType value;

	    	bool end_of_list;
		    int result;
		    this.client.retry.loop({
		    	this.client.sendRequestCommand(command, request);

		        do
		        {
		        	end_of_list = this.client.getTuple(key, value);
			    	if ( !end_of_list )
			    	{
			    		result = dg(key, value);
			    	}
		        } while ( !end_of_list && !result );
		    });

		    return result;
	    }
	}


	/***************************************************************************

	    Batch receiver structure template for iteration over a bulk request
	    result list.
	    
	    The iteration this struct provides is over key only data.
	    
	    Template params:
	    	RequestType = the type of the data sent to initiate the request
	    		(usually keys)
	    	KeyType = the data type of the keys which will be received
	
	***************************************************************************/

	struct BatchReceiverK ( RequestType, KeyType )
	{
		/***********************************************************************

			Alias for the type of the opApply delegate

		***********************************************************************/

		alias int delegate ( ref KeyType key ) ProcessDg;


		/***********************************************************************

			The command to be sent to the server to initiate the batch
			operation.

		***********************************************************************/

		Const.Code command;


		/***********************************************************************

			A reference to the SocketClient object which is to receive data sent
			from the server by the batch operation. (This reference is needed as
			the socket client contains the methods which do the actual reading
			and writing to the socket.)

		***********************************************************************/

		SocketClient client;


		/***********************************************************************

			The data to be sent to the server along with the command, defining
			the batch operation. (Usually a list of keys.)
	
		***********************************************************************/

		static if ( !is(RequestType == void) )
		{
			RequestType request;
		}
	

		/***********************************************************************

			opApply method. Initiates the batch operation and passes the
			received key/value pairs to the opApply delegate.

		***********************************************************************/

		int opApply ( ProcessDg dg )
	    {
	    	assert(this.client, "SocketClient not set");

	    	KeyType key;

	    	bool end_of_list;
		    int result;
		    this.client.retry.loop({
				static if ( is(RequestType == void) )
				{
			    	this.client.sendRequestCommand(command);
				}
				else
				{
			    	this.client.sendRequestCommand(command, request);
				}

		        do
		        {
		        	end_of_list = this.client.getTuple(key);
		        	if ( !end_of_list )
			    	{
			    		result = dg(key);
			    	}
		        } while ( !end_of_list && !result );
		    });

		    return result;
	    }
	}


    /***************************************************************************
    
		Convenience aliases for some commonly used batch receivers.

		ListReceiver:
			Sends a command with data as a list of strings (char[][]).
			Receives responses with hash_t keys and values as strings (char[]).

        ListListReceiver:
            Sends a command with data as a list of strings (char[][]).
            Receives responses with hash_t keys and values as lists of
                strings (char[][]).

		PairListReceiver:
			Sends a command with data as a list of strings (char[][]).
			Receives responses with string (char[]) keys and values as lists of
				string pairs (char[][2][]).

        AllKeysListReceiver:
            Sends a command without data.
            Receives responses with string (char[]) keys.

	***************************************************************************/

	public alias BatchReceiverKV!(char[][], char[], char[]) ListReceiver;

    public alias BatchReceiverKV!(char[][], char[], char[][]) ListListReceiver;

    public alias BatchReceiverKV!(char[][], char[], char[][2][]) PairListReceiver;

    public alias BatchReceiverK!(void, char[]) AllKeysListReceiver;


    /***************************************************************************

		Constructor.
		
		Initialises the socket protocol and retry members.
		
		Params:
			address = address of socket to connect to
			port = port of socket to connect to

	***************************************************************************/

	public this ( char[] address, ushort port )
	{
    	this.socket = new SocketProtocol(address, port);
        this.retry = new SocketRetry(&this.retryReconnect);
    	this.retry.ms = 500;
	}


    /***************************************************************************

		Is the socket still alive?

	***************************************************************************/

	public bool isAlive ( )
	{
        return this.socket.isAlive();
	}

	
    /***************************************************************************

		Closes the socket connection.

	***************************************************************************/

	public void close ( )
	{
        this.socket.disconnect();
	}


    /***************************************************************************

		Tries to get a single value from the server, by sending a command and
		the key of the desried value.
		
		Template params:
			K = data type of the key to read
			V = data type of the value to read
		
		Params:
			cmd = command to send to the server to initiate the get operation.
			key = key of requested value.
			value = value to receive the server's response.

		Note: If the value type is a list of pairs (T[2][]), then the
		standard ListWriter.get read process will not work. It expects a
		single empty value as a representation of EOF, but in the case of
		value pairs, we're actually receiving *2* values, both of which must
		be empty to signify an EOF. Therefore this function has special
		behaviour for pair value types. (If support for receiving triples or
		N-tuples were ever needed, then new behaviour would have to be
		implemented here.)

	***************************************************************************/

    public void get ( K, V ) ( Const.Code cmd, K key, out V value )
    {
    	this.retry.loop({
        	this.sendRequestCommand(cmd, key);

        	static if ( is ( V T == T[2][] ) )
        	{
    	        this.getPairList(value);
        	}
        	else
        	{
        		this.socket.get(value);
        	}
    	});
    }


    /***************************************************************************

		Tries to get a tuple of values from the server, by sending a command and
		a key to initiate the get operation.

		Template params:
			K = data type of the key to read
			V = data types of the values to read
		
		Params:
			cmd = command to send to the server to initiate the get operation.
			key = key to initiate the get request.
			values = values to receive the server's response.

    ***************************************************************************/

    public void get ( K, V ... ) ( Const.Code cmd, K key, out V values )
    {
    	this.retry.loop({
        	this.sendRequestCommand(cmd, key);

        	this.socket.get(values);
    	});
    }


    /***************************************************************************

		Tries to put a tuple of values to the server, by sending a command, a
		key for the data values and the values themselves.
	
		Template params:
			K = data type of the key to write
			V = data types of the values to write
		
		Params:
			cmd = command to send to the server to initiate the put operation.
			key = key to write.
			values = values to write.
	
	***************************************************************************/

    public void put ( K, V ... ) ( Const.Code cmd, K key, V values )
    {
    	this.retry.loop({
    		// Put request code, key & data
			this.socket.put(cmd, key, values).commit();

			// Check status
        	Const.Code status;
    		this.socket.get(status);
    	    this.checkStatus(cmd, status);
    	});
    }


    /***************************************************************************
    
	    Receives a list of pairs, discards one of the two elements in each pair
	    received, and creates a list of the other pair elements.
	    
	    This function would be useful in a situation where, for example the
	    server is sending a list of url/time pairs, but you only want the urls.

	    Note: If you wnat to keep both elements of a pair list, simply use the
	    normal get method.

		Template params:
			K = data type of the key to read
			V = data type of the value to read
		
		Params:
			cmd = command to send to the server to initiate the get operation.
			key = key to initiate the get request.
			keep_element = index of the pair element to keep and return.
			list = array to receive the requested list.

	***************************************************************************/

	public void getElementFromPairList ( K, V ) ( Const.Code cmd, K key, uint keep_element, out V[] list )
	{
		assert(keep_element < 2, "Invalid pair element index");

		this.retry.loop({
	        this.sendRequestCommand(cmd, key);
	
	        this.getElementFromPairList(keep_element, list);
		});
	}


	/***************************************************************************

		Sends a request command and checks the status response from the server.
		
		Template params:
			D = tuple of value types to send to the server along with the
				request command

		Params:
			cmd = the command to send to the server
			data = data to send to the server to initiate the request
			
	***************************************************************************/

	protected void sendRequestCommand ( D ... ) ( Const.Code cmd, D data )
	{
		// Put request code & key
	    this.socket.put(cmd, data).commit();

	    // Check status
	    Const.Code status;
	    this.socket.get(status);
	    this.checkStatus(cmd, status);
	}


	/***************************************************************************

		Checks whether a command has succeeded or not.
		
		Throws exceptions if the status is != Ok.
		
		Params:
			cmd = the command which has just been performed.
			status = the status returned by the server.
	
	***************************************************************************/

	protected void checkStatus ( Const.Code cmd, Const.Code status )
	{
        switch ( status )
		{
			case Const.instance().Status.Ok:
			break;

			// TODO: do we really need to make this distinction?
			case Const.instance().Status.PutOnReadOnly:
	            throw new SocketClientException!(Const).ReadOnly;
			break;

			case Const.instance().Status.Error:
			default:
	            throw new SocketClientException!(Const).Generic("error on " ~ Codes[cmd] ~ " request");
			break;
		}
	}


	/***************************************************************************

		Receives a tuple of values from the server. The first element of the
		tuple is read and checked for being a list terminator. If it isn't a
		list terminator then the remaining tuple elements are read.
	
		Template params:
			T = template tuple of types of the values to receive
	
		Params:
			items = variables to receive the values from the server

		Returns:
			true if the received tuple represented an "end of list" (the first
			element received is a list terminator)

	***************************************************************************/

	protected bool getTuple ( T... ) ( out T items )
	{
		static if ( items.length )
		{
			this.getItem(items[0]);
	        if ( !this.isListTerminator(items[0]) )
	        {
	        	foreach ( i, item; items[1..$] )
	        	{
	        		this.getItem(items[i + 1]);
	        	}
	        	return false;
	        }

	        return true;
		}
		else
		{
			return true;
		}
	}


	/***************************************************************************

		Receives a single value from the server.
		
		If the type of the value to receive is a list of pairs (T[2][]), then
		the getPairList method is called. Otherwise the value is simply read
		from the socket.

		Template params:
			T = type of value to receive

		Params:
			item = variable to receive the value from the server

	***************************************************************************/

	protected void getItem ( T ) ( out T item )
	{
		static if ( is(T == void) )
		{
			return;
		}

		static if ( is ( T U == U[2][] ) )
    	{
	        this.getPairList(item);
    	}
    	else
    	{
			this.socket.get(item);
    	}
	}


	/***************************************************************************

		Receives a list of pair values from the server.

		Template params:
			T = type of the pairs in the list

		Params:
			pair_list = array to receive the pairs from the server
	
	***************************************************************************/
	
	protected void getPairList ( T ) ( out T[2][] pair_list )
	{
	    T[2] pair;
	    bool end;
	    do
	    {
	    	end = this.getTuple(pair[0], pair[1]);
	    	if ( !end )
	    	{
		    	pair_list ~= pair;
	    	}
	    } while ( !end );
	}


	/***************************************************************************

		Receives a list of pair values from the server, and discards one of
		them, building up a list of the remaining pair elements.
		
		Template params:
			T = type of the pairs in the list
			
		Params:
			keep_element = index of the element to keep
			list = array to receive the pair elements from the server
	
	***************************************************************************/

	protected void getElementFromPairList ( T ) ( size_t keep_element, out T[] list )
	{
		assert(keep_element < 2, "Invalid pair element index");

		T[2] pair;
		bool end;

		do
		{
			end = this.getTuple(pair[0], pair[1]);
		    if ( !end )
		    {
		    	list ~= pair[keep_element];
		    }
		} while ( !end );
	}


	/***************************************************************************

		Determines whether a received data item indicates an end-of-list
		terminator from the server. It is a list terminator if:
		
			An array value is a list terminator if it has 0 length.
			A single value is a list terminator if it == 0.

		Template params:
			T = type of value received

		Params:
			value = data value to check

		Returns:
			true if the received data item represents a list terminator.
	
	***************************************************************************/

	protected static bool isListTerminator ( T ) ( T value )
	{
		// Array of values
        static if ( is(T U == U[]) )
        {
        	return value.length == 0;
        }
        // Single value
        else
        {
        	return value == 0;
        }
	}


    /***************************************************************************
    
		Reconnect method, used as the loop callback for the retry member to wait
		for a time then try disconnecting and reconnecting the socket.

	***************************************************************************/

	public void retryReconnect ( )
	{
		debug Trace.formatln("\nSocketProtocol, reconnecting");
		this.retry.wait();
		try
		{
			// Reconnect without clearing the R/W buffers
			this.socket.disconnect(false).connect(false);
		}
		catch ( Exception e )
		{
			debug Trace.formatln("\nSocket reconnection failed: {}", e.msg);
		}
	}
}



/*******************************************************************************

	SocketRetry class - derived from Retry.
	
	Only handles socket-based exceptions: SocketException & IOException. This is
	useful so that classes using SocketRetry can throw and handle their own
	exceptions within retry loops.
	
*******************************************************************************/

class SocketRetry : Retry
{
	/***************************************************************************
	
		Constructor.
	
	    Params:
	        delg = retry callback delegate
	
	***************************************************************************/
	
	public this ( CallbackDelg delg )
	{
		super(delg);
	}


	/***************************************************************************
	
		Overridden try / catch / retry loop which only catches exceptions of
		type SocketException or IOException.
	
	    Params:
	        code_block = code to try
	
	***************************************************************************/

	public override void defaultLoop ( void delegate () code_block )
	{
		do try
	    {
	    	super.tryBlock(code_block);
	    }
	    catch ( SocketException e )
	    {
	    	super.handleException(e);
	    }
	    catch ( IOException e )
	    {
	    	super.handleException(e);
	    }
	    while ( super.again )
	}
}



/*******************************************************************************

	ApiClientException structure.
	
	Contains exception classes related to socket clients.
	
	Template params:
		Const = the set of constants used by the class, must be derived from
			SocketClientConst.

*******************************************************************************/

struct SocketClientException ( Const : SocketClientConst )
{
	/**************************************************************************
	
	    ApiClientException.Generic class
	    
	    Generic ApiClient exception
	    
	 **************************************************************************/
	
	static class Generic : Exception
	{
	    this ( char[] msg = "Error" ) { super(msg); }
	}
	
	/**************************************************************************
	
	    ApiClientException.InvalidCode class
	    
	    Thrown when an attempt is made to get the description for an invalid
	    code
	    
	 **************************************************************************/
	
	static class InvalidCode : Generic
	{
	    this ( char[] msg = "Invalid command or status code" ) { super(msg); }
	}

	/**************************************************************************
	
	    ApiClientException.ReadOnly class
	    
	    ApiClient exception when attempted to write on read-only node
	    
	 **************************************************************************/

	static class ReadOnly : Generic
	{
    	static Const.Code code = Const.Status.PutOnReadOnly;
        this ( ) { super(Const.instance().descriptions_by_code[code]); }
	}
}

