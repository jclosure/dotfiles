# emacs

This module is stowed to `~/.emacs.d` (→ [Chemacs2](https://github.com/plexus/chemacs2),
a submodule) and `~/.emacs-profiles.el` (→ `.emacs-profiles.el` in this
directory). Chemacs2 is a profile switcher: it reads `.emacs-profiles.el`
and loads whichever profile's `user-emacs-directory` you ask for, instead
of Emacs always loading `~/.emacs.d` directly.

Current profiles: `minimal`, `light`, `ide` (submodule), `experimental`.
See the root [README.md](../README.md#emacs-profiles) for what each one is.

None of the profile directories are stowed into `$HOME` — Chemacs2
references them directly by their path in this checkout
(`~/dotfiles/emacs/<name>`), so there's nothing to symlink.

## Adding another profile

Say you want to add a profile called `writing`.

1. **Get the config into `emacs/writing/`.**

   - Plain config tracked in this repo:
     ```sh
     mkdir emacs/writing
     $EDITOR emacs/writing/init.el
     ```
   - Pulling in someone else's config (like `ide` does): add it as a
     submodule instead of a plain directory:
     ```sh
     git submodule add <url> emacs/writing
     ```

2. **Register it in [`.emacs-profiles.el`](.emacs-profiles.el)** — add a
   line to the alist:
   ```elisp
   ("writing" . ((user-emacs-directory . "~/dotfiles/emacs/writing")))
   ```

3. **Exclude it from stow** by adding to
   [`.stow-local-ignore`](.stow-local-ignore):
   ```
   ^/writing$
   ```
   Skip this and `stow emacs` will try to symlink `~/writing` into
   `$HOME`, which is not what you want.

4. **Re-stow** so any stow-tracked changes take effect (new/removed files
   in an already-stowed package need a re-run):
   ```sh
   cd ~/dotfiles && stow -R emacs
   ```
   (Not needed for the profile directory itself, per step 3 — but harmless
   to run, and needed if you touched anything else in `emacs/`.)

5. **Verify** before trusting it:
   ```sh
   # .emacs-profiles.el still parses and lists your new profile
   emacs --batch --eval '(with-temp-buffer
     (insert-file-contents "~/.emacs-profiles.el")
     (princ (mapcar (function car) (read (current-buffer)))))'

   # chemacs2 resolves it to the right directory
   CHEMACS_PROFILE=writing emacs --batch -Q -l ~/.emacs.d/chemacs.el \
     --eval '(princ user-emacs-directory)'

   # actually boot it
   emacs --with-profile writing
   ```

If the plain-directory config accumulates generated files (`elpa/`,
`eln-cache/`, etc.), you don't need to touch `.gitignore` — its patterns
are unanchored and already match at any depth under this directory.

## Removing a profile

Reverse the above: drop its `.emacs-profiles.el` entry, drop its
`.stow-local-ignore` line, and remove the directory. If it was a
submodule, don't just `rm -rf` it — deinit first or you'll leave stale
state in `.git/modules`:
```sh
git submodule deinit -f emacs/writing
git rm -f emacs/writing
rm -rf .git/modules/emacs/writing
```

## Changing the default

Plain `emacs` (no `--with-profile`, no `$CHEMACS_PROFILE`) loads whatever
`.emacs-profiles.el` maps `"default"` to — currently `ide`. Either repoint
`"default"` in that file, or override per-machine without touching the
repo:
```sh
echo writing > ~/.emacs-profile
```
