/*******************************************************************************

    Enum of exit statuses of the curl process.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        January 2012: Initial release

    authors:        Gavin Norman

    See http://curl.haxx.se/docs/manpage.html (section EXIT CODES)

*******************************************************************************/

module ocean.net.client.curl.process.ExitStatus;



/*******************************************************************************

    Status code enum, contains all curl exit codes plus code 0, meaning no code
    set, code 1000, meaning ok, and code -1, meaning that the curl process
    terminated abnormally and did not provide an exit code.

*******************************************************************************/

public enum ExitStatus
{
    ProcessTerminatedAbnormally = -1,

    OK = 0,

    UnsupportedProtocol = 1, // Unsupported protocol. This build of curl has no support for this protocol.
    FailedToInitialize = 2, // Failed to initialize.
    URLMalformed = 3, // URL malformed. The syntax was not correct.
    FeatureNotAvailable = 4, // A feature or option that was needed to perform the desired request was not enabled or was explicitly disabled at build-time. To make curl able to do this, you probably need another build of libcurl!
    CouldntResolveProxy = 5, // Couldn't resolve proxy. The given proxy host could not be resolved.
    CouldntResolveHost = 6, // Couldn't resolve host. The given remote host was not resolved.
    FailedToConnect = 7, // Failed to connect to host.
    FTPWeirdServerReply = 8, // FTP weird server reply. The server sent data curl couldn't parse.
    FTPAccessDenied = 9, // FTP access denied. The server denied login or denied access to the particular resource or directory you wanted to reach. Most often you tried to change to a directory that doesn't exist on the server.
    FTPWeirdPASSReply = 11, // FTP weird PASS reply. Curl couldn't parse the reply sent to the PASS request.
    FTPWeirdPASVReply = 13, // FTP weird PASV reply, Curl couldn't parse the reply sent to the PASV request.
    FTPWeird227Format = 14, // FTP weird 227 format. Curl couldn't parse the 227-line the server sent.
    FTPCantGetHost = 15, // FTP can't get host. Couldn't resolve the host IP we got in the 227-line.
    FTPCouldntSetBinary = 17, // FTP couldn't set binary. Couldn't change transfer method to binary.
    PartialFile = 18, // Partial file. Only a part of the file was transferred.
    FTPCouldntDownload = 19, // FTP couldn't download/access the given file, the RETR (or similar) command failed.
    FTPQuoteError = 21, // FTP quote error. A quote command returned error from the server.
    HTTPPageNotRetrieved = 22, // HTTP page not retrieved. The requested url was not found or returned another error with the HTTP error code being 400 or above. This return code only appears if -f, --fail is used.
    WriteError = 23, // Write error. Curl couldn't write data to a local filesystem or similar.
    FTPCouldntSTORFile = 25, // FTP couldn't STOR file. The server denied the STOR operation, used for FTP uploading.
    ReadError = 26, // Read error. Various reading problems.
    OutOfMemory = 27, // Out of memory. A memory allocation request failed.
    OperationTimeout = 28, // Operation timeout. The specified time-out period was reached according to the conditions.
    FTPPORTFailed = 30, // FTP PORT failed. The PORT command failed. Not all FTP servers support the PORT command, try doing a transfer using PASV instead!
    FTPCouldntUseREST = 31, // FTP couldn't use REST. The REST command failed. This command is used for resumed FTP transfers.
    HTTPRangeError = 33, // HTTP range error. The range "command" didn't work.
    HTTPPostError = 34, // HTTP post error. Internal post-request generation error.
    SSLConnectError = 35, // SSL connect error. The SSL handshaking failed.
    FTPBadDownloadResume = 36, // FTP bad download resume. Couldn't continue an earlier aborted download.
    FILECouldntReadFile = 37, // FILE couldn't read file. Failed to open the file. Permissions?
    LDAPCannotBind = 38, // LDAP cannot bind. LDAP bind operation failed.
    LDAPSearchFailed = 39, // LDAP search failed.
    FunctionNotFound = 41, // Function not found. A required LDAP function was not found.
    AbortedByCallback = 42, // Aborted by callback. An application told curl to abort the operation.
    InternalError = 43, // Internal error. A function was called with a bad parameter.
    InterfaceError = 45, // Interface error. A specified outgoing interface could not be used.
    TooManyRedirects = 47, // Too many redirects. When following redirects, curl hit the maximum amount.
    UnknownOption = 48, // Unknown option specified to libcurl. This indicates that you passed a weird option to curl that was passed on to libcurl and rejected. Read up in the manual!
    MalformedTelnetOption = 49, // Malformed telnet option.
    BadSSLCertificate = 51, // The peer's SSL certificate or SSH MD5 fingerprint was not OK.
    ServerDidntReply = 52, // The server didn't reply anything, which here is considered an error.
    NoSSLCryptoEngine = 53, // SSL crypto engine not found.
    CannotSetSSLCryptoEngine = 54, // Cannot set SSL crypto engine as default.
    FailedSendingNetworkData = 55, // Failed sending network data.
    FailedReceivingNetworkData = 56, // Failure in receiving network data.
    BadLocalCertificate = 58, // Problem with the local certificate.
    BadSSLCipher = 59, // Couldn't use specified SSL cipher.
    CouldntAuthenticateCertificate = 60, // Peer certificate cannot be authenticated with known CA certificates.
    UnrecognizedTransferEncoding = 61, // Unrecognized transfer encoding.
    InvalidLDAPURL = 62, // Invalid LDAP URL.
    MaximumFileSizeExceeded = 63, // Maximum file size exceeded.
    FTPSSLLevelFailed = 64, // Requested FTP SSL level failed.
    RewindFailed = 65, // Sending the data requires a rewind that failed.
    SSLInitializationFailed = 66, // Failed to initialise SSL Engine.
    LoginFailed = 67, // The user name, password, or similar was not accepted and curl failed to log in.
    TFTPFileNotFound = 68, // File not found on TFTP server.
    TFTPPermissionProblem = 69, // Permission problem on TFTP server.
    TFTPOutOfDiskSpace= 70, // Out of disk space on TFTP server.
    TFTPIllegalOperation = 71, // Illegal TFTP operation.
    TFTPUnknownTransferId = 72, // Unknown TFTP transfer ID.
    TFTPFileAlreadyExists = 73, // File already exists (TFTP).
    TFTPNoSuchUser = 74, // No such user (TFTP).
    CharacterConversionFailed = 75, // Character conversion failed.
    CharacterConversionFunctionRequired = 76, // Character conversion functions required.
    ProblemReadingSSLCertificate = 77, // Problem with reading the SSL CA cert (path? access rights?).
    ResourceDoesntExist = 78, // The resource referenced in the URL does not exist.
    SSHUnspecifiedError = 79, // An unspecified error occurred during the SSH session.
    SSLShutdownFailed = 80, // Failed to shut down the SSL connection.
    CouldntLoadCRLFile = 82, // Could not load CRL file, missing or wrong format (added in 7.19.0).
    IssuerCheckFailed = 83, // Issuer check failed (added in 7.19.0).
    FTPPRETFailed = 84, // The FTP PRET command failed
    RTSPCSeqMismatch = 85, // RTSP: mismatch of CSeq numbers
    RTSPSessionIdMismatch = 86, // RTSP: mismatch of Session Identifiers
    FTPCouldntParseFileList = 87, // unable to parse FTP file list
    FTPChunkCallbackError = 88 // FTP chunk callback reported error
}

