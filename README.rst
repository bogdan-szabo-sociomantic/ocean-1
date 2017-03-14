CODE REPOSITORY DEACTIVATED
===========================

This repository has been deactivated, all Ocean development will be now done in
the `Tsunami Ocean public
repository <https://github.com/sociomantic-tsunami/ocean>`_.

This repository should be only used to store historic issues and new issues
where sensitive information can't be shared in the public repository.

Before creating any new issues in this repository, please check if there is
a general way to describe the problem that doesn't involve disclosing private
information. If this is the case, please `create an issue in the public
repo <https://github.com/sociomantic-tsunami/ocean/issues/new) instead>`_.

If there is no way to remove all sensitive information because is relevant for
the issue, please check if you can split the issue in two: one part describing
the general problem (without private information) and one part with the
private information, like mentioning private repositories, production servers,
etc. If this is the case, please first `create an issue in the public
repo <https://github.com/sociomantic-tsunami/ocean/issues/new>`_ and then create
an issue in this repo linking to the public issue (do not link in the other
direction as we don't want to *leak* private issues in the public repo, which
will also be completely useless for people outside Sociomantic).

If, and only if, there is no way to dissociate the public and private
information, only then you can create one issue in this repo and none in the
public repository.

**NEVER SUBMIT PULL REQUESTS TO THIS REPO**

This repository was frozen at the branch v3.x.x, all other branches were
removed but converted to tags for future reference
(`v2.5.x <https://github.com/sociomantic/ocean/releases/tag/v2.5.x>`_,
`v2.6.x <https://github.com/sociomantic/ocean/releases/tag/v2.6.x>`_,
`v2.x.x <https://github.com/sociomantic/ocean/releases/tag/v2.x.x>`_ and
`v3.x.x <https://github.com/sociomantic/ocean/releases/tag/v3.x.x>`_).

Below is the original README file.


--------------------------------------------------------------------------------


Description
===========

Ocean is a general purpose library, compatible with both D1 and D2, with a focus
on supporting the development of high-performance, real-time applications. This
focus has led to several noteworthy design choices:

* **Ocean is not cross-platform.** The only supported platform is Linux.
* **Ocean assumes a single-threaded environment.** Fiber-based multi-tasking is
  favoured, internally.
* **Ocean aims to minimise use of the D garbage collector.** GC collect cycles
  can be very disruptive to real-time applications, so Ocean favours a model of
  allocating resources once then reusing them, wherever possible.

Ocean began life as an extension of `Tango
<http://www.dsource.org/projects/tango>`_, some elements of which were
eventually merged into Ocean.

Support Guarantees
------------------

* Major branch development period: 6 months
* Maintained minor versions: 2 most recent

Maintained Major Branches
-------------------------

====== ==================== ===============
Major  Initial release date Supported until
====== ==================== ===============
v2.x.x v2.0.0_: 30/06/2016  TBD
====== ==================== ===============
.. _v2.0.0: https://github.com/sociomantic/ocean/releases/tag/v2.0.0

Releases
========

`Latest release notes
<https://github.com/sociomantic/ocean/releases/latest>`_ | `All
releases <https://github.com/sociomantic/ocean/releases>`_

Ocean's release process is based on `SemVer
<https://github.com/sociomantic/ocean/blob/master/VERSIONING.rst>`_. This means
that the major version is increased for breaking changes, the minor version is
increased for feature releases, and the patch version is increased for bug fixes
that don't cause breaking changes.

Releases are handled using GitHub releases. The notes associated with a
major or minor github release are designed to help developers to migrate from
one version to another. The changes listed are the steps you need to take to
move from the previous version to the one listed.

The release notes are structured in 3 sections, a **Migration Instructions**,
which are the mandatory steps that users have to do to update to a new version,
**Deprecated** which contains deprecated functions that are recommended not to
use but will not break any old code, and the **New Features** which are optional
new features available in the new version that users might find interesting.
Using them is optional, but encouraged.
