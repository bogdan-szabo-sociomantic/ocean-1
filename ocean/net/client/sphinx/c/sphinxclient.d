module ocean.net.client.sphinx.c.sphinxclient;

/**
 * Pure C searchd client API library
 * Sphinx search engine, http://sphinxsearch.com/
 *
 * API notes
 * ------------
 *
 * 1. API can either copy the contents of passed pointer arguments,
 * or rely on the application that the pointer will not become invalid.
 * This is controlled on per-client basis; see 'copy_args' argument
 * to the sphinx_create() call.
 *
 * When 'copy_args' is true, API will create and manage a copy of every
 * string and array passed to it. This causes additional malloc() pressure,
 * but makes calling code easier to write.
 *
 * When 'copy_args' is false, API expects that pointers passed to
 * sphinx_set_xxx() calls will still be valid at the time when sphinx_query()
 * or sphinx_add_query() are called.
 *
 * Rule of thumb: when 'copy_args' is false, do not free query arguments
 * until you have the search result. Example code for that case:
 *
 * VALID CODE:
 *
 *         char * my_filter_name;
 *
 *         my_filter_name = malloc ( 256 );
 *         strncpy ( my_filter_name, "test", 256 );
 *
 *         sphinx_add_filter_range ( client, my_filter_name, 10, 20, false );
 *         result = sphinx_query ( client );
 *
 *         free ( my_filter_name );
 *         my_filter_name = NULL;
 *
 * INVALID CODE:
 *
 *         void setup_my_filter ( sphinx_client * client )
 *         {
 *                 char buffer[256];
 *                 strncpy ( buffer, "test", sizeof(buffer) );
 *
 *                 // INVALID! by the time when sphinx_query() is called,
 *                 // buffer will be out of scope
 *                 sphinx_add_filter_range ( client, buffer, 10, 20, false );
 *        }
 *
 *         setup_my_filter ( client );
 *         result = sphinx_query ( client );
 *
 */

extern (C):

alias long	sphinx_int64_t;
alias ulong sphinx_uint64_t;
alias int sphinx_bool;

const SPH_TRUE	= 1;
const SPH_FALSE	= 0;

const	MAX_REQS = 64;


//	/ known searchd status codes
enum
{
	SEARCHD_OK				= 0,
	SEARCHD_ERROR			= 1,
	SEARCHD_RETRY			= 2,
	SEARCHD_WARNING			= 3
};

//	/ known match modes
enum
{
	SPH_MATCH_ALL			= 0,
	SPH_MATCH_ANY			= 1,
	SPH_MATCH_PHRASE		= 2,
	SPH_MATCH_BOOLEAN		= 3,
	SPH_MATCH_EXTENDED		= 4,
	SPH_MATCH_FULLSCAN		= 5,
	SPH_MATCH_EXTENDED2		= 6
};

//	/ known ranking modes (ext2 only)
enum
{
	SPH_RANK_PROXIMITY_BM25	= 0,
	SPH_RANK_BM25			= 1,
	SPH_RANK_NONE			= 2,
	SPH_RANK_WORDCOUNT		= 3
};

//	/ known sort modes
enum
{
	SPH_SORT_RELEVANCE		= 0,
	SPH_SORT_ATTR_DESC		= 1,
	SPH_SORT_ATTR_ASC		= 2,
	SPH_SORT_TIME_SEGMENTS	= 3,
	SPH_SORT_EXTENDED		= 4,
	SPH_SORT_EXPR			= 5
};

//	/ known filter types
enum
{	SPH_FILTER_VALUES		= 0,
	SPH_FILTER_RANGE		= 1,
	SPH_FILTER_FLOATRANGE	= 2
};

//	/ known attribute types
enum
{
	SPH_ATTR_INTEGER		= 1,
	SPH_ATTR_TIMESTAMP		= 2,
	SPH_ATTR_ORDINAL		= 3,
	SPH_ATTR_BOOL			= 4,
	SPH_ATTR_FLOAT			= 5,
	SPH_ATTR_MULTI			= 0x40000000UL
};

//	/ known grouping functions
enum
{	SPH_GROUPBY_DAY			= 0,
	SPH_GROUPBY_WEEK		= 1,
	SPH_GROUPBY_MONTH		= 2,
	SPH_GROUPBY_YEAR		= 3,
	SPH_GROUPBY_ATTR		= 4,
	SPH_GROUPBY_ATTRPAIR	= 5
};

struct sphinx_wordinfo
{
	const char*				word;
	int						docs;
	int						hits;
}

alias sphinx_wordinfo* st_sphinx_wordinfo;

struct sphinx_result
{
	const char*				error;
	const char*				warning;
	int						status;

	int						num_fields;
	char**					fields;

	int						num_attrs;
	char**					attr_names;
	int*					attr_types;

	int						num_matches;
	void *					values_pool;

	int						total;
	int						total_found;
	int						time_msec;
	int						num_words;
	sphinx_wordinfo			words;
}

alias sphinx_result* st_sphinx_result;

struct sphinx_excerpt_options
{
	const char *			before_match;
	const char *			after_match;
	const char *			chunk_separator;

	int						limit;
	int						around;

	bool					exact_phrase;
	bool					single_passage;
	bool					use_boundaries;
	bool					weight_order;
}

alias sphinx_excerpt_options* st_sphinx_excerpt_options;


struct sphinx_keyword_info
{
	char *					tokenized;
	char *					normalized;
	int						num_docs;
	int						num_hits;
}

alias sphinx_keyword_info* st_sphinx_keyword_info;

struct st_filter
{
	char *					attr;
	int                     filter_type;
	int                     num_values;
	sphinx_uint64_t *       values;
	sphinx_uint64_t         umin;
	sphinx_uint64_t         umax;
	float                   fmin;
	float                   fmax;
	int                     exclude;
}

struct sphinx_client
{
	ushort                  ver_search;                     ///< compatibility mode
	sphinx_bool             copy_args;                      ///< whether to create a copy of each passed argument
	void*                   head_alloc;                     ///< head of client-owned allocations list

	char *                  error;                          ///< last error
	char *                  warning;                        ///< last warning
	char                    local_error_buf[256];   		///< buffer to store 'local' error messages (eg. connect() error)

	char *                  host;
	int                     port;
	float                   timeout;
	int                     offset;
	int                     limit;
	int                     mode;
	int                     num_weights;
	int *                   weights;
	int                     sort;
	char *                  sortby;
	sphinx_uint64_t         minid;
	sphinx_uint64_t         maxid;
	char *                  group_by;
	int                     group_func;
	char *                  group_sort;
	char *                  group_distinct;
	int                     max_matches;
	int                     cutoff;
	int                     retry_count;
	int                     retry_delay;
	char *                  geoanchor_attr_lat;
	char *                  geoanchor_attr_long;
	float                   geoanchor_lat;
	float                   geoanchor_long;
	int                     num_filters;
	int                     max_filters;
	st_filter *             filters;
	int                     num_index_weights;
	char **                 index_weights_names;
	int *                   index_weights_values;
	int                     ranker;
	int                     max_query_time;
	int                     num_field_weights;
	char **                 field_weights_names;
	int *                   field_weights_values;

	int                     num_reqs = 0;
	int                     req_lens [ MAX_REQS ];
	char *                  reqs [ MAX_REQS ];

	int                     response_len;
	char *                  response_buf;   ///< where the buffer begins (might also contain heading warning)
	char *                  response_start; ///< where the data to parse starts

	int                     num_results;
	sphinx_result           results [ MAX_REQS ];
}

alias sphinx_client* st_sphinx_client;


sphinx_client				sphinx_create   ( sphinx_bool copy_args );

void						sphinx_destroy	( sphinx_client* client );

char*						sphinx_error	( sphinx_client* client );
char*						sphinx_warning	( sphinx_client* client );

sphinx_bool					sphinx_set_server				( sphinx_client* client, char* host, int port );
sphinx_bool					sphinx_set_connect_timeout		( sphinx_client* client, float seconds );

sphinx_bool					sphinx_set_limits				( sphinx_client* client, int offset, int limit, int max_matches, int cutoff );
sphinx_bool					sphinx_set_max_query_time		( sphinx_client* client, int max_query_time );
sphinx_bool					sphinx_set_match_mode			( sphinx_client* client, int mode );
sphinx_bool					sphinx_set_ranking_mode			( sphinx_client* client, int ranker );
sphinx_bool					sphinx_set_sort_mode			( sphinx_client* client, int mode, char* sortby );
sphinx_bool					sphinx_set_field_weights		( sphinx_client* client, int num_weights, char** field_names, int* field_weights );
sphinx_bool					sphinx_set_index_weights		( sphinx_client* client, int num_weights, char** index_names, int* index_weights );

sphinx_bool					sphinx_set_id_range				( sphinx_client* client, sphinx_uint64_t minid, sphinx_uint64_t maxid );
sphinx_bool					sphinx_add_filter				( sphinx_client* client, char* attr, int num_values, sphinx_int64_t* values, sphinx_bool exclude );
sphinx_bool					sphinx_add_filter_range			( sphinx_client* client, char* attr, sphinx_int64_t umin, sphinx_int64_t umax, sphinx_bool exclude );
sphinx_bool					sphinx_add_filter_float_range	( sphinx_client* client, char* attr, float fmin, float fmax, sphinx_bool exclude );
sphinx_bool					sphinx_set_geoanchor			( sphinx_client* client, char* attr_latitude, char* attr_longitude, float latitude, float longitude );
sphinx_bool					sphinx_set_groupby				( sphinx_client* client, char* attr, int groupby_func, char* group_sort );
sphinx_bool					sphinx_set_groupby_distinct		( sphinx_client* client, char* attr );
sphinx_bool					sphinx_set_retries				( sphinx_client* client, int count, int delay );
sphinx_bool                 sphinx_add_override             ( sphinx_client* client, char* attr, sphinx_uint64_t* docids, int num_values, uint* values );
sphinx_bool                 sphinx_set_select               ( sphinx_client* client, char* select_list );

void						sphinx_reset_filters			( sphinx_client* client );
void						sphinx_reset_groupby			( sphinx_client* client );
sphinx_result*				sphinx_query					( sphinx_client* client, char* query, char* index_list, char* comment );
int							sphinx_add_query				( sphinx_client* client, char* query, char* index_list, char* comment );
sphinx_result*				sphinx_run_queries				( sphinx_client* client );

int							sphinx_get_num_results			( sphinx_client* client );
sphinx_uint64_t				sphinx_get_id					( sphinx_result* result, int match );
int							sphinx_get_weight				( sphinx_result* result, int match );
sphinx_int64_t				sphinx_get_int					( sphinx_result* result, int match, int attr );
float						sphinx_get_float				( sphinx_result* result, int match, int attr );
uint*						sphinx_get_mva					( sphinx_result* result, int match, int attr );

void						sphinx_init_excerpt_options		( sphinx_excerpt_options* opts );
char**						sphinx_build_excerpts			( sphinx_client* client, int num_docs, char** docs, char* index, char* words, sphinx_excerpt_options* opts );
int							sphinx_update_attributes		( sphinx_client* client, char* index, int num_attrs, char** attrs, int num_docs, sphinx_uint64_t* docids, sphinx_int64_t* values );
sphinx_keyword_info*		sphinx_build_keywords			( sphinx_client* client, char* query, char* index, int max_query_words, sphinx_bool hits, int* out_num_keywords );

