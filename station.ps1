# station.ps1 - the bot station on a second PC (D-145, BOTS_AND_DEV_BUILDS.md › Bots on a second PC). It keeps the
# latest development build from the builds repository's release "dev-latest" (tools/publish-dev-build.ps1 on the host's
# machine), runs N headless bots that join the host, and when a newer build is published it stops them, takes it and
# starts them again. A bot retries joining every 10 s, so the station can stay open: each time the host starts a match,
# the bots join it. A bot that quits is started again.
#   powershell -ExecutionPolicy Bypass -File station.ps1 -HostAddress 192.168.0.3        # 15 bots (station.bat does this)
#   ... -Count 10 -CheckSeconds 60
# Needs the GitHub CLI (https://cli.github.com) signed in to an account that can read the repository (gh auth login).
# Builds go to .\builds (the last two kept), the bots' logs to .\logs. Ctrl+C stops the bots. Windows PowerShell 5.1.

param(
    [string]$HostAddress = '192.168.0.3',
    [int]$Count = 15,
    [string]$Repository = 'dmelo10/SANDBOX-GAME-builds',
    [string]$Release = 'dev-latest',
    [int]$CheckSeconds = 60,
    [double]$Interval = 0.5
)

# Native commands report through $LASTEXITCODE; 'Stop' would turn their stderr into a terminating error in PowerShell 5.1.
$ErrorActionPreference = 'Continue'
$builds = Join-Path $PSScriptRoot 'builds'
$logs = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force $builds, $logs | Out-Null
$script:bots = @{}
$script:exe = $null
$current = $null

function Say([string]$text) { Write-Output ('{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $text) }

# The published build's version (the release's version.txt), or $null when GitHub can't be reached.
function Get-Published {
    $file = Join-Path $builds 'published.txt'
    if (Test-Path $file) { Remove-Item $file -Force }
    & gh release download $Release --repo $Repository --pattern 'version.txt' --output $file 2>$null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $file)) { return $null }
    return (Get-Content $file -Raw).Trim()
}

function Stop-Bots {
    foreach ($process in $script:bots.Values) { if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue } }
    $script:bots = @{}
}

# Downloads and unpacks the build into .\builds\<version>; keeps the last two.
function Get-Build([string]$version) {
    $folder = Join-Path $builds ($version -replace '[^\w\.\-]', '_')
    if (-not (Test-Path (Join-Path $folder 'SANDBOX.exe'))) {
        $zip = Join-Path $builds 'build.zip'
        if (Test-Path $zip) { Remove-Item $zip -Force }
        & gh release download $Release --repo $Repository --pattern 'SANDBOX-dev.zip' --output $zip
        if ($LASTEXITCODE -ne 0) { throw 'the download failed' }
        New-Item -ItemType Directory -Force $folder | Out-Null
        & tar -xf $zip -C $folder
        if ($LASTEXITCODE -ne 0) { throw 'unpacking failed' }
        Remove-Item $zip -Force
    }
    (Get-Item $folder).LastWriteTime = Get-Date
    Get-ChildItem $builds -Directory | Sort-Object LastWriteTime -Descending | Select-Object -Skip 2 | Remove-Item -Recurse -Force
    return (Join-Path $folder 'SANDBOX.exe')
}

function Start-Bot([int]$number) {
    $name = 'Bot{0:D2}' -f $number
    $arguments = @('-sandbox-bot', '-sandbox-name', $name, '-sandbox-connect', $HostAddress, '-batchmode', '-nographics', '-logFile', "`"$(Join-Path $logs ($name + '.log'))`"")
    $script:bots[$number] = Start-Process -FilePath $script:exe -ArgumentList $arguments -PassThru
}

try {
    Say "bot station: $Count bots joining $HostAddress, the build from $Repository ($Release)"
    while ($true) {
        $published = Get-Published
        if ($published -and $published -ne $current) {
            Say "build $published published: taking it"
            Stop-Bots
            try {
                $script:exe = Get-Build $published
                for ($i = 1; $i -le $Count; $i++) { Start-Bot $i; Start-Sleep -Milliseconds ([int]($Interval * 1000)) }
                $current = $published
                Say "$Count bots on $published, joining $HostAddress"
            }
            catch { Say "taking $published failed ($_): trying again" }
        }
        elseif (-not $published -and -not $current) { Say 'the release could not be read (gh auth login?): trying again' }
        foreach ($number in @($script:bots.Keys)) {
            if ($script:bots[$number].HasExited) { Say ('Bot{0:D2} quit: starting it again' -f $number); Start-Bot $number }
        }
        Start-Sleep -Seconds $CheckSeconds
    }
}
finally {
    Stop-Bots
    Say 'bots stopped'
}
