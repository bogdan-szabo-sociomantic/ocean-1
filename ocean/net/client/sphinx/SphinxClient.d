/*******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Jan 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        D Client for Sphinx a opensource SQL full-text search engine.

        This class provides bindings for the libsphinxclient library for Sphinx.
        Be aware that you have to pass the D parser the path to the
        libsphinxclient. If you use DSSS you have to add the buildfalgs option
        to your dsss.conf e.g.

        buildflags=-L/usr/lib/libsphinxclient.so

		You need to make sure that the libsphinxclient.so is located in /usr/lib.
		Furthermore you need to apply the sphinx client patch
		from ocean/util/c/sphinx.patch.txt file to the sphinx source package as
		long as the patch is not part of the official sphinx package.
		You'll more information about this issue at

		http://www.sphinxsearch.com/bugs/view.php?id=228

        --

        Usage example:

			SphinxClient sphinx = new SphinxClient("localhost", 3312);

			char[] query = "Blogosphere";

			if ( sphinx.search(query) ){
				foreach(id; sphinx.getResults()) {
					// ... do something with id
			}

				foreach(weight; sphinx.getWeights()) {
					// ... do something with weight
				}
			}

			sphinx.close;

        --

		Related

		Based on Sphinx PHP API by Andrew Aksyonoff <shodan at shodan.ru>
 		http://www.sphinxsearch.com/docs


*******************************************************************************/

module ocean.net.client.sphinx.SphinxClient;

public  import ocean.core.Exception: SphinxException;

private import ocean.net.client.c.sphinxclient;

private import tango.stdc.stringz : toDString = fromStringz, toCString = toStringz;

private import tango.text.Unicode : toLowerCase = toLower;

private import tango.text.Util : delimit, containsPattern;


/*******************************************************************************

@author  	Thomas Nicolai <thomas.nicolai () sociomantic () com>
@author  	Lars Kirchhoff <lars.kirchhoff () sociomantic () com>
@package 	ocean
@link    	http://www.sociomantic.com

*******************************************************************************/

class SphinxClient
{

	/**
	 * Pointer to sphinx client
	 */
	private sphinx_client* client;

	/**
	 * Pointer to result object
	 */
	private sphinx_result* result_list;

	/**
	 * Pointer to keywords result object
	 */
	private sphinx_keyword_info* keyword_list;

	/**
	 * Sphinx match modes
	 */
	public enum MATCH
	{
		ALL			= 0,
		ANY			= 1,
		PHRASE		= 2,
		BOOLEAN		= 3,
		EXTENDED	= 4,
		FULLSCAN	= 5,
		EXTENDED2	= 6
	}

	/**
	 * Sphinx ranking modes
	 */
	enum RANK
	{
		PROXIMITY_BM25	= 0,
		BM25			= 1,
		NONE			= 2,
		WORDCOUNT		= 3
	}

	/**
	 * Sphinx sort modes
	 */
	enum SORT
	{
		RELEVANCE		= 0,
		ATTR_DESC		= 1,
		ATTR_ASC		= 2,
		TIME_SEGMENTS	= 3,
		EXTENDED		= 4,
		EXPR			= 5
	}

	/**
	 * Minimum word length (also depends in the settings in sphinx.conf)
	 */
	const MIN_WORD_LGT = 4;


	/**
	 * Initializes sphinx client and set basic parameters
	 *
	 * Function creates a sphinx client object reference and sets the
	 * server and port where the Sphinx searchd runs on. Furthermore
	 * initial parameters like the match mode are set
	 *
	 * Params:
	 *     server = IP address or DNS name
	 *     port = Server port
	 */
	this(char[] server = "localhost", int port = 3312)
	{
		// if copy_args is true, API will create and manage a copy of every
		// string and array passed to it. This causes additional malloc() pressure
		int copy_args = 1;

		this.client = &sphinx_create(copy_args);

		if ( !sphinx_set_server(this.client, toCString(server), port) )
			SphinxException("Critial Error: " ~ toDString(sphinx_error(this.client)));

		if ( !sphinx_set_match_mode(this.client, SPH_MATCH_EXTENDED2) )
			SphinxException("Critical Error: " ~ toDString(sphinx_error(this.client)));
	}



	/**
	 * Set connection timeout
	 *
	 * Params:
	 *     sec = timeout in seconds
	 */
	public void setConnectionTimeout(float sec)
	{
		sphinx_set_connect_timeout(this.client, sec);
	}



	/**
	 * Sets maximum search query time (default = 0)
	 *
	 * Default value is no limit.
	 *
	 * Params:
	 *     ms = maximum query time in milliseconds.
	 */
	public void setMaxQueryTime(int ms)
	{
		if (ms < 0 )
			SphinxException("Error: Search query time limit can't be negative");

		sphinx_set_max_query_time(this.client, ms);
	}



	/**
	 * Set offset and limit of the result set
	 *
	 * Params:
	 *     offset = result set offset
	 *     limit = amount of matches to return
	 *     max = controls how much matches searchd will keep in RAM while searching
	 *     cutoff = used for advanced performance control. It tells searchd to
	 *     			forcibly stop search query once cutoff  matches have been found
	 *     			and processed.
	 */
	public void setLimits(int offset, int limit, int max = 0, int cutoff = 0)
	{
		sphinx_set_limits(this.client, offset, limit, max, cutoff);

		if ( toDString(sphinx_error(this.client)).length > 0 )
			SphinxException("Error: " ~ toDString(sphinx_error(this.client)));
	}



	/**
	 * Set full-text query matching mode
	 *
	 * To set the matching mode you can use the following constants:
	 *
	 * ALL		= Match all query words (default mode)
	 * ANY		= Match any of query words
	 * PHRASE		= Match query as a phrase, requiring perfect match
	 * BOOLEAN 	= Match query as a boolean expression
	 * EXTENDED 	= Match query as an expression in Sphinx internal query language
	 * FULLSCAN 	= Enables fullscan
	 * EXTENDED2 	= The same as SPH_MATCH_EXTENDED plus ranking and quorum searching support
	 *
	 * ---
	 *
	 * Usage Example
	 *
	 * 	SphinxClient sphinx = new SphinxClient("localhost", 3312);
	 *  sphinx.setMatchMode(SphinxClient.MATCH.ALL);
	 *  ...
	 * ---
	 *
	 * Params:
	 *     mode = matching mode
	 */
	public void setMatchMode(int mode)
	{
		sphinx_set_match_mode(this.client, mode);
	}



	/**
	 * Set matches sorting mode
	 *
	 * To set the sorting mode you can use the following constants:
	 *
	 * RELEVANCE  		= Sort by relevance in descending order (best matches first)
	 * ATTR_DESC 		= Sort by an attribute in descending order (bigger attribute values first)
	 * ATTR_ASC 		= Sort by an attribute in ascending order (smaller attribute values first)
	 * TIME_SEGMENTS 	= Sort by time segments (last hour/day/week/month) in descending order
	 * EXTENDED 		= Sort by SQL-like combination of columns in ASC/DESC order
	 * EXPR 			= Sort by an arithmetic expression
	 *
	 * ---
	 *
	 * Usage Example
	 *
	 * 	SphinxClient sphinx = new SphinxClient("localhost", 3312);
	 *  sphinx.setMatchMode(SphinxClient.SORT.RELEVANCE);
	 *  ...
	 * ---
	 *
	 * Params:
	 *     mode = sorting mode
	 */
	public void setSortMode(int mode)
	{
		char sortby;		// dont know what this char pointer is for

		sphinx_set_sort_mode(this.client, mode, &sortby );
	}



	/**
	 * Set ranking mode (default = BM25 with proximity)
	 *
	 * To set the sorting mode you can use the following constants:
	 *
	 * PROXIMITY_BM25	= Default ranking mode which uses both proximity and BM25 ranking
	 * BM25				= Statistical ranking mode which uses BM25 ranking only (similar
	 * 				  	  to most of other full-text engines). This mode is faster, but may
	 * 					  result in worse quality on queries which contain more than 1
	 * 					  keyword.
	 * NONE				= Disables ranking. This mode is the fastest. It is essentially
	 * 					  equivalent to boolean searching, a weight of 1 is assigned to all
	 * 					  matches.
	 * WORDCOUNT		= Ranking by wordcount
	 * ---
	 *
	 * Usage Example
	 *
	 * 	SphinxClient sphinx = new SphinxClient("localhost", 3312);
	 *  sphinx.setRankingMode(SphinxClient.RANK.BM25);
	 *  ...
	 * ---
	 *
	 * Params:
	 *     mode = ranking mode
	 */
	public void setRankingMode(int mode)
	{
		sphinx_set_ranking_mode(this.client, mode);
	}



	/**
	 * Performs a single query search and returns the number of documents found
	 *
	 * Params:
	 *     query = query term
	 *     index = search index (default = all)
	 *
	 * Returns: Number of documents found
	 */
	public int query(char[] query, char[] index = "*")
	{
		if ( query.length == 0 )
			SphinxException("Error: no query term given");

		this.result_list = sphinx_query(this.client, toCString(query),
			toCString(index), toCString(""));

		if ( toDString(sphinx_error(this.client)).length > 0 )
			SphinxException("Critical Error: " ~ toDString(sphinx_error(this.client)));

		return this.result_list.total_found;
	}



	/**
	 * Returns the result of the last search
	 *
	 * Returns: Array of document ids
	 */
	public uint[uint] getResults()
	{
		uint[uint] documents;

		for(uint i = 0; i < this.result_list.num_matches; i++)
			documents[i] = sphinx_get_id(this.result_list, i);

		return documents;
	}



	/**
	 * Returns the weight scores of the documents
	 *
	 * Returns: Array of weight scores
	 */
	public uint[uint] getWeights()
	{
		uint[uint] weights;

		for(uint i = 0; i < this.result_list.num_matches; i++)
			weights[i] = sphinx_get_weight(this.result_list, i);

		return weights;
	}



	/**
	 * Returns the keyword occurences in the search index of the given query
	 *
	 * Extracts keywords from query using tokenizer settings for the given index
	 * and returns per-keyword occurrence statistics.
	 *
	 * ---
	 *
	 * Usage Example
	 *
	 * 	SphinxClient sphinx = new SphinxClient("localhost", 3312);
	 *
	 * 	auto keywords = sphinx.getKeywords("a discussion about the blogosphere", "test1");
	 *
	 *  foreach(key,value; keywords) {
	 * 		Stdout.formatln("key = {}; value = {}", key, value);
	 *	}
	 *
	 * ---
	 *
	 * Params:
	 *     query = search query to extract keywords from
	 *     index = name of index to get keyword statistics from
	 *     max_words = maximum query words analysed and returned
	 *
	 * Returns: array of keyword occurences with the keywords as index
	 * 			and the the number of hits as values (keywords => num_hits)
	 */
	public uint[char[]] getKeywords(char[] query, char[] index, int max_words = 10)
	{
		int hits = 1;		// enable/disable keyword statistics generation
		int num;		    // number of returned keywords

		uint[char[]] klist;

		query = this.normalizeQuery(query);

		this.keyword_list = sphinx_build_keywords(this.client, toCString(query),
			toCString(index), max_words, hits, &num);

		if ( toDString(sphinx_error(this.client)).length > 0 )
			SphinxException("Critical Error: " ~ toDString(sphinx_error(this.client)));

		for(int i = 0; i <num; i++)
			klist[toDString(this.keyword_list[i].tokenized)] = this.keyword_list[i].num_hits;

		return klist;
	}



	/**
	 * Returns the last error message
	 *
	 * If there were no errors during the previous API call an empty string
	 * is returned instead.
	 *
	 * Returns: string with the last error message.
	 */
	public char[] getLastErrorMsg()
	{
		return toDString(sphinx_error(this.client));
	}



	/**
	 * Returns last warning messages
	 *
	 * If there was no warning during the previous API call an empty string
	 * is returned instead.
	 *
	 * Returns: string with the last error message.
	 */
	public char[] getLastWarningMsg()
	{
		return toDString(sphinx_warning(this.client));
	}



	/**
	 * Closes the sphinx client resources
	 */
	public void close()
	{
		sphinx_destroy(this.client);
	}



	/**
	 * Returns normalized query
	 *
	 * Functions removed all double entries of keywords in the given
	 * search query.
	 *
	 * Params:
	 *     query = normalized search query
	 * Returns:
	 */
	private char[] normalizeQuery(char[] query)
	{
		char[] normalizedQuery;

		foreach (word; delimit (toLowerCase(query), " "))
			if ( !containsPattern (normalizedQuery, word) && word.length >  MIN_WORD_LGT)
				normalizedQuery = normalizedQuery ~ " " ~ word;

		return normalizedQuery;
	}

} // class SphinxClient
