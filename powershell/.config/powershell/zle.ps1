# zle-style line editing for PSReadLine, dot-sourced from profile.ps1 after
# PSReadLine is imported in Emacs mode and the inline suggestions are set up
# (the motion keys below also accept suggestions). Works in PowerShell 7 and
# Windows PowerShell 5.1; keep this file ASCII for 5.1.

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
#   Ctrl+/ (Ctrl+_)        undo the last edit (zle undo)
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

# Bind a movement key: plain move normally, extend the region when a mark is
# set. With -Accept, at the end of the line it accepts the inline suggestion
# instead (all of it, or the next word), like zsh-autosuggestions' accept
# and partial-accept widgets.
function global:Set-ZleMotionKey([string[]]$Chord, [string]$Move, [string]$Select, [string]$Accept = '') {
    $acceptCode = if ($Accept) { @"
elseif ((Get-ZleState).Cursor -ge (Get-ZleState).Line.Length) {
    [Microsoft.PowerShell.PSConsoleReadLine]::$Accept(`$key, `$arg)
}
"@ } else { '' }
    $desc = "$Move (extends the region after Ctrl+Space" + $(if ($Accept) { "; $Accept at end of line" } else { '' }) + ')'
    Set-PSReadLineKeyHandler -Chord $Chord -Description $desc -ScriptBlock ([scriptblock]::Create(@"
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
}
$acceptCode
else {
    [Microsoft.PowerShell.PSConsoleReadLine]::$Move(`$key, `$arg)
}
"@))
}

Set-ZleMotionKey 'LeftArrow', 'Ctrl+b'                 BackwardChar     SelectBackwardChar
Set-ZleMotionKey 'RightArrow', 'Ctrl+f'                ForwardChar      SelectForwardChar   AcceptSuggestion
Set-ZleMotionKey 'Alt+LeftArrow', 'Ctrl+LeftArrow', 'Alt+b'   BackwardWord  SelectBackwardWord
Set-ZleMotionKey 'Alt+RightArrow', 'Ctrl+RightArrow', 'Alt+f' NextWord      SelectNextWord   AcceptNextSuggestionWord
Set-ZleMotionKey 'Home', 'Ctrl+a'                      BeginningOfLine  SelectBackwardsLine
Set-ZleMotionKey 'End', 'Ctrl+e'                       EndOfLine        SelectLine          AcceptSuggestion

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

# zle undo is Ctrl+/ -- terminals send it as Ctrl+_ (0x1F), so bind both.
Set-PSReadLineKeyHandler -Chord 'Ctrl+/', 'Ctrl+_' -Description 'Undo the last edit (zsh undo)' -ScriptBlock {
    param($key, $arg)
    Stop-ZleRegion
    [Microsoft.PowerShell.PSConsoleReadLine]::Undo($key, $arg)
}
