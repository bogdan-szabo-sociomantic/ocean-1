// TODO: header

module net.socket.SocketClient;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.net.socket.SocketProtocol;

private import tango.core.Exception;

private import ocean.io.Retry;

debug
{
	private import tango.util.log.Trace;
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
	
	public override void loop ( void delegate () code_block )
	{
		bool again;
		super.resetCounter();
	
		do try
	    {
			again = false;
	    	code_block();
	    }
	    catch ( SocketException e )
	    {
	    	debug Trace.formatln("caught {} {}", typeof(e).stringof, e.msg);
	    	super.handleException(e, again);
	    }
	    catch ( IOException e )
	    {
	    	debug Trace.formatln("caught {} {}", typeof(e).stringof, e.msg);
	    	super.handleException(e, again);
	    }
	    while (again)
	}
}



/*******************************************************************************

	Abstract SocketClientConst class.
	
	Defines TODO

*******************************************************************************/

abstract class SocketClientConst
{
	public static:

	/******************************************************************************
	
	    Code Definition
	    
	    Code is the base type of command and status codes
	
	 ******************************************************************************/
	
	alias uint Code;
	
	/******************************************************************************
	
	    Status codes definition
	
	 ******************************************************************************/
	
	enum Status : Code
	{
	    Ok            = 200,
	    Error         = 500,
	    PutOnReadOnly = 501
	}
	
	/******************************************************************************
	
	    Code structure
	    
	    Contains the command/status as code and description string
	
	 ******************************************************************************/
	
	struct CodeDescr
	{
	    Code code;
	    char[]   description;  
	}


	/******************************************************************************
	
	    Status Code
	
	 ******************************************************************************/
	
	struct StatusCode
	{
	    static const CodeDescr
	    
	        Ok           = {Status.Ok,    "OK"            },
	        Error        = {Status.Error, "Internal Error"},
	        PutOnReadOnly = {Status.PutOnReadOnly, "Attempted to put on read-only server"};
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
	    this ( char[] msg ) { super(msg); }
	}
	
	/**************************************************************************
	
	    ApiClientException.ReadOnly class
	    
	    ApiClient exception when attempted to write on read-only node
	    
	 **************************************************************************/
	
	static class ReadOnly : Generic
	{
	    this ( char[] msg  = Const.StatusCode.PutOnReadOnly.description )
	    {
	        super(msg);
	    }
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

	struct BatchReceiver ( RequestType, KeyType, ValueType )
	{
		/***********************************************************************

			Alias for the type of the opApply delegate

		***********************************************************************/

		alias int delegate ( ref KeyType, ref ValueType item ) ProcessDg;


		/***********************************************************************

			The command to be sent to the server to initiate the batch
			operation.

		***********************************************************************/

		Const.CodeDescr command;


		/***********************************************************************

			The data to be sent to the server along with the command, defining
			the batch operation. (Usually a list of keys.)

		***********************************************************************/

		RequestType request;


		/***********************************************************************

			A reference to the SocketClient object which is to receive data sent
			from the server by the batch operation. (This reference is needed as
			the socket client contains the methods which do the actual reading
			and writing to the socket.)

		***********************************************************************/

		SocketClient client;


		/***********************************************************************

			opApply method. Initiates the batch operation and passes the
			received key/value pairs to the opApply delegate.

		***********************************************************************/

		int opApply ( ProcessDg dg )
	    {
	    	assert(client, "SocketClient not set");

	    	KeyType key;
		    ValueType value;

		    int result;
		    this.client.retry.loop({
		    	this.client.sendRequestCommand(command, request);

		    	this.receiveItem(key, value);

		        while ( !SocketClient.isListTerminator(key, value) && !result )
		        {
		        	result = dg(key, value);
		
			    	this.receiveItem(key, value);
		        }
		    });

		    return result;
	    }


		/***********************************************************************

			Receives a single item as part of a batch operation.
			
			Params:
				key = key to be received
				value = value to be received

			Note: If the value type is a list of pairs (T[2][]), then the
			standard ListWriter.get read process will not work. It expects a
			single empty value as a representation of EOF, but in the case of
			value pairs, we're actually receiving *2* values, both of which must
			be empty to signify an EOF. Therefore this function has special
			behaviour for pair value types. (If support for receiving triples or
			N-tuples were ever needed, then new behaviour would have to be
			implemented here.)
			
		***********************************************************************/

		void receiveItem ( out KeyType key, out ValueType value )
	    {
	    	static if ( is ( ValueType T == T[2][] ) )
	    	{
    			this.client.socket.get(key);
    	        this.client.getPairList(value);
	    	}
	    	else
	    	{
    			this.client.socket.get(key, value);
	    	}
	    }
	}


    /***************************************************************************
    
		Convenience aliases for the most common types of batch receivers.

		ListReceiver:
			Sends a command with data as a list of strings (char[][]).
			Receives responses with string (char[]) keys and values as lists of
				strings (char[][]).

		PairListReceiver:
			Sends a command with data as a list of strings (char[][]).
			Receives responses with string (char[]) keys and values as lists of
				string pairs (char[][2][]).

	***************************************************************************/

	public alias BatchReceiver!(char[][], char[], char[][]) ListReceiver;

	public alias BatchReceiver!(char[][], char[], char[][2][]) PairListReceiver;


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

    public void get ( K, V ) ( Const.CodeDescr cmd, K key, out V value )
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

    public void get ( K, V ... ) ( Const.CodeDescr cmd, K key, out V values )
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

    public void put ( K, V ... ) ( Const.CodeDescr cmd, K key, V values )
    {
    	this.retry.loop({
    		// Put request code, key & data
        	this.socket.put(cmd.code, key, values).commit();

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

	public void getElementFromPairList ( K, V ) ( Const.CodeDescr cmd, K key, uint keep_element, out V[] list )
	{
		assert(keep_element < 2, "Invalid pair element index");

		this.retry.loop({
	        this.sendRequestCommand(cmd, key);
	
	        this.getElementFromPairList(keep_element, list);
		});
	}


    /***************************************************************************
    
		opApply overload which iterates over the keys in the server's database.

		Uses the abstract method beginKeyIteration, which must be implemented by
		any socket clients that support opApply key iteration. (It must be
		abstract, as this abstract class doesn't know the correct command to
		send to the individual servers.)

	***************************************************************************/
	
	public int opApply ( int delegate ( ref char[] key ) dg )
	{
		char[] key, last_key;
	
	    int result = 0;
		this.retry.loop({
			this.beginKeyIteration(last_key);
	
	    	this.socket.get(key);
	
	    	while (key.length && !result)
	        {
	            result = dg(key);
	
		    	last_key = key.dup;
	        	this.socket.get(key);
	
	        	if ( result )
	            {
	            	break;
	            }
	        }
		});
	
	    return result;
	}


	/***************************************************************************

		Sends the command to begin iteration over all keys. Used by the opApply
		key iterator, above. The opApply iterator keeps track of the last
		successfully received key, and passes it to this function in the case of
		having to restart the key iteration due to an exception.

		Params:
			last_key = the last key which was successfully read during the
				iteration.

	***************************************************************************/
	
	abstract protected void beginKeyIteration ( char[] start_key );
	
	
	/***************************************************************************

		Sends a request command and checks the status response from the server.
		
		Template params:
			D = tuple of value types to send to the server along with the
				request command

		Params:
			cmd = the command to send to the server
			data = data to send to the server to initiate the request
			
	***************************************************************************/

	protected void sendRequestCommand ( D ... ) ( Const.CodeDescr cmd, D data )
	{
		// Put request code & key
	    this.socket.put(cmd.code, data).commit();

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
			statuc = the status returned by the server.
	
	***************************************************************************/

	protected void checkStatus ( Const.CodeDescr cmd, Const.Code status )
	{
        switch ( status )
		{
			case Const.Status.Ok:
			break;

			case Const.Status.PutOnReadOnly:
	            throw new SocketClientException!(Const).ReadOnly;
			break;

			default:
		    	throw new SocketException("error on " ~ cmd.description ~ " request");
			break;
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

        this.socket.get(pair[0], pair[1]);
	    while ( !isListTerminator(pair) )
	    {
	    	pair_list ~= pair;
	        this.socket.get(pair[0], pair[1]);
	    }
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

	protected void getElementFromPairList ( T ) ( uint keep_element, out T[] list )
	{
		assert(keep_element < 2, "Invalid pair element index");

		T[2] pair;

        this.socket.get(pair[0], pair[1]);
	    while ( !isListTerminator(pair) )
	    {
	    	list ~= pair[keep_element];
	        this.socket.get(pair[0], pair[1]);
	    }
	}


	/***************************************************************************

		Determines whether a received data item indicates an end-of-list
		terminator from the server. Every value is checked for length > 0, and
		array values are iterated into.

		FIXME: arrays of arrays are not iterated into, if we ever need this
		behaviour it'd have to be added here.

		Template params:
			T = types of values received
			
		Params:
			values = data values to check
		
		Returns:
			true if the received data represents a list terminator.
	
	***************************************************************************/

	protected static bool isListTerminator ( T ... ) ( T values )
	{
		static if ( values.length )
		{
			foreach ( value; values )
			{
				// Array of values
		        static if (is (value U == U[]))
		        {
		        	foreach ( v; value )
		        	{
			        	if ( v.length )
			        	{
			        		return false;
			        	}
		        	}
	    			return true;
		        }
		        // Single value
		        else
		        {
		        	if ( value.length )
		        	{
		        		return false;
		        	}
		        }
			}

			return true;
		}
		else
		{
			return false;
		}
	}


    /***************************************************************************
    
		Reconnect method, used as the loop callback for the retry member to wait
		for a time then try disconnecting and reconnecting the socket.

		Params:
			msg = message describing the action being retried
	
		Returns:
	    	true to try again
	
	***************************************************************************/
	
	public bool retryReconnect ( char[] msg )
	{
		debug Trace.formatln("SocketProtocol, reconnecting");
		bool again = this.retry.wait(msg);
		if ( again )
	    {
			try
			{
				// Reconnect without clearing the R/W buffers
				this.socket.disconnect(false).connect(false);
			}
			catch ( Exception e )
			{
				debug Trace.formatln("Socket reconnection failed: {}", e.msg);
			}
	    }
		debug Trace.formatln("Try again? {}", again ? "yes" : "no");
		return again;
	}
}

