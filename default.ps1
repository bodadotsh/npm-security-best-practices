Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DEFAULT_MIN_RELEASE_AGE_DAYS = 3
$MINUTES_PER_DAY = 1440
$SECONDS_PER_DAY = 86400
$DEFAULT_MIN_RELEASE_AGE_MINUTES = $DEFAULT_MIN_RELEASE_AGE_DAYS * $MINUTES_PER_DAY
$DEFAULT_MIN_RELEASE_AGE_SECONDS = $DEFAULT_MIN_RELEASE_AGE_DAYS * $SECONDS_PER_DAY

$script:didApply = $false
$script:hadFailure = $false
$script:needsManualAction = $false
$script:pnpmSetupRequired = $false
$script:minReleaseAgeDays = $null

function Write-Stderr {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    try {
        [Console]::Error.WriteLine($Message)
    } catch {
        Write-Host $Message
    }
}

function Write-Stdout {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message
    )

    try {
        [Console]::Out.WriteLine($Message)
    } catch {
        Write-Host $Message
    }
}

function Show-Usage {
    $lines = @(
        'This script sets global package-manager defaults for npm, pnpm, yarn, and bun:'
        ''
        '  - npm: sets ignore-scripts=true, save-exact=true, and provenance=true in user config (~/.npmrc).'
        '  - npm: requires npm >= 11 for min-release-age; older versions skip this setting with a warning.'
        ''
        '  - pnpm: sets save-exact=true globally.'
        '  - pnpm: tries minimumReleaseAge=<minutes> globally and leaves it unchanged if unsupported.'
        ''
        '  - Yarn:'
        '    - If global home config is supported, applies Yarn Berry settings: enableScripts=false, defaultSemverRangePrefix="", and npmPublishProvenance=true.'
        '    - Otherwise, falls back to Yarn Classic settings: ignore-scripts=true and save-prefix="".'
        '    - For Yarn Berry, also tries npmMinimalAgeGate=<minutes>; requires yarn >= 4.10, older versions skip this setting with a warning.'
        ''
        '  - Bun: creates ~/.bunfig.toml when missing; if an existing ~/.bunfig.toml is missing exact=true or minimumReleaseAge=<seconds>, prints a manual update snippet.'
        ''
        "  - Interactive mode prompts for the release-age in days; pressing Enter uses $DEFAULT_MIN_RELEASE_AGE_DAYS."
        "  - Non-interactive mode uses $DEFAULT_MIN_RELEASE_AGE_DAYS days ($DEFAULT_MIN_RELEASE_AGE_MINUTES minutes, $DEFAULT_MIN_RELEASE_AGE_SECONDS seconds)."
        '  - Skips any package manager that is not installed.'
        '  - Exits non-zero only if none of npm, pnpm, yarn, or bun could be handled.'
    )

    Write-Stdout ($lines -join [Environment]::NewLine)
}

function Write-Info {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Stdout $Message
}

function Write-WarnMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Stderr "warn: $Message"
}

function Write-ErrorMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Stderr "error: $Message"
}

function Write-Success {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Stdout $Message
}

function Show-GlobalConfigHint {
    Write-Stdout ''
    Write-Stdout 'You can inspect global package manager configuration with:'
    Write-Stdout '  npm config list'
    Write-Stdout '  pnpm config list'
    Write-Stdout '  yarn config'
    Write-Stdout '  cat ~/.bunfig.toml'
}

function Skip-Message {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Info "skip $Message"
}

function Test-CanPrompt {
    if (-not [Environment]::UserInteractive) {
        return $false
    }

    try {
        return $null -ne $Host -and $null -ne $Host.UI -and $null -ne $Host.UI.RawUI
    } catch {
        return $false
    }
}

function Confirm-Continue {
    Show-Usage
    Write-Stdout ''

    if (-not (Test-CanPrompt)) {
        Write-Info 'non-interactive: continuing by default'
        return
    }

    try {
        $userInput = Read-Host 'Continue? [Y/n]'
    } catch {
        Write-Info 'non-interactive: continuing by default'
        return
    }

    switch -Regex ($userInput) {
        '^(|[Yy]|[Yy][Ee][Ss])$' {
            return
        }
        '^[Nn]([Oo])?$' {
            Write-Info 'exiting'
            exit 0
        }
        default {
            Write-WarnMessage "unrecognized response '$userInput'; continuing by default"
            return
        }
    }
}

function Invoke-ExternalQuiet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [string[]]$Arguments = @()
    )

    $global:LASTEXITCODE = 0

    try {
        & $Command @Arguments *> $null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Apply-Setting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SuccessMessage,

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [string[]]$Arguments = @()
    )

    if (Invoke-ExternalQuiet -Command $Command -Arguments $Arguments) {
        Write-Info $SuccessMessage
        $script:didApply = $true
    } else {
        Write-ErrorMessage $FailureMessage
        $script:hadFailure = $true
    }
}

function Probe-Setting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SuccessMessage,

        [Parameter(Mandatory = $true)]
        [string]$SkipMessage,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [string[]]$Arguments = @()
    )

    if (Invoke-ExternalQuiet -Command $Command -Arguments $Arguments) {
        Write-Info $SuccessMessage
        $script:didApply = $true
        return $true
    }

    Skip-Message $SkipMessage
    return $false
}

function Apply-NpmUserSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    Apply-Setting `
        -SuccessMessage "npm $Key=$Value" `
        -FailureMessage "failed to set npm $Key=$Value" `
        -Command 'npm' `
        -Arguments @('config', 'set', $Key, $Value, '--location=user')
}

function Probe-NpmUserSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [string]$SkipMessage
    )

    return Probe-Setting `
        -SuccessMessage "npm $Key=$Value" `
        -SkipMessage $SkipMessage `
        -Command 'npm' `
        -Arguments @('config', 'set', $Key, $Value, '--location=user')
}

function Apply-YarnHomeSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    Apply-Setting `
        -SuccessMessage "yarn $Key=$Value" `
        -FailureMessage "failed to set yarn $Key=$Value" `
        -Command 'yarn' `
        -Arguments @('config', 'set', '-H', $Key, $Value)
}

function Probe-YarnHomeSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [string]$SkipMessage
    )

    return Probe-Setting `
        -SuccessMessage "yarn $Key=$Value" `
        -SkipMessage $SkipMessage `
        -Command 'yarn' `
        -Arguments @('config', 'set', '-H', $Key, $Value)
}

function Apply-YarnGlobalSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    Apply-Setting `
        -SuccessMessage "yarn $Key=$Value" `
        -FailureMessage "failed to set yarn $Key=$Value" `
        -Command 'yarn' `
        -Arguments @('config', 'set', $Key, $Value, '--global')
}

function Convert-DaysToMinutes {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Days
    )

    return $Days * $MINUTES_PER_DAY
}

function Convert-DaysToSeconds {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Days
    )

    return $Days * $SECONDS_PER_DAY
}

function Format-HomeRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        $homePath = [System.IO.Path]::GetFullPath($HOME).TrimEnd([char[]]@('\', '/'))

        if ($fullPath.Equals($homePath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return '~'
        }

        foreach ($prefix in @("$homePath\", "$homePath/")) {
            if ($fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relativePath = $fullPath.Substring($prefix.Length).Replace('\', '/')
                return "~/$relativePath"
            }
        }
    } catch {
        return $Path
    }

    return $Path
}

function Write-BunManualInstructions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BunfigPath,

        [Parameter(Mandatory = $true)]
        [int]$MinReleaseAgeSeconds
    )

    $displayPath = Format-HomeRelativePath -Path $BunfigPath
    $script:needsManualAction = $true

    Write-Stderr "manual: we've detected you already have $displayPath; check the file contents and make sure the following Bun install config values are set:"
    Write-Stderr ''
    Write-Stderr '[install]'
    Write-Stderr 'exact = true'
    Write-Stderr "minimumReleaseAge = $MinReleaseAgeSeconds"
    Write-Stderr ''
    Write-Stderr 'If [install] already exists, update those keys in that section.'
}

function New-Bunfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BunfigPath,

        [Parameter(Mandatory = $true)]
        [int]$MinReleaseAgeSeconds
    )

    $displayPath = Format-HomeRelativePath -Path $BunfigPath
    $content = "[install]`nexact = true`nminimumReleaseAge = $MinReleaseAgeSeconds`n"

    try {
        Set-Content -Path $BunfigPath -Value $content -Encoding Ascii
        Write-Info "bun created $displayPath"
        $script:didApply = $true
        return $true
    } catch {
        Write-ErrorMessage "failed to create $displayPath"
        $script:hadFailure = $true
        return $false
    }
}

function Ensure-MinReleaseAgeDays {
    if ($null -eq $script:minReleaseAgeDays) {
        $script:minReleaseAgeDays = Get-MinReleaseAgeDays
    }
}

function Get-MinReleaseAgeDays {
    if (-not (Test-CanPrompt)) {
        Write-Info "non-interactive: min-release-age=$DEFAULT_MIN_RELEASE_AGE_DAYS days (${DEFAULT_MIN_RELEASE_AGE_MINUTES}m, ${DEFAULT_MIN_RELEASE_AGE_SECONDS}s for bun)"
        return $DEFAULT_MIN_RELEASE_AGE_DAYS
    }

    try {
        $userInput = Read-Host "Enter min-release-age in days [default: $DEFAULT_MIN_RELEASE_AGE_DAYS]"
    } catch {
        Write-Info "non-interactive: min-release-age=$DEFAULT_MIN_RELEASE_AGE_DAYS days (${DEFAULT_MIN_RELEASE_AGE_MINUTES}m, ${DEFAULT_MIN_RELEASE_AGE_SECONDS}s for bun)"
        return $DEFAULT_MIN_RELEASE_AGE_DAYS
    }

    if ($userInput -eq '') {
        $userInput = $DEFAULT_MIN_RELEASE_AGE_DAYS.ToString()
    }

    if ($userInput -notmatch '^\d+$') {
        Write-WarnMessage "invalid min-release-age '$userInput'; using $DEFAULT_MIN_RELEASE_AGE_DAYS days (${DEFAULT_MIN_RELEASE_AGE_MINUTES}m, ${DEFAULT_MIN_RELEASE_AGE_SECONDS}s for bun)"
        return $DEFAULT_MIN_RELEASE_AGE_DAYS
    }

    return [int]$userInput
}

function Test-CommandAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Invoke-YarnClassic {
    Apply-YarnGlobalSetting -Key 'ignore-scripts' -Value 'true'
    Apply-YarnGlobalSetting -Key 'save-prefix' -Value ''
}

function Get-YarnVersionInfo {
    try {
        $versionOutput = (& yarn --version 2>$null | Select-Object -First 1)
    } catch {
        return $null
    }

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($versionOutput)) {
        return $null
    }

    $versionString = $versionOutput.Trim()
    $parts = $versionString.Split('.')

    if ($parts.Length -lt 2) {
        return $null
    }

    $major = 0
    $minor = 0
    if (-not [int]::TryParse($parts[0], [ref]$major)) {
        return $null
    }
    if (-not [int]::TryParse($parts[1], [ref]$minor)) {
        return $null
    }

    return [PSCustomObject]@{
        Version = $versionString
        Major   = $major
        Minor   = $minor
    }
}

function Test-YarnSupportsMinAgeGate {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $VersionInfo
    )

    if ($null -eq $VersionInfo) {
        return $false
    }

    if ($VersionInfo.Major -gt 4) {
        return $true
    }

    if ($VersionInfo.Major -eq 4 -and $VersionInfo.Minor -ge 10) {
        return $true
    }

    return $false
}

function Get-NpmVersionInfo {
    try {
        $versionOutput = (& npm --version 2>$null | Select-Object -First 1)
    } catch {
        return $null
    }

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($versionOutput)) {
        return $null
    }

    $versionString = $versionOutput.Trim()
    $majorString = $versionString.Split('.')[0]

    $major = 0
    if (-not [int]::TryParse($majorString, [ref]$major)) {
        return $null
    }

    return [PSCustomObject]@{
        Version = $versionString
        Major   = $major
    }
}

function Invoke-NpmDefaults {
    if (-not (Test-CommandAvailable -Name 'npm')) {
        Skip-Message 'npm not installed'
        return
    }

    Apply-NpmUserSetting -Key 'ignore-scripts' -Value 'true'
    Apply-NpmUserSetting -Key 'save-exact' -Value 'true'
    Apply-NpmUserSetting -Key 'provenance' -Value 'true'

    $npmVersionInfo = Get-NpmVersionInfo
    if ($null -eq $npmVersionInfo) {
        Write-WarnMessage 'could not detect npm version; min-release-age requires npm >= 11; skipping'
        return
    }

    if ($npmVersionInfo.Major -lt 11) {
        Write-WarnMessage "npm $($npmVersionInfo.Version) detected; min-release-age requires npm >= 11; skipping. Upgrade with: npm install -g npm@latest"
        return
    }

    Ensure-MinReleaseAgeDays
    [void](Probe-NpmUserSetting `
        -Key 'min-release-age' `
        -Value $script:minReleaseAgeDays.ToString() `
        -SkipMessage 'npm min-release-age unsupported; unchanged')
}

function Test-PnpmPathError {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Output
    )

    return ($Output -match 'is not in PATH') -and ($Output -match 'pnpm setup')
}

function Write-PnpmPathError {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Output
    )

    Write-Stderr $Output.TrimEnd()
    Write-ErrorMessage "pnpm global bin directory is not in PATH; run 'pnpm setup' and re-run this script"
}

function Invoke-PnpmGlobalSet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [string]$SkipMessage,

        [switch]$AllowSkip
    )

    $global:LASTEXITCODE = 0
    $output = ''
    $success = $false

    try {
        $output = (& 'pnpm' 'config' 'set' $Key $Value '--global' 2>&1 | Out-String)
        $success = $LASTEXITCODE -eq 0
    } catch {
        $output = "$($_.Exception.Message)"
        $success = $false
    }

    if ($success) {
        Write-Info "pnpm $Key=$Value"
        $script:didApply = $true
        return
    }

    if (Test-PnpmPathError -Output $output) {
        $script:pnpmSetupRequired = $true
        Write-PnpmPathError -Output $output
        $script:hadFailure = $true
        return
    }

    if ($AllowSkip) {
        Skip-Message $SkipMessage
        return
    }

    Write-ErrorMessage "failed to set pnpm $Key=$Value"
    $script:hadFailure = $true
}

function Invoke-PnpmDefaults {
    if (-not (Test-CommandAvailable -Name 'pnpm')) {
        Skip-Message 'pnpm not installed'
        return
    }

    Invoke-PnpmGlobalSet -Key 'save-exact' -Value 'true'
    if ($script:pnpmSetupRequired) {
        return
    }

    Ensure-MinReleaseAgeDays
    $minReleaseAgeMinutes = Convert-DaysToMinutes -Days $script:minReleaseAgeDays
    Invoke-PnpmGlobalSet `
        -Key 'minimumReleaseAge' `
        -Value $minReleaseAgeMinutes.ToString() `
        -SkipMessage 'pnpm minimumReleaseAge unsupported; unchanged' `
        -AllowSkip
}

function Invoke-YarnDefaults {
    if (-not (Test-CommandAvailable -Name 'yarn')) {
        Skip-Message 'yarn not installed'
        return
    }

    if (Probe-YarnHomeSetting `
        -Key 'enableScripts' `
        -Value 'false' `
        -SkipMessage 'yarn home-scoped config unsupported; falling back to Yarn Classic') {
        Apply-YarnHomeSetting -Key 'defaultSemverRangePrefix' -Value ''
        Apply-YarnHomeSetting -Key 'npmPublishProvenance' -Value 'true'

        $yarnVersionInfo = Get-YarnVersionInfo
        if ($null -eq $yarnVersionInfo) {
            Write-WarnMessage 'could not detect yarn version; npmMinimalAgeGate requires yarn >= 4.10; skipping'
            return
        }

        if (-not (Test-YarnSupportsMinAgeGate -VersionInfo $yarnVersionInfo)) {
            Write-WarnMessage "yarn $($yarnVersionInfo.Version) detected; npmMinimalAgeGate requires yarn >= 4.10; skipping. Upgrade with: yarn set version stable"
            return
        }

        Ensure-MinReleaseAgeDays
        $minReleaseAgeMinutes = Convert-DaysToMinutes -Days $script:minReleaseAgeDays
        [void](Probe-YarnHomeSetting `
            -Key 'npmMinimalAgeGate' `
            -Value $minReleaseAgeMinutes.ToString() `
            -SkipMessage 'yarn npmMinimalAgeGate unsupported; unchanged')
        return
    }

    Invoke-YarnClassic
}

function Invoke-BunDefaults {
    if (-not (Test-CommandAvailable -Name 'bun')) {
        Skip-Message 'bun not installed'
        return
    }

    Ensure-MinReleaseAgeDays
    $minReleaseAgeSeconds = Convert-DaysToSeconds -Days $script:minReleaseAgeDays
    $bunfigPath = Join-Path $HOME '.bunfig.toml'

    if (-not (Test-Path -LiteralPath $bunfigPath -PathType Leaf)) {
        [void](New-Bunfig -BunfigPath $bunfigPath -MinReleaseAgeSeconds $minReleaseAgeSeconds)
        return
    }

    Write-BunManualInstructions -BunfigPath $bunfigPath -MinReleaseAgeSeconds $minReleaseAgeSeconds
}

if ($args.Count -gt 0 -and $args[0] -in @('--help', '-h')) {
    Show-Usage
    exit 0
}

Confirm-Continue

Invoke-NpmDefaults
Invoke-PnpmDefaults
Invoke-YarnDefaults
Invoke-BunDefaults

Write-Stdout ''

if ($script:didApply) {
    Write-Success 'done'
    Show-GlobalConfigHint
    exit 0
}

if ($script:hadFailure) {
    Write-ErrorMessage 'nothing applied'
    Show-GlobalConfigHint
    exit 1
}

if ($script:needsManualAction) {
    Write-WarnMessage 'manual bun update required'
    Show-GlobalConfigHint
    exit 0
}

Write-ErrorMessage 'npm/pnpm/yarn/bun unavailable; nothing applied'
Show-GlobalConfigHint
exit 2
