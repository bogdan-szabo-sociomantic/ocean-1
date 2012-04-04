module ocean.db.ebtree.c.eb64tree;

private import ocean.db.ebtree.c.ebtree: eb_root, eb_node;

/* This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 */
struct eb64_node
{
    eb_node node; /* the tree node, must be at the beginning */
    ulong   key;
    
    typeof (this) next ( )
    {
        return eb64_next(this);
    }
    
    typeof (this) prev ( )
    {
        return eb64_prev(this);
    }
    
    typeof (this) next_unique ( )
    {
        return eb64_next_unique(this);
    }
    
    typeof (this) prev_unique ( )
    {
        return eb64_prev_unique(this);
    }
}

extern (C):

/* Return leftmost node in the tree, or NULL if none */
eb64_node* eb64_first(eb_root* root);

/* Return rightmost node in the tree, or NULL if none */
eb64_node* eb64_last(eb_root* root);

/* Return next node in the tree, or NULL if none */
eb64_node* eb64_next(eb64_node* eb64);

/* Return previous node in the tree, or NULL if none */
eb64_node* eb64_prev(eb64_node* eb64);

/* Return next node in the tree, skipping duplicates, or NULL if none */
eb64_node* eb64_next_unique(eb64_node* eb64);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
eb64_node* eb64_prev_unique(eb64_node* eb64);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
void eb64_delete(eb64_node* eb64);

/*
 * The following functions are not inlined by default. They are declared
 * in eb64tree.c, which simply relies on their inline version.
 */
eb64_node* eb64_lookup(eb_root* root, ulong x);
eb64_node* eb64i_lookup(eb_root* root, long x);
eb64_node* eb64_lookup_le(eb_root* root, ulong x);
eb64_node* eb64_lookup_ge(eb_root* root, ulong x);
eb64_node* eb64_insert(eb_root* root, eb64_node* neww);
eb64_node* eb64i_insert(eb_root* root, eb64_node* neww);

/*
 * The following functions are less likely to be used directly, because their
 * code is larger. The non-inlined version is preferred.
 */

/* Delete node from the tree if it was linked in. Mark the node unused. */
void __eb64_delete(eb64_node* eb64);

/*
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
eb64_node* __eb64_lookup(eb_root* root, ulong x);

/*
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */
eb64_node* __eb64i_lookup(eb_root* root, long x);

/* Insert eb64_node <neww> into subtree starting at node root <root>.
 * Only neww->key needs be set with the key. The eb64_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb64_node* __eb64_insert(eb_root* root, eb64_node* neww);

/* Insert eb64_node <neww> into subtree starting at node root <root>, using
 * signed keys. Only neww->key needs be set with the key. The eb64_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb64_node* __eb64i_insert(eb_root* root, eb64_node* neww);