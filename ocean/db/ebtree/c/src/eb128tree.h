/*
 * Elastic Binary Trees - macros and structures for operations on 128bit nodes.
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

#ifndef _EB128TREE_H
#define _EB128TREE_H

/* This is the EB Tree implementation for 128-bit keys. It uses the GCC 4.6
 * extension of 128-bit integer types for platforms with native support for
 * 128-bit integers. If supported, the __SIZEOF_INT128__ macro is defined and
 * the intrinsic signed/unsigned __int128 type exists.
 *
 * @see http://gcc.gnu.org/onlinedocs/gcc-4.6.2/gcc/_005f_005fint128.html
 * @see http://gcc.gnu.org/gcc-4.6/changes.html
 *
 * The 128-bit key EB Tree support, that is, all functions declared below, is
 * compiled in only if that GCC extension is enabled. Otherwise these functions
 * will be missing in the produced library.
 */

#ifdef __SIZEOF_INT128__

#include "ebtree.h"

#include <limits.h>
#include <stdint.h>
#include <stdbool.h>

#define EB128_ROOT	EB_ROOT
#define EB128_TREE_HEAD	EB_TREE_HEAD

/* These types may sometimes already be defined */
typedef unsigned __int128 uint128_t;
typedef signed __int128   int128_t;

/* This structure carries a node, a leaf, and a key. It must start with the
 * eb_node so that it can be cast into an eb_node. We could also have put some
 * sort of transparent union here to reduce the indirection level, but the fact
 * is, the end user is not meant to manipulate internals, so this is pointless.
 */
struct eb128_node {
	struct eb_node node; /* the tree node, must be at the beginning */
	uint128_t key;
};

/*
 * Exported functions and macros.
 * Many of them are always inlined because they are extremely small, and
 * are generally called at most once or twice in a program.
 */

/* Return leftmost node in the tree, or NULL if none */
extern struct eb128_node *eb128_first(struct eb_root *root);

/* Return rightmost node in the tree, or NULL if none */
extern struct eb128_node *eb128_last(struct eb_root *root);

/* Return next node in the tree, or NULL if none */
extern struct eb128_node *eb128_next(struct eb128_node *eb128);

/* Return previous node in the tree, or NULL if none */
extern struct eb128_node *eb128_prev(struct eb128_node *eb128);

/* Return next node in the tree, skipping duplicates, or NULL if none */
extern struct eb128_node *eb128_next_unique(struct eb128_node *eb128);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
extern struct eb128_node *eb128_prev_unique(struct eb128_node *eb128);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
/*
 * The following functions are less likely to be used directly, because their
 * code is larger. The non-inlined version is preferred.
 */

/* Delete node from the tree if it was linked in. Mark the node unused. */
extern void eb128_delete(struct eb128_node *eb128);

/*
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
extern struct eb128_node *eb128_lookup(struct eb_root *root, uint128_t x);
extern struct eb128_node *eb128i_lookup(struct eb_root *root, int128_t x);
extern struct eb128_node *eb128_lookup_264(struct eb_root *root, uint64_t lo, uint64_t hi);
extern struct eb128_node *eb128i_lookup_264(struct eb_root *root, uint64_t lo, int64_t hi);

extern struct eb128_node *eb128_lookup_le(struct eb_root *root, uint128_t x);
extern struct eb128_node *eb128_lookup_le_264(struct eb_root *root, uint64_t lo, uint64_t hi);

extern struct eb128_node *eb128_lookup_ge(struct eb_root *root, uint128_t x);
extern struct eb128_node *eb128_lookup_ge_264(struct eb_root *root, uint64_t lo, uint64_t hi);

/* Insert eb128_node <new> into subtree starting at node root <root>.
 * Only new->key needs be set with the key. The eb128_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
extern struct eb128_node *eb128_insert(struct eb_root *root, struct eb128_node *new);

/* Insert eb128_node <new> into subtree starting at node root <root>, using
 * signed keys. Only new->key needs be set with the key. The eb128_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
extern struct eb128_node *eb128i_insert(struct eb_root *root, struct eb128_node *new);

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

extern bool eb128_less_264(uint64_t alo, uint64_t ahi, uint64_t blo, uint64_t bhi);

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

extern bool eb128_less_or_equal_264(uint64_t alo, uint64_t ahi, uint64_t blo, uint64_t bhi);

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

extern bool eb128_equal_264(uint64_t alo, uint64_t ahi, uint64_t blo, uint64_t bhi);

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

extern bool eb128_greater_or_equal_264(uint64_t alo, uint64_t ahi, uint64_t blo, const uint64_t bhi);

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

extern bool eb128_greater_264(uint64_t alo, uint64_t ahi, uint64_t blo, uint64_t bhi);

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

extern int eb128_cmp_264(uint64_t alo, uint64_t ahi, uint64_t blo, uint64_t bhi);

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

extern bool eb128i_less_264(uint64_t alo, int64_t ahi, uint64_t blo, int64_t bhi);

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

extern bool eb128i_less_or_equal_264(uint64_t alo, int64_t ahi,	uint64_t blo, int64_t bhi);

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

extern bool eb128i_equal_264(uint64_t alo, int64_t ahi, uint64_t blo, int64_t bhi);

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

extern bool eb128i_greater_or_equal_264(uint64_t alo, int64_t ahi, uint64_t blo, int64_t bhi);

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

extern bool eb128i_greater_264(uint64_t alo, int64_t ahi, uint64_t blo, int64_t bhi);

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

extern int eb128i_cmp_264(uint64_t alo, int64_t ahi, uint64_t blo, int64_t bhi);

/******************************************************************************

	Sets node->key to an uint128_t value composed from lo and hi.

	Params:
		node = node to set the key
		lo   = value of the lower 64 value bits of node->key
		hi   = value of the higher 64 value bits of node->key

	Returns:
		node

 ******************************************************************************/

extern struct eb128_node *eb128_node_setkey_264(struct eb128_node *node, uint64_t lo, uint64_t hi);

/******************************************************************************

	Sets node->key to an int128_t value composed from lo and hi.

	Params:
		node = node to set the key
		lo   = value of the lower 64 value bits of node->key
		hi   = value of the higher 64 value bits of node->key

	Returns:
		node

 ******************************************************************************/

extern struct eb128_node *eb128i_node_setkey_264(struct eb128_node *node, uint64_t lo, int64_t hi);

/******************************************************************************

	Obtains node->key,and decomposes it into two uint64_t values. This assumes
	that the key was originally unsigned, e.g. set by eb128_node_setkey_264().

	Params:
		node = node to obtain the key
		lo   = output of the value of the lower 64 value bits of node->key
		hi   = output of the value of the higher 64 value bits of node->key

 ******************************************************************************/

extern void eb128_node_getkey_264(const struct eb128_node *node, uint64_t *restrict lo, uint64_t *restrict hi);

/******************************************************************************

	Obtains node->key,and decomposes it into an int64_t and an uint64_t value.
	This assumes that the key was originally signed, e.g. set by
	eb128i_node_setkey_264().

	Params:
		node = node to obtain the key
		lo   = output of the value of the lower 64 value bits of node->key
		hi   = output of the value of the higher 64 value bits of node->key

 ******************************************************************************/

extern void eb128i_node_getkey_264(const struct eb128_node *node, uint64_t *lo, int64_t *hi);

#endif /* __SIZEOF_INT128__ */
#endif /* _EB128_TREE_H */
