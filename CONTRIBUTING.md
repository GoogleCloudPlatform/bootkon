# How to contribute

We'd love to accept your patches and contributions to this project.

## Before you begin

### Sign our Contributor License Agreement

Contributions to this project must be accompanied by a
[Contributor License Agreement](https://cla.developers.google.com/about) (CLA).
You (or your employer) retain the copyright to your contribution; this simply
gives us permission to use and redistribute your contributions as part of the
project.

If you or your current employer have already signed the Google CLA (even if it
was for a different project), you probably don't need to do it again.

Visit <https://cla.developers.google.com/> to see your current agreements or to
sign a new one.

### Review our community guidelines

This project follows
[Google's Open Source Community Guidelines](https://opensource.google/conduct/).

## Contribution process

### Code reviews

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Consult
[GitHub Help](https://help.github.com/articles/about-pull-requests/) for more
information on using pull requests.

## Running bootkon from a fork

Forks work out of the box -- `bk` derives the repo identity (`BK_REPO`) from
the checkout's own git origin, so rendered image links automatically follow
the fork. Three caveats:

1. Set `BK_REPO=<you>/<fork>` in the launch command you hand out; the launch
   fetches `.scripts/bk` from whatever repo that line names (only after the
   clone does bk self-correct from the checkout's origin).
2. The fork must be **public**: the tutorial pane fetches images through
   unauthenticated `?raw=true` blob URLs, which 404 on a private fork.
3. A few upstream references are hardcoded and are NOT redirected by forking,
   e.g. `.scripts/bk-legacy-download` always fetches the data-stream dataset
   from `fhirschmann/bootkon-data`.
