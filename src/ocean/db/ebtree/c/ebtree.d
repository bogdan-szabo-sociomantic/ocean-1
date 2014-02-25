/*
 * Elastic Binary Trees - generic macros and structures.
 * Version 6.0.1
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
 *
 *
 * Short history :
 *
 * 2007/09/28: full support for the duplicates tree => v3
 * 2007/07/08: merge back cleanups from kernel version.
 * 2007/07/01: merge into Linux Kernel (try 1).
 * 2007/05/27: version 2: compact everything into one single struct
 * 2007/05/18: adapted the structure to support embedded nodes
 * 2007/05/13: adapted to mempools v2.
 */



/*
  General idea:
  -------------
  In a radix binary tree, we may have up to 2N-1 nodes for N keys if all of
  them are leaves. If we find a way to differentiate intermediate nodes (later
  called "nodes") and final nodes (later called "leaves"), and we associate
  them by two, it is possible to build sort of a self-contained radix tree with
  intermediate nodes always present. It will not be as cheap as the ultree for
  optimal cases as shown below, but the optimal case almost never happens :

  Eg, to store 8, 10, 12, 13, 14 :

             ultree          this theorical tree

               8                   8
              / \                 / \
             10 12               10 12
               /  \                /  \
              13  14              12  14
                                 / \
                                12 13

   Note that on real-world tests (with a scheduler), is was verified that the
   case with data on an intermediate node never happens. This is because the
   data spectrum is too large for such coincidences to happen. It would require
   for instance that a task has its expiration time at an exact second, with
   other tasks sharing that second. This is too rare to try to optimize for it.

   What is interesting is that the node will only be added above the leaf when
   necessary, which implies that it will always remain somewhere above it. So
   both the leaf and the node can share the exact value of the leaf, because
   when going down the node, the bit mask will be applied to comparisons. So we
   are tempted to have one single key shared between the node and the leaf.

   The bit only serves the nodes, and the dups only serve the leaves. So we can
   put a lot of information in common. This results in one single entity with
   two branch pointers and two parent pointers, one for the node part, and one
   for the leaf part :

              node's         leaf's
              parent         parent
                |              |
              [node]         [leaf]
               / \
           left   right
         branch   branch

   The node may very well refer to its leaf counterpart in one of its branches,
   indicating that its own leaf is just below it :

              node's
              parent
                |
              [node]
               / \
           left  [leaf]
         branch

   Adding keys in such a tree simply consists in inserting nodes between
   other nodes and/or leaves :

                [root]
                  |
               [node2]
                 / \
          [leaf1]   [node3]
                      / \
               [leaf2]   [leaf3]

   On this diagram, we notice that [node2] and [leaf2] have been pulled away
   from each other due to the insertion of [node3], just as if there would be
   an elastic between both parts. This elastic-like behaviour gave its name to
   the tree : "Elastic Binary Tree", or "EBtree". The entity which associates a
   node part and a leaf part will be called an "EB node".

   We also notice on the diagram that there is a root entity required to attach
   the tree. It only contains two branches and there is nothing above it. This
   is an "EB root". Some will note that [leaf1] has no [node1]. One property of
   the EBtree is that all nodes have their branches filled, and that if a node
   has only one branch, it does not need to exist. Here, [leaf1] was added
   below [root] and did not need any node.

   An EB node contains :
     - a pointer to the node's parent (node_p)
     - a pointer to the leaf's parent (leaf_p)
     - two branches pointing to lower nodes or leaves (branches)
     - a bit position (bit)
     - an optional key.

   The key here is optional because it's used only during insertion, in order
   to classify the nodes. Nothing else in the tree structure requires knowledge
   of the key. This makes it possible to write type-agnostic primitives for
   everything, and type-specific insertion primitives. This has led to consider
   two types of EB nodes. The type-agnostic ones will serve as a header for the
   other ones, and will simply be called "eb_node". The other ones will
   have their type indicated in the structure name. Eg: "eb32_node" for
   nodes carrying 32 bit keys.

   We will also node that the two branches in a node serve exactly the same
   purpose as an EB root. For this reason, a "eb_root" will be used as
   well inside the eb_node. In order to ease pointer manipulation and
   ROOT detection when walking upwards, all the pointers inside an eb_node will
   point to the eb_root part of the referenced EB nodes, relying on the same
   principle as the linked lists in Linux.

   Another important point to note, is that when walking inside a tree, it is
   very convenient to know where a node is attached in its parent, and what
   type of branch it has below it (leaf or node). In order to simplify the
   operations and to speed up the processing, it was decided in this specific
   implementation to use the lowest bit from the pointer to designate the side
   of the upper pointers (left/right) and the type of a branch (leaf/node).
   This practise is not mandatory by design, but an implementation-specific
   optimisation permitted on all platforms on which data must be aligned. All
   known 32 bit platforms align their integers and pointers to 32 bits, leaving
   the two lower bits unused. So, we say that the pointers are "tagged". And
   since they designate pointers to root parts, we simply call them
   "tagged root pointers", or "eb_troot" in the code.

   Duplicate keys are stored in a special manner. When inserting a key, if
   the same one is found, then an incremental binary tree is built at this
   place from these keys. This ensures that no special case has to be written
   to handle duplicates when walking through the tree or when deleting entries.
   It also guarantees that duplicates will be walked in the exact same order
   they were inserted. This is very important when trying to achieve fair
   processing distribution for instance.

   Algorithmic complexity can be derived from 3 variables :
     - the number of possible different keys in the tree : P
     - the number of entries in the tree : N
     - the number of duplicates for one key : D

   Note that this tree is deliberately NOT balanced. For this reason, the worst
   case may happen with a small tree (eg: 32 distinct keys of one bit). BUT,
   the operations required to manage such data are so much cheap that they make
   it worth using it even under such conditions. For instance, a balanced tree
   may require only 6 levels to store those 32 keys when this tree will
   require 32. But if per-level operations are 5 times cheaper, it wins.

   Minimal, Maximal and Average times are specified in number of operations.
   Minimal is given for best condition, Maximal for worst condition, and the
   average is reported for a tree containing random keys. An operation
   generally consists in jumping from one node to the other.

   Complexity :
     - lookup              : min=1, max=log(P), avg=log(N)
     - insertion from root : min=1, max=log(P), avg=log(N)
     - insertion of dups   : min=1, max=log(D), avg=log(D)/2 after lookup
     - deletion            : min=1, max=1,      avg=1
     - prev/next           : min=1, max=log(P), avg=2 :
       N/2 nodes need 1 hop  => 1*N/2
       N/4 nodes need 2 hops => 2*N/4
       N/8 nodes need 3 hops => 3*N/8
       ...
       N/x nodes need log(x) hops => log2(x)*N/x
       Total cost for all N nodes : sum[i=1..N](log2(i)*N/i) = N*sum[i=1..N](log2(i)/i)
       Average cost across N nodes = total / N = sum[i=1..N](log2(i)/i) = 2

   This design is currently limited to only two branches per node. Most of the
   tree descent algorithm would be compatible with more branches (eg: 4, to cut
   the height in half), but this would probably require more complex operations
   and the deletion algorithm would be problematic.

   Useful properties :
     - a node is always added above the leaf it is tied to, and never can get
       below nor in another branch. This implies that leaves directly attached
       to the root do not use their node part, which is indicated by a null
       value in node_p. This also enhances the cache efficiency when walking
       down the tree, because when the leaf is reached, its node part will
       already have been visited (unless it's the first leaf in the tree).

     - pointers to lower nodes or leaves are stored in "branch" pointers. Only
       the root node may have a null in either branch, it is not possible for
       other branches. Since the nodes are attached to the left branch of the
       root, it is not possible to see a null left branch when walking up a
       tree. Thus, an empty tree is immediately identified by a null left
       branch at the root. Conversely, the one and only way to identify the
       root node is to check that it right branch is null. Note that the
       null pointer may have a few low-order bits set.

     - a node connected to its own leaf will have branch[0|1] pointing to
       itself, and leaf_p pointing to itself.

     - a node can never have node_p pointing to itself.

     - a node is linked in a tree if and only if it has a non-null leaf_p.

     - a node can never have both branches equal, except for the root which can
       have them both null.

     - deletion only applies to leaves. When a leaf is deleted, its parent must
       be released too (unless it's the root), and its sibling must attach to
       the grand-parent, replacing the parent. Also, when a leaf is deleted,
       the node tied to this leaf will be removed and must be released too. If
       this node is different from the leaf's parent, the freshly released
       leaf's parent will be used to replace the node which must go. A released
       node will never be used anymore, so there's no point in tracking it.

     - the bit index in a node indicates the bit position in the key which is
       represented by the branches. That means that a node with (bit == 0) is
       just above two leaves. Negative bit values are used to build a duplicate
       tree. The first node above two identical leaves gets (bit == -1). This
       value logarithmically decreases as the duplicate tree grows. During
       duplicate insertion, a node is inserted above the highest bit value (the
       lowest absolute value) in the tree during the right-sided walk. If bit
       -1 is not encountered (highest < -1), we insert above last leaf.
       Otherwise, we insert above the node with the highest value which was not
       equal to the one of its parent + 1.

     - the "eb_next" primitive walks from left to right, which means from lower
       to higher keys. It returns duplicates in the order they were inserted.
       The "eb_first" primitive returns the left-most entry.

     - the "eb_prev" primitive walks from right to left, which means from
       higher to lower keys. It returns duplicates in the opposite order they
       were inserted. The "eb_last" primitive returns the right-most entry.

     - a tree which has 1 in the lower bit of its root's right branch is a
       tree with unique nodes. This means that when a node is inserted with
       a key which already exists will not be inserted, and the previous
       entry will be returned.

 */

module ocean.db.ebtree.c.ebtree;

/* This is the same as an eb_node pointer, except that the lower bit embeds
 * a tag. See eb_dotag()/eb_untag()/eb_gettag(). This tag has two meanings :
 *  - 0=left, 1=right to designate the parent's branch for leaf_p/node_p
 *  - 0=link, 1=leaf  to designate the branch's type for branch[]
 */
typedef void eb_troot_t;

/* The eb_root connects the node which contains it, to two nodes below it, one
 * of which may be the same node. At the top of the tree, we use an eb_root
 * too, which always has its right branch NULL (+/1 low-order bits).
 */
struct eb_root
{
    /* Number of bits per node, and number of leaves per node */
    const BITS          = 1;
    const BRANCHES      = (1 << BITS);
    
    eb_troot_t*[BRANCHES] b; /* left and right branches */
    
    /* Return non-zero if the tree is empty, otherwise zero */
    bool is_empty ( )
    {
        return !!eb_is_empty(this);
    }
}

/* The eb_node contains the two parts, one for the leaf, which always exists,
 * and one for the node, which remains unused in the very first node inserted
 * into the tree. This structure is 20 bytes per node on 32-bit machines. Do
 * not change the order, benchmarks have shown that it's optimal this way.
 */
struct eb_node
{
    eb_root     branches; /* branches, must be at the beginning */
    eb_troot_t* node_p,   /* link node's parent */
                leaf_p;   /* leaf node's parent */
    short       bit;      /* link's bit position. */
    short       pfx;      /* data prefix length, always related to leaf */
    
    /* Return the first leaf in the tree starting at <root>, or NULL if none */
    alias .eb_first first;

    /* Return the last leaf in the tree starting at <root>, or NULL if none */
    alias .eb_last last;
    
    /* Return previous leaf node before an existing leaf node, or NULL if none. */
    typeof (this) prev( )
    {
        return eb_prev(this);
    }

    /* Return next leaf node after an existing leaf node, or NULL if none. */
    typeof (this) next ( )
    {
        return eb_next(this);
    }

    /* Return previous leaf node before an existing leaf node, skipping duplicates,
     * or NULL if none. */
    typeof (this) prev_unique ( )
    {
        return eb_prev_unique(this);
    }

    /* Return next leaf node after an existing leaf node, skipping duplicates, or
     * NULL if none.
     */
    typeof (this) next_unique ( )
    {
        return eb_next_unique(this);
    }

    /* Removes a leaf node from the tree if it was still in it. Marks the node
     * as unlinked.
     */
    void remove ( )
    {
        eb_delete(this);
    }
};

/**************************************\
 * Public functions, for the end-user *
\**************************************/

extern (C):

/* Return non-zero if the tree is empty, otherwise zero */
int eb_is_empty(eb_root* root);

/* Return the first leaf in the tree starting at <root>, or NULL if none */
eb_node* eb_first(eb_root* root);

/* Return the last leaf in the tree starting at <root>, or NULL if none */
eb_node* eb_last(eb_root* root);

/* Return previous leaf node before an existing leaf node, or NULL if none. */
eb_node* eb_prev(eb_node* node);

/* Return next leaf node after an existing leaf node, or NULL if none. */
eb_node* eb_next(eb_node* node);

/* Return previous leaf node before an existing leaf node, skipping duplicates,
 * or NULL if none. */
eb_node* eb_prev_unique(eb_node* node);

/* Return next leaf node after an existing leaf node, skipping duplicates, or
 * NULL if none.
 */
eb_node* eb_next_unique(eb_node* node);

/* Removes a leaf node from the tree if it was still in it. Marks the node
 * as unlinked.
 */
void eb_delete(eb_node* node);

/* Compare blocks <a> and <b> byte-to-byte, from bit <ignore> to bit <len-1>.
 * Return the number of equal bits between strings, assuming that the first
 * <ignore> bits are already identical. It is possible to return slightly more
 * than <len> bits if <len> does not stop on a byte boundary and we find exact
 * bytes. Note that parts or all of <ignore> bits may be rechecked. It is only
 * passed here as a hint to speed up the check.
 */
int equal_bits(char* a, char* b, int ignore, int len);

/* check that the two blocks <a> and <b> are equal on <len> bits. If it is known
 * they already are on some bytes, this number of equal bytes to be skipped may
 * be passed in <skip>. It returns 0 if they match, otherwise non-zero.
 */
int check_bits(char* a, char* b, int skip, int len);

/* Compare strings <a> and <b> byte-to-byte, from bit <ignore> to the last 0.
 * Return the number of equal bits between strings, assuming that the first
 * <ignore> bits are already identical. Note that parts or all of <ignore> bits
 * may be rechecked. It is only passed here as a hint to speed up the check.
 * The caller is responsible for not passing an <ignore> value larger than any
 * of the two strings. However, referencing any bit from the trailing zero is
 * permitted. Equal strings are reported as a negative number of bits, which
 * indicates the end was reached.
 */
int string_equal_bits(char* a, char* b, int ignore);

int cmp_bits(char* a, char* b, uint pos);

int get_bit(char* a, uint pos);
