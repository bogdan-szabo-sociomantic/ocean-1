/*
 * Elastic Binary Trees - macros and structures for operations on 128bit nodes.
 *
 * Extension to the HAProxy Elastic Binary Trees library.
 *
 * HAProxy Elastic Binary Trees library:
 *
 * Version 6.0
 * (C) 2002-2010 - Willy Tarreau <w@1wt.eu>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * 128-bit key extension:
 *
 * copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved
 *
 * version:        April 2012: Initial release
 *
 * authors:        Mathias Baumann, David Eckardt
 *
 * This extension to the Elastic Binary Trees library uses a 128-bit integer
 * type for the node keys, which is not a part of the standard C language but
 * provided as an extension by GCC 4.6 and later for targets that support it.
 * These targets include x86-64 but not x86.
 *
 * @see http://gcc.gnu.org/onlinedocs/gcc-4.6.2/gcc/_005f_005fint128.html
 * @see http://gcc.gnu.org/gcc-4.6/changes.html
 *
 * If this extension is not enabled, the functions defined below will be missing
 * in the produced binary.
 */

#include "int128.h"

#ifdef INT128_SUPPORTED

#include "eb128tree.h"
#include "ebtree.h"

#include <stdint.h>
#include <stdbool.h>

/******************************************************************************

	Composes an uint128_t value from two uint64_t values.

	Params:
		lo = value of the lower 64 bits
		hi = value of the higher 64 bits

	Returns:
		the resulting uint128_t value.

 ******************************************************************************/

static inline uint128_t eb128_compose_264(const uint64_t lo, const uint64_t hi)
	{return ((uint128_t)hi << 0x40) | lo;}

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

bool eb128_less_264(
		const uint64_t alo, const uint64_t ahi,
		const uint64_t blo, const uint64_t bhi
) {return eb128_compose_264(alo, ahi) < eb128_compose_264(blo, bhi);}

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

bool eb128_less_or_equal_264(
	const uint64_t alo, const uint64_t ahi,
	const uint64_t blo, const uint64_t bhi
) {return eb128_compose_264(alo, ahi) <= eb128_compose_264(blo, bhi);}

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

bool eb128_equal_264(
	const uint64_t alo, const uint64_t ahi,
	const uint64_t blo, const uint64_t bhi
) {return eb128_compose_264(alo, ahi) == eb128_compose_264(blo, bhi);}

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

bool eb128_greater_or_equal_264(
	const uint64_t alo, const uint64_t ahi,
	const uint64_t blo, const uint64_t bhi
) {return eb128_compose_264(alo, ahi) >= eb128_compose_264(blo, bhi);}

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

bool eb128_greater_264(
	const uint64_t alo, const uint64_t ahi,
	const uint64_t blo, const uint64_t bhi
) {return eb128_compose_264(alo, ahi) > eb128_compose_264(blo, bhi);}

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

int eb128_cmp_264(
	const uint64_t alo, const uint64_t ahi,
	const uint64_t blo, const uint64_t bhi
) {
	const uint128_t a = eb128_compose_264(alo, ahi),
	                b = eb128_compose_264(blo, bhi);

	return (a >= b)? a >= b : -1;
}

/******************************************************************************

	Composes an int128_t value from an int64_t and an uint64_t value.

	Params:
		lo = value of the lower 64 bits
		hi = value of the higher 64 bits

	Returns:
		the resulting uint128_t value.

 ******************************************************************************/

static inline int128_t eb128i_compose_264(const uint64_t lo, const int64_t hi)
	{return ((uint128_t)hi << 0x40) | lo;}

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

bool eb128i_less_264(
	const uint64_t alo, const int64_t ahi,
	const uint64_t blo, const int64_t bhi
) {return eb128_compose_264(alo, ahi) < eb128_compose_264(blo, bhi);}

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

bool eb128i_less_or_equal_264(
	const uint64_t alo, const int64_t ahi,
	const uint64_t blo, const int64_t bhi
) {return eb128_compose_264(alo, ahi) <= eb128_compose_264(blo, bhi);}

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

bool eb128i_equal_264(
	const uint64_t alo, const int64_t ahi,
	const uint64_t blo, const int64_t bhi
) {return eb128_compose_264(alo, ahi) == eb128_compose_264(blo, bhi);}

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

bool eb128i_greater_or_equal_264(
	const uint64_t alo, const int64_t ahi,
	const uint64_t const blo, int64_t bhi
) {return eb128_compose_264(alo, ahi) >= eb128_compose_264(blo, bhi);}

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

bool eb128i_greater_264(
	const uint64_t alo, const int64_t ahi,
	const uint64_t blo, const int64_t bhi
) {return eb128_compose_264(alo, ahi) > eb128_compose_264(blo, bhi);}

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

int eb128i_cmp_264(
	const uint64_t alo, const int64_t ahi,
	const uint64_t blo, const int64_t bhi
) {
	const int128_t a = eb128_compose_264(alo, ahi),
			   b = eb128_compose_264(blo, bhi);

	return (a >= b)? a >= b : -1;
}

/******************************************************************************

	Sets node->key to an uint128_t value composed from lo and hi.

	Params:
		node = node to set the key
		lo   = value of the lower 64 value bits of node->key
		hi   = value of the higher 64 value bits of node->key

	Returns:
		node

 ******************************************************************************/

struct eb128_node *eb128_node_setkey_264(
	struct eb128_node *node, const uint64_t lo, const uint64_t hi
) {
	node->key = eb128_compose_264(lo, hi);
	return node;
}

/******************************************************************************

	Sets node->key to an int128_t value composed from lo and hi.

	Params:
		node = node to set the key
		lo   = value of the lower 64 value bits of node->key
		hi   = value of the higher 64 value bits of node->key

	Returns:
		node

 ******************************************************************************/

struct eb128_node *eb128i_node_setkey_264(
	struct eb128_node *const node, const uint64_t lo, const int64_t hi
) {
	node->key = eb128i_compose_264(lo, hi);
	return node;
}

/******************************************************************************

	Obtains node->key,and decomposes it into two uint64_t values. This assumes
	that the key was originally unsigned, e.g. set by eb128_node_setkey_264().

	Params:
		node = node to obtain the key
		lo   = output of the value of the lower 64 value bits of node->key
		hi   = output of the value of the higher 64 value bits of node->key

 ******************************************************************************/

void eb128_node_getkey_264(
	const struct eb128_node *const node,
	uint64_t *restrict const lo, uint64_t *restrict const hi
) {
	*lo = (uint64_t) node->key;
	*hi = (uint64_t) (node->key >> 0x40);
}

/******************************************************************************

	Obtains node->key,and decomposes it into an int64_t and an uint64_t value.
	This assumes that the key was originally signed, e.g. set by
	eb128i_node_setkey_264().

	Params:
		node = node to obtain the key
		lo   = output of the value of the lower 64 value bits of node->key
		hi   = output of the value of the higher 64 value bits of node->key

 ******************************************************************************/

void eb128i_node_getkey_264(
	const struct eb128_node *const node, uint64_t *const lo, int64_t *const hi
) {
	*lo = (uint64_t) node->key;
	*hi = (int64_t) (node->key >> 0x40);
}

/******************************************************************************

	Find the first occurence of a key in the tree <root>. If none can be found,
	return NULL.

	Params:
		node = node to obtain the key
		lo   = value of the lower 64 value bits of node->key
		hi   = value of the higher 64 value bits of node->key

	Returns:
		corresponding node or NULL if not found.

 ******************************************************************************/

struct eb128_node *eb128_lookup_264(
	struct eb_root *root, const uint64_t lo, const uint64_t hi
) {return eb128_lookup(root, eb128_compose_264(lo, hi));}

/******************************************************************************

	Find the first occurence of a key in the tree <root>. If none can be found,
	return NULL.

	Params:
		node = node to obtain the key
		lo   = value of the lower 64 value bits of node->key
		hi   = value of the higher 64 value bits of node->key

	Returns:
		corresponding node or NULL if not found.

 ******************************************************************************/

struct eb128_node *eb128i_lookup_264(
	struct eb_root *root, const uint64_t lo, const int64_t hi
) {return eb128i_lookup(root, eb128i_compose_264(lo, hi));}

/******************************************************************************

	Find the first occurence of a key in the tree <root>. If none can be found,
	return NULL.

	Params:
		node = node to obtain the key
		lo   = value of the lower 64 value bits of node->key
		hi   = value of the higher 64 value bits of node->key

	Returns:
		corresponding node or NULL if not found.

 ******************************************************************************/

struct eb128_node *eb128_lookup_le_264(
	struct eb_root *const root, const uint64_t lo, const uint64_t hi
) {return eb128_lookup_le(root, eb128_compose_264(lo, hi));}

/******************************************************************************

	Find the first occurence of a key in the tree <root>. If none can be found,
	return NULL.

	Params:
		node = node to obtain the key
		lo   = value of the lower 64 value bits of node->key
		hi   = value of the higher 64 value bits of node->key

	Returns:
		corresponding node or NULL if not found.

 ******************************************************************************/

struct eb128_node *eb128_lookup_ge_264(
	struct eb_root *root, const uint64_t lo, const uint64_t hi
) {return eb128_lookup_ge(root, eb128_compose_264(lo, hi));}

/******************************************************************************/


/* Return the structure of type <type> whose member <member> points to <ptr> */
#define eb128_entry(ptr, type, member) container_of(ptr, type, member)

/*
 * Exported functions and macros.
 * Many of them are always inlined because they are extremely small, and
 * are generally called at most once or twice in a program.
 */

/* Return leftmost node in the tree, or NULL if none */
struct eb128_node *eb128_first(struct eb_root *root)
{
	return eb128_entry(eb_first(root), struct eb128_node, node);
}

/* Return rightmost node in the tree, or NULL if none */
struct eb128_node *eb128_last(struct eb_root *root)
{
	return eb128_entry(eb_last(root), struct eb128_node, node);
}

/* Return next node in the tree, or NULL if none */
struct eb128_node *eb128_next(struct eb128_node *eb128)
{
	return eb128_entry(eb_next(&eb128->node), struct eb128_node, node);
}

/* Return previous node in the tree, or NULL if none */
struct eb128_node *eb128_prev(struct eb128_node *eb128)
{
	return eb128_entry(eb_prev(&eb128->node), struct eb128_node, node);
}

/* Return next node in the tree, skipping duplicates, or NULL if none */
struct eb128_node *eb128_next_unique(struct eb128_node *eb128)
{
	return eb128_entry(eb_next_unique(&eb128->node), struct eb128_node, node);
}

/* Return previous node in the tree, skipping duplicates, or NULL if none */
struct eb128_node *eb128_prev_unique(struct eb128_node *eb128)
{
	return eb128_entry(eb_prev_unique(&eb128->node), struct eb128_node, node);
}

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
void eb128_delete(struct eb128_node *eb128)
{
	eb_delete(&eb128->node);
}

/*
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
struct eb128_node *eb128_lookup(struct eb_root *root, uint128_t x)
{
	struct eb128_node *node;
	eb_troot_t *troot = root->b[EB_LEFT];
	uint128_t y;
	int node_bit;


	if (unlikely(troot == NULL))
		return NULL;

	while (1) {
		if ((eb_gettag(troot) == EB_LEAF)) {
			node = container_of(eb_untag(troot, EB_LEAF),
					    struct eb128_node, node.branches);
			if (node->key == x)
				return node;
			else
				return NULL;
		}
		node = container_of(eb_untag(troot, EB_NODE),
				    struct eb128_node, node.branches);
		node_bit = node->node.bit;

		y = node->key ^ x;
		if (!y) {
			/* Either we found the node which holds the key, or
			 * we have a dup tree. In the later case, we have to
			 * walk it down left to get the first entry.
			 */
			if (node->node.bit < 0) {
				troot = node->node.branches.b[EB_LEFT];
				while (eb_gettag(troot) != EB_LEAF)
					troot = (eb_untag(troot, EB_NODE))->b[EB_LEFT];
				node = container_of(eb_untag(troot, EB_LEAF),
						    struct eb128_node, node.branches);
			}
			return node;
		}

		if ((y >> node->node.bit) >= EB_NODE_BRANCHES)
			return NULL; /* no more common bits */

		troot = node->node.branches.b[(x >> node->node.bit) & EB_NODE_BRANCH_MASK];
	}
}

/*
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */
struct eb128_node *eb128i_lookup(struct eb_root *root, int128_t x)
{
	struct eb128_node *node;
	eb_troot_t *troot = root->b[EB_LEFT];
	uint128_t key = x ^ (((int128_t) 1) << 0x7F);
	uint128_t y;
	int node_bit;

	if (unlikely(troot == NULL))
		return NULL;

	while (1) {
		if ((eb_gettag(troot) == EB_LEAF)) {
			node = container_of(eb_untag(troot, EB_LEAF),
					    struct eb128_node, node.branches);
			if (node->key == (uint128_t)x)
				return node;
			else
				return NULL;
		}
		node = container_of(eb_untag(troot, EB_NODE),
				    struct eb128_node, node.branches);
		node_bit = node->node.bit;

		y = node->key ^ x;
		if (!y) {
			/* Either we found the node which holds the key, or
			 * we have a dup tree. In the later case, we have to
			 * walk it down left to get the first entry.
			 */
			if (node->node.bit < 0) {
				troot = node->node.branches.b[EB_LEFT];
				while (eb_gettag(troot) != EB_LEAF)
					troot = (eb_untag(troot, EB_NODE))->b[EB_LEFT];
				node = container_of(eb_untag(troot, EB_LEAF),
						    struct eb128_node, node.branches);
			}
			return node;
		}

		if ((y >> node->node.bit) >= EB_NODE_BRANCHES)
			return NULL; /* no more common bits */

		troot = node->node.branches.b[(key >> node->node.bit) & EB_NODE_BRANCH_MASK];
	}
}

/* Insert eb128_node <new> into subtree starting at node root <root>.
 * Only new->key needs be set with the key. The eb128_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
struct eb128_node *eb128_insert(struct eb_root *root, struct eb128_node *new) {
	struct eb128_node *old;
	uint64_t                 side = EB_LEFT;
	eb_troot_t             *troot = root->b[EB_LEFT];
	uint128_t newkey; /* caching the key saves approximately one cycle */
	eb_troot_t        *root_right = root->b[EB_RGHT];
	int old_node_bit;

	if (unlikely(troot == NULL)) {
		/* Tree is empty, insert the leaf part below the left branch */
		root->b[EB_LEFT] = eb_dotag(&new->node.branches, EB_LEAF);
		new->node.leaf_p = eb_dotag(root, EB_LEFT);
		new->node.node_p = NULL; /* node part unused */
		return new;
	}

	/* The tree descent is fairly easy :
	 *  - first, check if we have reached a leaf node
	 *  - second, check if we have gone too far
	 *  - third, reiterate
	 * Everywhere, we use <new> for the node node we are inserting, <root>
	 * for the node we attach it to, and <old> for the node we are
	 * displacing below <new>. <troot> will always point to the future node
	 * (tagged with its type). <side> carries the side the node <new> is
	 * attached to below its parent, which is also where previous node
	 * was attached. <newkey> carries the key being inserted.
	 */
	newkey = new->key;

	while (1) {
		if (unlikely(eb_gettag(troot) == EB_LEAF)) {
			eb_troot_t *new_left, *new_rght;
			eb_troot_t *new_leaf, *old_leaf;

			old = container_of(eb_untag(troot, EB_LEAF),
					    struct eb128_node, node.branches);

			new_left = eb_dotag(&new->node.branches, EB_LEFT);
			new_rght = eb_dotag(&new->node.branches, EB_RGHT);
			new_leaf = eb_dotag(&new->node.branches, EB_LEAF);
			old_leaf = eb_dotag(&old->node.branches, EB_LEAF);

			new->node.node_p = old->node.leaf_p;

			/* Right here, we have 3 possibilities :
			   - the tree does not contain the key, and we have
			     new->key < old->key. We insert new above old, on
			     the left ;

			   - the tree does not contain the key, and we have
			     new->key > old->key. We insert new above old, on
			     the right ;

			   - the tree does contain the key, which implies it
			     is alone. We add the new key next to it as a
			     first duplicate.

			   The last two cases can easily be partially merged.
			*/
			 
			if (new->key < old->key) {
				new->node.leaf_p = new_left;
				old->node.leaf_p = new_rght;
				new->node.branches.b[EB_LEFT] = new_leaf;
				new->node.branches.b[EB_RGHT] = old_leaf;
			} else {
				/* we may refuse to duplicate this key if the tree is
				 * tagged as containing only unique keys.
				 */
				if ((new->key == old->key) && eb_gettag(root_right))
					return old;

				/* new->key >= old->key, new goes the right */
				old->node.leaf_p = new_left;
				new->node.leaf_p = new_rght;
				new->node.branches.b[EB_LEFT] = old_leaf;
				new->node.branches.b[EB_RGHT] = new_leaf;

				if (new->key == old->key) {
					new->node.bit = -1;
					root->b[side] = eb_dotag(&new->node.branches, EB_NODE);
					return new;
				}
			}
			break;
		}

		/* OK we're walking down this link */
		old = container_of(eb_untag(troot, EB_NODE),
				    struct eb128_node, node.branches);
		old_node_bit = old->node.bit;

		/* Stop going down when we don't have common bits anymore. We
		 * also stop in front of a duplicates tree because it means we
		 * have to insert above.
		 */

		if ((old_node_bit < 0) || /* we're above a duplicate tree, stop here */
		    (((new->key ^ old->key) >> old_node_bit) >= EB_NODE_BRANCHES)) {
			/* The tree did not contain the key, so we insert <new> before the node
			 * <old>, and set ->bit to designate the lowest bit position in <new>
			 * which applies to ->branches.b[].
			 */
			eb_troot_t *new_left, *new_rght;
			eb_troot_t *new_leaf, *old_node;

			new_left = eb_dotag(&new->node.branches, EB_LEFT);
			new_rght = eb_dotag(&new->node.branches, EB_RGHT);
			new_leaf = eb_dotag(&new->node.branches, EB_LEAF);
			old_node = eb_dotag(&old->node.branches, EB_NODE);

			new->node.node_p = old->node.node_p;

			if (new->key < old->key) {
				new->node.leaf_p = new_left;
				old->node.node_p = new_rght;
				new->node.branches.b[EB_LEFT] = new_leaf;
				new->node.branches.b[EB_RGHT] = old_node;
			}
			else if (new->key > old->key) {
				old->node.node_p = new_left;
				new->node.leaf_p = new_rght;
				new->node.branches.b[EB_LEFT] = old_node;
				new->node.branches.b[EB_RGHT] = new_leaf;
			}
			else {
				struct eb_node *ret;
				ret = eb_insert_dup(&old->node, &new->node);
				return container_of(ret, struct eb128_node, node);
			}
			break;
		}

		/* walk down */
		root = &old->node.branches;
#if __SIZEOF_LONG__ >= 16
		side = (newkey >> old_node_bit) & EB_NODE_BRANCH_MASK;
#elif ULONG_MAX >= UINT64_T_MAX
		side = newkey;
		side >>= old_node_bit;
		if (old_node_bit >= 0x40) {
			side = newkey >> 0x40;
			side >>= old_node_bit & 0x3FF;
		}
		side &= EB_NODE_BRANCH_MASK;
#else
#	error "need 'long' to have at least 64 bits"
#endif
		troot = root->b[side];
	}

	/* Ok, now we are inserting <new> between <root> and <old>. <old>'s
	 * parent is already set to <new>, and the <root>'s branch is still in
	 * <side>. Update the root's leaf till we have it. Note that we can also
	 * find the side by checking the side of new->node.node_p.
	 */

	/* We need the common higher bits between new->key and old->key.
	 * What differences are there between new->key and the node here ?
	 * NOTE that bit(new) is always < bit(root) because highest
	 * bit of new->key and old->key are identical here (otherwise they
	 * would sit on different branches).
	 */
	// note that if EB_NODE_BITS > 1, we should check that it's still >= 0
	new->node.bit = fls128(new->key ^ old->key) - EB_NODE_BITS;
	root->b[side] = eb_dotag(&new->node.branches, EB_NODE);

	return new;
}

/* Insert eb128_node <new> into subtree starting at node root <root>, using
 * signed keys. Only new->key needs be set with the key. The eb128_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
struct eb128_node *eb128i_insert(struct eb_root *root, struct eb128_node *new) {
	struct eb128_node    *old;
	uint64_t              side = EB_LEFT;
	eb_troot_t          *troot = root->b[EB_LEFT];
	uint128_t newkey; /* caching the key saves approximately one cycle */
	eb_troot_t     *root_right = root->b[EB_RGHT];
	int old_node_bit;

	if (unlikely(troot == NULL)) {
		/* Tree is empty, insert the leaf part below the left branch */
		root->b[EB_LEFT] = eb_dotag(&new->node.branches, EB_LEAF);
		new->node.leaf_p = eb_dotag(root, EB_LEFT);
		new->node.node_p = NULL; /* node part unused */
		return new;
	}

	/* The tree descent is fairly easy :
	 *  - first, check if we have reached a leaf node
	 *  - second, check if we have gone too far
	 *  - third, reiterate
	 * Everywhere, we use <new> for the node node we are inserting, <root>
	 * for the node we attach it to, and <old> for the node we are
	 * displacing below <new>. <troot> will always point to the future node
	 * (tagged with its type). <side> carries the side the node <new> is
	 * attached to below its parent, which is also where previous node
	 * was attached. <newkey> carries a high bit shift of the key being
	 * inserted in order to have negative keys stored before positive
	 * ones.
	 */
	newkey = new->key ^ ((int128_t) 1 << 127);

	while (1) {
		if (unlikely(eb_gettag(troot) == EB_LEAF)) {
			eb_troot_t *new_left, *new_rght;
			eb_troot_t *new_leaf, *old_leaf;

			old = container_of(eb_untag(troot, EB_LEAF),
					    struct eb128_node, node.branches);

			new_left = eb_dotag(&new->node.branches, EB_LEFT);
			new_rght = eb_dotag(&new->node.branches, EB_RGHT);
			new_leaf = eb_dotag(&new->node.branches, EB_LEAF);
			old_leaf = eb_dotag(&old->node.branches, EB_LEAF);

			new->node.node_p = old->node.leaf_p;

			/* Right here, we have 3 possibilities :
			   - the tree does not contain the key, and we have
			     new->key < old->key. We insert new above old, on
			     the left ;

			   - the tree does not contain the key, and we have
			     new->key > old->key. We insert new above old, on
			     the right ;

			   - the tree does contain the key, which implies it
			     is alone. We add the new key next to it as a
			     first duplicate.

			   The last two cases can easily be partially merged.
			*/
			 
			if ((int128_t)new->key < (int128_t)old->key) {
				new->node.leaf_p = new_left;
				old->node.leaf_p = new_rght;
				new->node.branches.b[EB_LEFT] = new_leaf;
				new->node.branches.b[EB_RGHT] = old_leaf;
			} else {
				/* we may refuse to duplicate this key if the tree is
				 * tagged as containing only unique keys.
				 */
				if ((new->key == old->key) && eb_gettag(root_right))
					return old;

				/* new->key >= old->key, new goes the right */
				old->node.leaf_p = new_left;
				new->node.leaf_p = new_rght;
				new->node.branches.b[EB_LEFT] = old_leaf;
				new->node.branches.b[EB_RGHT] = new_leaf;

				if (new->key == old->key) {
					new->node.bit = -1;
					root->b[side] = eb_dotag(&new->node.branches, EB_NODE);
					return new;
				}
			}
			break;
		}

		/* OK we're walking down this link */
		old = container_of(eb_untag(troot, EB_NODE),
				    struct eb128_node, node.branches);
		old_node_bit = old->node.bit;

		/* Stop going down when we don't have common bits anymore. We
		 * also stop in front of a duplicates tree because it means we
		 * have to insert above.
		 */

		if ((old_node_bit < 0) || /* we're above a duplicate tree, stop here */
		    (((new->key ^ old->key) >> old_node_bit) >= EB_NODE_BRANCHES)) {
			/* The tree did not contain the key, so we insert <new> before the node
			 * <old>, and set ->bit to designate the lowest bit position in <new>
			 * which applies to ->branches.b[].
			 */
			eb_troot_t *new_left, *new_rght;
			eb_troot_t *new_leaf, *old_node;

			new_left = eb_dotag(&new->node.branches, EB_LEFT);
			new_rght = eb_dotag(&new->node.branches, EB_RGHT);
			new_leaf = eb_dotag(&new->node.branches, EB_LEAF);
			old_node = eb_dotag(&old->node.branches, EB_NODE);

			new->node.node_p = old->node.node_p;

			if ((int128_t)new->key < (int128_t)old->key) {
				new->node.leaf_p = new_left;
				old->node.node_p = new_rght;
				new->node.branches.b[EB_LEFT] = new_leaf;
				new->node.branches.b[EB_RGHT] = old_node;
			}
			else if ((int128_t)new->key > (int128_t)old->key) {
				old->node.node_p = new_left;
				new->node.leaf_p = new_rght;
				new->node.branches.b[EB_LEFT] = old_node;
				new->node.branches.b[EB_RGHT] = new_leaf;
			}
			else {
				struct eb_node *ret;
				ret = eb_insert_dup(&old->node, &new->node);
				return container_of(ret, struct eb128_node, node);
			}
			break;
		}

		/* walk down */
		root = &old->node.branches;
#if __SIZEOF_LONG__ >= 16
		side = (newkey >> old_node_bit) & EB_NODE_BRANCH_MASK;
#elif ULONG_MAX >= UINT64_T_MAX
		side = newkey;
		side >>= old_node_bit;
		if (old_node_bit >= 0x40) {
			side = newkey >> 0x40;
			side >>= old_node_bit & 0x3FF;
		}
		side &= EB_NODE_BRANCH_MASK;
#else
#	error "need 'long' to have at least 64 bits"
#endif
		troot = root->b[side];
	}

	/* Ok, now we are inserting <new> between <root> and <old>. <old>'s
	 * parent is already set to <new>, and the <root>'s branch is still in
	 * <side>. Update the root's leaf till we have it. Note that we can also
	 * find the side by checking the side of new->node.node_p.
	 */

	/* We need the common higher bits between new->key and old->key.
	 * What differences are there between new->key and the node here ?
	 * NOTE that bit(new) is always < bit(root) because highest
	 * bit of new->key and old->key are identical here (otherwise they
	 * would sit on different branches).
	 */
	// note that if EB_NODE_BITS > 1, we should check that it's still >= 0
	new->node.bit = fls128(new->key ^ old->key) - EB_NODE_BITS;
	root->b[side] = eb_dotag(&new->node.branches, EB_NODE);

	return new;
}

/*
 * Find the last occurrence of the highest key in the tree <root>, which is
 * equal to or less than <x>. NULL is returned is no key matches.
 */
struct eb128_node *eb128_lookup_le(struct eb_root *root, uint128_t x)
{
	struct eb128_node *node;
	eb_troot_t *troot = root->b[EB_LEFT];

	if (unlikely(troot == NULL))
		return NULL;

	while (1) {
		if ((eb_gettag(troot) == EB_LEAF)) {
			/* We reached a leaf, which means that the whole upper
			 * parts were common. We will return either the current
			 * node or its next one if the former is too small.
			 */
			node = container_of(eb_untag(troot, EB_LEAF),
					    struct eb128_node, node.branches);
			if (node->key <= x)
				return node;
			/* return prev */
			troot = node->node.leaf_p;
			break;
		}
		node = container_of(eb_untag(troot, EB_NODE),
				    struct eb128_node, node.branches);

		if (node->node.bit < 0) {
			/* We're at the top of a dup tree. Either we got a
			 * matching value and we return the rightmost node, or
			 * we don't and we skip the whole subtree to return the
			 * prev node before the subtree. Note that since we're
			 * at the top of the dup tree, we can simply return the
			 * prev node without first trying to escape from the
			 * tree.
			 */
			if (node->key <= x) {
				troot = node->node.branches.b[EB_RGHT];
				while (eb_gettag(troot) != EB_LEAF)
					troot = (eb_untag(troot, EB_NODE))->b[EB_RGHT];
				return container_of(eb_untag(troot, EB_LEAF),
						    struct eb128_node, node.branches);
			}
			/* return prev */
			troot = node->node.node_p;
			break;
		}

		if (((x ^ node->key) >> node->node.bit) >= EB_NODE_BRANCHES) {
			/* No more common bits at all. Either this node is too
			 * small and we need to get its highest value, or it is
			 * too large, and we need to get the prev value.
			 */
			if ((node->key >> node->node.bit) < (x >> node->node.bit)) {
				troot = node->node.branches.b[EB_RGHT];
				return eb128_entry(eb_walk_down(troot, EB_RGHT), struct eb128_node, node);
			}

			/* Further values will be too high here, so return the prev
			 * unique node (if it exists).
			 */
			troot = node->node.node_p;
			break;
		}
		troot = node->node.branches.b[(x >> node->node.bit) & EB_NODE_BRANCH_MASK];
	}

	/* If we get here, it means we want to report previous node before the
	 * current one which is not above. <troot> is already initialised to
	 * the parent's branches.
	 */
	while (eb_gettag(troot) == EB_LEFT) {
		/* Walking up from left branch. We must ensure that we never
		 * walk beyond root.
		 */
		if (unlikely(eb_clrtag((eb_untag(troot, EB_LEFT))->b[EB_RGHT]) == NULL))
			return NULL;
		troot = (eb_root_to_node(eb_untag(troot, EB_LEFT)))->node_p;
	}
	/* Note that <troot> cannot be NULL at this stage */
	troot = (eb_untag(troot, EB_RGHT))->b[EB_LEFT];
	node = eb128_entry(eb_walk_down(troot, EB_RGHT), struct eb128_node, node);
	return node;
}

/*
 * Find the first occurrence of the lowest key in the tree <root>, which is
 * equal to or greater than <x>. NULL is returned is no key matches.
 */
struct eb128_node *eb128_lookup_ge(struct eb_root *root, uint128_t x)
{
	struct eb128_node *node;
	eb_troot_t *troot = root->b[EB_LEFT];

	if (unlikely(troot == NULL))
		return NULL;

	while (1) {
		if ((eb_gettag(troot) == EB_LEAF)) {
			/* We reached a leaf, which means that the whole upper
			 * parts were common. We will return either the current
			 * node or its next one if the former is too small.
			 */
			node = container_of(eb_untag(troot, EB_LEAF),
					    struct eb128_node, node.branches);
			if (node->key >= x)
				return node;
			/* return next */
			troot = node->node.leaf_p;
			break;
		}
		node = container_of(eb_untag(troot, EB_NODE),
				    struct eb128_node, node.branches);

		if (node->node.bit < 0) {
			/* We're at the top of a dup tree. Either we got a
			 * matching value and we return the leftmost node, or
			 * we don't and we skip the whole subtree to return the
			 * next node after the subtree. Note that since we're
			 * at the top of the dup tree, we can simply return the
			 * next node without first trying to escape from the
			 * tree.
			 */
			if (node->key >= x) {
				troot = node->node.branches.b[EB_LEFT];
				while (eb_gettag(troot) != EB_LEAF)
					troot = (eb_untag(troot, EB_NODE))->b[EB_LEFT];
				return container_of(eb_untag(troot, EB_LEAF),
						    struct eb128_node, node.branches);
			}
			/* return next */
			troot = node->node.node_p;
			break;
		}

		if (((x ^ node->key) >> node->node.bit) >= EB_NODE_BRANCHES) {
			/* No more common bits at all. Either this node is too
			 * large and we need to get its lowest value, or it is too
			 * small, and we need to get the next value.
			 */
			if ((node->key >> node->node.bit) > (x >> node->node.bit)) {
				troot = node->node.branches.b[EB_LEFT];
				return eb128_entry(eb_walk_down(troot, EB_LEFT), struct eb128_node, node);
			}

			/* Further values will be too low here, so return the next
			 * unique node (if it exists).
			 */
			troot = node->node.node_p;
			break;
		}
		troot = node->node.branches.b[(x >> node->node.bit) & EB_NODE_BRANCH_MASK];
	}

	/* If we get here, it means we want to report next node after the
	 * current one which is not below. <troot> is already initialised
	 * to the parent's branches.
	 */
	while (eb_gettag(troot) != EB_LEFT)
		/* Walking up from right branch, so we cannot be below root */
		troot = (eb_root_to_node(eb_untag(troot, EB_RGHT)))->node_p;

	/* Note that <troot> cannot be NULL at this stage */
	troot = (eb_untag(troot, EB_LEFT))->b[EB_RGHT];
	if (eb_clrtag(troot) == NULL)
		return NULL;

	node = eb128_entry(eb_walk_down(troot, EB_LEFT), struct eb128_node, node);
	return node;
}

#endif /* __SIZEOF_INT128__ */
