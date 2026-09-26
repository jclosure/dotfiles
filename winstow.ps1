<#
winstow - GNU Stow for Windows, as a single PowerShell script.

A faithful port of GNU Stow 2.4.1 (lib/Stow.pm + bin/stow): same options,
same .stowrc / .stow-local-ignore / .stow-global-ignore handling, same tree
folding/unfolding, conflict detection, --adopt, --dotfiles, --defer,
--override, -p/--compat, and the same plan-then-execute behavior (nothing is
touched if any conflict is found). Links are real relative symlinks, so a
tree stowed here looks exactly like one stowed by stow on Linux/macOS.

Requirements: Windows Developer Mode (Settings -> System -> For developers)
or an elevated shell, so symlinks can be created. Works in Windows
PowerShell 5.1 and PowerShell 7.

Windows-specific differences from stow:
  - Path comparisons are case-insensitive (NTFS is).
  - A leading ~ in -d/-t values is expanded (PowerShell doesn't do it for you).
  - Junctions and absolute symlinks count as links "not owned by stow", just
    like absolute symlinks do in stow.

Usage:  winstow.ps1 [OPTION ...] [-D|-S|-R] PACKAGE ... [-D|-S|-R] PACKAGE ...
#>

# No param() block on purpose: stow-style options (-d, -t, -n, -v, --dir=...)
# must reach us verbatim in $args instead of being bound by PowerShell.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$script:ProgramName = 'winstow'
$script:Version     = '2.4.1'
$script:LocalIgnoreFile  = '.stow-local-ignore'
$script:GlobalIgnoreFile = '.stow-global-ignore'

$script:DefaultIgnoreList = @'
# Comments and blank lines are allowed.

RCS
.+,v

CVS
\.\#.+       # CVS conflict files / emacs lock files
\.cvsignore

\.svn
_darcs
\.hg

\.git
\.gitignore
\.gitmodules

.+~          # emacs backup files
\#.*\#       # emacs autosave files

^/README.*
^/LICENSE.*
^/COPYING
'@

if (-not ('WinStow.Native' -as [type])) {
    Add-Type -Namespace WinStow -Name Native -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
[return: MarshalAs(UnmanagedType.U1)]
public static extern bool CreateSymbolicLink(string lpSymlinkFileName, string lpTargetFileName, int dwFlags);
'@
}

# ---------------------------------------------------------------------------
# Output / errors (stow's debug(), error(), internal_error())
# ---------------------------------------------------------------------------
$script:DebugLevel = 0

function Write-Warn([string]$msg) { [Console]::Error.WriteLine($msg) }

function Write-Dbg([int]$level, [int]$indent, [string]$msg) {
    if ($script:DebugLevel -ge $level) {
        Write-Warn (('    ' * $indent) + $msg)
    }
}

class StowError : System.Exception {
    [int]$ExitCode = 255
    StowError([string]$m) : base($m) {}
    StowError([string]$m, [int]$code) : base($m) { $this.ExitCode = $code }
}

# Perl's die exits with errno when set (2 = ENOENT after a failed -d), else 255.
function Stow-Error([string]$msg, [int]$exitCode = 255) {
    throw [StowError]::new("${script:ProgramName}: ERROR: $msg", $exitCode)
}

function Internal-Error([string]$msg) {
    throw [StowError]::new(("${script:ProgramName}: INTERNAL ERROR: $msg`n" +
        "This _is_ a bug. Please report it along with the command you ran."))
}

# ---------------------------------------------------------------------------
# Path helpers (Stow::Util). Paths are kept stow-style: '/'-separated and
# relative to the target directory, which plays the role of stow's cwd.
# ---------------------------------------------------------------------------
function Test-AbsPath([string]$p) {
    return ($p -match '^[/\\]' -or $p -match '^[A-Za-z]:')
}

function Join-StowPath {
    Write-Dbg 5 5 "| Joining: $($args -join ' ')"
    $result = ''
    foreach ($part in $args) {
        $part = [string]$part
        if (-not $part.Length) { continue }
        $part = $part -replace '\\', '/'
        if (Test-AbsPath $part) {
            $result = $part
        } else {
            if ($result.Length -and $result -ne '/') { $result += '/' }
            $result += $part
        }
        Write-Dbg 7 6 "| Join now: $result"
    }
    Write-Dbg 6 5 "| Joined: $result"
    # File::Spec->canonpath: squash '//' and '/./', strip leading './' and trailing '/'
    $abs = ''
    if ($result -match '^([A-Za-z]:)?/') { $abs = $Matches[0] }
    $segs = New-Object System.Collections.Generic.List[string]
    $sawDot = $false
    foreach ($s in ($result.Substring($abs.Length) -split '/')) {
        if ($s -eq '') { continue }
        if ($s -eq '.') { $sawDot = $true; continue }
        $segs.Add($s)
    }
    # Stow's "1 while s,(^|/)(?!\.\.)[^/]+/\.\.(/|$),$1," : drop "x/.." pairs.
    $changed = $true
    while ($changed) {
        $changed = $false
        for ($i = 0; $i -lt $segs.Count - 1; $i++) {
            if (-not $segs[$i].StartsWith('..') -and $segs[$i + 1] -eq '..') {
                $segs.RemoveAt($i); $segs.RemoveAt($i)
                $changed = $true
                break
            }
        }
    }
    $joined = $abs + ($segs -join '/')
    if (-not $joined.Length -and $sawDot -and $segs.Count -eq 0 -and $result -notmatch '\.\.') { $joined = '.' }
    Write-Dbg 6 5 "| After .. removal: $joined"
    Write-Dbg 5 5 "| Final join: $joined"
    return $joined
}

function Get-StowParent([string]$path) {
    $elts = @($path -split '/+')
    while ($elts.Count -and $elts[-1] -eq '') { $elts = @($elts | Select-Object -SkipLast 1) }
    if ($elts.Count -le 1) { return '' }
    return ($elts[0..($elts.Count - 2)] -join '/')
}

function Resolve-AbsDir([string]$path) {
    $p = (Resolve-Path -LiteralPath $path).ProviderPath
    if ($p -notmatch '^[A-Za-z]:\\$') { $p = $p.TrimEnd('\') }
    return $p
}

function Get-RelPath([string]$path, [string]$base) {
    # File::Spec->abs2rel for two absolute Windows directory paths.
    $p = $path.TrimEnd('\') -split '\\'
    $b = $base.TrimEnd('\') -split '\\'
    if ($p[0] -ne $b[0]) {
        Stow-Error "stow dir $path and target $base are on different drives"
    }
    $i = 0
    while ($i -lt $p.Count -and $i -lt $b.Count -and $p[$i] -eq $b[$i]) { $i++ }
    $parts = @()
    for ($j = $i; $j -lt $b.Count; $j++) { $parts += '..' }
    for ($j = $i; $j -lt $p.Count; $j++) { $parts += $p[$j] }
    if (-not $parts.Count) { return '.' }
    return ($parts -join '/')
}

# Stow-relative path -> absolute Windows path.
function Get-FullPath([string]$rel) {
    $w = $rel -replace '/', '\'
    if (-not (Test-AbsPath $rel)) { $w = [IO.Path]::Combine($script:TargetAbs, $w) }
    return [IO.Path]::GetFullPath($w)
}

function Get-Attrs([string]$full) {
    try { return [IO.File]::GetAttributes($full) } catch { return $null }
}

function Test-FullIsLink([string]$full) {
    $a = Get-Attrs $full
    if ($null -eq $a -or -not ($a -band [IO.FileAttributes]::ReparsePoint)) { return $false }
    $item = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
    return ($null -ne $item -and $item.LinkType -in @('SymbolicLink', 'Junction'))
}

function Read-FullLink([string]$full) {
    $item = Get-Item -LiteralPath $full -Force
    $t = @($item.Target)[0]
    if ($null -eq $t) { return $null }
    $t = [string]$t
    if ($t.StartsWith('\??\')) { $t = $t.Substring(4) }
    return ($t -replace '\\', '/')
}

# Follow symlinks like stat(2); returns the final attributes or $null.
function Get-FollowedAttrs([string]$full) {
    for ($hops = 0; $hops -lt 40; $hops++) {
        $a = Get-Attrs $full
        if ($null -eq $a) { return $null }
        if (-not (Test-FullIsLink $full)) { return $a }
        $dest = Read-FullLink $full
        if (-not $dest) { return $null }
        $w = $dest -replace '/', '\'
        if (-not (Test-AbsPath $dest)) {
            $w = [IO.Path]::Combine([IO.Path]::GetDirectoryName($full), $w)
        }
        $full = [IO.Path]::GetFullPath($w)
    }
    return $null
}

# Perl's -l, -e, -d on a stow-relative path.
function Test-L([string]$rel) { return (Test-FullIsLink (Get-FullPath $rel)) }
function Test-E([string]$rel) { return ($null -ne (Get-FollowedAttrs (Get-FullPath $rel))) }
function Test-D([string]$rel) {
    $a = Get-FollowedAttrs (Get-FullPath $rel)
    return ($null -ne $a -and [bool]($a -band [IO.FileAttributes]::Directory))
}

function Read-Link([string]$rel) { return (Read-FullLink (Get-FullPath $rel)) }

function Get-Listing([string]$rel) {
    $full = Get-FullPath $rel
    try {
        $names = [string[]]@([IO.Directory]::GetFileSystemEntries($full) | ForEach-Object { [IO.Path]::GetFileName($_) })
    } catch {
        Stow-Error "cannot read directory: $rel ($($_.Exception.Message))"
    }
    [Array]::Sort($names, [StringComparer]::Ordinal)
    return ,$names
}

function Get-AdjustedDotfile([string]$node) {
    return ($node -creplace '^dot-([^.])', '.$1')
}

function Get-UnadjustedDotfile([string]$node) {
    if ($node -match '^\.\.?$') { return $node }
    return ($node -creplace '^\.', 'dot-')
}

# ---------------------------------------------------------------------------
# Stow engine state
# ---------------------------------------------------------------------------
$script:O = $null            # options hashtable
$script:StowPath = $null     # stow dir relative to target
$script:TargetAbs = $null
$script:Conflicts = [ordered]@{}
$script:ConflictCount = 0
$script:Tasks = New-Object System.Collections.Generic.List[hashtable]
$script:DirTaskFor = @{}     # case-insensitive, like NTFS
$script:LinkTaskFor = @{}
$script:IgnoreCache = @{}

function Add-Conflict([string]$action, [string]$package, [string]$message) {
    Write-Dbg 2 0 "CONFLICT when ${action}ing ${package}: $message"
    if (-not $script:Conflicts.Contains($action)) { $script:Conflicts[$action] = [ordered]@{} }
    if (-not $script:Conflicts[$action].Contains($package)) {
        $script:Conflicts[$action][$package] = New-Object System.Collections.Generic.List[string]
    }
    $script:Conflicts[$action][$package].Add($message)
    $script:ConflictCount++
}

function Test-ShouldSkipTarget([string]$target) {
    if ($target -eq $script:StowPath) {
        Write-Warn "WARNING: skipping target which was current stow directory $target"
        return $true
    }
    if (Test-MarkedStowDir $target) {
        Write-Warn "WARNING: skipping marked Stow directory $target"
        return $true
    }
    if (Test-E (Join-StowPath $target '.nonstow')) {
        Write-Warn "WARNING: skipping protected directory $target"
        return $true
    }
    Write-Dbg 4 1 "$target not protected; shouldn't skip"
    return $false
}

function Test-MarkedStowDir([string]$dir) {
    if (Test-E (Join-StowPath $dir '.stow')) {
        Write-Dbg 5 5 "> $dir contained .stow"
        return $true
    }
    return $false
}

# --- ignore lists -----------------------------------------------------------
function ConvertTo-IgnoreRegexps([string[]]$lines) {
    $set = [ordered]@{}
    foreach ($l in $lines) {
        $l = $l.Trim()
        if ($l -match '^#' -or -not $l.Length) { continue }
        $l = $l -replace '\s+#.+', ''
        $l = $l -replace '\\#', '#'
        $set[$l] = $true
    }
    $set['^/' + [regex]::Escape($script:LocalIgnoreFile) + '$'] = $true
    $seg = @(); $path = @()
    foreach ($r in $set.Keys) {
        if ($r.IndexOf('/') -lt 0) { $seg += $r } else { $path += $r }
    }
    try {
        $segRe  = if ($seg.Count)  { [regex]('^(' + ($seg -join '|') + ')$') } else { $null }
        $pathRe = if ($path.Count) { [regex]('(^|/)(' + ($path -join '|') + ')(/|$)') } else { $null }
    } catch {
        throw [StowError]::new("Failed to compile regexp: $($_.Exception.Message)")
    }
    return ,@($pathRe, $segRe)
}

function Get-IgnoreRegexps([string]$dir) {
    $local  = Join-StowPath $dir $script:LocalIgnoreFile
    $global = Join-StowPath $script:HomeDir $script:GlobalIgnoreFile
    foreach ($f in @($local, $global)) {
        if (Test-E $f) {
            Write-Dbg 5 1 "Using ignore file: $f"
            $full = Get-FullPath $f
            if (-not $script:IgnoreCache.ContainsKey($full)) {
                $script:IgnoreCache[$full] = ConvertTo-IgnoreRegexps ([IO.File]::ReadAllLines($full))
            } else {
                Write-Dbg 4 2 "Using memoized regexps from $f"
            }
            return ,$script:IgnoreCache[$full]
        }
        Write-Dbg 5 1 "$f didn't exist"
    }
    Write-Dbg 4 1 'Using built-in ignore list'
    if (-not $script:IgnoreCache.ContainsKey('<default>')) {
        $script:IgnoreCache['<default>'] = ConvertTo-IgnoreRegexps ($script:DefaultIgnoreList -split "`r?`n")
    }
    return ,$script:IgnoreCache['<default>']
}

function Test-Ignore([string]$stowPath, [string]$package, [string]$target) {
    if (-not $target.Length) { Internal-Error 'ignore() called with empty target' }
    foreach ($re in $script:O.ignore) {
        if ($re.IsMatch($target)) {
            Write-Dbg 4 1 "Ignoring path $target due to --ignore=$re"
            return $true
        }
    }
    $pair = Get-IgnoreRegexps (Join-StowPath $stowPath $package)
    $pathRe = $pair[0]; $segRe = $pair[1]
    Write-Dbg 5 2 ('Ignore list regexp for paths:    ' + $(if ($null -ne $pathRe) { "/(?^:$pathRe)/" } else { 'none' }))
    Write-Dbg 5 2 ('Ignore list regexp for segments: ' + $(if ($null -ne $segRe) { "/(?^:$segRe)/" } else { 'none' }))
    if ($null -ne $pathRe -and $pathRe.IsMatch("/$target")) {
        Write-Dbg 4 1 "Ignoring path /$target"
        return $true
    }
    $basename = $target -replace '^.+/', ''
    if ($null -ne $segRe -and $segRe.IsMatch($basename)) {
        Write-Dbg 4 1 "Ignoring path segment $basename"
        return $true
    }
    Write-Dbg 5 1 "Not ignoring $target"
    return $false
}

function Test-Defer([string]$path) {
    foreach ($re in $script:O.defer) { if ($re.IsMatch($path)) { return $true } }
    return $false
}

function Test-Override([string]$path) {
    foreach ($re in $script:O.override) { if ($re.IsMatch($path)) { return $true } }
    return $false
}

# --- planned-state queries (is_a_link / is_a_dir / is_a_node / read_a_link) ---
function Get-LinkTaskAction([string]$path) {
    if (-not $script:LinkTaskFor.ContainsKey($path)) {
        Write-Dbg 4 4 "| link_task_action(${path}): no task"
        return ''
    }
    $a = $script:LinkTaskFor[$path].action
    if ($a -ne 'remove' -and $a -ne 'create') { Internal-Error "bad task action: $a" }
    Write-Dbg 4 1 "link_task_action(${path}): link task exists with action $a"
    return $a
}

function Get-DirTaskAction([string]$path) {
    if (-not $script:DirTaskFor.ContainsKey($path)) {
        Write-Dbg 4 4 "| dir_task_action(${path}): no task"
        return ''
    }
    $a = $script:DirTaskFor[$path].action
    if ($a -ne 'remove' -and $a -ne 'create') { Internal-Error "bad task action: $a" }
    Write-Dbg 4 4 "| dir_task_action(${path}): dir task exists with action $a"
    return $a
}

function Test-ParentLinkScheduledForRemoval([string]$targetPath) {
    $prefix = ''
    foreach ($part in ($targetPath -split '/+')) {
        $prefix = Join-StowPath $prefix $part
        Write-Dbg 5 4 "| parent_link_scheduled_for_removal(${targetPath}): prefix $prefix"
        if ($script:LinkTaskFor.ContainsKey($prefix) -and $script:LinkTaskFor[$prefix].action -eq 'remove') {
            Write-Dbg 4 4 "| parent_link_scheduled_for_removal(${targetPath}): link scheduled for removal"
            return $true
        }
    }
    Write-Dbg 4 4 "| parent_link_scheduled_for_removal(${targetPath}): returning false"
    return $false
}

function Test-IsALink([string]$p) {
    Write-Dbg 4 2 "is_a_link($p)"
    $a = Get-LinkTaskAction $p
    if ($a -eq 'remove') {
        Write-Dbg 4 2 "is_a_link(${p}): returning 0 (remove action found)"
        return $false
    }
    if ($a -eq 'create') {
        Write-Dbg 4 2 "is_a_link(${p}): returning 1 (create action found)"
        return $true
    }
    if (Test-L $p) {
        Write-Dbg 4 2 "is_a_link(${p}): is a real link"
        return (-not (Test-ParentLinkScheduledForRemoval $p))
    }
    Write-Dbg 4 2 "is_a_link(${p}): returning 0"
    return $false
}

function Test-IsADir([string]$p) {
    Write-Dbg 4 1 "is_a_dir($p)"
    $a = Get-DirTaskAction $p
    if ($a -eq 'remove') { return $false }
    if ($a -eq 'create') { return $true }
    if (Test-ParentLinkScheduledForRemoval $p) { return $false }
    if (Test-D $p) {
        Write-Dbg 4 1 "is_a_dir(${p}): real dir"
        return $true
    }
    Write-Dbg 4 1 "is_a_dir(${p}): returning false"
    return $false
}

function Test-IsANode([string]$p) {
    Write-Dbg 4 4 "| Checking whether $p is a current/planned node"
    $la = Get-LinkTaskAction $p
    $da = Get-DirTaskAction $p
    if ($la -eq 'remove') {
        if ($da -eq 'remove') { Internal-Error "removing link and dir: $p" }
        return ($da -eq 'create')
    }
    elseif ($la -eq 'create') {
        if ($da -eq 'create') { Internal-Error "creating link and dir: $p" }
        return $true
    }
    else {
        if ($da -eq 'remove') { return $false }
        if ($da -eq 'create') { return $true }
    }
    if (Test-ParentLinkScheduledForRemoval $p) { return $false }
    if (Test-E $p) {
        Write-Dbg 4 3 "| is_a_node(${p}): really exists"
        return $true
    }
    Write-Dbg 4 3 "| is_a_node(${p}): returning false"
    return $false
}

function Read-ALink([string]$link) {
    $a = Get-LinkTaskAction $link
    if ($a) {
        Write-Dbg 4 2 "read_a_link(${link}): task exists with action $a"
        if ($a -eq 'create') { return $script:LinkTaskFor[$link].source }
        Internal-Error "read_a_link() passed a path that is scheduled for removal: $link"
    }
    if (Test-L $link) {
        Write-Dbg 4 2 "read_a_link(${link}): is a real link"
        $d = Read-Link $link
        if (-not $d) { Stow-Error "Could not read link: $link" }
        return $d
    }
    Internal-Error "read_a_link() passed a non-link path: $link"
}

# --- task scheduling (do_link / do_unlink / do_mkdir / do_rmdir / do_mv) -----
function Add-LinkTask([string]$linkDest, [string]$linkSrc) {
    if ($script:DirTaskFor.ContainsKey($linkSrc)) {
        $t = $script:DirTaskFor[$linkSrc]
        if ($t.action -eq 'create') {
            Internal-Error "new link ($linkSrc => $linkDest) clashes with planned new directory"
        }
    }
    if ($script:LinkTaskFor.ContainsKey($linkSrc)) {
        $t = $script:LinkTaskFor[$linkSrc]
        if ($t.action -eq 'create') {
            if ($t.source -ne $linkDest) {
                Internal-Error "new link clashes with planned new link: $($t.path) => $($t.source)"
            }
            Write-Dbg 1 0 "LINK: $linkSrc => $linkDest (duplicates previous action)"
            return
        }
        elseif ($t.action -eq 'remove') {
            if ($t.source -eq $linkDest) {
                Write-Dbg 1 0 "LINK: $linkSrc => $linkDest (reverts previous action)"
                $t.action = 'skip'
                $script:LinkTaskFor.Remove($linkSrc)
                return
            }
        }
    }
    Write-Dbg 1 0 "LINK: $linkSrc => $linkDest"
    $task = @{ action = 'create'; type = 'link'; path = $linkSrc; source = $linkDest }
    $script:Tasks.Add($task)
    $script:LinkTaskFor[$linkSrc] = $task
}

function Add-UnlinkTask([string]$file) {
    if ($script:LinkTaskFor.ContainsKey($file)) {
        $t = $script:LinkTaskFor[$file]
        if ($t.action -eq 'remove') {
            Write-Dbg 1 0 "UNLINK: $file (duplicates previous action)"
            return
        }
        elseif ($t.action -eq 'create') {
            Write-Dbg 1 0 "UNLINK: $file (reverts previous action)"
            $t.action = 'skip'
            $script:LinkTaskFor.Remove($file)
            return
        }
    }
    if ($script:DirTaskFor.ContainsKey($file) -and $script:DirTaskFor[$file].action -eq 'create') {
        Internal-Error "new unlink operation clashes with planned operation: create dir $file"
    }
    Write-Dbg 1 0 "UNLINK: $file"
    $source = Read-Link $file
    if (-not $source) { Stow-Error "could not readlink $file" }
    $task = @{ action = 'remove'; type = 'link'; path = $file; source = $source }
    $script:Tasks.Add($task)
    $script:LinkTaskFor[$file] = $task
}

function Add-MkdirTask([string]$dir) {
    if ($script:LinkTaskFor.ContainsKey($dir)) {
        $t = $script:LinkTaskFor[$dir]
        if ($t.action -eq 'create') {
            Internal-Error "new dir clashes with planned new link ($($t.path) => $($t.source))"
        }
    }
    if ($script:DirTaskFor.ContainsKey($dir)) {
        $t = $script:DirTaskFor[$dir]
        if ($t.action -eq 'create') {
            Write-Dbg 1 0 "MKDIR: $dir (duplicates previous action)"
            return
        }
        elseif ($t.action -eq 'remove') {
            Write-Dbg 1 0 "MKDIR: $dir (reverts previous action)"
            $t.action = 'skip'
            $script:DirTaskFor.Remove($dir)
            return
        }
    }
    Write-Dbg 1 0 "MKDIR: $dir"
    $task = @{ action = 'create'; type = 'dir'; path = $dir; source = $null }
    $script:Tasks.Add($task)
    $script:DirTaskFor[$dir] = $task
}

function Add-RmdirTask([string]$dir) {
    if ($script:LinkTaskFor.ContainsKey($dir)) {
        $t = $script:LinkTaskFor[$dir]
        Internal-Error "rmdir clashes with planned operation: $($t.action) link $($t.path) => $($t.source)"
    }
    if ($script:DirTaskFor.ContainsKey($dir)) {
        $t = $script:DirTaskFor[$dir]
        if ($t.action -eq 'remove') {
            Write-Dbg 1 0 "RMDIR $dir (duplicates previous action)"
            return
        }
        elseif ($t.action -eq 'create') {
            Write-Dbg 1 0 "MKDIR $dir (reverts previous action)"
            $t.action = 'skip'
            $script:DirTaskFor.Remove($dir)
            return
        }
    }
    Write-Dbg 1 0 "RMDIR $dir"
    $task = @{ action = 'remove'; type = 'dir'; path = $dir; source = '' }
    $script:Tasks.Add($task)
    $script:DirTaskFor[$dir] = $task
}

function Add-MoveTask([string]$src, [string]$dst) {
    if ($script:LinkTaskFor.ContainsKey($src)) {
        $t = $script:LinkTaskFor[$src]
        Internal-Error "do_mv: pre-existing link task for $src; action: $($t.action), source: $($t.source)"
    }
    if ($script:DirTaskFor.ContainsKey($src)) {
        Internal-Error "do_mv: pre-existing dir task for $src?! action: $($script:DirTaskFor[$src].action)"
    }
    Write-Dbg 1 0 "MV: $src -> $dst"
    $script:Tasks.Add(@{ action = 'move'; type = 'file'; path = $src; dest = $dst })
}

# --- ownership --------------------------------------------------------------
function Find-StowedPath([string]$targetSubpath, [string]$linkDest) {
    if (Test-AbsPath $linkDest) { return ,@('', '', '') }
    Write-Dbg 4 2 "find_stowed_path(target=$targetSubpath; source=$linkDest)"
    $pkgPathFromCwd = Join-StowPath (Get-StowParent $targetSubpath) $linkDest
    Write-Dbg 4 3 "is symlink destination $pkgPathFromCwd owned by stow?"
    $r = Get-LinkDestWithinStowDir $pkgPathFromCwd
    if ($r[0].Length) {
        Write-Dbg 4 3 "yes - package $($r[0]) in $($script:StowPath) may contain $($r[1])"
        return ,@($pkgPathFromCwd, $script:StowPath, $r[0])
    }
    $m = Find-ContainingMarkedStowDir $pkgPathFromCwd
    if ($m[0].Length) {
        Write-Dbg 5 5 "yes - $($m[0]) in $pkgPathFromCwd was marked as a stow dir; package=$($m[1])"
        return ,@($pkgPathFromCwd, $m[0], $m[1])
    }
    return ,@('', '', '')
}

function Get-LinkDestWithinStowDir([string]$linkDest) {
    Write-Dbg 4 4 "common prefix? link_dest=$linkDest; stow_path=$($script:StowPath)"
    $prefix = $script:StowPath + '/'
    if (-not $linkDest.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Dbg 4 3 "no - $linkDest not under $($script:StowPath)"
        return ,@('', '')
    }
    $rest = $linkDest.Substring($prefix.Length)
    Write-Dbg 4 4 "remaining after removing $($script:StowPath): $rest"
    $dirs = @($rest -split '/' | Where-Object { $_ -ne '' })
    $package = if ($dirs.Count) { $dirs[0] } else { '' }
    $sub = if ($dirs.Count -gt 1) { $dirs[1..($dirs.Count - 1)] -join '/' } else { '' }
    return ,@($package, $sub)
}

function Find-ContainingMarkedStowDir([string]$pkgPathFromCwd) {
    $segments = @($pkgPathFromCwd -split '/')
    for ($last = 0; $last -lt $segments.Count; $last++) {
        $prefixSegs = @($segments[0..$last])
        $p = Join-StowPath @prefixSegs
        if (Test-MarkedStowDir $p) {
            if ($last -eq $segments.Count - 1) { Internal-Error 'find_stowed_path() called directly on stow dir' }
            return ,@($p, $segments[$last + 1])
        }
    }
    return ,@('', '')
}

function Get-LinkOwner([string]$targetSubpath, [string]$linkDest) {
    return (Find-StowedPath $targetSubpath $linkDest)[2]
}

# --- stow -------------------------------------------------------------------
function Invoke-StowContents([string]$stowPath, [string]$package, [string]$pkgSubdir, [string]$targetSubdir) {
    if (Test-ShouldSkipTarget $pkgSubdir) { return }
    Write-Dbg 3 0 "Stowing contents of $stowPath / $package / $pkgSubdir (cwd=$($script:TargetAbs))"
    Write-Dbg 4 1 "target subdir is $targetSubdir"
    $pkgPathFromCwd = Join-StowPath $stowPath $package $pkgSubdir
    if (-not (Test-IsANode $targetSubdir)) {
        Stow-Error "stow_contents() called with non-directory target: $targetSubdir"
    }
    foreach ($node in (Get-Listing $pkgPathFromCwd)) {
        $packageNodePath = Join-StowPath $pkgSubdir $node
        $targetNode = $node
        $targetNodePath = Join-StowPath $targetSubdir $targetNode
        if (Test-Ignore $stowPath $package $targetNodePath) { continue }
        if ($script:O.dotfiles) {
            $adj = Get-AdjustedDotfile $node
            if ($adj -cne $node) {
                Write-Dbg 4 1 "Adjusting: $node => $adj"
                $targetNode = $adj
                $targetNodePath = Join-StowPath $targetSubdir $targetNode
            }
        }
        Invoke-StowNode $stowPath $package $packageNodePath $targetNodePath
    }
}

function Invoke-StowNode([string]$stowPath, [string]$package, [string]$pkgSubpath, [string]$targetSubpath) {
    Write-Dbg 3 0 "Stowing entry $stowPath / $package / $pkgSubpath"
    $pkgPathFromCwd = Join-StowPath $stowPath $package $pkgSubpath

    if (Test-L $pkgPathFromCwd) {
        $src = Read-Link $pkgPathFromCwd
        if (Test-AbsPath $src) {
            Add-Conflict 'stow' $package "source is an absolute symlink $pkgPathFromCwd => $src"
            Write-Dbg 3 0 'Absolute symlinks cannot be unstowed'
            return
        }
    }

    $level = ([regex]::Matches($pkgSubpath, '/')).Count
    Write-Dbg 2 1 "level of $pkgSubpath is $level"
    $linkDest = Join-StowPath ('../' * $level) $pkgPathFromCwd
    Write-Dbg 4 1 "link destination $linkDest"

    if (Test-IsALink $targetSubpath) {
        $existingLinkDest = Read-ALink $targetSubpath
        if (-not $existingLinkDest) { Stow-Error "Could not read link: $targetSubpath" }
        Write-Dbg 4 1 "Evaluate existing link: $targetSubpath => $existingLinkDest"
        $e = Find-StowedPath $targetSubpath $existingLinkDest
        $existingPkgPath = $e[0]; $existingStowPath = $e[1]; $existingPackage = $e[2]
        if (-not $existingPkgPath) {
            Add-Conflict 'stow' $package "existing target is not owned by stow: $targetSubpath"
            return
        }
        if (Test-IsANode $existingPkgPath) {
            if ($existingLinkDest -eq $linkDest) {
                Write-Dbg 2 0 "--- Skipping $targetSubpath as it already points to $linkDest"
            }
            elseif (Test-Defer $targetSubpath) {
                Write-Dbg 2 0 "--- Deferring installation of: $targetSubpath"
            }
            elseif (Test-Override $targetSubpath) {
                Write-Dbg 2 0 "--- Overriding installation of: $targetSubpath"
                Add-UnlinkTask $targetSubpath
                Add-LinkTask $linkDest $targetSubpath
            }
            elseif ((Test-IsADir (Join-StowPath (Get-StowParent $targetSubpath) $existingLinkDest)) -and
                    (Test-IsADir (Join-StowPath (Get-StowParent $targetSubpath) $linkDest))) {
                Write-Dbg 2 0 "--- Unfolding $targetSubpath which was already owned by $existingPackage"
                Add-UnlinkTask $targetSubpath
                Add-MkdirTask $targetSubpath
                Invoke-StowContents $existingStowPath $existingPackage $pkgSubpath $targetSubpath
                Invoke-StowContents $script:StowPath $package $pkgSubpath $targetSubpath
            }
            else {
                Add-Conflict 'stow' $package ("existing target is stowed to a different package: " +
                    "$targetSubpath => $existingLinkDest")
            }
        }
        else {
            Write-Dbg 2 0 "--- replacing invalid link: $targetSubpath"
            Add-UnlinkTask $targetSubpath
            Add-LinkTask $linkDest $targetSubpath
        }
    }
    elseif (Test-IsANode $targetSubpath) {
        Write-Dbg 4 1 "Evaluate existing node: $targetSubpath"
        if (Test-IsADir $targetSubpath) {
            if (-not (Test-D $pkgPathFromCwd)) {
                Add-Conflict 'stow' $package "cannot stow non-directory $pkgPathFromCwd over existing directory target $targetSubpath"
            }
            else {
                Invoke-StowContents $script:StowPath $package $pkgSubpath $targetSubpath
            }
        }
        else {
            if ($script:O.adopt) {
                if (Test-D $pkgPathFromCwd) {
                    Add-Conflict 'stow' $package "cannot stow directory $pkgPathFromCwd over existing non-directory target $targetSubpath"
                }
                else {
                    Add-MoveTask $targetSubpath $pkgPathFromCwd
                    Add-LinkTask $linkDest $targetSubpath
                }
            }
            else {
                Add-Conflict 'stow' $package "cannot stow $pkgPathFromCwd over existing target $targetSubpath since neither a link nor a directory and --adopt not specified"
            }
        }
    }
    elseif ($script:O['no-folding'] -and (Test-D $pkgPathFromCwd) -and -not (Test-L $pkgPathFromCwd)) {
        Add-MkdirTask $targetSubpath
        Invoke-StowContents $script:StowPath $package $pkgSubpath $targetSubpath
    }
    else {
        Add-LinkTask $linkDest $targetSubpath
    }
}

# --- unstow -----------------------------------------------------------------
function Invoke-UnstowContents([string]$package, [string]$pkgSubdir, [string]$targetSubdir) {
    if (Test-ShouldSkipTarget $targetSubdir) { return }
    $compat = [bool]$script:O.compat
    Write-Dbg 3 0 ("Unstowing contents of $($script:StowPath) / $package / $pkgSubdir (cwd=$($script:TargetAbs)" +
        $(if ($compat) { ', compat' } else { '' }) + ')')
    Write-Dbg 4 1 "target subdir is $targetSubdir"
    $pkgPathFromCwd = Join-StowPath $script:StowPath $package $pkgSubdir
    if ($compat) {
        if (-not (Test-D $targetSubdir)) {
            Stow-Error "unstow_contents() in compat mode called with non-directory target: $targetSubdir"
        }
    }
    else {
        if (-not (Test-D $pkgPathFromCwd)) { Stow-Error "unstow_contents() called with non-directory path: $pkgPathFromCwd" }
        if (-not (Test-IsANode $targetSubdir)) { Stow-Error "unstow_contents() called with invalid target: $targetSubdir" }
    }
    $dir = if ($compat) { $targetSubdir } else { $pkgPathFromCwd }
    foreach ($node in (Get-Listing $dir)) {
        $packageNode = $node
        $targetNode = $node
        $targetNodePath = Join-StowPath $targetSubdir $targetNode
        if (Test-Ignore $script:StowPath $package $targetNodePath) { continue }
        if ($script:O.dotfiles) {
            if ($compat) {
                $adj = Get-UnadjustedDotfile $node
                if ($adj -cne $node) {
                    Write-Dbg 4 1 "Reverse adjusting: $node => $adj"
                    $packageNode = $adj
                }
            }
            else {
                $adj = Get-AdjustedDotfile $node
                if ($adj -cne $node) {
                    Write-Dbg 4 1 "Adjusting: $node => $adj"
                    $targetNode = $adj
                    $targetNodePath = Join-StowPath $targetSubdir $targetNode
                }
            }
        }
        $packageNodePath = Join-StowPath $pkgSubdir $packageNode
        Invoke-UnstowNode $package $packageNodePath $targetNodePath
    }
    if (-not $compat -and (Test-D $targetSubdir)) {
        Invoke-CleanupInvalidLinks $targetSubdir
    }
}

function Invoke-UnstowNode([string]$package, [string]$pkgSubpath, [string]$targetSubpath) {
    Write-Dbg 3 0 "Unstowing entry from target: $targetSubpath"
    Write-Dbg 4 1 "Package entry: $($script:StowPath) / $package / $pkgSubpath"
    if (Test-IsALink $targetSubpath) {
        Invoke-UnstowLinkNode $package $pkgSubpath $targetSubpath
    }
    elseif (Test-D $targetSubpath) {
        Invoke-UnstowContents $package $pkgSubpath $targetSubpath
        $parentInPkg = Get-Foldable $targetSubpath
        if ($parentInPkg) { Invoke-FoldTree $targetSubpath $parentInPkg }
    }
    elseif (Test-E $targetSubpath) {
        Write-Dbg 2 1 "$targetSubpath doesn't need to be unstowed"
    }
    else {
        Write-Dbg 2 1 "$targetSubpath did not exist to be unstowed"
    }
}

function Invoke-UnstowLinkNode([string]$package, [string]$pkgSubpath, [string]$targetSubpath) {
    Write-Dbg 4 2 "Evaluate existing link: $targetSubpath"
    $linkDest = Read-ALink $targetSubpath
    if (-not $linkDest) { Stow-Error "Could not read link: $targetSubpath" }
    if (Test-AbsPath $linkDest) {
        Write-Warn "Ignoring an absolute symlink: $targetSubpath => $linkDest"
        return
    }
    $e = Find-StowedPath $targetSubpath $linkDest
    $existingPkgPath = $e[0]
    if (-not $existingPkgPath) {
        Write-Dbg 5 3 "Ignoring unowned link $targetSubpath => $linkDest"
        return
    }
    $pkgPathFromCwd = Join-StowPath $script:StowPath $package $pkgSubpath
    if (Test-E $existingPkgPath) {
        if ($existingPkgPath -eq $pkgPathFromCwd) {
            Add-UnlinkTask $targetSubpath
        }
        else {
            Write-Dbg 5 3 "Ignoring link $targetSubpath => $linkDest"
        }
    }
    else {
        Write-Dbg 2 0 "--- removing invalid link into a stow directory: $pkgPathFromCwd"
        Add-UnlinkTask $targetSubpath
    }
}

function Invoke-CleanupInvalidLinks([string]$dir) {
    Write-Dbg 2 0 "Cleaning up any invalid links in $dir (pwd=$($script:TargetAbs))"
    if (-not (Test-D $dir)) { Internal-Error "cleanup_invalid_links() called with a non-directory: $dir" }
    foreach ($node in (Get-Listing $dir)) {
        $nodePath = Join-StowPath $dir $node
        if (-not (Test-L $nodePath)) { continue }
        Write-Dbg 4 1 "Checking validity of link $nodePath"
        if ($script:LinkTaskFor.ContainsKey($nodePath)) {
            $a = $script:LinkTaskFor[$nodePath].action
            if ($a -ne 'remove') {
                Write-Warn "Unexpected action $a scheduled for $nodePath; skipping clean-up"
            } else {
                Write-Dbg 4 2 "$nodePath scheduled for removal; skipping clean-up"
            }
            continue
        }
        $linkDest = Read-Link $nodePath
        if (-not $linkDest) { Stow-Error "Could not read link $nodePath" }
        $targetSubpath = Join-StowPath $dir $linkDest
        Write-Dbg 4 2 "join $dir $linkDest"
        if (Test-E $targetSubpath) {
            Write-Dbg 4 2 "Link target $linkDest exists at $targetSubpath; skipping clean up"
            continue
        }
        Write-Dbg 4 2 "Link target $linkDest doesn't exist at $targetSubpath"
        Write-Dbg 3 1 "Checking whether valid link $nodePath -> $linkDest is owned by stow"
        $owner = Get-LinkOwner $nodePath $linkDest
        if ($owner) {
            Write-Dbg 2 0 "--- removing link owned by ${owner}: $nodePath => $(Join-StowPath $dir $linkDest)"
            Add-UnlinkTask $nodePath
        }
    }
}

function Get-Foldable([string]$targetSubdir) {
    Write-Dbg 3 2 "Is $targetSubdir foldable?"
    if ($script:O['no-folding']) {
        Write-Dbg 3 3 'Not foldable because --no-folding enabled'
        return ''
    }
    $parentInPkg = ''
    foreach ($node in (Get-Listing $targetSubdir)) {
        $targetNodePath = Join-StowPath $targetSubdir $node
        if (-not (Test-IsANode $targetNodePath)) { continue }
        if (-not (Test-IsALink $targetNodePath)) {
            Write-Dbg 3 3 "Not foldable because $targetNodePath not a link"
            return ''
        }
        $linkDest = Read-ALink $targetNodePath
        if (-not $linkDest) { Stow-Error "Could not read link $targetNodePath" }
        $newParent = Get-StowParent $linkDest
        if ($parentInPkg -eq '') {
            $parentInPkg = $newParent
        }
        elseif ($parentInPkg -ne $newParent) {
            Write-Dbg 3 3 "Not foldable because $targetSubdir contains links to entries in both $parentInPkg and $newParent"
            return ''
        }
    }
    if (-not $parentInPkg) {
        Write-Dbg 3 3 "Not foldable because $targetSubdir contains no links"
        return ''
    }
    $parentInPkg = $parentInPkg -replace '^\.\./', ''
    if (Get-LinkOwner $targetSubdir $parentInPkg) {
        Write-Dbg 3 3 "$targetSubdir is foldable"
        return $parentInPkg
    }
    Write-Dbg 3 3 "$targetSubdir is not foldable"
    return ''
}

function Invoke-FoldTree([string]$targetSubdir, [string]$pkgSubpath) {
    Write-Dbg 3 0 "--- Folding tree: $targetSubdir => $pkgSubpath"
    foreach ($node in (Get-Listing $targetSubdir)) {
        if (-not (Test-IsANode (Join-StowPath $targetSubdir $node))) { continue }
        Add-UnlinkTask (Join-StowPath $targetSubdir $node)
    }
    Add-RmdirTask $targetSubdir
    Add-LinkTask $pkgSubpath $targetSubdir
}

# --- plan / execute ---------------------------------------------------------
function Invoke-PlanUnstow([string[]]$packages) {
    if (-not $packages.Count) { return }
    Write-Dbg 2 0 "Planning unstow of: $($packages -join ' ') ..."
    Write-Dbg 3 0 "cwd now $($script:O.target)"
    foreach ($package in $packages) {
        if (-not (Test-D (Join-StowPath $script:StowPath $package))) {
            Stow-Error "The stow directory $($script:StowPath) does not contain package $package" 2
        }
        Write-Dbg 2 0 "Planning unstow of package $package..."
        Invoke-UnstowContents $package '.' '.'
        Write-Dbg 2 0 "Planning unstow of package $package... done"
    }
    Write-Dbg 3 0 "cwd restored to $($PWD.ProviderPath)"
}

function Invoke-PlanStow([string[]]$packages) {
    if (-not $packages.Count) { return }
    Write-Dbg 2 0 "Planning stow of: $($packages -join ' ') ..."
    Write-Dbg 3 0 "cwd now $($script:O.target)"
    foreach ($package in $packages) {
        if (-not (Test-D (Join-StowPath $script:StowPath $package))) {
            Stow-Error "The stow directory $($script:StowPath) does not contain package $package" 2
        }
        Write-Dbg 2 0 "Planning stow of package $package..."
        Invoke-StowContents $script:StowPath $package '.' '.'
        Write-Dbg 2 0 "Planning stow of package $package... done"
    }
    Write-Dbg 3 0 "cwd restored to $($PWD.ProviderPath)"
}

function Invoke-ProcessTasks {
    Write-Dbg 2 0 'Processing tasks...'
    $todo = @($script:Tasks | Where-Object { $_.action -ne 'skip' })
    if (-not $todo.Count) { return }
    Write-Dbg 3 0 "cwd now $($script:O.target)"
    foreach ($t in $todo) {
        $full = Get-FullPath $t.path
        switch ("$($t.action)/$($t.type)") {
            'create/dir' {
                if ($null -ne (Get-Attrs $full)) { Stow-Error "Could not create directory: $($t.path) (File exists)" }
                try { [void][IO.Directory]::CreateDirectory($full) }
                catch { Stow-Error "Could not create directory: $($t.path) ($($_.Exception.Message))" }
            }
            'create/link' {
                # Windows symlinks are typed: point at a directory -> directory link.
                $srcFull = [IO.Path]::GetFullPath([IO.Path]::Combine(
                    [IO.Path]::GetDirectoryName($full), ($t.source -replace '/', '\')))
                $fa = Get-FollowedAttrs $srcFull
                $flags = 0x2   # SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE
                if ($null -ne $fa -and ($fa -band [IO.FileAttributes]::Directory)) { $flags = $flags -bor 0x1 }
                if (-not [WinStow.Native]::CreateSymbolicLink($full, ($t.source -replace '/', '\'), $flags)) {
                    $err = New-Object ComponentModel.Win32Exception ([Runtime.InteropServices.Marshal]::GetLastWin32Error())
                    $hint = if ($err.NativeErrorCode -eq 1314) { ' - enable Developer Mode or run elevated' } else { '' }
                    Stow-Error "Could not create symlink: $($t.path) => $($t.source) ($($err.Message)$hint)"
                }
            }
            'remove/dir' {
                try { [IO.Directory]::Delete($full, $false) }
                catch { Stow-Error "Could not remove directory: $($t.path) ($($_.Exception.Message))" }
            }
            'remove/link' {
                try {
                    $a = Get-Attrs $full
                    # Delete the link itself, never what it points to.
                    if ($null -ne $a -and ($a -band [IO.FileAttributes]::Directory)) { [IO.Directory]::Delete($full, $false) }
                    else { [IO.File]::Delete($full) }
                }
                catch { Stow-Error "Could not remove link: $($t.path) ($($_.Exception.Message))" }
            }
            'move/file' {
                $dst = Get-FullPath $t.dest
                try {
                    if ([IO.File]::Exists($dst)) { [IO.File]::Delete($dst) }
                    [IO.File]::Move($full, $dst)
                }
                catch { Stow-Error "Could not move $($t.path) -> $($t.dest) ($($_.Exception.Message))" }
            }
            default { Internal-Error "bad task action: $($t.action)" }
        }
    }
    Write-Dbg 3 0 "cwd restored to $($PWD.ProviderPath)"
    Write-Dbg 2 0 'Processing tasks... done'
}

# ---------------------------------------------------------------------------
# CLI (bin/stow): Getopt::Long with bundling, no_ignore_case, permute
# ---------------------------------------------------------------------------
function Show-Usage($msg) {
    # $null = --help (exit 0); '' or a message = usage error (exit 1).
    if ($null -ne $msg -and $msg.Length) { Write-Warn "${script:ProgramName}: $msg`n" }
    $p = $script:ProgramName
    [Console]::Out.WriteLine(@"
$p (GNU Stow) version $($script:Version) (PowerShell port)

SYNOPSIS:

    $p [OPTION ...] [-D|-S|-R] PACKAGE ... [-D|-S|-R] PACKAGE ...

OPTIONS:

    -d DIR, --dir=DIR     Set stow dir to DIR (default is current dir)
    -t DIR, --target=DIR  Set target to DIR (default is parent of stow dir)

    -S, --stow            Stow the package names that follow this option
    -D, --delete          Unstow the package names that follow this option
    -R, --restow          Restow (like stow -D followed by stow -S)

    --ignore=REGEX        Ignore files ending in this Perl regex
    --defer=REGEX         Don't stow files beginning with this Perl regex
                          if the file is already stowed to another package
    --override=REGEX      Force stowing files beginning with this Perl regex
                          if the file is already stowed to another package
    --adopt               (Use with care!)  Import existing files into stow package
                          from target.  Please read docs before using.
    --dotfiles            Enables special handling for dotfiles that are
                          Stow packages that start with "dot-" and not "."
    -p, --compat          Use legacy algorithm for unstowing

    -n, --no, --simulate  Do not actually make any filesystem changes
    -v, --verbose[=N]     Increase verbosity (levels are from 0 to 5;
                            -v or --verbose adds 1; --verbose=N sets level)
    -V, --version         Show stow version number
    -h, --help            Show this help

Symlinks need Windows Developer Mode or an elevated shell.
Stow home page: <http://www.gnu.org/software/stow/>
"@)
    exit $(if ($null -ne $msg) { 1 } else { 0 })
}

$script:LongOpts = [ordered]@{
    'verbose' = 'verbose'; 'help' = 'help'; 'simulate' = 'simulate'; 'no' = 'simulate'
    'version' = 'version'; 'compat' = 'compat'; 'dir' = 'dir'; 'target' = 'target'
    'adopt' = 'adopt'; 'no-folding' = 'no-folding'; 'dotfiles' = 'dotfiles'
    'ignore' = 'ignore'; 'override' = 'override'; 'defer' = 'defer'
    'delete' = 'D'; 'stow' = 'S'; 'restow' = 'R'
}
# Case-sensitive (no_ignore_case): -v is verbose, -V is version.
$script:ShortOpts = New-Object Collections.Hashtable ([StringComparer]::Ordinal)
foreach ($kv in @(('v', 'verbose'), ('h', 'help'), ('n', 'simulate'), ('V', 'version'), ('p', 'compat'),
                  ('d', 'dir'), ('t', 'target'), ('D', 'D'), ('S', 'S'), ('R', 'R'))) {
    $script:ShortOpts[$kv[0]] = $kv[1]
}
$script:ValueOpts = @('dir', 'target', 'ignore', 'override', 'defer')

function ConvertFrom-StowArgs([string[]]$argv) {
    $opts = @{}
    $unstow = New-Object System.Collections.Generic.List[string]
    $stow = New-Object System.Collections.Generic.List[string]
    $action = 'stow'
    $bad = $false

    $apply = {
        param($name, $value, $hasValue)
        switch ($name) {
            'verbose' {
                if ($hasValue) { $opts['verbose'] = [int]$value }
                else { $opts['verbose'] = 1 + $(if ($opts.ContainsKey('verbose')) { $opts['verbose'] } else { 0 }) }
            }
            'ignore'   { if (-not $opts.ContainsKey('ignore'))   { $opts['ignore']   = @() }; $opts['ignore']   += [regex]"($value)\z" }
            'override' { if (-not $opts.ContainsKey('override')) { $opts['override'] = @() }; $opts['override'] += [regex]"\A($value)" }
            'defer'    { if (-not $opts.ContainsKey('defer'))    { $opts['defer']    = @() }; $opts['defer']    += [regex]"\A($value)" }
            'D' { Set-Variable -Scope 1 action 'unstow' }
            'S' { Set-Variable -Scope 1 action 'stow' }
            'R' { Set-Variable -Scope 1 action 'restow' }
            default { $opts[$name] = $(if ($hasValue) { $value } else { 1 }) }
        }
    }
    $addPkg = {
        param($pkg)
        if ($action -eq 'restow') { $unstow.Add($pkg); $stow.Add($pkg) }
        elseif ($action -eq 'unstow') { $unstow.Add($pkg) }
        else { $stow.Add($pkg) }
    }

    $i = 0
    $endOfOpts = $false
    while ($i -lt $argv.Count) {
        $a = $argv[$i]; $i++
        if ($endOfOpts -or $a -eq '-' -or -not $a.StartsWith('-')) { & $addPkg $a; continue }
        if ($a -eq '--') { $endOfOpts = $true; continue }

        if ($a.StartsWith('--')) {
            $body = $a.Substring(2)
            $val = $null; $hasVal = $false
            $eq = $body.IndexOf('=')
            if ($eq -ge 0) { $val = $body.Substring($eq + 1); $body = $body.Substring(0, $eq); $hasVal = $true }
            # Getopt::Long auto_abbrev: exact match, else unique prefix.
            $name = $null
            if ($script:LongOpts.Contains($body)) { $name = $script:LongOpts[$body] }
            else {
                $cands = @($script:LongOpts.Keys | Where-Object { $_.StartsWith($body, [StringComparison]::Ordinal) })
                $targets = @($cands | ForEach-Object { $script:LongOpts[$_] } | Select-Object -Unique)
                if ($body.Length -and $targets.Count -eq 1) { $name = $targets[0] }
                elseif ($targets.Count -gt 1) {
                    Write-Warn "Option $body is ambiguous ($($cands -join ', '))"; $bad = $true; continue
                }
            }
            if (-not $name) { Write-Warn "Unknown option: $body"; $bad = $true; continue }
            if ($name -in $script:ValueOpts) {
                if (-not $hasVal) {
                    if ($i -ge $argv.Count) { Write-Warn "Option $body requires an argument"; $bad = $true; continue }
                    $val = $argv[$i]; $i++
                }
                & $apply $name $val $true
            }
            elseif ($name -eq 'verbose') {
                if (-not $hasVal -and $i -lt $argv.Count -and $argv[$i] -match '^\d+$') { $val = $argv[$i]; $i++; $hasVal = $true }
                if ($hasVal -and $val -notmatch '^-?\d+$') { Write-Warn "Value `"$val`" invalid for option verbose (number expected)"; $bad = $true; continue }
                & $apply $name $val $hasVal
            }
            else {
                if ($hasVal) { Write-Warn "Option $body does not take an argument"; $bad = $true; continue }
                & $apply $name $null $false
            }
            continue
        }

        # Bundled short options: -nvS, -tDIR, -t DIR, -v3
        $k = 1
        while ($k -lt $a.Length) {
            $c = [string]$a[$k]; $k++
            $name = $script:ShortOpts[$c]
            if (-not $name) { Write-Warn "Unknown option: $c"; $bad = $true; continue }
            if ($name -in $script:ValueOpts) {
                if ($k -lt $a.Length) { $val = $a.Substring($k) }
                elseif ($i -lt $argv.Count) { $val = $argv[$i]; $i++ }
                else { Write-Warn "Option $c requires an argument"; $bad = $true; break }
                & $apply $name $val $true
                break
            }
            elseif ($name -eq 'verbose' -and $k -lt $a.Length -and $a.Substring($k) -match '^\d+$') {
                & $apply $name $a.Substring($k) $true
                break
            }
            else { & $apply $name $null $false }
        }
    }
    if ($bad) { Show-Usage '' }
    return @{ opts = $opts; unstow = $unstow.ToArray(); stow = $stow.ToArray() }
}

function Split-ShellWords([string]$line) {
    $words = @(); $cur = $null; $q = $null
    for ($i = 0; $i -lt $line.Length; $i++) {
        $c = $line[$i]
        if ($q) {
            if ($c -eq $q) { $q = $null }
            elseif ($c -eq '\' -and $q -eq '"' -and $i + 1 -lt $line.Length) { $i++; $cur += $line[$i] }
            else { $cur += $c }
        }
        elseif ($c -eq "'" -or $c -eq '"') { $q = $c; if ($null -eq $cur) { $cur = '' } }
        elseif ($c -eq '\' -and $i + 1 -lt $line.Length) { $i++; if ($null -eq $cur) { $cur = '' }; $cur += $line[$i] }
        elseif ([char]::IsWhiteSpace($c)) { if ($null -ne $cur) { $words += $cur; $cur = $null } }
        else { if ($null -eq $cur) { $cur = '' }; $cur += $c }
    }
    if ($null -ne $cur) { $words += $cur }
    return ,$words
}

function Expand-FilePath([string]$path, [string]$source) {
    $expand = {
        param($m)
        $v = [Environment]::GetEnvironmentVariable($m.Groups[1].Value)
        if ($null -eq $v) {
            throw [StowError]::new("$source references undefined environment variable `$$($m.Groups[1].Value); aborting!")
        }
        $v
    }
    $path = [regex]::Replace($path, '(?<!\\)\$\{([\w\s]+)\}', $expand)
    $path = [regex]::Replace($path, '(?<!\\)\$(\w+)', $expand)
    $path = $path -replace '\\\$', '$'
    return (Expand-Tilde $path)
}

function Expand-Tilde([string]$path) {
    if ($path -match '^~(?=$|[/\\])') { $path = $script:HomeDir + $path.Substring(1) }
    return ($path -replace '\\~', '~')
}

function Get-StowOptions([string[]]$argv) {
    $cli = ConvertFrom-StowArgs $argv
    if ($cli.opts.ContainsKey('help')) { Show-Usage $null }
    if ($cli.opts.ContainsKey('version')) {
        [Console]::Out.WriteLine("$($script:ProgramName) (GNU Stow) version $($script:Version) (PowerShell port)")
        exit 0
    }

    # ~/.stowrc then ./.stowrc; CLI wins, list options accumulate.
    $rcWords = @()
    foreach ($f in @((Join-Path $script:HomeDir '.stowrc'), (Join-Path $PWD.ProviderPath '.stowrc'))) {
        if (Test-Path -LiteralPath $f -PathType Leaf) {
            foreach ($line in [IO.File]::ReadAllLines($f)) { $rcWords += Split-ShellWords $line }
        }
    }
    $rc = (ConvertFrom-StowArgs $rcWords).opts
    if ($rc.ContainsKey('target')) { $rc['target'] = Expand-FilePath $rc['target'] '--target option' }
    if ($rc.ContainsKey('dir'))    { $rc['dir']    = Expand-FilePath $rc['dir'] '--dir option' }

    $o = @{}
    foreach ($k in $rc.Keys) { $o[$k] = $rc[$k] }
    foreach ($k in $cli.opts.Keys) {
        if ($cli.opts[$k] -is [array] -and $rc.ContainsKey($k)) { $o[$k] = @($rc[$k]) + @($cli.opts[$k]) }
        else { $o[$k] = $cli.opts[$k] }
    }
    foreach ($k in @('ignore', 'override', 'defer')) { if (-not $o.ContainsKey($k)) { $o[$k] = @() } }
    foreach ($k in @('verbose', 'simulate', 'compat', 'adopt', 'no-folding', 'dotfiles')) {
        if (-not $o.ContainsKey($k)) { $o[$k] = 0 }
    }
    if ($cli.opts.ContainsKey('dir'))    { $o['dir']    = Expand-Tilde $o['dir'] }
    if ($cli.opts.ContainsKey('target')) { $o['target'] = Expand-Tilde $o['target'] }

    # sanitize_path_options
    if (-not $o.ContainsKey('dir')) {
        $o['dir'] = if ($env:STOW_DIR) { $env:STOW_DIR } else { $PWD.ProviderPath }
    }
    if (-not (Test-Path -LiteralPath $o['dir'] -PathType Container)) {
        Show-Usage "--dir value '$($o['dir'])' is not a valid directory"
    }
    if ($o.ContainsKey('target')) {
        if (-not (Test-Path -LiteralPath $o['target'] -PathType Container)) {
            Show-Usage "--target value '$($o['target'])' is not a valid directory"
        }
    }
    else {
        $parent = Split-Path -Path ($o['dir'] -replace '(?<=.)[/\\]+$', '') -Parent
        $o['target'] = if ($parent) { $parent } else { '.' }
    }

    # check_packages
    $unstow = @(); $stow = @()
    foreach ($pair in @(@('unstow', $cli.unstow), @('stow', $cli.stow))) {
        foreach ($pkg in $pair[1]) {
            $pkg = $pkg -replace '[/\\]+$', ''
            if ($pkg -match '[/\\]') { Stow-Error 'Slashes are not permitted in package names' }
            if ($pair[0] -eq 'unstow') { $unstow += $pkg } else { $stow += $pkg }
        }
    }
    if (-not $unstow.Count -and -not $stow.Count) { Show-Usage 'No packages to stow or unstow' }
    return @{ opts = $o; unstow = $unstow; stow = $stow }
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
$script:HomeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }

$argv = @($args | ForEach-Object { $_ } | ForEach-Object { [string]$_ })
try {
    $parsed = Get-StowOptions $argv
    $script:O = $parsed.opts
    $script:DebugLevel = [int]$script:O.verbose

    $stowDir = Resolve-AbsDir $script:O.dir
    $script:TargetAbs = Resolve-AbsDir $script:O.target
    $script:StowPath = Get-RelPath $stowDir $script:TargetAbs
    Write-Dbg 2 0 "stow dir is $stowDir"
    Write-Dbg 2 0 "stow dir path relative to target $($script:TargetAbs) is $($script:StowPath)"

    Invoke-PlanUnstow $parsed.unstow
    Invoke-PlanStow $parsed.stow

    if ($script:ConflictCount) {
        foreach ($action in @('unstow', 'stow')) {
            if (-not $script:Conflicts.Contains($action)) { continue }
            foreach ($package in ($script:Conflicts[$action].Keys | Sort-Object)) {
                Write-Warn "WARNING! ${action}ing $package would cause conflicts:"
                foreach ($m in ($script:Conflicts[$action][$package] | Sort-Object)) { Write-Warn "  * $m" }
            }
        }
        Write-Warn 'All operations aborted.'
        exit 1
    }
    if ($script:O.simulate) {
        Write-Warn 'WARNING: in simulation mode so not modifying filesystem.'
        exit 0
    }
    Invoke-ProcessTasks
    exit 0
}
catch [StowError] {
    Write-Warn $_.Exception.Message
    exit $_.Exception.ExitCode
}
catch {
    $e = $_.Exception
    while ($e -is [Management.Automation.MethodInvocationException] -and $e.InnerException) { $e = $e.InnerException }
    Write-Warn "${script:ProgramName}: ERROR: $($e.Message)"
    Write-Dbg 1 0 $_.ScriptStackTrace
    exit 255
}
