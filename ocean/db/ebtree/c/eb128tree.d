module ocean.db.ebtree.c.eb128tree;

private import ocean.db.ebtree.c.ebtree: eb_root, eb_node;

/******************************************************************************

    ucent emulator struct

 ******************************************************************************/

struct UCent
{
    /**************************************************************************

        lo contains the lower, hi the higher 64 bits of the ucent value.
    
     **************************************************************************/
    
    ulong lo, hi;
    
    /**************************************************************************

        Compares this instance to other in the same way as the libebtree does.
        
        Params:
            other = instance to compare against this
            
        Returns:
            
    
     **************************************************************************/
    
    int opCmp ( typeof (this) other )
    {
        return eb128_cmp_264((*this).tupleof, (*other).tupleof);
    }
}

struct Cent
{
    ulong lo;
    long  hi;
    
    int opCmp ( typeof (this) other )
    {
        return eb128i_cmp_264((*this).tupleof, (*other).tupleof);
    }
}

/* This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 */
struct eb128_node
{
    eb_node node; /* the tree node, must be at the beginning */
    private ubyte[0x10] key_;
    
    template UC ( bool signed )
    {
        static if (signed)
        {
            alias Cent UC;
        }
        else
        {
            alias UCent UC;
        }
    }
    
    UCent key ( ) ( UCent key_ )
    {
        eb128_node_setkey_264(this, key_.lo, key_.hi);
        
        return key_;
    }
    
    Cent key ( ) ( Cent key_ )
    {
        eb128i_node_setkey_264(this, key_.lo, key_.hi);
        
        return key_;
    }
    
    UC!(signed) key ( bool signed = false ) ( )
    {
        static if (signed)
        {
            Cent result;
            
            eb128i_node_getkey_264(this, &result.lo, &result.hi);
        }
        else
        {
            UCent result;
            
            eb128_node_getkey_264(this, &result.lo, &result.hi);
        }
        
        return result;
    }
    
    typeof (this) next ( )
    {
        return eb128_next(this);
    }
    
    typeof (this) prev ( )
    {
        return eb128_prev(this);
    }
    
    typeof (this) next_unique ( )
    {
        return eb128_next_unique(this);
    }
    
    typeof (this) prev_unique ( )
    {
        return eb128_prev_unique(this);
    }
}

extern (C):

/* Return leftmost node in the tree, or NULL if none */
eb128_node* eb128_first(eb_root* root);

/* Return rightmost node in the tree, or NULL if none */
eb128_node* eb128_last(eb_root* root);

/* Return next node in the tree, or NULL if none */
eb128_node* eb128_next(eb128_node* eb128);

/* Return previous node in the tree, or NULL if none */
eb128_node* eb128_prev(eb128_node* eb128);

/* Return next node in the tree, skipping duplicates, or NULL if none */
eb128_node* eb128_next_unique(eb128_node* eb128);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
eb128_node* eb128_prev_unique(eb128_node* eb128);

/* Delete node from the tree if it was linked in. Mark the node unused. */
void eb128_delete(eb128_node* eb128);

/*
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
eb128_node* eb128_lookup_264 ( eb_root* root, ulong lo, ulong hi );

/*
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */
eb128_node* eb128i_lookup_264 ( eb_root* root, ulong lo, long hi );

/*
 * Find the last occurrence of the highest key in the tree <root>, which is
 * equal to or less than <x>. NULL is returned is no key matches.
 */
eb128_node* eb128_lookup_le_264 ( eb_root* root, ulong lo, ulong hi );

/*
 * Find the first occurrence of the lowest key in the tree <root>, which is
 * equal to or greater than <x>. NULL is returned is no key matches.
 */
eb128_node* eb128_lookup_ge_264 ( eb_root* root, ulong lo, ulong hi );

/* Insert eb128_node <neww> into subtree starting at node root <root>.
 * Only neww->key needs be set with the key. The eb128_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb128_node* eb128_insert ( eb_root* root, eb128_node* neww );

/* Insert eb128_node <neww> into subtree starting at node root <root>, using
 * signed keys. Only neww->key needs be set with the key. The eb128_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb128_node* eb128i_insert ( eb_root* root, eb128_node* neww );

/******************************************************************************

    Tells whether a is less than b. a and b are uint128_t values composed from
    alo and ahi or blo and bhi, respectively.
    
    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b
    
    Returns:
        true if a < b or false otherwise.

 ******************************************************************************/

bool eb128_less_264 ( ulong alo, ulong ahi, ulong blo, ulong bhi );

/******************************************************************************

    Tells whether a is less than or equal to b. a and b are uint128_t values
    composed from alo and ahi or blo and bhi, respectively.
    
    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b
    
    Returns:
        true if a <= b or false otherwise.

 ******************************************************************************/

bool eb128_less_or_equal_264 ( ulong alo, ulong ahi, ulong blo, ulong bhi );

/******************************************************************************

    Tells whether a is equal to b. a and b are uint128_t values
    composed from alo and ahi or blo and bhi, respectively.
    
    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b
    
    Returns:
        true if a == b or false otherwise.

 ******************************************************************************/

bool eb128_equal_264 ( ulong alo, ulong ahi, ulong blo, ulong bhi );

/******************************************************************************

    Tells whether a is greater than or equal to b. a and b are uint128_t values
    composed from alo and ahi or blo and bhi, respectively.
    
    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b
    
    Returns:
        true if a >= b or false otherwise.

 ******************************************************************************/

bool eb128_greater_or_equal_264 ( ulong alo, ulong ahi, ulong blo, ulong bhi );

/******************************************************************************

    Tells whether a is greater than b. a and b are uint128_t values
    composed from alo and ahi or blo and bhi, respectively.
    
    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b
    
    Returns:
        true if a <= b or false otherwise.

 ******************************************************************************/

bool eb128_greater_264 ( ulong alo, ulong ahi, ulong blo, ulong bhi );

/******************************************************************************

    Compares a and b in a qsort callback/D opCmp fashion. a and b are uint128_t
    values composed from alo and ahi or blo and bhi, respectively.
    
    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b
    
    Returns:
        a value less than 0 if a < b,
        a value greater than 0 if a > b
        or 0 if a == b.

 ******************************************************************************/

int  eb128_cmp_264 ( ulong alo, ulong ahi, ulong blo, ulong bhi );

/******************************************************************************

    Tells whether a is less than b. a and b are int128_t values composed from
    alo and ahi or blo and bhi, respectively.
    
    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b
    
    Returns:
        true if a < b or false otherwise.

 ******************************************************************************/

bool eb128i_less_264 ( ulong alo, long  ahi, ulong blo, long  bhi );

/******************************************************************************

    Tells whether a is less than or equal to b. a and b are int128_t values
    composed from alo and ahi or blo and bhi, respectively.
    
    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b
    
    Returns:
        true if a <= b or false otherwise.

 ******************************************************************************/

bool eb128i_less_or_equal_264 ( ulong alo, long  ahi, ulong blo, long  bhi );

/******************************************************************************

    Tells whether a is equal to b. a and b are int128_t values composed from
    alo and ahi or blo and bhi, respectively.
    
    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b
    
    Returns:
        true if a == b or false otherwise.

 ******************************************************************************/

bool eb128i_equal_264 ( ulong alo, long  ahi, ulong blo, long  bhi );

/******************************************************************************

    Tells whether a is greater or equal to than b. a and b are int128_t values
    composed from alo and ahi or blo and bhi, respectively.
    
    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b
    
    Returns:
        true if a >= b or false otherwise.

 ******************************************************************************/

bool eb128i_greater_or_equal_264 ( ulong alo, long  ahi, ulong blo, long  bhi );

/******************************************************************************

    Tells whether a is greater than b. a and b are int128_t values composed from
    alo and ahi or blo and bhi, respectively.
    
    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b
    
    Returns:
        true if a > b or false otherwise.

 ******************************************************************************/

bool eb128i_greater_264 ( ulong alo, long  ahi, ulong blo, long  bhi);

/******************************************************************************

    Compares a and b in a qsort callback/D opCmp fashion. a and b are int128_t
    values composed from alo and ahi or blo and bhi, respectively.
    
    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b
    
    Returns:
        a value less than 0 if a < b,
        a value greater than 0 if a > b
        or 0 if a == b.

 ******************************************************************************/

int  eb128i_cmp_264 ( ulong alo, long  ahi, ulong blo, long  bhi );

/******************************************************************************

    Sets node->key to an uint128_t value composed from lo and hi.
    
    Params:
        node = node to set the key
        lo   = value of the lower 64 value bits of node->key
        hi   = value of the higher 64 value bits of node->key
    
    Returns:
        node

 ******************************************************************************/

eb128_node* eb128_node_setkey_264 ( eb128_node* node, ulong lo, ulong hi );

/******************************************************************************

    Sets node->key to an int128_t value composed from lo and hi.
    
    Params:
        node = node to set the key
        lo   = value of the lower 64 value bits of node->key
        hi   = value of the higher 64 value bits of node->key
    
    Returns:
        node

 ******************************************************************************/

eb128_node* eb128i_node_setkey_264 ( eb128_node* node, long lo, ulong hi );

/******************************************************************************
    
    Obtains node->key,and decomposes it into two uint64_t values. This assumes
    that the key was originally unsigned, e.g. set by eb128_node_setkey_264().
    
    Params:
        node = node to obtain the key
        lo   = output of the value of the lower 64 value bits of node->key
        hi   = output of the value of the higher 64 value bits of node->key

 ******************************************************************************/

void eb128_node_getkey_264 ( eb128_node* node, ulong* lo, ulong* hi );

/******************************************************************************

    Obtains node->key,and decomposes it into an int64_t and an uint64_t value.
    This assumes that the key was originally signed, e.g. set by
    eb128i_node_setkey_264().
    
    Params:
        node = node to obtain the key
        lo   = output of the value of the lower 64 value bits of node->key
        hi   = output of the value of the higher 64 value bits of node->key

******************************************************************************/

void eb128i_node_getkey_264 ( eb128_node* node, ulong* lo, long* hi );
