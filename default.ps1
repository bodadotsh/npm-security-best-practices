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
        '  - npm: sets ignore-scripts=true and save-exact=true globally.'
        '  - npm: tries min-release-age=<days> globally and leaves it unchanged if unsupported.'
        ''
        '  - pnpm: sets save-exact=true globally.'
        '  - pnpm: tries minimumReleaseAge=<minutes> globally and leaves it unchanged if unsupported.'
        ''
        '  - Yarn:'
        '    - If global home config is supported, applies Yarn Berry settings: enableScripts=false and defaultSemverRangePrefix="".'
        '    - Otherwise, falls back to Yarn Classic settings: ignore-scripts=true and save-prefix="".'
        '    - For Yarn Berry, also tries npmMinimalAgeGate=<minutes> and leaves it unchanged if unsupported.'
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

function Skip-Message {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Info "skip $Message"
}

function Test-CanPrompt {
    try {
        return -not [Console]::IsInputRedirected
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

function Apply-GlobalSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Manager,

        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    Apply-Setting `
        -SuccessMessage "$Manager $Key=$Value" `
        -FailureMessage "failed to set $Manager $Key=$Value" `
        -Command $Manager `
        -Arguments @('config', 'set', $Key, $Value, '--global')
}

function Probe-GlobalSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Manager,

        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [string]$SkipMessage
    )

    return Probe-Setting `
        -SuccessMessage "$Manager $Key=$Value" `
        -SkipMessage $SkipMessage `
        -Command $Manager `
        -Arguments @('config', 'set', $Key, $Value, '--global')
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

function Invoke-NpmDefaults {
    if (-not (Test-CommandAvailable -Name 'npm')) {
        Skip-Message 'npm not installed'
        return
    }

    Apply-GlobalSetting -Manager 'npm' -Key 'ignore-scripts' -Value 'true'
    Apply-GlobalSetting -Manager 'npm' -Key 'save-exact' -Value 'true'

    Ensure-MinReleaseAgeDays
    [void](Probe-GlobalSetting `
        -Manager 'npm' `
        -Key 'min-release-age' `
        -Value $script:minReleaseAgeDays.ToString() `
        -SkipMessage 'npm min-release-age unsupported; unchanged')
}

function Invoke-PnpmDefaults {
    if (-not (Test-CommandAvailable -Name 'pnpm')) {
        Skip-Message 'pnpm not installed'
        return
    }

    Apply-GlobalSetting -Manager 'pnpm' -Key 'save-exact' -Value 'true'

    Ensure-MinReleaseAgeDays
    $minReleaseAgeMinutes = Convert-DaysToMinutes -Days $script:minReleaseAgeDays
    [void](Probe-GlobalSetting `
        -Manager 'pnpm' `
        -Key 'minimumReleaseAge' `
        -Value $minReleaseAgeMinutes.ToString() `
        -SkipMessage 'pnpm minimumReleaseAge unsupported; unchanged')
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
    exit 0
}

if ($script:hadFailure) {
    Write-ErrorMessage 'nothing applied'
    exit 1
}

if ($script:needsManualAction) {
    Write-WarnMessage 'manual bun update required'
    exit 0
}

Write-ErrorMessage 'npm/pnpm/yarn/bun unavailable; nothing applied'
exit 2
