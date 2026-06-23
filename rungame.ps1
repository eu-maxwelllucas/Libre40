<#
.SYNOPSIS
    Manual launcher for Libre40.

.EXAMPLE
    .\rungame.ps1 -StopExisting

.EXAMPLE
    .\rungame.ps1 -Build -Regenerate -StopExisting
#>

[CmdletBinding()]
param(
    [string]$ExePath = "build\l40-ninja-release\l40.exe",
    [string]$GameRoot = "game",
    [switch]$StopExisting,
    [switch]$Build,
    [switch]$Regenerate,
    [switch]$Wait,
    [switch]$DryRun,
    [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path $PSScriptRoot

function Resolve-RepoPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path $repoRoot $Path
}

function Normalize-ExtraArgs([string[]]$InputArgs) {
    $normalized = @()
    foreach ($arg in $InputArgs) {
        foreach ($commaPart in $arg.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries)) {
            $normalized += $commaPart.Split([char[]]@(" ", "`t", "`r", "`n"), [System.StringSplitOptions]::RemoveEmptyEntries)
        }
    }
    return $normalized
}

function Has-ArgPrefix([string[]]$InputArgs, [string]$Prefix) {
    foreach ($arg in $InputArgs) {
        if ($arg.StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

if ($Build -or $Regenerate) {
    $buildScript = Join-Path $repoRoot "scripts\build-l40.ps1"
    if (-not (Test-Path -LiteralPath $buildScript)) {
        throw "Build script not found: $buildScript"
    }

    $buildArgs = @()
    if ($Regenerate) {
        $buildArgs += "-Regenerate"
    }

    if ($DryRun) {
        Write-Output "dry_run_would_build=true"
        Write-Output "build_script=$buildScript"
        Write-Output "build_args=$($buildArgs -join ' ')"
    } else {
        & $buildScript @buildArgs
    }
}

$exe = Resolve-RepoPath $ExePath
$gameRootPath = Resolve-RepoPath $GameRoot
$logsDir = Join-Path (Split-Path -Parent $exe) "logs"
$normalizedExtraArgs = Normalize-ExtraArgs $ExtraArgs
$launchArgs = @()

if (-not (Has-ArgPrefix -InputArgs $normalizedExtraArgs -Prefix "--game_data_root")) {
    $launchArgs += "--game_data_root=$gameRootPath"
}
$launchArgs += $normalizedExtraArgs

if (-not (Test-Path -LiteralPath $exe)) {
    throw "Executable not found: $exe. Build first with scripts\build-l40.ps1."
}
if (-not (Test-Path -LiteralPath $gameRootPath)) {
    throw "Game data root not found: $gameRootPath"
}

$existing = Get-Process -Name "l40" -ErrorAction SilentlyContinue
if ($existing) {
    if ($DryRun) {
        Write-Output "existing_l40_processes:"
        $existing | Select-Object ProcessName,Id,CPU,StartTime,Path
        if ($StopExisting) {
            Write-Output "dry_run_would_stop_existing=true"
        } else {
            Write-Output "dry_run_would_refuse_existing=true"
        }
    } elseif ($StopExisting) {
        $existing | Stop-Process -Force
    } else {
        Write-Output "existing_l40_processes:"
        $existing | Select-Object ProcessName,Id,CPU,StartTime,Path
        throw "Refusing to launch while l40 processes are already running. Re-run with -StopExisting if they should be terminated."
    }
}

Write-Output "exe=$exe"
Write-Output "game_data_root=$gameRootPath"
Write-Output "args=$($launchArgs -join ' ')"

if ($DryRun) {
    Write-Output "dry_run=true"
    return
}

$startedAt = Get-Date
$proc = Start-Process `
    -FilePath $exe `
    -ArgumentList $launchArgs `
    -WorkingDirectory $repoRoot `
    -PassThru

Write-Output "started=true"
Write-Output "pid=$($proc.Id)"
Write-Output "logs_dir=$logsDir"

if ($Wait) {
    $proc.WaitForExit()
    $proc.Refresh()
    Write-Output "exit_code=$($proc.ExitCode)"

    $latestLog = Get-ChildItem $logsDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $startedAt.AddSeconds(-2) } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestLog) {
        Write-Output "latest_log=$($latestLog.FullName)"
    }
}
