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

module ocean.db.drizzle.c.drizzle;

public import ocean.db.drizzle.c.structs;

extern (C):

struct sockaddr_un
{
  short sun_family;
  char sun_path[108];
};




/+
#include <libdrizzle/visibility.h>
#include <libdrizzle/constants.h>
#include <libdrizzle/conn.h>
#include <libdrizzle/result.h>
#include <libdrizzle/column.h>
+/

/**
 * This is the core library structure that other structures  ( such as
 * connections )  are created from.
 *
 * There is no locking within a single drizzle_st structure, so for threaded
 * applications you must either ensure isolation in the application or use
 * multiple drizzle_st structures  ( for example, one for each thread ) .
 * @{
 */

/**
 * Get library version string.
 *
 * @return Pointer to static buffer in library that holds the version string.
 */
char *drizzle_version ( ) ;

/**
 * Get bug report URL.
 *
 * @return Bug report URL string.
 */
char *drizzle_bugreport ( ) ;

/**
 * Get string with the name of the given verbose level.
 *
 * @param[in] verbose Verbose logging level.
 * @return String form of verbose level.
 */
char *drizzle_verbose_name ( drizzle_verbose_t verbose ) ;

/**
 * Initialize a drizzle structure. Always check the return value even if passing
 * in a pre-allocated structure. Some other initialization may have failed.
 *
 * @param[in] drizzle Caller allocated structure, or NULL to allocate one.
 * @return On success, a pointer to the  ( possibly allocated )  structure. On
 * failure this will be NULL.
 */
drizzle_st *drizzle_create ( drizzle_st *drizzle ) ;

/**
 * Clone a drizzle structure.
 *
 * @param[in] drizzle Caller allocated structure, or NULL to allocate one.
 * @param[in] from Drizzle structure to use as a source to clone from.
 * @return Same return as drizzle_create (  ) .
 */
drizzle_st *drizzle_clone ( drizzle_st *drizzle, drizzle_st *from ) ;

/**
 * Free a drizzle structure.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 */

void drizzle_free ( drizzle_st *drizzle ) ;

/**
 * Return an error string for last error encountered.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @return Pointer to static buffer in library that holds an error string.
 */

char *drizzle_error ( drizzle_st *drizzle ) ;

/**
 * Value of errno in the case of a DRIZZLE_RETURN_ERRNO return value.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @return An errno value as defined in your system errno.h file.
 */

int drizzle_errno ( drizzle_st *drizzle ) ;

/**
 * Get server defined error code for the last result read.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @return An error code given back in the server response.
 */

ushort drizzle_error_code ( drizzle_st *drizzle ) ;

/**
 * Get SQL state code for the last result read.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @return A SQLSTATE code given back in the server response.
 */

char *drizzle_sqlstate ( drizzle_st *drizzle ) ;

/**
 * Get options for a drizzle structure.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @return Options set for the drizzle structure.
 */

drizzle_options_t drizzle_options ( drizzle_st *drizzle ) ;

/**
 * Set options for a drizzle structure.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @param[in] options Available options for drizzle structure to set.
 */

void drizzle_set_options ( drizzle_st *drizzle, drizzle_options_t options ) ;

/**
 * Add options for a drizzle structure.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @param[in] options Available options for drizzle structure to add.
 */

void drizzle_add_options ( drizzle_st *drizzle, drizzle_options_t options ) ;

/**
 * Remove options for a drizzle structure.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @param[in] options Available options for drizzle structure to remove.
 */

void drizzle_remove_options ( drizzle_st *drizzle, drizzle_options_t options ) ;

/**
 * Get application context pointer.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @return Application context that was previously set, or NULL.
 */

void *drizzle_context ( drizzle_st *drizzle ) ;

/**
 * Set application context pointer.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @param[in] context Application context to set.
 */

void drizzle_set_context ( drizzle_st *drizzle, void *context ) ;

/**
 * Set function to call when the drizzle structure is being cleaned up so
 * the application can clean up the context pointer.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @param[in] func Function to call to clean up drizzle context.
 */

void drizzle_set_context_free_fn ( drizzle_st *drizzle,
                                 drizzle_context_free_fn *func ) ;

/**
 * Get current socket I/O activity timeout value.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @return Timeout in milliseconds to wait for I/O activity. A negative value
 *  means an infinite timeout.
 */

int drizzle_timeout ( drizzle_st *drizzle ) ;

/**
 * Set socket I/O activity timeout for connections in a Drizzle structure.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @param[in] timeout Milliseconds to wait for I/O activity. A negative value
 *  means an infinite timeout.
 */

void drizzle_set_timeout ( drizzle_st *drizzle, int timeout ) ;

/**
 * Get current verbosity threshold for logging messages.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @return Current verbosity threshold.
 */

drizzle_verbose_t drizzle_verbose ( drizzle_st *drizzle ) ;

/**
 * Set verbosity threshold for logging messages. If this is set above
 * DRIZZLE_VERBOSE_NEVER and the drizzle_set_log_fn (  )  callback is set to NULL,
 * messages are printed to STDOUT.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @param[in] verbose Verbosity threshold of what to log.
 */
void drizzle_set_verbose ( drizzle_st *drizzle, drizzle_verbose_t verbose ) ;

/**
 * Set logging function for a drizzle structure. This function is only called
 * for log messages that are above the verbosity threshold set with
 * drizzle_set_verbose (  ) .
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @param[in] func Function to call when there is a logging message.
 * @param[in] context Argument to pass into the callback function.
 */
void drizzle_set_log_fn ( drizzle_st *drizzle, drizzle_log_fn *func,
                        void *context ) ;

/**
 * Set a custom I/O event watcher function for a drizzle structure. Used to
 * integrate libdrizzle with a custom event loop. The callback will be invoked
 * to register or deregister interest in events for a connection. When the
 * events are triggered, drizzle_con_set_revents (  )  should be called to
 * indicate which events are ready. The event loop should stop waiting for
 * these events, as libdrizzle will call the callback again if it is still
 * interested. To resume processing, the libdrizzle function that returned
 * DRIZZLE_RETURN_IO_WAIT should be called again. See drizzle_event_watch_fn (  ) .
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @param[in] func Function to call when there is an I/O event.
 * @param[in] context Argument to pass into the callback function.
 */
void drizzle_set_event_watch_fn ( drizzle_st *drizzle,
                                drizzle_event_watch_fn *func,
                                void *context ) ;

/**
 * Initialize a connection structure. Always check the return value even if
 * passing in a pre-allocated structure. Some other initialization may have
 * failed.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @param[in] con Caller allocated structure, or NULL to allocate one.
 * @return On success, a pointer to the  ( possibly allocated )  structure. On
 *  failure this will be NULL.
 */
drizzle_con_st *drizzle_con_create ( drizzle_st *drizzle, drizzle_con_st *con ) ;

/**
 * Clone a connection structure.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @param[in] con Caller allocated structure, or NULL to allocate one.
 * @param[in] from Connection structure to use as a source to clone from.
 * @return Same return as drizzle_con_create (  ) .
 */
drizzle_con_st *drizzle_con_clone ( drizzle_st *drizzle, drizzle_con_st *con,
                                  drizzle_con_st *from ) ;

/**
 * Free a connection structure.
 *
 * @param[in] con Connection structure previously initialized with
 *  drizzle_con_create (  ) , drizzle_con_clone (  ) , or related functions.
 */
void drizzle_con_free ( drizzle_con_st *con ) ;

/**
 * Free all connections in a drizzle structure.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 */
void drizzle_con_free_all ( drizzle_st *drizzle ) ;

/**
 * Wait for I/O on connections.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @return Standard drizzle return value.
 */
drizzle_return_t drizzle_con_wait ( drizzle_st *drizzle ) ;

/**
 * Get next connection that is ready for I/O.
 *
 * @param[in] drizzle Drizzle structure previously initialized with
 *  drizzle_create (  )  or drizzle_clone (  ) .
 * @return Connection that is ready for I/O, or NULL if there are none.
 */
drizzle_con_st *drizzle_con_ready ( drizzle_st *drizzle ) ;
