[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('dart', 'flutter')]
    [string]$Tool,

    [string]$App,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ToolArguments
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$fvm = Join-Path $env:USERPROFILE 'AppData\Local\Pub\Cache\bin\fvm.bat'
$fvmSdk = Join-Path $repoRoot '.fvm\flutter_sdk'
$sdkTool = Join-Path $fvmSdk "bin\$Tool.bat"
$sdkDart = Join-Path $fvmSdk 'bin\cache\dart-sdk\bin\dart.exe'

if ($Tool -eq 'dart' -and (Test-Path -LiteralPath $sdkDart -PathType Leaf)) {
    # dart.bat loads Flutter's shared bootstrap script and waits on the global
    # Flutter startup lock. Calling the selected SDK executable directly keeps
    # format/analyze/test available while a local Flutter app is running.
    $toolCommand = $sdkDart
}
elseif (Test-Path -LiteralPath $sdkTool -PathType Leaf) {
    # Use the SDK selected by FVM directly. Keeping long-running commands behind
    # `fvm dart ...` can leave the spawned Dart VM alive while the pub-global FVM
    # shim exits and attempts to run again on Windows.
    $toolCommand = $sdkTool
}
elseif (Test-Path -LiteralPath $fvm -PathType Leaf) {
    $toolCommand = $fvm
    $ToolArguments = @($Tool) + $ToolArguments
}
else {
    throw "Neither the active FVM SDK nor FVM was found. Run 'fvm use' in the repository."
}

if (-not $env:PUB_CACHE) {
    $env:PUB_CACHE = Join-Path $repoRoot '.pub-cache'
}

$workingDirectory = $repoRoot
if ($App) {
    $workingDirectory = Join-Path $repoRoot $App
    if (-not (Test-Path -LiteralPath $workingDirectory)) {
        throw "App directory does not exist: $workingDirectory"
    }
}

Push-Location $workingDirectory
try {
    & $toolCommand @ToolArguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Tool failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
