/*******************************************************************************

    Abstract base classes for suspendable throttlers.

    copyright:      Copyright (c) 2015 sociomantic labs. All rights reserved

    Provides a simple mechanism for throttling a set of one or more suspendable
    processes based on some condition (as defined by a derived class).

*******************************************************************************/

module ocean.io.model.ISuspendableThrottler;


/*******************************************************************************

    Abstract base class for suspendable throttlers.

    Provides the following functionality:
        * Maintains a set of ISuspendables which are suspended / resumed
          together.
        * A throttle() method, to be called when the suspension state should be
          updated / reassessed.
        * Abstract suspend() and resume() methods which define the conditions
          for suspension and resumption of the set of ISuspendables.
        * A suspended() method to tell whether the ISuspendables are suspended.

*******************************************************************************/

abstract public class ISuspendableThrottler
{
    import ocean.io.model.ISuspendable;

    import tango.core.Array : contains, remove;


    /***************************************************************************

        List of suspendables which are to be throttled. Suspendables are added
        to the list with the addSuspendable() method, and can be cleared by clear().

    ***************************************************************************/

    private ISuspendable[] suspendables;


    /***************************************************************************

        Flag set to true when the suspendables are suspended.

    ***************************************************************************/

    private bool suspended_;


    /***************************************************************************

        Adds a suspendable to the list of suspendables which are to be
        throttled. If it is already in the list, nothing happens.

        Params:
            s = suspendable

    ***************************************************************************/

    public void addSuspendable ( ISuspendable s )
    {
        if ( !this.suspendables.contains(s) )
        {
            this.suspendables ~= s;
            if (this.suspended_)
            {
                s.suspend();
            }
        }
    }


    /***************************************************************************

        Removes a suspendable from the list of suspendables if it exists.

        Params:
            s = suspendable

    ***************************************************************************/

    public void removeSuspendable ( ISuspendable s )
    {
        this.suspendables = this.suspendables[0 .. this.suspendables.remove(s)];
    }


    /***************************************************************************

        Returns:
            true if the suspendables are currently suspended.

    ***************************************************************************/

    public bool suspended ( )
    {
        return this.suspended_;
    }


    /***************************************************************************

        Clears the list of suspendables.

    ***************************************************************************/

    public void clear ( )
    {
        this.suspendables.length = 0;
        this.suspended_ = false;
    }


    /***************************************************************************

        Throttles the suspendables based on the derived class' implementation of
        the abstract methods suspend() and resume().

        This method must be called whenever the suspension state should
        be reassessed.

    ***************************************************************************/

    public void throttle ( )
    {
        if ( this.suspended_ )
        {
            if (  this.resume() )
            {
                this.resumeAll();
            }
        }
        else
        {
            if ( this.suspend() )
            {
                this.suspendAll();
            }
        }
    }


    /***************************************************************************

        Decides whether the suspendables should be suspended. Called by
        throttle() when not suspended.

        Returns:
            true if the suspendables should be suspeneded

    ***************************************************************************/

    abstract protected bool suspend ( );


    /***************************************************************************

        Decides whether the suspendables should be resumed. Called by
        throttle() when suspended.

        Returns:
            true if the suspendables should be resumed

    ***************************************************************************/

    abstract protected bool resume ( );


    /***************************************************************************

        Resumes all suspendables and sets the suspended_ flag to false.

        Note that the suspended_ flag is set before resuming the suspendables
        in order to avoid a race condition when the resumption of a suspendable
        performs actions which would cause the throttle() method to be
        called again.

    ***************************************************************************/

    private void resumeAll ( )
    {
        this.suspended_ = false;
        foreach ( s; this.suspendables )
        {
            s.resume();
        }
    }


    /***************************************************************************

        Suspends all suspendables and sets the suspended_ flag to true.

        Note that the suspended_ flag is set before suspending the suspendables
        in order to avoid a race condition when the suspending of a suspendable
        performs actions which would cause the throttle() method to be
        called again.

    ***************************************************************************/

    private void suspendAll ( )
    {
        this.suspended_ = true;
        foreach ( s; this.suspendables )
        {
            s.suspend();
        }
    }
}
