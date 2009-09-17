/*******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Feb 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        Abstract Client Interface for API Clients

        --
        
        TODO    
                
        1. finish implementation of abstract class and integrate into clients
        

*******************************************************************************/

module ocean.net.services.model.IClient;

private import  tango.text.json.Json;


/*******************************************************************************

    IClient

*******************************************************************************/

abstract class IClient
{
    /*******************************************************************************

         JSON Alias

     ******************************************************************************/ 
    
    /**
     * Json Alias
     */    
    protected       alias Json!(char)           JSON;
      
}
