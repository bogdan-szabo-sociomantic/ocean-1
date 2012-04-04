module ocean.db.ebtree.c.eb32tree;

private import ocean.db.ebtree.c.ebtree: eb_root, eb_node;

/*
 * Exported functions and macros.
 * Many of them are always inlined because they are extremely small, and
 * are generally called at most once or twice in a program.
 */

/* This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 */
struct eb32_node
{
    eb_node  node; /* the tree node, must be at the beginning */
    uint     key;
    
    typeof (this) next ( )
    {
        return eb32_next(this);
    }
    
    typeof (this) prev ( )
    {
        return eb32_prev(this);
    }
    
    typeof (this) next_unique ( )
    {
        return eb32_next_unique(this);
    }
    
    typeof (this) prev_unique ( )
    {
        return eb32_prev_unique(this);
    }
}

extern (C):
    
/* Return leftmost node in the tree, or NULL if none */
eb32_node* eb32_first(eb_root* root);

/* Return rightmost node in the tree, or NULL if none */
eb32_node* eb32_last(eb_root* root);

/* Return next node in the tree, or NULL if none */
eb32_node* eb32_next(eb32_node* eb32);

/* Return previous node in the tree, or NULL if none */
eb32_node* eb32_prev(eb32_node* eb32);

/* Return next node in the tree, skipping duplicates, or NULL if none */
eb32_node* eb32_next_unique(eb32_node* eb32);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
eb32_node* eb32_prev_unique(eb32_node* eb32);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
void eb32_delete(eb32_node* eb32);

/*
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
eb32_node* eb32_lookup(eb_root* root, uint x);

/*
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */
eb32_node* eb32i_lookup(eb_root* root, int x);

/*
 * Find the last occurrence of the highest key in the tree <root>, which is
 * equal to or less than <x>. NULL is returned is no key matches.
 */
eb32_node* eb32_lookup_le(eb_root* root, uint x);

/*
 * Find the first occurrence of the lowest key in the tree <root>, which is
 * equal to or greater than <x>. NULL is returned is no key matches.
 */
eb32_node* eb32_lookup_ge(eb_root* root, uint x);

/* Insert eb32_node <new> into subtree starting at node root <root>.
 * Only new->key needs be set with the key. The eb32_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb32_node* eb32_insert(eb_root* root, eb32_node* neww);

/* Insert eb32_node <new> into subtree starting at node root <root>, using
 * signed keys. Only new->key needs be set with the key. The eb32_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb32_node* eb32i_insert(eb_root* root, eb32_node* neww);
