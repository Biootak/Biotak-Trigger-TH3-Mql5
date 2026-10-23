# audit-all.ps1 - the ONE parity gate. Run it after every change.
#
# Five checks, in the order that answers the cheapest question first. Together
# they cover every blind spot the plain line comparison leaves open:
#
#   1. module-report   the line multiset per module (the baseline verdict)
#   2. rewrite-audit   the 71 declared symbol rewrites   (call set, not lines)
#   3. patch-audit     the 97 declared patch blocks      (call set, not lines)
#   4. resource-audit  the #resource directives          (the preprocessor blind spot)
#   5. property-audit  #define VALUES + OBJPROP_* writes (a constant or a write)
#   6. objprop-audit   accessor TYPE per property        (a silent no-op write)
#
# WHY A GATE AND NOT A HABIT: four real defects on 2026-10-23 each sat in a
# different one of these holes - LAST OBJECT's missing same-event refresh (2),
# the BaseKnot box dropping its own selection (3/6), the strip's blank anchor
# cell (4), and the halved drag cadence (5). A check nobody runs is a blind spot
# with a report attached.
#
# AND ITS LIMIT, STATED SO NOBODY READS GREEN AS "PROVEN": these checks prove
# the mirror is the SAME as MT4 and that no call uses an accessor the property
# cannot answer. They cannot prove a shared line is CORRECT - MT4 and MT5 can be
# wrong together, and a platform can change a behaviour under unchanged code
# (the selection drop is exactly that). Every escape so far needed a NEW rule,
# not a better diff; when one is found, name the class here, add its check, and
# make the fix a declared patch so the same line can never slip again silently.
#
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File tools/parity/audit-all.ps1
#         ... -Quiet      # one line per check
# Read-only. Never writes to either tree.

[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$py = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $py) { throw "python not found on PATH" }

$checks = @(
    @{ name = 'module-report  (line multiset)'; script = 'module-report.py'; args = @('--quiet') },
    @{ name = 'rewrite-audit  (declared rewrites)'; script = 'rewrite-audit.py'; args = @() },
    @{ name = 'patch-audit    (declared patches)'; script = 'patch-audit.py'; args = @() },
    @{ name = 'resource-audit (#resource)'; script = 'resource-audit.py'; args = @('--quiet') },
    @{ name = 'property-audit (#define + OBJPROP)'; script = 'property-audit.py'; args = @('--defines') },
    @{ name = 'objprop-audit  (accessor types)'; script = 'objprop-audit.py'; args = @() }
)

$verdicts = @()
foreach ($c in $checks) {
    $out = & $py (Join-Path $here $c.script) @($c.args) 2>&1
    $code = $LASTEXITCODE
    $tail = @($out | Where-Object { $_ -match 'VERDICT|checked:|declared patches:|resources missing|define values|wrong accessor|MT4-ONLY|MT5-ONLY' })
    $verdicts += [pscustomobject]@{ check = $c.name; exit = $code; detail = ($tail -join ' | ') }
    if (-not $Quiet) {
        Write-Host ""
        Write-Host ("=" * 78)
        Write-Host $c.name
        Write-Host ("=" * 78)
        $out | ForEach-Object { Write-Host $_ }
    }
}

Write-Host ""
Write-Host ("=" * 78)
Write-Host "PARITY GATE"
Write-Host ("=" * 78)
$fail = 0
foreach ($v in $verdicts) {
    $mark = if ($v.exit -eq 0) { 'PASS' } else { $fail++; 'FAIL' }
    Write-Host ("  {0}  {1,-42} {2}" -f $mark, $v.check, $v.detail)
}
Write-Host ""
# module-report and resource-audit return non-zero only on a real verdict; the
# three audits are REVIEW lists, so their exit code is reported, not enforced.
Write-Host ("gate: {0}" -f $(if ($fail -eq 0) { 'all checks ran; review the FAIL lines above' } else { "$fail check(s) reported work" }))
exit $fail
