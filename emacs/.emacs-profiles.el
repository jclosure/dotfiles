;; Chemacs2 profile definitions — stowed to ~/.emacs-profiles.el.
;; Chemacs2 itself lives at emacs/.emacs.d (a submodule), stowed to
;; ~/.emacs.d. See https://github.com/plexus/chemacs2#emacs-profilesel
;;
;; Plain `emacs` (no --with-profile, no $CHEMACS_PROFILE) loads "default",
;; which is aliased to ide below to match this repo's prior single-profile
;; behavior. Switch explicitly with:
;;
;;   emacs --with-profile minimal
;;   emacs --with-profile light
;;   emacs --with-profile ide
;;   emacs --with-profile experimental
;;
;; ...or persist a different default with:
;;
;;   echo minimal > ~/.emacs-profile
;;
;; minimal, light, and experimental are plain directories in this repo;
;; ide is a submodule pulling in
;; https://github.com/jclosure/vscode-flavored-emacs-2026
;;
;; See README.md in this directory for how to add another profile.

(("default"      . ((user-emacs-directory . "~/dotfiles/emacs/ide")))
 ("minimal"      . ((user-emacs-directory . "~/dotfiles/emacs/minimal")))
 ("light"        . ((user-emacs-directory . "~/dotfiles/emacs/light")))
 ("ide"          . ((user-emacs-directory . "~/dotfiles/emacs/ide")))
 ("experimental" . ((user-emacs-directory . "~/dotfiles/emacs/experimental"))))
