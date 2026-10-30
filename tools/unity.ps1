#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Doctor','Open','Compile','EditMode','PlayMode','Check','Logs')]
    [string]$Task = 'Doctor',
    [string]$ProjectPath = (Split-Path $PSScriptRoot -Parent),
    [string]$UnityPath = $env:UNITY_EDITOR_PATH,
    [ValidateRange(1,86400)][int]$TimeoutSeconds = 900,
    [ValidateRange(1,10000)][int]$Tail = 100
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runDir = $null
$gate = $null
$summary = [ordered]@{ schemaVersion=1; task=$Task; status='failed'; exitCode=1; steps=@(); error=$null }

function Get-Editor([string]$Version) {
    if ($UnityPath) {
        if (!(Test-Path -LiteralPath $UnityPath -PathType Leaf)) { throw "Editor not found: $UnityPath" }
        return (Resolve-Path -LiteralPath $UnityPath).Path
    }
    $base = ${env:ProgramFiles}
    if (!$base) { throw 'Set -UnityPath or UNITY_EDITOR_PATH to Unity.exe.' }
    $candidate = Join-Path $base "Unity/Hub/Editor/$Version/Editor/Unity.exe"
    if (!(Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "Install Unity $Version using Hub, or set -UnityPath." }
    return $candidate
}

function Write-Json($Value, [string]$Path) {
    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-EditorStep([string]$Name) {
    $log = Join-Path $runDir "$Name.log"
    $xml = Join-Path $runDir "$Name.xml"
    $marker = Join-Path $runDir "$Name.complete"
    $arguments = @('-projectPath', $root, '-batchmode', '-logFile', $log)
    if ($Name -eq 'Compile') {
        $arguments += @('-nographics','-executeMethod','Harness.Editor.HarnessCommands.Compile','-harnessMarker',$marker,'-quit')
    } else {
        # Test Runner owns shutdown. -quit can terminate before tests finish.
        $arguments += @('-runTests','-testPlatform',$Name,'-testResults',$xml)
    }
    $step = [ordered]@{ name=$Name; status='failed'; editorExitCode=$null; log=$log; results=$null; error=$null }
    $summary.steps += $step
    $process = $null
    try {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $editor
        # Unity arguments never end in a slash or contain a literal quote.
        foreach ($arg in $arguments) {
            if ($arg.Contains('"') -or $arg.EndsWith('\')) { throw "Unsupported argument: $arg" }
        }
        $info.Arguments = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
        $info.UseShellExecute = $false
        $process = [System.Diagnostics.Process]::Start($info)
        if (!$process.WaitForExit($TimeoutSeconds * 1000)) {
            # Kill only the process tree started by this step; never all Unity processes.
            if ($env:OS -eq 'Windows_NT') {
                & taskkill.exe /PID $process.Id /T /F | Out-Null
            } else { $process.Kill() }
            if (!$process.WaitForExit(10000)) {
                throw "Timeout; process $($process.Id) could not be stopped. Check it manually."
            }
            throw "Timeout after $TimeoutSeconds seconds."
        }
        $step.editorExitCode = $process.ExitCode
        if ($process.ExitCode -ne 0) { throw "Unity exited with code $($process.ExitCode)." }
        if (!(Test-Path -LiteralPath $log)) { throw 'Unity did not produce a log.' }
        if ($Name -eq 'Compile') {
            if (!(Test-Path -LiteralPath $marker)) { throw 'Compile method did not complete.' }
        } else {
            if (!(Test-Path -LiteralPath $xml)) { throw 'Test results are missing.' }
            $step.results = $xml
            [xml]$report = Get-Content -LiteralPath $xml -Raw
            $testRun = $report.SelectSingleNode('/test-run')
            if (!$testRun) { throw 'Invalid NUnit test report.' }
            $count = 0
            if (![int]::TryParse($testRun.GetAttribute('total'), [ref]$count) -or $count -le 0) {
                throw 'No tests were executed.'
            }
            if ($testRun.GetAttribute('result') -ne 'Passed' -or $testRun.GetAttribute('failed') -ne '0') {
                throw "Tests did not pass: $($testRun.GetAttribute('result'))."
            }
        }
        $step.status = 'passed'
    } catch {
        $step.error = $_.Exception.Message
        throw
    } finally {
        if ($process) { $process.Dispose() }
        Write-Json $step (Join-Path $runDir "$Name.json")
        if (Test-Path -LiteralPath $log) {
            Select-String -LiteralPath $log -Pattern 'error CS\d+|Exception:|error |failed|Aborting batchmode' |
                Select-Object -Last 60 | ForEach-Object { $_.Line } |
                Set-Content -LiteralPath (Join-Path $runDir "$Name.diagnostics.txt") -Encoding UTF8
        }
    }
}

try {
    $root = (Resolve-Path -LiteralPath $ProjectPath).Path.TrimEnd('\','/')
    $versionFile = Join-Path $root 'ProjectSettings/ProjectVersion.txt'
    if (!(Test-Path -LiteralPath $versionFile)) { throw 'ProjectVersion.txt is missing.' }
    $versionText = Get-Content -LiteralPath $versionFile -Raw
    if ($versionText -notmatch '(?m)^m_EditorVersion:\s*(\S+)') { throw 'Cannot read Unity version.' }
    $version = $Matches[1]
    $artifacts = Join-Path $root 'artifacts/harness'
    if ($Task -eq 'Logs') {
        $latest = Get-Content -LiteralPath (Join-Path $artifacts 'latest.json') -Raw | ConvertFrom-Json
        Get-Content -LiteralPath (Join-Path $latest.directory 'summary.json') -Raw
        Get-ChildItem -LiteralPath $latest.directory -Filter '*.log' | ForEach-Object {
            Write-Output "--- $($_.Name) ---"
            Get-Content -LiteralPath $_.FullName -Tail $Tail
        }
        exit 0
    }
    $runDir = Join-Path $artifacts ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    $summary['directory'] = $runDir
    $summary['unityVersion'] = $version
    # Serialize harness invocations even before Unity creates UnityLockfile.
    $gate = [System.IO.File]::Open((Join-Path $artifacts 'session.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    if (Test-Path -LiteralPath (Join-Path $root 'Temp/UnityLockfile')) {
        throw 'Project is open or has a stale UnityLockfile. Close the Editor; do not auto-delete its lock.'
    }
    $editor = Get-Editor $version
    $summary['editor'] = $editor
    if ($Task -eq 'Doctor') {
        foreach ($required in @('Assets','Packages/manifest.json')) {
            if (!(Test-Path -LiteralPath (Join-Path $root $required))) { throw "Missing: $required" }
        }
        Write-Output "Project: $root`nRequired Unity: $version`nEditor: $editor"
    } elseif ($Task -eq 'Open') {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $editor
        if ($root.Contains('"')) { throw 'Project path cannot contain a quote.' }
        $info.Arguments = '-projectPath "' + $root + '" -logFile "' + (Join-Path $runDir 'Editor.log') + '"'
        $info.UseShellExecute = $false
        $p = [System.Diagnostics.Process]::Start($info)
        $summary['editorPid'] = $p.Id
        $p.Dispose()
        # Open reports launch only, not import/compile or test success.
        $summary.status = 'launched'
    } else {
        $steps = if ($Task -eq 'Check') { @('Compile','EditMode','PlayMode') } else { @($Task) }
        foreach ($name in $steps) { Invoke-EditorStep $name }
    }
    if ($summary.status -ne 'launched') { $summary.status = 'passed' }
    $summary.exitCode = 0
} catch {
    $summary.error = $_.Exception.Message
    [Console]::Error.WriteLine($summary.error)
} finally {
    if ($runDir) {
        Write-Json $summary (Join-Path $runDir 'summary.json')
        # A rejected competing invocation must not replace the active run pointer.
        if ($gate) { Write-Json @{ directory=$runDir } (Join-Path $artifacts 'latest.json') }
        Write-Output "Summary: $(Join-Path $runDir 'summary.json')"
    }
    if ($gate) { $gate.Dispose() }
}
exit $summary.exitCode
