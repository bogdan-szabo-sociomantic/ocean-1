/*
 * Elastic Binary Trees - macros for Indirect Multi-Byte data nodes.
 * Version 6.0.5
 * (C) 2002-2011 - Willy Tarreau <w@1wt.eu>
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

module ocean.util.container.ebtree.c.ebimtree;

private import ocean.util.container.ebtree.c.ebtree;
private import ocean.util.container.ebtree.c.ebpttree;

extern (C):

/* Find the first occurence of a key of a least <len> bytes matching <x> in the
 * tree <root>. The caller is responsible for ensuring that <len> will not exceed
 * the common parts between the tree's keys and <x>. In case of multiple matches,
 * the leftmost node is returned. This means that this function can be used to
 * lookup string keys by prefix if all keys in the tree are zero-terminated. If
 * no match is found, NULL is returned. Returns first node if <len> is zero.
 */
ebpt_node* ebim_lookup(ebpt_node* root, void *x, uint len);

/* Insert ebpt_node <new> into subtree starting at node root <root>.
 * Only new->key needs be set with the key. The ebpt_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys. The
 * len is specified in bytes.
 */
ebpt_node* ebim_insert(ebpt_node* root, ebpt_node* neww, uint len);
