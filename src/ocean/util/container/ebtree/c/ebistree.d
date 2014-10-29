/*
 * Elastic Binary Trees - macros to manipulate Indirect String data nodes.
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

/* These functions and macros rely on Multi-Byte nodes */

module ocean.util.container.ebtree.c.ebistree;

import ocean.util.container.ebtree.c.ebtree;
import ocean.util.container.ebtree.c.ebpttree;

extern (C):

/* Find the first occurence of a zero-terminated string <x> in the tree <root>.
 * It's the caller's reponsibility to use this function only on trees which
 * only contain zero-terminated strings. If none can be found, return NULL.
 */
ebpt_node* ebis_lookup(eb_root* root, char* x);

/* Find the first occurence of a length <len> string <x> in the tree <root>.
 * It's the caller's reponsibility to use this function only on trees which
 * only contain zero-terminated strings, and that no null character is present
 * in string <x> in the first <len> chars. If none can be found, return NULL.
 */
ebpt_node* ebis_lookup_len(eb_root* root, char* x, uint len);

/* Insert ebpt_node <new> into subtree starting at node root <root>. Only
 * new->key needs be set with the zero-terminated string key. The ebpt_node is
 * returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys. The
 * caller is responsible for properly terminating the key with a zero.
 */
ebpt_node* ebis_insert(eb_root* root, ebpt_node* neww);
