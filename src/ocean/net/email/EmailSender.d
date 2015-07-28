/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        10/10/2012: Initial release

    authors:        Hans Bjerkander

    Class containing a single function which sends a email by spawning a child
    process that executes the command sendmail.

*******************************************************************************/

module ocean.net.email.EmailSender;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Array : append;

import tango.io.Stdout;
import tango.sys.Process;
import tango.core.Exception : ProcessException;


class EmailSender
{
    /***************************************************************************

        tango process

    ***************************************************************************/

    private Process process;


    /***************************************************************************

        Constructor that creates the reusable process

    ***************************************************************************/

    public this ( )
    {
        this.process = new Process("sendmail -t", null);
    }


    /***************************************************************************

        Spawns a child process that sends a email with help of sendmail.

        Params:
            sender     = the sender of the email
            recipients = the recipient/s of the email
            subject    = the email subject
            msg_body   = the email body
            reply_to   = an optional Reply To. default empty
            mail_id    = an optional mail id/In-Reply-To. default empty
            cc         = an optional cc. default empty
            bcc        = an optional bcc. default empty

        Returns:
            true if the mail was sent without any errors, otherwise false;

    ***************************************************************************/


    public bool sendEmail ( char[] sender, char [] recipients, char[] subject,
                            char[] msg_body, char[] reply_to = null,
                            char[] mail_id = null,
                            char[] cc = null, char[] bcc = null )
    {
        Process.Result result;

        with (this.process)
        {
            try
            {
                execute;
                stdin.write("From: ");
                stdin.write(sender);
                stdin.write("\nTo: ");
                stdin.write(recipients);
                if ( cc != null )
                {
                    stdin.write("\nCc: ");
                    stdin.write(cc);
                }
                if ( bcc != null )
                {
                    stdin.write("\nBcc: ");
                    stdin.write(bcc);
                }
                stdin.write("\nSubject: ");
                stdin.write(subject);
                if ( reply_to != null)
                {
                    stdin.write("\nReply-To: ");
                    stdin.write(reply_to);
                }
                if ( mail_id != null)
                {
                    stdin.write("\nIn-Reply-To: ");
                    stdin.write(mail_id);

                }
                stdin.write("\nMime-Version: 1.0");
                stdin.write("\nContent-Type: text/html; charset=UTF-8\n");
                stdin.write(msg_body);
                stdin.close();
                result = process.wait;
            }
            catch ( ProcessException e )
            {
                Stderr.formatln("Process '{}' ({}) exited with reason {}, "
                    "status {}", programName, pid, cast(int) result.reason,
                    result.status);
                return false;
            }
        }
        return true;
    }
}
