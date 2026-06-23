param(
    [string]$BuildType = "Release",
    [string]$BuildDir = "",
    [ValidateSet("Ninja", "NMake Makefiles")]
    [string]$Generator = "Ninja",
    [string]$RexGluePrefix = "tools\rexglue-sdk\out\install\win-amd64-nmake",
    [string]$CompilerFlags = "-mssse3",
    [int]$Jobs = 4,
    [string]$LogFile = "",
    [int]$NativeStallTimeoutSeconds = 180,
    [switch]$Regenerate,
    [switch]$Configure,
    [switch]$SkipGeneratedWorkarounds
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-RepoPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path $repoRoot $Path
}

if (-not $BuildDir) {
    $generatorName = if ($Generator -eq "Ninja") { "ninja" } else { "nmake" }
    $BuildDir = "build\l40-$generatorName-$($BuildType.ToLowerInvariant())"
}

$buildPath = Resolve-RepoPath $BuildDir
if (-not $LogFile) {
    $LogFile = Join-Path $buildPath "build.log"
} else {
    $LogFile = Resolve-RepoPath $LogFile
}

New-Item -ItemType Directory -Force -Path $buildPath | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LogFile) | Out-Null

function Write-BuildLog([string]$Message) {
    $line = "[$(Get-Date -Format o)] $Message"
    $line | Out-File -FilePath $LogFile -Append -Encoding utf8
}

function Show-LogTail {
    if (Test-Path -LiteralPath $LogFile) {
        Write-Host "Last 80 build log lines from $LogFile"
        Get-Content -LiteralPath $LogFile -Tail 80
    }
}

function ConvertTo-NativeArgument([string]$Argument) {
    if ($null -eq $Argument) {
        return '""'
    }
    if ($Argument -notmatch '[\s"]') {
        return $Argument
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashes = 0
    foreach ($char in $Argument.ToCharArray()) {
        if ($char -eq '\') {
            $backslashes++
            continue
        }
        if ($char -eq '"') {
            [void]$builder.Append("\" * (($backslashes * 2) + 1))
            [void]$builder.Append('"')
            $backslashes = 0
            continue
        }
        if ($backslashes -gt 0) {
            [void]$builder.Append("\" * $backslashes)
            $backslashes = 0
        }
        [void]$builder.Append($char)
    }
    if ($backslashes -gt 0) {
        [void]$builder.Append("\" * ($backslashes * 2))
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Get-ChildProcessIds([int]$ParentProcessId) {
    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ParentProcessId" -ErrorAction SilentlyContinue)
    foreach ($child in $children) {
        [int]$child.ProcessId
        Get-ChildProcessIds ([int]$child.ProcessId)
    }
}

function Get-TrackedProcesses([int]$RootProcessId) {
    $ids = @($RootProcessId) + @(Get-ChildProcessIds $RootProcessId)
    $ids = $ids | Sort-Object -Unique
    foreach ($id in $ids) {
        Get-Process -Id $id -ErrorAction SilentlyContinue
    }
}

function Stop-ProcessTree([int]$RootProcessId) {
    $ids = @($RootProcessId) + @(Get-ChildProcessIds $RootProcessId)
    $ids | Sort-Object -Descending -Unique | ForEach-Object {
        Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-LoggedNative([string]$Label, [string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory = "") {
    Write-Host "$Label (logging to $LogFile)"
    Write-BuildLog "$Label`: $FilePath $($Arguments -join ' ')"
    $safeLabel = $Label -replace "[^A-Za-z0-9_.-]", "_"
    $stdoutLog = Join-Path $buildPath "$safeLabel.stdout.tmp.log"
    $stderrLog = Join-Path $buildPath "$safeLabel.stderr.tmp.log"
    Remove-Item -LiteralPath $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue
    $argumentLine = ($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join " "

    $commandLine = "$(ConvertTo-NativeArgument $FilePath) $argumentLine > $(ConvertTo-NativeArgument $stdoutLog) 2> $(ConvertTo-NativeArgument $stderrLog)"
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "$env:ComSpec"
    $startInfo.Arguments = "/d /c $commandLine"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    if ($WorkingDirectory) {
        $startInfo.WorkingDirectory = $WorkingDirectory
    } else {
        $startInfo.WorkingDirectory = $repoRoot
    }

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $lastActivity = Get-Date
    $lastStdoutSize = 0
    $lastStderrSize = 0
    $lastCpu = 0.0
    if ($process.CPU) {
        $lastCpu = [double]$process.CPU
    }

    while (-not $process.HasExited) {
        Start-Sleep -Seconds 5
        $process.Refresh()

        $stdoutSize = 0
        $stderrSize = 0
        if (Test-Path -LiteralPath $stdoutLog) {
            $stdoutSize = (Get-Item -LiteralPath $stdoutLog).Length
        }
        if (Test-Path -LiteralPath $stderrLog) {
            $stderrSize = (Get-Item -LiteralPath $stderrLog).Length
        }

        $trackedProcesses = @(Get-TrackedProcesses $process.Id)
        $cpu = ($trackedProcesses | Measure-Object -Property CPU -Sum).Sum
        if ($null -eq $cpu) { $cpu = 0.0 }

        $activeWorker = $false
        if ($Label -like "Ninja*") {
            $activeWorker = [bool]($trackedProcesses | Where-Object { $_.ProcessName -in @("clang", "clang++", "cl", "link", "lld-link") })
        } elseif ($Label -like "NMake*") {
            $activeWorker = [bool]($trackedProcesses | Where-Object { $_.ProcessName -in @("clang", "clang++", "cl", "link", "lld-link", "nmake") })
        } elseif ($Label -like "CMake*") {
            $activeWorker = [bool]($trackedProcesses | Where-Object { $_.ProcessName -eq "cmake" })
        } elseif ($Label -like "ReXGlue*") {
            $activeWorker = [bool]($trackedProcesses | Where-Object { $_.ProcessName -eq "rexglue" })
        }

        if ($stdoutSize -ne $lastStdoutSize -or $stderrSize -ne $lastStderrSize -or [Math]::Abs($cpu - $lastCpu) -gt 0.05 -or $activeWorker) {
            $lastActivity = Get-Date
            $lastStdoutSize = $stdoutSize
            $lastStderrSize = $stderrSize
            $lastCpu = $cpu
        } elseif (((Get-Date) - $lastActivity).TotalSeconds -ge $NativeStallTimeoutSeconds) {
            Write-BuildLog "$Label stalled for $NativeStallTimeoutSeconds seconds; killing pid $($process.Id)"
            Stop-ProcessTree $process.Id
            Show-LogTail
            throw "$Label stalled for $NativeStallTimeoutSeconds seconds without output, CPU, or worker-process activity"
        }
    }
    $process.WaitForExit()
    $process.Refresh()

    if (Test-Path -LiteralPath $stdoutLog) {
        Get-Content -LiteralPath $stdoutLog | Add-Content -LiteralPath $LogFile
    }
    if (Test-Path -LiteralPath $stderrLog) {
        Get-Content -LiteralPath $stderrLog | Add-Content -LiteralPath $LogFile
    }
    Remove-Item -LiteralPath $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue

    $exitCode = $process.ExitCode
    if ($exitCode -ne 0) {
        Show-LogTail
        throw "$Label failed with exit code $exitCode"
    }
}

Write-BuildLog "build-l40 start BuildType=$BuildType BuildDir=$buildPath Generator=$Generator Jobs=$Jobs Regenerate=$Regenerate Configure=$Configure"

$manifest = Resolve-RepoPath "config\l40_manifest.toml"
$gameXex = Resolve-RepoPath "game\default.xex"
$rexgluePrefixPath = Resolve-RepoPath $RexGluePrefix
$rexglueExe = Join-Path $rexgluePrefixPath "bin\rexglue.exe"
$rexglueCmakeDir = Join-Path $rexgluePrefixPath "lib\cmake\rexglue"
$cmakeRexGluePrefixPath = $rexgluePrefixPath.Replace("\", "/")
$cmakeRexGlueDir = $rexglueCmakeDir.Replace("\", "/")
$clang = "C:\Program Files\LLVM\bin\clang.exe"
$clangxx = "C:\Program Files\LLVM\bin\clang++.exe"

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
$vsInstall = $null
if (Test-Path $vswhere) {
    $vsInstall = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
}
if (-not $vsInstall) {
    $vsInstall = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
}
$vcvars = Join-Path $vsInstall "VC\Auxiliary\Build\vcvarsall.bat"

if (-not (Test-Path -LiteralPath $manifest)) { throw "Manifest not found: $manifest" }
if (-not (Test-Path -LiteralPath $gameXex)) { throw "Missing user-supplied game\default.xex. Extract your own legal copy into game\ first." }
if (-not (Test-Path -LiteralPath $rexglueExe)) { throw "ReXGlue executable not found: $rexglueExe. Build the official ReXGlue SDK or pass -RexGluePrefix." }
if (-not (Test-Path -LiteralPath $vcvars)) { throw "vcvarsall.bat was not found at $vcvars" }
if (-not (Test-Path -LiteralPath $clang)) { throw "clang.exe was not found at $clang" }
if (-not (Test-Path -LiteralPath $clangxx)) { throw "clang++.exe was not found at $clangxx" }

if ($Regenerate) {
    Invoke-LoggedNative "ReXGlue codegen" $rexglueExe @("codegen", $manifest)

    if (-not $SkipGeneratedWorkarounds) {
        $generatedWorkarounds = Join-Path $PSScriptRoot "apply-l40-generated-workarounds.ps1"
        if (Test-Path -LiteralPath $generatedWorkarounds) {
            Invoke-LoggedNative "Generated workaround patch" "powershell" @("-ExecutionPolicy", "Bypass", "-File", $generatedWorkarounds, "-Root", $repoRoot)
        }
    }
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$envLines = cmd.exe /d /c "`"$vcvars`" x64 >nul && set" 2>&1
$ErrorActionPreference = $previousErrorActionPreference

$envLines | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
}

$cacheFile = Join-Path $buildPath "CMakeCache.txt"
if ($Configure -or $Regenerate -or -not (Test-Path -LiteralPath $cacheFile)) {
    Invoke-LoggedNative "CMake configure" "cmake" @(
        "-S", $repoRoot,
        "-B", $buildPath,
        "-G", $Generator,
        "-DCMAKE_BUILD_TYPE=$BuildType",
        "-DCMAKE_C_COMPILER=$clang",
        "-DCMAKE_CXX_COMPILER=$clangxx",
        "-DCMAKE_C_FLAGS=$CompilerFlags",
        "-DCMAKE_CXX_FLAGS=$CompilerFlags",
        "-DCMAKE_PREFIX_PATH=$cmakeRexGluePrefixPath",
        "-Urexglue_DIR",
        "-Drexglue_DIR=$cmakeRexGlueDir"
    )
}

if ($Generator -eq "Ninja") {
    # Ninja parallelizes to core count by default, but the generated recomp TUs
    # are memory-heavy (each includes the large l40_init.h at -O3). On this
    # workspace an unbounded job count exhausts RAM and thrashes/OOMs clang,
    # which previously read as a "Ninja hang." Cap concurrency with -Jobs.
    Invoke-LoggedNative "Ninja build l40" "ninja" @("-C", $buildPath, "-j", "$Jobs", "l40") $repoRoot
} else {
    Invoke-LoggedNative "NMake build l40" "nmake" @("/NOLOGO", "/C", "l40") $buildPath
}
Write-BuildLog "build-l40 complete"
Write-Host "Build complete: $buildPath\l40.exe"
Write-Host "Build log: $LogFile"
