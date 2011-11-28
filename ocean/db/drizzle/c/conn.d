/*
 * Drizzle Client & Protocol Library
 *
 * Copyright  ( C )  2008 Eric Day  ( eday@oddments.org ) 
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *
 *     * The names of its contributors may not be used to endorse or
 * promote products derived from this software without specific prior
 * written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES  ( INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION )  HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *  ( INCLUDING NEGLIGENCE OR OTHERWISE )  ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

module ocean.db.drizzle.c.conn;

public import tango.stdc.posix.arpa.inet;

public import ocean.db.drizzle.c.structs;

extern(C):

/**
 * Get file descriptor for connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return File descriptor of connection, or -1 if not active.
 */

int drizzle_con_fd ( drizzle_con_st *con ) ;

/**
 * Use given file descriptor for connction.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @param[in] fd File descriptor for connection.
 * @return Standard drizzle return value.
 */

drizzle_return_t drizzle_con_set_fd ( drizzle_con_st *con, int fd ) ;

/**
 * Close a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 */

void drizzle_con_close ( drizzle_con_st *con ) ;

/**
 * Set events to be watched for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @param[in] events Bitfield of poll (  )  events to watch.
 * @return Standard drizzle return value.
 */

drizzle_return_t drizzle_con_set_events ( drizzle_con_st *con, short events ) ;

/**
 * Set events that are ready for a connection. This is used with the external
 * event callbacks. See drizzle_set_event_watch_fn (  ) .
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @param[in] revents Bitfield of poll (  )  events that were detected.
 * @return Standard drizzle return value.
 */

drizzle_return_t drizzle_con_set_revents ( drizzle_con_st *con, short revents ) ;

/**
 * Get the drizzle_st struct that the connection belongs to.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Drizzle object that this connection is part of.
 */

drizzle_st *drizzle_con_drizzle ( drizzle_con_st *con ) ;

/**
 * Return an error string for last error encountered.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Pointer to static buffer in library that holds an error string.
 */

char *drizzle_con_error ( drizzle_con_st *con ) ;

/**
 * Value of errno in the case of a DRIZZLE_RETURN_ERRNO return value.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return An errno value as defined in your system errno.h file.
 */

int drizzle_con_errno ( drizzle_con_st *con ) ;

/**
 * Get server defined error code for the last result read.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return An error code given back in the server response.
 */

uint16_t drizzle_con_error_code ( drizzle_con_st *con ) ;

/**
 * Get SQL state code for the last result read.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return A SQLSTATE code given back in the server response.
 */

char *drizzle_con_sqlstate ( drizzle_con_st *con ) ;

/**
 * Get options for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Options set for the connection structure.
 */

drizzle_con_options_t drizzle_con_options ( drizzle_con_st *con ) ;

/**
 * Set options for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @param[in] options Available options for connection structure to set.
 */

void drizzle_con_set_options ( drizzle_con_st *con,
                             drizzle_con_options_t options ) ;

/**
 * Add options for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @param[in] options Available options for connection structure to set.
 */

void drizzle_con_add_options ( drizzle_con_st *con,
                             drizzle_con_options_t options ) ;

/**
 * Remove options for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @param[in] options Available options for connection structure to remove.
 */

void drizzle_con_remove_options ( drizzle_con_st *con,
                                drizzle_con_options_t options ) ;

/**
 * Get TCP host for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Host this connection is configured for, or NULL if not set.
 */

char *drizzle_con_host ( drizzle_con_st *con ) ;

/**
 * Get TCP port for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Port this connection is configured for, 0 if not set.
 */

in_port_t drizzle_con_port ( drizzle_con_st *con ) ;

/**
 * Set TCP host and port for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @param[in] host Host to use for this connection, NULL for default value.
 * @param[in] port Port to use for this connection, 0 for default value.
 */

void drizzle_con_set_tcp ( drizzle_con_st *con, char *host, in_port_t port ) ;

/**
 * Get unix domain socket for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Unix domain socket set for this connection, NULL if not set.
 */

char *drizzle_con_uds ( drizzle_con_st *con ) ;

/**
 * Set unix domain socket for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @param[in] uds Unix domain socket to use for this connection, NULL for
 *  defailt value.
 */

void drizzle_con_set_uds ( drizzle_con_st *con, char *uds ) ;

/**
 * Get username for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return User associated with this connection.
 */

char *drizzle_con_user ( drizzle_con_st *con ) ;

/**
 * Get password for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Password associated with this connection.
 */

char *drizzle_con_password ( drizzle_con_st *con ) ;

/**
 * Set username and password for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @param[in] user Username to use for this connection.
 * @param[in] password Password to use for this connection.
 */

void drizzle_con_set_auth ( drizzle_con_st *con, char *user,
                          char *password ) ;

/**
 * Get database for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Database associated with this connection.
 */

char *drizzle_con_db ( drizzle_con_st *con ) ;

/**
 * Set database for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @param[in] db Database to use with this connection.
 */

void drizzle_con_set_db ( drizzle_con_st *con, char *db ) ;

/**
 * Get application context pointer for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Application context with this connection.
 */

void *drizzle_con_context ( drizzle_con_st *con ) ;

/**
 * Set application context pointer for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @param[in] context Application context to use with this connection.
 */

void drizzle_con_set_context ( drizzle_con_st *con, void *context ) ;

/**
 * Set callback func when the context pointer should be freed.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @param[in] func func to call to clean up connection context.
 */

void drizzle_con_set_context_free_fn ( drizzle_con_st *con,
                                     drizzle_con_context_free_fn *func ) ;

/**
 * Get protocol version for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Protocol version for connection.
 */

ubyte drizzle_con_protocol_version ( drizzle_con_st *con ) ;

/**
 * Get server version string for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Server version string for connection.
 */

char *drizzle_con_server_version ( drizzle_con_st *con ) ;

/**
 * Get server version number for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Server version number for connection.
 */

uint drizzle_con_server_version_number ( drizzle_con_st *con ) ;

/**
 * Get thread ID for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Thread ID for connection.
 */

uint drizzle_con_thread_id ( drizzle_con_st *con ) ;

/**
 * Get scramble buffer for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Scramble buffer for connection.
 */

ubyte *drizzle_con_scramble ( drizzle_con_st *con ) ;

/**
 * Get capabilities for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Capabilities for connection.
 */

drizzle_capabilities_t drizzle_con_capabilities ( drizzle_con_st *con ) ;

/**
 * Get character set for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Character set for connection.
 */

drizzle_charset_t drizzle_con_charset ( drizzle_con_st *con ) ;

/**
 * Get status for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Status for connection.
 */

drizzle_con_status_t drizzle_con_status ( drizzle_con_st *con ) ;

/**
 * Get max packet size for a connection.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related funcs.
 * @return Max packet size for connection.
 */

uint drizzle_con_max_packet_size ( drizzle_con_st *con ) ;
