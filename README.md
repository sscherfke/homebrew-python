Python versions for homebrew
============================

Insane copy of homebrew's original Python version packages.  Provides formulas
for Python 3.2, 3.3 and 3.5(beta).  Python 2.7 and 3.4 will be added once they
are removed from the official Homebrew formula.

To use them, run brew tap sscherfke/homebrew-python; brew update.

When you install additional Python versions, you may get errors in the *link*
step (because each version claims to be *the* python3).  To workaround this,
execute the link command with the `--overwrite` option and repeat it for
python3 so that `python3` point to the newest versions, e.g:

```bash
brew link --overwrite python33
brew link --overwrite python3
```
