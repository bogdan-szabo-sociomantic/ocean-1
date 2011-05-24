module ocean.io.select.protocol.model.ISelectProtocol;



/******************************************************************************

    Imports

******************************************************************************/

private import ocean.io.select.model.ISelectClient;

private import ocean.io.select.EpollSelectDispatcher;

private import tango.io.model.IConduit: ISelectable, IConduit;

debug private import tango.util.log.Trace;



/******************************************************************************

    ISelectProtocol abstract class

******************************************************************************/

abstract class ISelectProtocol : IAdvancedSelectClient
{
    /**************************************************************************

        IOWarning exception instance 

     **************************************************************************/

    protected IOWarning warning_e;


    /**************************************************************************

        IOError exception instance 

     **************************************************************************/

    protected IOError error_e;


    /**************************************************************************

        Event(s) reported to handle()

     **************************************************************************/

    private Event events_;


    /**************************************************************************

        Constructor

        Params:
            conduit = I/O device

     **************************************************************************/

    this ( ISelectable conduit )
    {
        super(conduit);

        this.warning_e = new      IOWarning;
        this.error_e   = this.new IOError;
    }


    /**************************************************************************

        Handles events events_in which occurred for conduit. Invokes the
        abstract handle_() method.

        (Implements an abstract super class method.)

        Params:
            events = events which fired for conduit

        Returns:
            true to indicate to the Dispatcher that the event registration
            should be left unchanged or false to unregister the Conduit. 

     **************************************************************************/

    final bool handle ( Event events )
    {
        this.events = events;

        return this.handle_();
    }

    abstract bool handle_ ( );


    /**************************************************************************

        Gets event(s) reported to handle()

     **************************************************************************/

    protected Event events ( )
    {
        return this.events_;
    }


    /**************************************************************************

        IOWarning class; to be thrown on end-of-flow conditions without an
        error reported by errno or a socket error.
        
     **************************************************************************/
    
    static class IOWarning : IOException
    {
        /**********************************************************************
    
            Throws this instance if ok is false, 0 or null.
            
            Params:
                ok   = condition that must not be false, 0 or null
                msg  = message
                file = source code file name
                line = source code line
            
            Throws:
                this instance if ok is false, 0 or null
            
         **********************************************************************/
        
        void assertEx ( T ) ( T ok, char[] msg, char[] file = "", long line = 0 )
        {
            if (!ok)
            {
                super.set(msg, file, line);
                throw this;
            }
        }
        
        /**********************************************************************
    
            Queries and resets errno and sets the exception parameters.
            
            Params:
                msg  = message
                file = source code file name
                line = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        public typeof (this) opCall ( char[] msg, char[] file = "", long line = 0 )
        {
            super.set(msg, file, line);
            return this;
        }
        
        /**********************************************************************
    
            Sets the exception parameters.
            
            Params:
                errnum = error number
                msg    = message
                file   = source code file name
                line   = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        public typeof (this) opCall  ( int errnum, char[] msg, char[] file = "", long line = 0 )
        {
            super.set(errnum, msg, file, line);
            return this;
        }
    }
    
    /**************************************************************************
    
        IOError class; to be thrown on end-of-flow conditions with an error
        reported by errno or a socket error.
        
     **************************************************************************/
    
    class IOError : IOException
    {
        /**********************************************************************
    
            Queries and resets errno and sets the exception parameters.
            
            Params:
                msg  = message
                file = source code file name
                line = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        public typeof (this) opCall ( char[] msg, char[] file = "", long line = 0 )
        {
            super.set(msg, file, line);
            return this;
        }
        
        /**********************************************************************
    
            Sets the exception parameters.
            
            Params:
                errnum = error number
                msg    = message
                file   = source code file name
                line   = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        public typeof (this) opCall  ( int errnum, char[] msg, char[] file = "", long line = 0 )
        {
            super.set(errnum, msg, file, line);
            return this;
        }
        
        /**********************************************************************
        
            Checks the socket error state of the conduit of the outer instance.
            Does nothing if the conduit is not a socket. 
             
            Params:
                msg    = message
                file   = source code file name
                line   = source code line
            
            Throws:
                this instance if an error is reported for the conduit of the
                outer instance
            
         **********************************************************************/
        
        void checkSocketError ( char[] msg, char[] file = "", long line = 0 )
        {
            auto berkeley = Berkeley(cast (socket_t) this.outer.conduit.fileHandle);
            if (berkeley.error)
            {
                super.set(errnum, msg, file, line);
                throw this; 
            }
        }
    }
    
    /**************************************************************************
    
        IOException class; base class for IOWarning and IOError
    
     **************************************************************************/
    
    static class IOException : TangoException.IOException
    {
        /**********************************************************************
    
            This alias
        
         **********************************************************************/
        
        alias typeof (this) This;
        
        /**********************************************************************
    
            Error number
        
         **********************************************************************/
        
        int errnum = 0;
        
        /**********************************************************************
    
            Constructor
        
         **********************************************************************/
        
        this ( ) {super("");}
        
        /**********************************************************************
    
            Queries and resets errno and sets the exception parameters.
            
            Params:
                msg  = message
                file = source code file name
                line = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        protected void set ( char[] msg, char[] file = "", long line = 0 )
        {
            scope (exit) .errno = 0;
            
            this.set(.errno, msg, file, line);
        }
        
        /**********************************************************************
        
            Sets the exception parameters.
            
            Params:
                errnum = error number
                msg    = message
                file   = source code file name
                line   = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        protected void set ( int errnum, char[] msg, char[] file = "", long line = 0 )
        {
            this.errnum = errnum;
            
            if (this.errnum)
            {
                char[0x100] buf;
                char* e = strerror_r(errnum, buf.ptr, buf.length);
                
                super.msg.concat(msg, " - ", e[0 .. strlen(e)]);
            }
            else
            {
                super.msg.copy(msg);
            }
            
            super.file.copy(file);
            super.line = line;
        }
    }

}

