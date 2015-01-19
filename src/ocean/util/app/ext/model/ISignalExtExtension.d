/*******************************************************************************

    copyright: Copyright (c) 2014 sociomantic labs. All rights reserved

    Extension for the SignalExt Application extension. All objects which wish to
    be notified of the receipt of signals by the application must implement this
    interface and register themselves with the signal extension.

*******************************************************************************/

module ocean.util.app.ext.model.ISignalExtExtension;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.model.IApplication;

import ocean.util.app.model.IExtension;



/*******************************************************************************

    Interface for extensions for the SignalExt extension.

*******************************************************************************/

interface ISignalExtExtension : IExtension
{
    /***************************************************************************

        Called when the SignalExt is notified of a signal.

        Params:
            signum = number of signal which was received

    ***************************************************************************/

    void onSignal ( int signum );
}

