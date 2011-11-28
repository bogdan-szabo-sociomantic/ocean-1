/*
 * Elastic Binary Trees - macros and structures for operations on pointer nodes.
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

#ifndef _EBPTTREE_H
#define _EBPTTREE_H

#include "ebtree.h"
#include "eb32tree.h"
#include "eb64tree.h"


#define EBPT_ROOT	EB_ROOT
#define EBPT_TREE_HEAD	EB_TREE_HEAD

/* on *almost* all platforms, a pointer can be cast into a size_t which is unsigned */
#ifndef PTR_INT_TYPE
#define PTR_INT_TYPE	size_t
#endif

typedef PTR_INT_TYPE ptr_t;

/* This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 * Internally, it is automatically cast as an eb32_node or eb64_node.
 */
struct ebpt_node {
	struct eb_node node; /* the tree node, must be at the beginning */
	void *key;
};

/*
 * Exported functions and macros.
 * Many of them are always inlined because they are extremely small, and
 * are generally called at most once or twice in a program.
 */

/* Return leftmost node in the tree, or NULL if none */
extern struct ebpt_node *ebpt_first(struct eb_root *root);

/* Return rightmost node in the tree, or NULL if none */
extern struct ebpt_node *ebpt_last(struct eb_root *root);

/* Return next node in the tree, or NULL if none */
extern struct ebpt_node *ebpt_next(struct ebpt_node *ebpt);

/* Return previous node in the tree, or NULL if none */
extern struct ebpt_node *ebpt_prev(struct ebpt_node *ebpt);

/* Return next node in the tree, skipping duplicates, or NULL if none */
extern struct ebpt_node *ebpt_next_unique(struct ebpt_node *ebpt);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
extern struct ebpt_node *ebpt_prev_unique(struct ebpt_node *ebpt);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
extern void ebpt_delete(struct ebpt_node *ebpt);

/*
 * The following functions are inlined but derived from the integer versions.
 */
extern struct ebpt_node *ebpt_lookup(struct eb_root *root, void *x);

extern struct ebpt_node *ebpt_lookup_le(struct eb_root *root, void *x);

extern struct ebpt_node *ebpt_lookup_ge(struct eb_root *root, void *x);

extern struct ebpt_node *ebpt_insert(struct eb_root *root, struct ebpt_node *new);

/*
 * The following functions are less likely to be used directly, because
 * their code is larger. The non-inlined version is preferred.
 */

/* Delete node from the tree if it was linked in. Mark the node unused. */
extern void ebpt_delete(struct ebpt_node *ebpt);

extern struct ebpt_node *ebpt_lookup(struct eb_root *root, void *x);

extern struct ebpt_node *ebpt_insert(struct eb_root *root, struct ebpt_node *new);

#endif /* _EBPT_TREE_H */
