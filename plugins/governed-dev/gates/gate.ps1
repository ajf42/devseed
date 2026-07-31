# gate.ps1 -- PowerShell shim for gate.sh.
#
# The gate is bash (DESIGN.md §3, ADR-0006). On Windows, Claude Code runs hooks
# under PowerShell when Git Bash is not installed -- in which case a bash-only
# gate would not run at all, which is verbatim the failure §3 names. This shim
# closes that hole: it finds a bash and hands off, or fails loudly with install
# instructions. It never silently skips.
#
# Exit codes match gate.sh: 0 pass, 2 fail. Never 1 -- Claude Code treats exit 1
# as non-blocking and proceeds.
#
# Usage:  powershell -File gate.ps1 [--fast]

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$gate = Join-Path $here 'gate.sh'

if (-not (Test-Path $gate)) {
    [Console]::Error.WriteLine("GATE FAIL: $gate is missing. The gate is incomplete; restore it rather than skipping.")
    exit 2
}

# Ordered by preference: PATH first, then the standard Git for Windows installs.
$candidates = @()
$onPath = Get-Command bash -ErrorAction SilentlyContinue
if ($onPath) { $candidates += $onPath.Source }
$candidates += "$env:ProgramFiles\Git\bin\bash.exe"
$candidates += "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
$candidates += "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"

$bash = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $bash) {
    [Console]::Error.WriteLine(@"
GATE FAIL: no bash found, so the gate cannot run.

The gate is a bash script and Git Bash is a stated prerequisite on Windows
(DESIGN.md §3). A check that cannot run is a failed check, so this is exit 2
rather than a skip.

Install Git for Windows, which provides Git Bash:
  winget install --id Git.Git -e
  or download from https://git-scm.com/download/win

Then re-run the gate.
"@)
    exit 2
}

& $bash $gate @args
exit $LASTEXITCODE
