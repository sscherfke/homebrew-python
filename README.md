Python versions for homebrew
============================

Insane copy of homebrew's original Python version packages. Provides formulas
for Python 2.4, 2.5, 2.6, 3.1 and 3.2.

To use them, run brew tap ctheune/homebrew-python; brew update.

When you install additional Python 2 or 3 versions, you'll get errors in the
*link* step (because each version claims to be *the* python(3)). To workaround
this, execute the link command with the `--overwrite` option and repeat it
for python(3) so that `python`/`python3` point to the newest versions, e.g, for
Python 2.6:

```bash
brew link --overwrite python26
brew link --overwrite python
```
or for Python 3.3:
```bash
brew link --overwrite python33
brew link --overwrite python3
```
