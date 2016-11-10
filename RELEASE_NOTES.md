Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

New Release Notes Procedure (from v1.35.0)
==========================================

Instead of each change being noted in this file (and the subsequent conflict
hell), in release v1.35.0, we're trying a new approach:
* Release notes will be added to individual files, one (or more) per pull
  request.
* Release notes files will be collected in the `relnotes` folder of this repo.
* The files should be named as follows: `<name>.<change-type>.md`:
  - `<name>` can be whatever you want, but should indicate the change made.
  - `<change-type>` is one of `migration`, `feature`, `deprecation`.
  - e.g. `add-suspendable-throttler.feature.md`,
    `change-epoll-selector.migration.md`.
* If a subsequent commit needs to modify previously added release notes, the PR
  can simply edit the corresponding release notes file.
* When the release is ready, the notes from all the files will be collated into
  the final release notes document and the release notes folder cleared.

