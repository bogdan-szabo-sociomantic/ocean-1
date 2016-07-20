Description |BuildStatus|_
==========================

Ocean is a base, platform-dependant general purpose D library with all the
required core functionality that is missing from the language standard library
(Tango).  Part of Ocean is dedicated to fill some gaps in Tango or add some
improvements over the existing modules, but a big part of it contains very
low-level infrastructure needed to do real-time applications efficiently. That
is why memory allocation minimization is a key component in Ocean's design. For
the same reason a lot of non-portable constructions are used in Ocean.

Versioning
==========

Ocean uses `Sociomantic's SemVer`_ versioning model.

.. _Sociomantic SemVer: https://github.com/sociomantic/backend/blob/master/doc/structure/versioning.rst

The guaranteed development period for old major versions is 6 months from the
release of a new major version. At any time, only the last two minor versions of
each developed major branch are supported; the rest will get bug fixes only
on-demand (create an issue in the ocean repo to request it).

Currently the default major branch is `v1.x.x`. It will go out of support on
2016-12-30 and `v2.x.x` will become the default major branch.

Releases
========

`Latest stable release notes
<https://github.com/sociomantic/ocean/releases/latest>`_ | `Current, in
development, release notes
<https://github.com/sociomantic/ocean/blob/master/RELEASE_NOTES.md>`_ | `All
releases <https://github.com/sociomantic/ocean/releases>`_

Releases are handled using `GitHub releases
<https://github.com/sociomantic/ocean/releases>`_. The release notes provided
there are usually structured in 3 sections, a **Migration Instructions**, which
are the mandatory steps the users have to do to update to a new version,
**Deprecated** which contains deprecated functions which is recommended not to
use but will not break any old code, and the **New Features** which are
optional new features available in the new version that users might find
interesting.  Using them is optional, but encouraged.

These instructions should help developers to migrate from one version to
another. The changes listed here are the steps you need to take to move from
the previous version to the one being listed. For example, all the steps
described in version **v1.5** are the steps required to move from **v1.4** to
**v1.5**.

If you need to jump several versions at once, you should read all the steps from
all the intermediate versions. For example, to jump from **v1.2** to **v1.5**,
you need to first follow the steps in version **v1.3**, then the steps in
version **v1.4** and finally the steps in version **v1.5**.

There are also sometimes *patch-level* releases, in that case there are no
breaking changes or new features, just bug fixes, and thus, only bug fixes are
listed in the release notes.

.. |BuildStatus| image:: https://ci.sociomantic.com/buildStatus/icon?job=core-team/ocean
.. _BuildStatus: https://ci.sociomantic.com/job/core-team/job/ocean/
