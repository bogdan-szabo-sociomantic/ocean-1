/*
 * Elastic Binary Trees - macros and structures for operations on 32bit nodes.
 * Version 6.0
 * (C) 2002-2010 - Willy Tarreau <w@1wt.eu>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

module ocean.db.ebtree.c.ebnode;

private import ocean.db.ebtree.c.ebtree;

/* This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 */
struct ebT_node ( T )
{
    eb_node node; /* the tree node, must be at the beginning */
    T key;
    
    alias typeof (this) This;
    
    static if ( T.sizeof == 4 )
    {
        alias Node32Ptr NodePtr;
        alias int CType;
        alias uint UCType;
        
        /* Return leftmost node in the tree, or NULL if none */
        alias .eb32_first first;
    
        /* Return rightmost node in the tree, or NULL if none */
        alias .eb32_last last;
        
        /*
         * Find the first occurence of a key in the tree <root>. If none can be
         * found, return NULL.
         */
        alias .eb32_lookup clookup;
    
        /*
         * Find the first occurence of a signed key in the tree <root>. If none can
         * be found, return NULL.
         */
        alias .eb32i_lookup clookup;
    
        public alias eb32_node Node;
        private alias eb32_first cgetFirst;
        private alias eb32_last cgetLast;
        private alias eb32_lookup_le clookupLE;
        private alias eb32_lookup_ge clookupGE;
        private alias eb32_prev cprev;
        private alias eb32_next cnext;
        private alias eb32_next_unique cnext_unique;
        private alias eb32_prev_unique cprev_unique;
        private alias eb32_insert cinsert;
        private alias eb32i_insert ciinsert;  
        private alias eb32_delete cdelete;
    }
    else static if ( T.sizeof == 8 )
    {
        alias Node64Ptr NodePtr;
        alias long CType;
        alias ulong UCType;
        
        /* Return leftmost node in the tree, or NULL if none */
        alias .eb64_first first;
    
        /* Return rightmost node in the tree, or NULL if none */
        alias .eb64_last last;
                
        /*
         * Find the first occurence of a key in the tree <root>. If none can be
         * found, return NULL.
         */
        alias .eb64_lookup clookup;
    
        /*
         * Find the first occurence of a signed key in the tree <root>. If none can
         * be found, return NULL.
         */
        alias .eb64i_lookup clookup;
        
        private alias eb64_first cgetFirst;
        private alias eb64_last cgetLast;
        private alias eb64_lookup_le clookupLE;
        private alias eb64_lookup_ge clookupGE;
        private alias eb64_prev cprev;
        private alias eb64_next cnext;
        private alias eb64_next_unique cnext_unique;
        private alias eb64_prev_unique cprev_unique;
        private alias eb64_insert cinsert;
        private alias eb64i_insert ciinsert;    
        private alias eb64_delete cdelete;    
    }
    else static if ( T.sizeof == 16 )
    {
        alias Node128Ptr NodePtr;        
        alias Cent CType;       
        alias UCent UCType;
        
        /* Return leftmost node in the tree, or NULL if none */
        alias .eb128_first first;
    
        /* Return rightmost node in the tree, or NULL if none */
        alias .eb128_last last;
                            
        /*
         * Find the first occurence of a key in the tree <root>. If none can be
         * found, return NULL.
         */
        alias .eb128_lookup clookup;
    
        /*
         * Find the first occurence of a signed key in the tree <root>. If none can
         * be found, return NULL.
         */
        alias .eb128i_lookup clookup;
            
        private alias eb128_first cgetFirst;
        private alias eb128_last cgetLast;
        private alias eb128_lookup_le clookupLE;
        private alias eb128_lookup_ge clookupGE;
        private alias eb128_prev cprev;
        private alias eb128_next cnext;
        private alias eb128_next_unique cnext_unique;
        private alias eb128_prev_unique cprev_unique;
        private alias eb128_insert cinsert;
        private alias eb128i_insert ciinsert;       
        private alias eb128_delete cdelete;  
    }    
    else
    {
        public alias bool Node;
        static assert(false, typeof(this).stringof ~ ": internal type must be either a 32-, 64-bit or 128-bit type, not " ~ T.stringof);
    } 
    
    /* Return next node in the tree, or NULL if none */
    This next ( )
    {
        return cast(This) cnext(cast(NodePtr)this);
    }

    /* Return previous node in the tree, or NULL if none */
    This prev ( )
    {
        return cast(This) cprev(cast(NodePtr)this);
    }

    /* Return next node in the tree, skipping duplicates, or NULL if none */
    This next_unique ( )
    {
        return cast(This) cnext_unique(cast(NodePtr) this);
    }

    /* Return previous node in the tree, skipping duplicates, or NULL if none */
    This prev_unique ( )
    {
        return cast(This) cprev_unique(cast(NodePtr)this);
    }

    /* Delete node from the tree if it was linked in. Mark the node unused. Note
     * that this function relies on a non-inlined generic function: eb_delete.
     */
    void remove ( )
    {
        cdelete(cast(NodePtr)this);
    }

    static This lookupLE ( eb_root* root, T key )
    {
        return cast(This) clookupLE(root, *cast(UCType*)&key);
    }

    static This lookupGE ( eb_root* root, T key )
    {
        return cast(This) clookupGE(root, *cast(UCType*)&key);
    }  

    static This getFirst ( eb_root* root )
    {
        return cast(This) cgetFirst(root);
    }   

    static This getLast ( eb_root* root )
    {
        return cast(This) cgetLast(root);
    } 

    static This lookup ( eb_root* root, T key )
    {
        return cast(This) clookup(root, *cast(UCType*)&key);
    }     

    /* Insert eb32_node <new> into subtree starting at node root <root>.
     * Only new->key needs be set with the key. The eb32_node is returned.
     * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
     */
    This insert ( eb_root* root )
    {
        return cast(This) cinsert(root, cast(NodePtr) this);
    }

    /* Insert eb32_node <new> into subtree starting at node root <root>, using
     * signed keys. Only new->key needs be set with the key. The eb32_node
     * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
     */
    This insert_signed ( eb_root* root )
    {
        return cast(This) ciinsert(root, cast(NodePtr)this);
    }
}

/*
 * Exported functions and macros.
 * Many of them are always inlined because they are extremely small, and
 * are generally called at most once or twice in a program.
 */

extern (C):
    
typedef void* Node32Ptr;

/* Return leftmost node in the tree, or NULL if none */
Node32Ptr eb32_first(eb_root* root);

/* Return rightmost node in the tree, or NULL if none */
Node32Ptr eb32_last(eb_root* root);

/* Return next node in the tree, or NULL if none */
Node32Ptr eb32_next(Node32Ptr eb32);

/* Return previous node in the tree, or NULL if none */
Node32Ptr eb32_prev(Node32Ptr eb32);

/* Return next node in the tree, skipping duplicates, or NULL if none */
Node32Ptr eb32_next_unique(Node32Ptr eb32);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
Node32Ptr eb32_prev_unique(Node32Ptr eb32);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
void eb32_delete(Node32Ptr eb32);

/*
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
Node32Ptr eb32_lookup(eb_root* root, uint x);

/*
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */
Node32Ptr eb32i_lookup(eb_root* root, int x);

/*
 * Find the last occurrence of the highest key in the tree <root>, which is
 * equal to or less than <x>. NULL is returned is no key matches.
 */
Node32Ptr eb32_lookup_le(eb_root* root, uint x);

/*
 * Find the first occurrence of the lowest key in the tree <root>, which is
 * equal to or greater than <x>. NULL is returned is no key matches.
 */
Node32Ptr eb32_lookup_ge(eb_root* root, uint x);

/* Insert eb32_node <new> into subtree starting at node root <root>.
 * Only new->key needs be set with the key. The eb32_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
Node32Ptr eb32_insert(eb_root* root, Node32Ptr neww);

/* Insert eb32_node <new> into subtree starting at node root <root>, using
 * signed keys. Only new->key needs be set with the key. The eb32_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
Node32Ptr eb32i_insert(eb_root* root, Node32Ptr neww);


typedef void* Node64Ptr;
    
/* Return leftmost node in the tree, or NULL if none */
Node64Ptr eb64_first(eb_root* root);

/* Return rightmost node in the tree, or NULL if none */
Node64Ptr eb64_last(eb_root* root);

/* Return next node in the tree, or NULL if none */
Node64Ptr eb64_next(Node64Ptr eb64);

/* Return previous node in the tree, or NULL if none */
Node64Ptr eb64_prev(Node64Ptr eb64);

/* Return next node in the tree, skipping duplicates, or NULL if none */
Node64Ptr eb64_next_unique(Node64Ptr eb64);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
Node64Ptr eb64_prev_unique(Node64Ptr eb64);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
void eb64_delete(Node64Ptr eb64);

/*
 * The following functions are not inlined by default. They are declared
 * in eb64tree.c, which simply relies on their inline version.
 */
Node64Ptr eb64_lookup(eb_root* root, ulong x);
Node64Ptr eb64i_lookup(eb_root* root, long x);
Node64Ptr eb64_lookup_le(eb_root* root, ulong x);
Node64Ptr eb64_lookup_ge(eb_root* root, ulong x);
Node64Ptr eb64_insert(eb_root* root, Node64Ptr neww);
Node64Ptr eb64i_insert(eb_root* root, Node64Ptr neww);

/*
 * The following functions are less likely to be used directly, because their
 * code is larger. The non-inlined version is preferred.
 */

/* Delete node from the tree if it was linked in. Mark the node unused. */
void __eb64_delete(Node64Ptr eb64);

/*
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
Node64Ptr __eb64_lookup(eb_root* root, ulong x);

/*
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */
Node64Ptr __eb64i_lookup(eb_root* root, long x);

/* Insert eb64_node <neww> into subtree starting at node root <root>.
 * Only neww->key needs be set with the key. The eb64_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
Node64Ptr __eb64_insert(eb_root* root, Node64Ptr neww);

/* Insert eb64_node <neww> into subtree starting at node root <root>, using
 * signed keys. Only neww->key needs be set with the key. The eb64_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
Node64Ptr __eb64i_insert(eb_root* root, Node64Ptr neww);


typedef void* Node128Ptr;

struct Cent
{
    long a,b;
}

struct UCent
{
    long a,b;
}

/* Return leftmost node in the tree, or NULL if none */
Node128Ptr eb128_first(eb_root* root);

/* Return rightmost node in the tree, or NULL if none */
Node128Ptr eb128_last(eb_root* root);

/* Return next node in the tree, or NULL if none */
Node128Ptr eb128_next(Node128Ptr eb128);

/* Return previous node in the tree, or NULL if none */
Node128Ptr eb128_prev(Node128Ptr eb128);

/* Return next node in the tree, skipping duplicates, or NULL if none */
Node128Ptr eb128_next_unique(Node128Ptr eb128);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
Node128Ptr eb128_prev_unique(Node128Ptr eb128);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
void eb128_delete(Node128Ptr eb128);

/*
 * The following functions are not inlined by default. They are declared
 * in eb128tree.c, which simply relies on their inline version.
 */
Node128Ptr eb128_lookup(eb_root* root, UCent x);
Node128Ptr eb128i_lookup(eb_root* root, Cent x);
Node128Ptr eb128_lookup_le(eb_root* root, UCent x);
Node128Ptr eb128_lookup_ge(eb_root* root, UCent x);
Node128Ptr eb128_insert(eb_root* root, Node128Ptr neww);
Node128Ptr eb128i_insert(eb_root* root, Node128Ptr neww);

/*
 * The following functions are less likely to be used directly, because their
 * code is larger. The non-inlined version is preferred.
 */

/* Delete node from the tree if it was linked in. Mark the node unused. */
void __eb128_delete(Node128Ptr eb128);

/*
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
Node128Ptr __eb128_lookup(eb_root* root, UCent x);

/*
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */
Node128Ptr __eb128i_lookup(eb_root* root, Cent x);

/* Insert eb128_node <neww> into subtree starting at node root <root>.
 * Only neww->key needs be set with the key. The eb128_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
Node128Ptr __eb128_insert(eb_root* root, Node128Ptr neww);

/* Insert eb128_node <neww> into subtree starting at node root <root>, using
 * signed keys. Only neww->key needs be set with the key. The eb128_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
Node128Ptr __eb128i_insert(eb_root* root, Node128Ptr neww);