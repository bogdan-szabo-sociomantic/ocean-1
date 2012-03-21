/*
 * Drizzle Client & Protocol Library
 *
 * Copyright (C) 2008 Eric Day (eday@oddments.org)
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
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */
module ocean.db.drizzle.c.constants;

import ocean.db.drizzle.c.structs;

extern (C):

/**
 * @todo Remove these with next major API change.
 */
//alias DRIZZLE_RETURN_SERVER_GONE DRIZZLE_RETURN_LOST_CONNECTION;
//alias DRIZZLE_RETURN_EOF DRIZZLE_RETURN_LOST_CONNECTION;
const DRIZZLE_COLUMN_TYPE_VIRTUAL = 17;

/* Defines. */
const DRIZZLE_DEFAULT_TCP_HOST         = "126.0.0.1";
const DRIZZLE_DEFAULT_TCP_PORT         = 4427;
const DRIZZLE_DEFAULT_TCP_PORT_MYSQL   = 4427;
const DRIZZLE_DEFAULT_UDS              = "/tmp/drizzle.sock";
const DRIZZLE_DEFAULT_UDS_MYSQL        = "/tmp/mysql.sock";
const DRIZZLE_DEFAULT_BACKLOG          = 64;
const DRIZZLE_MAX_ERROR_SIZE           = 2048;
const DRIZZLE_MAX_USER_SIZE            = 64;
const DRIZZLE_MAX_PASSWORD_SIZE        = 32;
const DRIZZLE_MAX_DB_SIZE              = 64;
const DRIZZLE_MAX_INFO_SIZE            = 2048;
const DRIZZLE_MAX_SQLSTATE_SIZE        = 5;
const DRIZZLE_MAX_CATALOG_SIZE         = 128;
const DRIZZLE_MAX_TABLE_SIZE           = 128;
const DRIZZLE_MAX_COLUMN_NAME_SIZE     = 2048;
const DRIZZLE_MAX_DEFAULT_VALUE_SIZE   = 2048;
const DRIZZLE_MAX_PACKET_SIZE          = uint.max;
const DRIZZLE_MAX_BUFFER_SIZE          = 32768;
const DRIZZLE_BUFFER_COPY_THRESHOLD    = 8192;
const DRIZZLE_MAX_SERVER_VERSION_SIZE  = 32;
const DRIZZLE_MAX_SERVER_EXTRA_SIZE    = 32;
const DRIZZLE_MAX_SCRAMBLE_SIZE        = 20;
const DRIZZLE_STATE_STACK_SIZE         = 8;
const DRIZZLE_ROW_GROW_SIZE            = 8192;
const DRIZZLE_DEFAULT_SOCKET_TIMEOUT   = 10;
const DRIZZLE_DEFAULT_SOCKET_SEND_SIZE = 32768;
const DRIZZLE_DEFAULT_SOCKET_RECV_SIZE = 32768;
const DRIZZLE_MYSQL_PASSWORD_HASH      = 41;;

/**
 * Return codes.
 */
enum drizzle_return_t
{
  DRIZZLE_RETURN_OK,
  DRIZZLE_RETURN_IO_WAIT,
  DRIZZLE_RETURN_PAUSE,
  DRIZZLE_RETURN_ROW_BREAK,
  DRIZZLE_RETURN_MEMORY,
  DRIZZLE_RETURN_ERRNO,
  DRIZZLE_RETURN_INTERNAL_ERROR,
  DRIZZLE_RETURN_GETADDRINFO,
  DRIZZLE_RETURN_NOT_READY,
  DRIZZLE_RETURN_BAD_PACKET_NUMBER,
  DRIZZLE_RETURN_BAD_HANDSHAKE_PACKET,
  DRIZZLE_RETURN_BAD_PACKET,
  DRIZZLE_RETURN_PROTOCOL_NOT_SUPPORTED,
  DRIZZLE_RETURN_UNEXPECTED_DATA,
  DRIZZLE_RETURN_NO_SCRAMBLE,
  DRIZZLE_RETURN_AUTH_FAILED,
  DRIZZLE_RETURN_NULL_SIZE,
  DRIZZLE_RETURN_ERROR_CODE,
  DRIZZLE_RETURN_TOO_MANY_COLUMNS,
  DRIZZLE_RETURN_ROW_END,
  DRIZZLE_RETURN_LOST_CONNECTION,
  DRIZZLE_RETURN_COULD_NOT_CONNECT,
  DRIZZLE_RETURN_NO_ACTIVE_CONNECTIONS,
  DRIZZLE_RETURN_HANDSHAKE_FAILED,
  DRIZZLE_RETURN_TIMEOUT,
  DRIZZLE_RETURN_MAX /* Always add new codes to the end before this one. */
};

/**
 * Verbosity levels.
 */
enum drizzle_verbose_t
{
  DRIZZLE_VERBOSE_NEVER,
  DRIZZLE_VERBOSE_FATAL,
  DRIZZLE_VERBOSE_ERROR,
  DRIZZLE_VERBOSE_INFO,
  DRIZZLE_VERBOSE_DEBUG,
  DRIZZLE_VERBOSE_CRAZY,
  DRIZZLE_VERBOSE_MAX
};

/** @} */

/**
 * @ingroup drizzle
 * Options for drizzle_st.
 */
enum drizzle_options_t
{
  DRIZZLE_NONE=            0,
  DRIZZLE_ALLOCATED=       (1 << 0),
  DRIZZLE_NON_BLOCKING=    (1 << 1),
  DRIZZLE_FREE_OBJECTS=    (1 << 2),
  DRIZZLE_ASSERT_DANGLING= (1 << 3)
};

/**
 * @ingroup drizzle_con
 * Options for drizzle_con_st.
 */
enum drizzle_con_options_t
{
  DRIZZLE_CON_NONE=             0,
  DRIZZLE_CON_ALLOCATED=        (1 << 0),
  DRIZZLE_CON_MYSQL=            (1 << 1),
  DRIZZLE_CON_RAW_PACKET=       (1 << 2),
  DRIZZLE_CON_RAW_SCRAMBLE=     (1 << 3),
  DRIZZLE_CON_READY=            (1 << 4),
  DRIZZLE_CON_NO_RESULT_READ=   (1 << 5),
  DRIZZLE_CON_IO_READY=         (1 << 6),
  DRIZZLE_CON_LISTEN=           (1 << 7),
  DRIZZLE_CON_EXPERIMENTAL=     (1 << 8),
  DRIZZLE_CON_FOUND_ROWS=       (1 << 9),
  DRIZZLE_CON_ADMIN=            (1 << 10),
  DRIZZLE_CON_INTERACTIVE=      (1 << 11),
  DRIZZLE_CON_MULTI_STATEMENTS= (1 << 12),
  DRIZZLE_CON_AUTH_PLUGIN=      (1 << 13)
} ;

/**
 * @ingroup drizzle_con
 * Socket types for drizzle_con_st.
 */
enum drizzle_con_socket_t
{
  DRIZZLE_CON_SOCKET_TCP= 0,
  DRIZZLE_CON_SOCKET_UDS= (1 << 0)
}

/**
 * @ingroup drizzle_con
 * Status flags for drizle_con_st.
 */
enum drizzle_con_status_t
{
  DRIZZLE_CON_STATUS_NONE=                     0,
  DRIZZLE_CON_STATUS_IN_TRANS=                 (1 << 0),
  DRIZZLE_CON_STATUS_AUTOCOMMIT=               (1 << 1),
  DRIZZLE_CON_STATUS_MORE_RESULTS_EXISTS=      (1 << 3),
  DRIZZLE_CON_STATUS_QUERY_NO_GOOD_INDEX_USED= (1 << 4),
  DRIZZLE_CON_STATUS_QUERY_NO_INDEX_USED=      (1 << 5),
  DRIZZLE_CON_STATUS_CURSOR_EXISTS=            (1 << 6),
  DRIZZLE_CON_STATUS_LAST_ROW_SENT=            (1 << 7),
  DRIZZLE_CON_STATUS_DB_DROPPED=               (1 << 8),
  DRIZZLE_CON_STATUS_NO_BACKSLASH_ESCAPES=     (1 << 9),
  DRIZZLE_CON_STATUS_QUERY_WAS_SLOW=           (1 << 10)
}

/**
 * @ingroup drizzle_con
 * Capabilities for drizzle_con_st.
 */
enum drizzle_capabilities_t
{
  DRIZZLE_CAPABILITIES_NONE=                   0,
  DRIZZLE_CAPABILITIES_LONG_PASSWORD=          (1 << 0),
  DRIZZLE_CAPABILITIES_FOUND_ROWS=             (1 << 1),
  DRIZZLE_CAPABILITIES_LONG_FLAG=              (1 << 2),
  DRIZZLE_CAPABILITIES_CONNECT_WITH_DB=        (1 << 3),
  DRIZZLE_CAPABILITIES_NO_SCHEMA=              (1 << 4),
  DRIZZLE_CAPABILITIES_COMPRESS=               (1 << 5),
  DRIZZLE_CAPABILITIES_ODBC=                   (1 << 6),
  DRIZZLE_CAPABILITIES_LOCAL_FILES=            (1 << 7),
  DRIZZLE_CAPABILITIES_IGNORE_SPACE=           (1 << 8),
  DRIZZLE_CAPABILITIES_PROTOCOL_41=            (1 << 9),
  DRIZZLE_CAPABILITIES_INTERACTIVE=            (1 << 10),
  DRIZZLE_CAPABILITIES_SSL=                    (1 << 11),
  DRIZZLE_CAPABILITIES_IGNORE_SIGPIPE=         (1 << 12),
  DRIZZLE_CAPABILITIES_TRANSACTIONS=           (1 << 13),
  DRIZZLE_CAPABILITIES_RESERVED=               (1 << 14),
  DRIZZLE_CAPABILITIES_SECURE_CONNECTION=      (1 << 15),
  DRIZZLE_CAPABILITIES_MULTI_STATEMENTS=       (1 << 16),
  DRIZZLE_CAPABILITIES_MULTI_RESULTS=          (1 << 17),
  DRIZZLE_CAPABILITIES_PS_MULTI_RESULTS=       (1 << 18),
  DRIZZLE_CAPABILITIES_PLUGIN_AUTH=            (1 << 19),
  DRIZZLE_CAPABILITIES_ADMIN=                  (1 << 25),
  DRIZZLE_CAPABILITIES_SSL_VERIFY_SERVER_CERT= (1 << 30),
  DRIZZLE_CAPABILITIES_REMEMBER_OPTIONS=       (1 << 31),
  DRIZZLE_CAPABILITIES_CLIENT= (DRIZZLE_CAPABILITIES_LONG_PASSWORD |
                                DRIZZLE_CAPABILITIES_FOUND_ROWS |
                                DRIZZLE_CAPABILITIES_LONG_FLAG |
                                DRIZZLE_CAPABILITIES_CONNECT_WITH_DB |
                                DRIZZLE_CAPABILITIES_PLUGIN_AUTH |
                                DRIZZLE_CAPABILITIES_TRANSACTIONS |
                                DRIZZLE_CAPABILITIES_PROTOCOL_41 |
                                DRIZZLE_CAPABILITIES_SECURE_CONNECTION |
                                DRIZZLE_CAPABILITIES_ADMIN)
}

/**
 * @ingroup drizzle_command
 * Commands for drizzle_command functions.
 */
enum drizzle_command_t
{
  DRIZZLE_COMMAND_SLEEP,               /* Not used currently. */
  DRIZZLE_COMMAND_QUIT,
  DRIZZLE_COMMAND_INIT_DB,
  DRIZZLE_COMMAND_QUERY,
  DRIZZLE_COMMAND_FIELD_LIST,          /* Deprecated. */
  DRIZZLE_COMMAND_CREATE_DB,           /* Deprecated. */
  DRIZZLE_COMMAND_DROP_DB,             /* Deprecated. */
  DRIZZLE_COMMAND_REFRESH,
  DRIZZLE_COMMAND_SHUTDOWN,
  DRIZZLE_COMMAND_STATISTICS,
  DRIZZLE_COMMAND_PROCESS_INFO,        /* Deprecated. */
  DRIZZLE_COMMAND_CONNECT,             /* Not used currently. */
  DRIZZLE_COMMAND_PROCESS_KILL,        /* Deprecated. */
  DRIZZLE_COMMAND_DEBUG,
  DRIZZLE_COMMAND_PING,
  DRIZZLE_COMMAND_TIME,                /* Not used currently. */
  DRIZZLE_COMMAND_DELAYED_INSERT,      /* Not used currently. */
  DRIZZLE_COMMAND_CHANGE_USER,
  DRIZZLE_COMMAND_BINLOG_DUMP,         /* Not used currently. */
  DRIZZLE_COMMAND_TABLE_DUMP,          /* Not used currently. */
  DRIZZLE_COMMAND_CONNECT_OUT,         /* Not used currently. */
  DRIZZLE_COMMAND_REGISTER_SLAVE,      /* Not used currently. */
  DRIZZLE_COMMAND_STMT_PREPARE,        /* Not used currently. */
  DRIZZLE_COMMAND_STMT_EXECUTE,        /* Not used currently. */
  DRIZZLE_COMMAND_STMT_SEND_LONG_DATA, /* Not used currently. */
  DRIZZLE_COMMAND_STMT_CLOSE,          /* Not used currently. */
  DRIZZLE_COMMAND_STMT_RESET,          /* Not used currently. */
  DRIZZLE_COMMAND_SET_OPTION,          /* Not used currently. */
  DRIZZLE_COMMAND_STMT_FETCH,          /* Not used currently. */
  DRIZZLE_COMMAND_DAEMON,              /* Not used currently. */
  DRIZZLE_COMMAND_END                  /* Not used currently. */
}

/**
 * @ingroup drizzle_command
 * Commands for the Drizzle protocol functions.
 */
enum drizzle_command_drizzle_t
{
  DRIZZLE_COMMAND_DRIZZLE_SLEEP,
  DRIZZLE_COMMAND_DRIZZLE_QUIT,
  DRIZZLE_COMMAND_DRIZZLE_INIT_DB,
  DRIZZLE_COMMAND_DRIZZLE_QUERY,
  DRIZZLE_COMMAND_DRIZZLE_SHUTDOWN,
  DRIZZLE_COMMAND_DRIZZLE_CONNECT,
  DRIZZLE_COMMAND_DRIZZLE_PING,
  DRIZZLE_COMMAND_DRIZZLE_KILL,
  DRIZZLE_COMMAND_DRIZZLE_END
}

/**
 * @ingroup drizzle_query
 * Options for drizzle_query_st.
 */
enum drizzle_query_options_t
{
  DRIZZLE_QUERY_NONE,
  DRIZZLE_QUERY_ALLOCATED= (1 << 0)
}

/**
 * @ingroup drizzle_query
 * States for drizle_query_st.
 */
enum drizzle_query_state_t
{
  DRIZZLE_QUERY_STATE_INIT,
  DRIZZLE_QUERY_STATE_QUERY,
  DRIZZLE_QUERY_STATE_RESULT,
  DRIZZLE_QUERY_STATE_DONE
}

/**
 * @ingroup drizzle_result
 * Options for drizzle_result_st.
 */
enum drizzle_result_options_t
{
  DRIZZLE_RESULT_NONE=          0,
  DRIZZLE_RESULT_ALLOCATED=     (1 << 0),
  DRIZZLE_RESULT_SKIP_COLUMN=   (1 << 1),
  DRIZZLE_RESULT_BUFFER_COLUMN= (1 << 2),
  DRIZZLE_RESULT_BUFFER_ROW=    (1 << 3),
  DRIZZLE_RESULT_EOF_PACKET=    (1 << 4),
  DRIZZLE_RESULT_ROW_BREAK=     (1 << 5)
}

/**
 * @ingroup drizzle_column
 * Options for drizzle_column_st.
 */
enum drizzle_column_options_t
{
  DRIZZLE_COLUMN_ALLOCATED= (1 << 0)
}

/**
 * @ingroup drizzle_column
 * Types for drizzle_column_st.
 */
enum drizzle_column_type_t
{
  DRIZZLE_COLUMN_TYPE_DECIMAL,
  DRIZZLE_COLUMN_TYPE_TINY,
  DRIZZLE_COLUMN_TYPE_SHORT,
  DRIZZLE_COLUMN_TYPE_LONG,
  DRIZZLE_COLUMN_TYPE_FLOAT,
  DRIZZLE_COLUMN_TYPE_DOUBLE,
  DRIZZLE_COLUMN_TYPE_NULL,
  DRIZZLE_COLUMN_TYPE_TIMESTAMP,
  DRIZZLE_COLUMN_TYPE_LONGLONG,
  DRIZZLE_COLUMN_TYPE_INT24,
  DRIZZLE_COLUMN_TYPE_DATE,
  DRIZZLE_COLUMN_TYPE_TIME,
  DRIZZLE_COLUMN_TYPE_DATETIME,
  DRIZZLE_COLUMN_TYPE_YEAR,
  DRIZZLE_COLUMN_TYPE_NEWDATE,
  DRIZZLE_COLUMN_TYPE_VARCHAR,
  DRIZZLE_COLUMN_TYPE_BIT,
  DRIZZLE_COLUMN_TYPE_NEWDECIMAL=  246,
  DRIZZLE_COLUMN_TYPE_ENUM=        247,
  DRIZZLE_COLUMN_TYPE_SET=         248,
  DRIZZLE_COLUMN_TYPE_TINY_BLOB=   249,
  DRIZZLE_COLUMN_TYPE_MEDIUM_BLOB= 250,
  DRIZZLE_COLUMN_TYPE_LONG_BLOB=   251,
  DRIZZLE_COLUMN_TYPE_BLOB=        252,
  DRIZZLE_COLUMN_TYPE_VAR_STRING=  253,
  DRIZZLE_COLUMN_TYPE_STRING=      254,
  DRIZZLE_COLUMN_TYPE_GEOMETRY=    255
}

/**
 * @ingroup drizzle_column
 * Types for drizzle_column_st for Drizzle.
 */
enum drizzle_column_type_drizzle_t
{
  DRIZZLE_COLUMN_TYPE_DRIZZLE_TINY,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_LONG,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_DOUBLE,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_NULL,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_TIMESTAMP,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_LONGLONG,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_DATETIME,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_DATE,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_VARCHAR,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_NEWDECIMAL,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_ENUM,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_BLOB,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_TIME,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_BOOLEAN,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_UUID,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_MICROTIME,
  DRIZZLE_COLUMN_TYPE_DRIZZLE_MAX=DRIZZLE_COLUMN_TYPE_DRIZZLE_MICROTIME
}

/**
 * @ingroup drizzle_column
 * Flags for drizzle_column_st.
 */
enum drizzle_column_flags_t
{
  DRIZZLE_COLUMN_FLAGS_NONE=             0,
  DRIZZLE_COLUMN_FLAGS_NOT_NULL=         (1 << 0),
  DRIZZLE_COLUMN_FLAGS_PRI_KEY=          (1 << 1),
  DRIZZLE_COLUMN_FLAGS_UNIQUE_KEY=       (1 << 2),
  DRIZZLE_COLUMN_FLAGS_MULTIPLE_KEY=     (1 << 3),
  DRIZZLE_COLUMN_FLAGS_BLOB=             (1 << 4),
  DRIZZLE_COLUMN_FLAGS_UNSIGNED=         (1 << 5),
  DRIZZLE_COLUMN_FLAGS_ZEROFILL=         (1 << 6),
  DRIZZLE_COLUMN_FLAGS_BINARY=           (1 << 7),
  DRIZZLE_COLUMN_FLAGS_ENUM=             (1 << 8),
  DRIZZLE_COLUMN_FLAGS_AUTO_INCREMENT=   (1 << 9),
  DRIZZLE_COLUMN_FLAGS_TIMESTAMP=        (1 << 10),
  DRIZZLE_COLUMN_FLAGS_SET=              (1 << 11),
  DRIZZLE_COLUMN_FLAGS_NO_DEFAULT_VALUE= (1 << 12),
  DRIZZLE_COLUMN_FLAGS_ON_UPDATE_NOW=    (1 << 13),
  DRIZZLE_COLUMN_FLAGS_PART_KEY=         (1 << 14),
  DRIZZLE_COLUMN_FLAGS_NUM=              (1 << 15),
  DRIZZLE_COLUMN_FLAGS_GROUP=            (1 << 15), /* NUM & GROUP the same. */
  DRIZZLE_COLUMN_FLAGS_UNIQUE=           (1 << 16),
  DRIZZLE_COLUMN_FLAGS_BINCMP=           (1 << 17),
  DRIZZLE_COLUMN_FLAGS_GET_FIXED_FIELDS= (1 << 18),
  DRIZZLE_COLUMN_FLAGS_IN_PART_FUNC=     (1 << 19),
  DRIZZLE_COLUMN_FLAGS_IN_ADD_INDEX=     (1 << 20),
  DRIZZLE_COLUMN_FLAGS_RENAMED=          (1 << 21)
}

/**
 * @addtogroup drizzle_types Types
 * @ingroup drizzle_client_interface
 * @ingroup drizzle_server_interface
 * @{
 */

/* Types. */
alias char* drizzle_field_t;
alias  drizzle_field_t *drizzle_row_t;
alias ubyte drizzle_charset_t;

/* Function types. */
alias void (drizzle_context_free_fn)(drizzle_st *drizzle,
                                       void *context);
alias void (drizzle_log_fn)( char *line, drizzle_verbose_t verbose,
                              void *context);
alias drizzle_return_t (drizzle_state_fn)(drizzle_con_st *con);
alias void (drizzle_con_context_free_fn)(drizzle_con_st *con,
                                           void *context);
alias void (drizzle_query_context_free_fn)(drizzle_query_st *query,
                                             void *context);
/**
 * Custom function to register or deregister interest in file descriptor
 * events. See drizzle_set_event_watch_fn().
 *
 * @param[in] con Connection that has changed the events it is interested in.
 *  Use drizzle_con_fd() to get the file descriptor.
 * @param[in] events A bit mask of POLLIN | POLLOUT, specifying if the
 *  connection is waiting for read or write events.
 * @param[in] context Application context pointer registered with
 *  drizzle_set_event_watch_fn().
 * @return DRIZZLE_RETURN_OK if successful.
 */
alias drizzle_return_t (drizzle_event_watch_fn)(drizzle_con_st *con,
                                                  short events,
                                                  void *context);

/** @} */

/**
 * @addtogroup drizzle_macros Macros
 * @ingroup drizzle_client_interface
 * @ingroup drizzle_server_interface
 * @{
 */

/* Protocol unpacking macros. */
ushort drizzle_get_byte2 ( ubyte[] __buffer )
{
    return cast(ushort)((__buffer)[0] |
            ((__buffer)[1] << 8));
}

uint drizzle_get_byte3 ( ubyte[] __buffer )
{
    return cast(uint)((__buffer)[0] |
            ((__buffer)[1] << 8) |
            ((__buffer)[2] << 16));
}

uint drizzle_get_byte4 ( ubyte[] __buffer)
{
    return cast(uint)((__buffer)[0] |
            ((__buffer)[1] << 8) |
            ((__buffer)[2] << 16) |
            ((__buffer)[3] << 24));
}

ulong drizzle_get_byte8 ( ubyte[] __buffer)
{
    return
        (cast(ulong)(__buffer)[0] |
         (cast(ulong)(__buffer)[1] << 8) |
         (cast(ulong)(__buffer)[2] << 16) |
         (cast(ulong)(__buffer)[3] << 24) |
         (cast(ulong)(__buffer)[4] << 32) |
         (cast(ulong)(__buffer)[5] << 40) |
         (cast(ulong)(__buffer)[6] << 48) |
         (cast(ulong)(__buffer)[7] << 56));
}
/* Protocol packing macros. */
void drizzle_set_byte2 ( T ) ( ubyte[] __buffer, T __int)
{
    (__buffer)[0]= cast(ubyte)((__int) & 0xFF);
    (__buffer)[1]= cast(ubyte)(((__int) >> 8) & 0xFF);
}

void drizzle_set_byte3 ( T ) (ubyte[] __buffer, T __int)
{
    (__buffer)[0]= cast(ubyte)((__int) & 0xFF);
    (__buffer)[1]= cast(ubyte)(((__int) >> 8) & 0xFF);
    (__buffer)[2]= cast(ubyte)(((__int) >> 16) & 0xFF);
}
void drizzle_set_byte4 ( T ) ( ubyte[] __buffer, T __int )
{
    (__buffer)[0]= cast(ubyte)((__int) & 0xFF);
    (__buffer)[1]= cast(ubyte)(((__int) >> 8) & 0xFF);
    (__buffer)[2]= cast(ubyte)(((__int) >> 16) & 0xFF);
    (__buffer)[3]= cast(ubyte)(((__int) >> 24) & 0xFF);
}

void drizzle_set_byte8 ( T ) ( ubyte[] __buffer, T __int)
{
    (__buffer)[0]= cast(ubyte)((__int) & 0xFF);
    (__buffer)[1]= cast(ubyte)(((__int) >> 8) & 0xFF);
    (__buffer)[2]= cast(ubyte)(((__int) >> 16) & 0xFF);
    (__buffer)[3]= cast(ubyte)(((__int) >> 24) & 0xFF);
    (__buffer)[4]= cast(ubyte)(((__int) >> 32) & 0xFF);
    (__buffer)[5]= cast(ubyte)(((__int) >> 40) & 0xFF);
    (__buffer)[6]= cast(ubyte)(((__int) >> 48) & 0xFF);
    (__buffer)[7]= cast(ubyte)(((__int) >> 56) & 0xFF);
}
/* Multi-byte character macros. */

T drizzle_mb_char ( T ) ( T __c )
{
    return (((__c) & 0x80) != 0);
}

T drizzle_mb_length ( T ) ( T __c )
{
    return
        (cast(uint)(__c) <= 0x7f ? 1 :
        (cast(uint)(__c) <= 0x7ff ? 2 :
        (cast(uint)(__c) <= 0xd7ff ? 3 :
        (cast(uint)(__c) <= 0xdfff || cast(uint)(__c) > 0x10ffff ? 0 :
        (cast(uint)(__c) <= 0xffff ? 3 : 4)))));
}
