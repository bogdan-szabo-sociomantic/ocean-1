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

private import ocean.core.StringEnum;

private import ocean.net.socket.SocketProtocol;

private import tango.core.Exception;

private import ocean.io.Retry;

debug private import tango.util.log.Trace;



/*******************************************************************************

	Abstract SocketClientConst class.
	
	Defines the status and command codes used by a socket client implementation.

	Each socket client class should also implement this class, which should
	specify the commands which are valid for that API.

    The class is designed so that everything remains static (ie the class never
    need be instantiated). This is slightly tricky, as it also needs the
    capability for derived classes to add to the list of command codes (as each
    API has its own set of commands). This problem is solved by having a
    singleton (static) instance of the derived class, and a set of static
    methods in the base class, which call abstract methods implemented in the
    singleton instance. That way everything remains static, but derived classes
    can implement different behaviour.
    
    For convenience, the following template mixins are provided:

        1. Create a singleton (static) instance of the class which is then
            called by the base class.

        2. Provide implementations of various abstract methods required by the
            base class.

*******************************************************************************/

abstract class SocketClientConst
{
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

    static private typeof(this) instance;

    template Singleton ( T )
    {
        /***********************************************************************
        
            Creates the static instance of this class.
        
        ***********************************************************************/
    
        static this ( )
        {
            instance = new T;
        }
    }


    /***************************************************************************

        Template to be used as a mixin by derived classes to implement the three
        abstract methods - isValidCode_, codeDescription_ and traceCommands_.

        (This is done as a template mixin as it's not possible to put static 
        functionality in a base class which can then be overridden, but still
        remain static, in deriving classes. If these members were simply static
        members of the base class, then there'd only be a single gloabl instance
        shared by all derived classes - which isn't what we want here.)
    
    ***************************************************************************/

    template CommandCodes ( Commands )
    {
        /***********************************************************************
        
            Tells whether the given code is valid.
            
            Params:
                code = code to check
        
            Returns:
                true if code is valid
        
        ***********************************************************************/
        
        public bool isValidCode_ ( Code code )
        {
            return code in Commands;
        }


        /***********************************************************************
        
            Gets the description for the given code.
            
            Params:
                code = code to get description for
        
            Returns:
                code's description
        
        ***********************************************************************/

        public char[] codeDescription_ ( Code code )
        {
            return Commands.description(code);
        }


        /***********************************************************************
        
            Outputs the names of all commands to Trace.
            
        ***********************************************************************/

        public void traceCommands_ ( )
        {
            foreach ( cmd, descr; Commands )
            {
                Trace.formatln("  {}", descr);
            }
        }
    }


    /***************************************************************************
	
	    Code Definition. Code is the base type of command and status codes.
	
	***************************************************************************/
	
	public alias uint Code;

    public alias StringEnumValue!(Code) CodeDesc;


	/***************************************************************************
	
	    Status codes definition
	
	***************************************************************************/

    static public StringEnum!(Code,
            CodeDesc("Ok", 200),
            CodeDesc("Error", 500),
            CodeDesc("PutOnReadOnly", 501)
        ) Status;


	/***************************************************************************
	
	    Checks if a code is valid. Ie either a Status code or a code defined in
        the implementing (derived) class.
        
        Params:
            code = code to check
	    
	    Returns:
	    	true if the code passed is valid
	
	***************************************************************************/

	static public bool isValidCode ( Code code)
	{
        return code in Status || instance.isValidCode_(code);
	}

    abstract public bool isValidCode_ ( Code code );


    /***************************************************************************
    
        Gets the text description for a code.

        Params:
            code = code to get description for

        Returns:
            code's description
    
    ***************************************************************************/

    static public char[] codeDescription ( Code code )
    {
        if ( code in Status )
        {
            return Status.description(code);
        }
        else
        {
            return instance.codeDescription_(code);
        }
    }

    abstract public char[] codeDescription_ ( Code code );


    /***********************************************************************
    
        Outputs the names of all commands to Trace.
        
    ***********************************************************************/

    static public void traceCommands ( )
    {
        Trace.formatln("{} commands:", instance.apiName_());
        instance.traceCommands_();
    }

    abstract public void traceCommands_ ( );


    /***********************************************************************

        Returns:
            api name
        
    ***********************************************************************/

    static public char[] apiName ( )
    {
        return instance.apiName_();
    }

    abstract public char[] apiName_ ( );
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
			case Const.Status.Ok:
			break;

			// TODO: do we really need to make this distinction?
			case Const.Status.PutOnReadOnly:
	            throw new SocketClientException!(Const).ReadOnly;
			break;

			case Const.Status.Error:
			default:
	            throw new SocketClientException!(Const).Generic("error on " ~ Const.codeDescription(cmd) ~ " request");
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
	
	protected void getPairList ( T ) ( ref T[2][] pair_list )
	{
        pair_list.length = 0;
        
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

	protected void getElementFromPairList ( T ) ( size_t keep_element, ref T[] list )
	{
		assert(keep_element < 2, "Invalid pair element index");

        list.length = 0;
        
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
        this ( ) { super(Const.Status.description(Const.Status.PutOnReadOnly)); }
	}
}

