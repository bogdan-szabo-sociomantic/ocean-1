/******************************************************************************

    Read helper for Select event-driven, non-blocking socket input
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        June 2011: Initial release
    
    authors:        David Eckardt
    
    Provides a method for non-blocking read from an input device for which a
    read and possibly a hangup event has been reported. Reads data from the
    socket and detects an end-of-flow or hung-up or condition or an error by
    evaluating the combination of
        - a reported hangup event, if any,
        - the return value of read() which may be a positive number on success
          or 0 or indicate an end-of-flow condition,
        - errno with respect to EAGAIN/EWOULDBLOCK and
        - a socket error if the input device is a socket.
    
 ******************************************************************************/

module ocean.io.select.protocol.generic.ReadConduit;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.model.ISelectClient: ISelectClient;

private import ocean.io.select.protocol.generic.ErrnoIOException: IOError, IOWarning;

private import tango.io.model.IConduit: InputStream;

private import tango.stdc.errno: errno, EAGAIN, EWOULDBLOCK;

/******************************************************************************/

class ReadConduit
{
    /**************************************************************************

        Input device
    
     **************************************************************************/

    private InputStream conduit;
    
    /**************************************************************************

        Exception instances
    
     **************************************************************************/

    private IOWarning warning;
    
    private IOError   error;
    
    /**************************************************************************

        Constructor
        
        Params:
            conduit = input device
            warning = IOWarning instance to throw on end-of-flow or hung-up
                      condition
            error   = IOError instance to throw on error
    
     **************************************************************************/

    this ( InputStream conduit, IOWarning warning, IOError error )
    in
    {
        assert (conduit !is null);
        assert (warning !is null);
        assert (error   !is null);
    }
    body
    {
        this.conduit = conduit;
        this.warning = warning;
        this.error   = error;
    }
    
    /**************************************************************************

        Performs one conduit.read(data) and checks for errors afterwards.
    
        Params:
            data   = destination data buffer; data[0 .. {return value}] will
                     contain the received data
            events = events reported for this.conduit
            
        Returns:
            number of bytes read
        
        Throws:
            IOWarning on end-of-flow or hung-up condition or IOError on error.
        
        Notes: Eof returned by conduit.read() together with errno reporting
            EAGAIN or EWOULDBLOCK indicates that there was currently no data to
            read but the conduit will become readable later. Thus, in that case
            0 is returned and no exception thrown.
            However, the case when conduit.read() returns Eof AND errno reports
            EAGAIN or EWOULDBLOCK AND the selector reports a hangup event for
            the conduit is treated as end-of-flow condition and an IOWarning is
            thrown then.
            The reason for this is that, as experience shows, epoll keeps
            reporting the read event together with a hangup event even if the
            conduit is actually not readable and, since it has been hung up, it
            will not become later.
            So, if conduit.read() returns EOF and errno reports EAGAIN or
            EWOULDBLOCK, the only way to detect whether a conduit will become
            readable later or not is to check if a hangup event was reported.
        
     **************************************************************************/
    
    public size_t opCall ( void[] data, ISelectClient.Event events )
    in
    {
        assert ((cast (InputStream) this.conduit) !is null,
                "attempted to read from a device which is not an input stream");
    }
    body
    {
        errno = 0;
        size_t received = this.conduit.read(data);
        
        switch ( received )
        {
            case 0:
                if ( errno ) throw this.error(errno, "read error", __FILE__, __LINE__);
                else         break;
            
            case InputStream.Eof: switch ( errno )
            {   
                case 0:
                    // Throw IOError if getsockopt() reports an error for the fd
                    this.error.checkSocketError("read error", __FILE__, __LINE__);

                    // Otherwise throw IOWarning
                    throw this.warning("end of flow whilst reading", __FILE__, __LINE__);
                
                default:
                    throw this.error(errno, "read error", __FILE__, __LINE__);
                
                case EAGAIN:
                    static if ( EAGAIN != EWOULDBLOCK )
                    {
                        case EWOULDBLOCK:
                    }
    
                    this.warning.assertEx(!(events & events.ReadHangup), "connection hung up on read", __FILE__, __LINE__);
                    this.warning.assertEx(!(events & events.Hangup),     "connection hung up", __FILE__, __LINE__);
    
                    received = 0;
            }
    
            default:
        }
        
        return received;
    }
}