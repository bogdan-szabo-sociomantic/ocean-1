/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Initial release: Aug 2006

        author:         Kris

*******************************************************************************/

module tango.net.InternetAddress;

import tango.transition;

import tango.net.device.Berkeley;

/*******************************************************************************


*******************************************************************************/

class InternetAddress : IPv4Address
{
        /***********************************************************************

                useful for Datagrams

        ***********************************************************************/

        this(){}

        /***********************************************************************

                -port- can be PORT_ANY
                -addr- is an IP address or host name

        ***********************************************************************/

        this (istring addr, int port = PORT_ANY)
        {
                foreach (int i, char c; addr)
                         if (c is ':')
                            {
                            port = parse (addr [i+1 .. $]);
                            addr = addr [0 .. i];
                            break;
                            }

                super (addr, cast(ushort) port);
        }

        /***********************************************************************


        ***********************************************************************/

        this (uint addr, ushort port)
        {
                super (addr, port);
        }


        /***********************************************************************


        ***********************************************************************/

        this (ushort port)
        {
                super (port);
        }

        /**********************************************************************

        **********************************************************************/

        private static int parse (cstring s)
        {
                int number;

                foreach (c; s)
                         number = number * 10 + (c - '0');

                return number;
        }
}