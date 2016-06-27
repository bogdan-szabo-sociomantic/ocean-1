================
Ocean Versioning
================

This is a versioning guide based on SemVer_ that Ocean uses. The goal is to
improve stability and convenience of the users of this library.

.. _SemVer: http://semver.org

.. contents::

Goals
-----

1. Separate feature additions from bug fixes. Separate both from breaking
   changes and major refactorings.
2. Allow reasonable adaptation time span for projects using the library for
   "risky" upgrades.
3. Enable a flexible on-demand release model.

Versioning
----------

Standard **X.Y.Z** pattern where:

- **X** (major release) is incremented for removal of deprecated symbols,
  refactorings that affect API or any major semantical changes in general
- **Y** (minor release) is incremented for new features, deprecations
  and minor internal refactorings that don't affect API
- **Z** (point release) is incremented only for non-intrusive bug fixes
  that are always 100% safe to upgrade to

A major release will be made as need at most every 6 months, minor releases
come out roughly each month and point releases come out as soon as possible to
fix critical bugs. Major version keeps being developed for
1 to 3 months after next major release is out, allowing for smooth upgrade
period. The guaranteed support period of old major versions is specified in
``README.rst``.

Compatibility is defined as "keeps compiling with ``-di`` with no semantical
changes to existing code". Minor releases ensure backwards compatibility but
not forward compatibility - thus discipline in usage of new features is
required for libraries that depend on Ocean if they don't want to indirectly
force users to upgrade.

The main goal of this versioning scheme is to ensure developers can upgrade to
any new minor version without being ever forced to change anything in their
code. And at the same time a way to provide bug fixes for those who are
concerned about accidental changes/bugs from new features too.

Terminology
~~~~~~~~~~~

**Developing a (major) version** means that it gets new features by default,
even if there is a newer major version released.

**Supporting a (minor) version** means it gets new bug fixes by default. For
example, at any time at least the last minor release of any developed major
version should be supported.

Branching, tagging and milestones
---------------------------------

At any given point of time there must be at least these branches in the git
repo:

* One that matches last released major (e.g. v3.x.x) which is used for all
  feature development and is configured to be default branch in GitHub. When
  a feature release is made, a new minor version branch is forked from its
  ``HEAD`` (e.g. v3.2.x).

* One that matches next planned major (e.g. v4.x.x) where all long term
  cleanups and breaking changes go. Current major (e.g. v3.x.x) is merged into
  it upon minor releases.

* One that matches last feature release (e.g. v3.1.x). All bug fixes go here by
  default and cherry-picked into even older minor release branches on demand.
  After point release is created, matching tag (e.g. v3.1.2) gets merged into
  current major version branch (e.g. v3.x.x).

All branches referring to a version being maintained or developed should have
at least one *.x* in its name. All tags should have all concrete numbers.
Milestones should be named the same as the tag that will be created when the
milestone is completed.

Example:

* Current major/minor branch being developed: v3.x.x
* Current major/minor branch being maintained: v3.1.x
* Last released version: v3.1.1
* Milestone for the next point release: v3.1.2
* Milestone for the next minor release: v3.2.0
* Next unreleased major: v4.x.x
* Milestone for next major release: v4.0.0

Supporting multiple major versions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Once next planned major reaches release (e.g. v4.0.0) it doesn't replace
current major immediately. For the sake of stability and developer convenience
new features should still go to previous major (v3.x.x) by default and merged
to v4.x.x after.

After support cycle for v3.x.x expires (usually around 3 months after the next
major was released, v4.0.0 in the example), v4.x.x branch becomes new stable
version and v3.x.x stops receiving changes apart from critical on-demand bug
fixes.

Lack of master branch
~~~~~~~~~~~~~~~~~~~~~

In GitHub it is impossible to change base branch for a pull request once it has
been created and "default" base branch can be configured in GitHub web
interface. As most common type of pull request is adding new feature it makes
most sense to always configure repository to have oldest supported major
version branch as default one - to avoid lot of pull request noise when
contributors chose wrong one by mistake. Because of this Ocean doesn't have
a ``master`` branch, but instead changes the default branch to the current in
development minor.

Example branch graph
--------------------

Lines define branches and their relations:

- ``-``: commit history for a branch (right == older)
- ``/`` or ``\``: merging (always happens from lower version to higher one)
- ``|``: tagging or forking a branch

Letters within a dashed line highlight different types of commits:

- ``B``: commit with a bug-fix
- ``F``: commit with backwards-compatible feature
- ``D``: commit which deprecates symbols
- ``X``: commit with a breaking change
- ``M``: merge commit

.. code::

                                     .---X--X--X--M--F--X--F----F----M--> v4.x.x
                                    /            /       \          /
                                   /            /         +-B--M---B----> v4.0.x
                                  /       .----´          |   /    |
                                 /       /            v4.0.0 /  v4.0.1
                                /       /     .-------------´
                               /       /     /
     --F--F-----M--F--M--F-D--D--F-F--M-----M--------------------F------> v3.x.x
           \   /     /         \     /     /                     |\
            +-B--B--B--.        +---B--B--B--.                   | `----> v3.2.x
            | |     |   \       |   |     |   \               v3.2.0
       v3.0.0 |  v3.0.2  \   v3.1.0 |  v3.1.2  `------------------------> v3.1.x
           v3.0.1         \      v3.1.1
                           `--------------------------------------------> v3.0.x


Points worth additional attention:

1. v4.x.x gets branched from one of v3.x.x releases at arbitrary moment when
   necessity of first braking change is identified - but it doesn't get own
   release immediately. Once v4.0.0 is tagged you can't put any new breaking
   changes there because v4.1.0 must comply to minor release rules. That means
   it is a good idea to wait some time before tagging first release of new major
   branch in case more breaking changes will be needed.
2. There is one feature commit in v4.x.x which doesn't exist in v3.x.x - which
   normally shouldn't happen as all feature should be implemented against
   oldest supported major first. However sometimes implementation becomes
   feasible only after big refactorings and can't be reasonably done against
   and older base. In such case saying it is v4.x.x only feature is OK.
3. Tag v3.1.2 gets merged twice - to v3.x.x branch and to v4.0.x branch. It is
   done so that v4.0.1 with same bug fixes can be released without also merging
   new feature from v3.x.x itself. Such pattern has confused earlier versions
   of git resulting in "fake" conflicts but all up to date ones seem to figure
   it out decently.
4. For simplicity this graph assumes that only latest minor release gets bug
   fixes. In practice this may not be true for more mature libraries and bug
   fixes will be based on v3.0.x even if v3.1.0 has been already released. In
   such case v3.0.3 would be first merged to v3.1.x and only later v3.1.3 would
   be merged to v3.x.x.

