# Oh My Zsh-style PowerShell: Oh My Posh prompt + git + PSReadLine + fzf.
#
# Stowed to ~/.config/powershell/profile.ps1 and dot-sourced from $PROFILE by a
# one-line loader (see powershell/README.md), since $PROFILE lives under
# OneDrive, which doesn't handle symlinks. Shared by PowerShell 7 (the main
# shell) and Windows PowerShell 5.1; each has its own $PROFILE loader.
#
# No Terminal-Icons: plain `ls`. In PowerShell 7, $PSStyle colors only
# directories, which is close to Oh My Zsh's default ls.

# PowerShell 7's default directory style is bold on a blue *background*;
# use bold blue text instead, like GNU ls (di=01;34).
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSStyle.FileInfo.Directory = "`e[1;34m"
}

# Prompt theme with git status (installed via: winget install JanDeDobbeleer.OhMyPosh).
# robbyrussell = the Oh My Zsh default; local copy of the upstream theme from
# https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/robbyrussell.omp.json
# customized with a Windows logo + hostname before the arrow (logo needs a Nerd Font).
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$HOME\.config\oh-my-posh\robbyrussell.omp.json" | Invoke-Expression
}

Import-Module posh-git         # git tab completion

# Emacs key bindings, and no as-you-type suggestions: history only comes up
# on demand with Ctrl-r (below). PSReadLine 2.2+ turns predictions on by
# default, so switch them off explicitly. (Installed to CurrentUser; the
# built-in 2.0.0 is too old for -PredictionSource.)
Import-Module PSReadLine -MinimumVersion 2.2
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -PredictionSource None

# ---------------------------------------------------------------------------
# zle-style line editing, mirroring zsh/init.zsh + zsh/clipboard_wrapper.zsh
# (with zsh-delsel-mode):
#   Alt+Left / Alt+Right   word left / right (zsh forward-word / backward-word)
#   Ctrl+Space             set mark; movement keys then extend a highlighted
#                          region. Typing or Backspace replaces/deletes it
#                          (delsel). Ctrl+G cancels.
#   Ctrl+W                 cut region to the system clipboard (cutbuffer)
#   Alt+W / Alt+Shift+W    copy region to the system clipboard (copybuffer)
#   Ctrl+Y                 paste from the system clipboard (pastebuffer)
# With no region, Ctrl+W / Alt+W act from the start of the line to the
# cursor, the same as zle's kill-region with the default mark at 0.
# (Windows Terminal binds Alt+Left/Right to pane focus by default; that's
# unbound in Terminal's settings so the keys reach PowerShell.)
# ---------------------------------------------------------------------------

# Word boundaries like zsh's default WORDCHARS ('*?_-.[]~=/&;!#$%^(){}<>'
# are part of words), so Alt+Left jumps over ~/dotfiles/emacs-ide in one go.
# (The en/em/horizontal-bar dashes are written as char codes because
# Windows PowerShell 5.1 would misread them in this BOM-less UTF-8 file.)
Set-PSReadLineOption -WordDelimiters (":,\|+'`"@``" + [char]0x2013 + [char]0x2014 + [char]0x2015)

# Region color, Emacs-style: a color clearly different from the cursor.
# PSReadLine's default (black on light gray, \e[30;47m) is almost the
# terminal's block-cursor color, so the character under the cursor lost
# its highlight and turned black. Bright white on blue (#264F78, VS Code's
# selection blue) keeps the whole region visible, and the cursor cell shows
# as the light cursor block on top. ([char]27 instead of `e so 5.1 can read it.)
Set-PSReadLineOption -Colors @{ Selection = "$([char]27)[97;48;2;38;79;120m" }

# Region state. PSReadLine only has Shift+arrow selection, not a sticky
# mark, so Ctrl+Space turns movement keys into their Select* counterparts
# until the region is used, cancelled, or edited away.
$global:ZleRegion = @{ Active = $false; Started = $false; Anchor = 0 }

function global:Get-ZleState {
    $line = $null; $cursor = 0; $selStart = 0; $selLength = 0
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selStart, [ref]$selLength)
    @{ Line = $line; Cursor = $cursor; SelStart = $selStart; SelLength = $selLength }
}

function global:Stop-ZleRegion { $global:ZleRegion.Active = $false; $global:ZleRegion.Started = $false }

# Bind a movement key: plain move normally, extend the region when a mark is set.
function global:Set-ZleMotionKey([string[]]$Chord, [string]$Move, [string]$Select) {
    Set-PSReadLineKeyHandler -Chord $Chord -Description "$Move (extends the region after Ctrl+Space)" -ScriptBlock ([scriptblock]::Create(@"
param(`$key, `$arg)
`$r = `$global:ZleRegion
if (`$r.Active) {
    `$s = Get-ZleState
    # Region is gone if anything other than movement happened since
    # (typing, deleting, cut/paste): the cursor left the anchor without a selection.
    if ((-not `$r.Started -or `$s.SelLength -le 0) -and `$s.Cursor -ne `$r.Anchor) { Stop-ZleRegion }
}
if (`$r.Active) {
    [Microsoft.PowerShell.PSConsoleReadLine]::$Select(`$key, `$arg)
    `$r.Started = `$true
} else {
    [Microsoft.PowerShell.PSConsoleReadLine]::$Move(`$key, `$arg)
}
"@))
}

Set-ZleMotionKey 'LeftArrow', 'Ctrl+b'                 BackwardChar     SelectBackwardChar
Set-ZleMotionKey 'RightArrow', 'Ctrl+f'                ForwardChar      SelectForwardChar
Set-ZleMotionKey 'Alt+LeftArrow', 'Ctrl+LeftArrow', 'Alt+b'   BackwardWord  SelectBackwardWord
Set-ZleMotionKey 'Alt+RightArrow', 'Ctrl+RightArrow', 'Alt+f' NextWord      SelectNextWord
Set-ZleMotionKey 'Home', 'Ctrl+a'                      BeginningOfLine  SelectBackwardsLine
Set-ZleMotionKey 'End', 'Ctrl+e'                       EndOfLine        SelectLine

Set-PSReadLineKeyHandler -Chord 'Ctrl+Spacebar', 'Ctrl+@' -Description 'Set mark: movement keys extend a highlighted region (zsh set-mark-command)' -ScriptBlock {
    param($key, $arg)
    $s = Get-ZleState
    # Pressing it again drops the old region and starts a new one here.
    if ($s.SelLength -gt 0) { [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($s.Cursor) }
    $global:ZleRegion.Active = $true
    $global:ZleRegion.Started = $false
    $global:ZleRegion.Anchor = $s.Cursor
}

Set-PSReadLineKeyHandler -Chord 'Ctrl+g' -Description 'Cancel the region / abort' -ScriptBlock {
    param($key, $arg)
    Stop-ZleRegion
    [Microsoft.PowerShell.PSConsoleReadLine]::Abort($key, $arg)
}

Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Description 'Cut region to the system clipboard (zsh cutbuffer)' -ScriptBlock {
    param($key, $arg)
    $s = Get-ZleState
    Stop-ZleRegion
    if ($s.SelLength -gt 0) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Cut($key, $arg)
    } elseif ($s.Cursor -gt 0) {
        Set-Clipboard -Value $s.Line.Substring(0, $s.Cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::Delete(0, $s.Cursor)
    }
}

Set-PSReadLineKeyHandler -Chord 'Alt+w', 'Alt+W' -Description 'Copy region to the system clipboard (zsh copybuffer)' -ScriptBlock {
    param($key, $arg)
    $s = Get-ZleState
    Stop-ZleRegion
    if ($s.SelLength -gt 0) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Copy($key, $arg)
    } elseif ($s.Cursor -gt 0) {
        Set-Clipboard -Value $s.Line.Substring(0, $s.Cursor)
    }
}

Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Description 'Paste from the system clipboard (zsh pastebuffer)' -ScriptBlock {
    param($key, $arg)
    Stop-ZleRegion
    [Microsoft.PowerShell.PSConsoleReadLine]::Paste($key, $arg)
}

# Ctrl-r = fzf over command history, like fzf's zsh widget: fuzzy filter,
# Enter puts the command on the prompt to edit or run.
# Needs: winget install junegunn.fzf; Install-Module PSFzf -Scope CurrentUser
if ((Get-Command fzf -ErrorAction SilentlyContinue) -and (Get-Module -ListAvailable PSFzf)) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'
}
