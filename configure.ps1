#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Restore')][string]$Mode = 'Install',
    [string]$BackupPath = (Join-Path $PSScriptRoot 'data\registry-backup.json')
)
$ErrorActionPreference = 'Stop'
$subkey = 'Software\Microsoft\InputMethod\Settings\CHS'
$names = @('Enable Double Pinyin', 'DoublePinyinScheme', 'UserDefinedDoublePinyinScheme0')
$expected = @(1, 10, '小鹤双拼*2*^*iuvdjhcwfg^xmlnpbksqszxkrltvyovt')

function Read-Settings {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($subkey)
    try {
        foreach ($name in $names) {
            $exists = $null -ne $key -and $key.GetValueNames() -contains $name
            $kind = $null
            $value = $null
            if ($exists) {
                $kind = $key.GetValueKind($name).ToString()
                $value = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            }
            [pscustomobject]@{ Name = $name; Exists = $exists; Kind = $kind; Value = $value }
        }
    } finally { if ($key) { $key.Dispose() } }
}

function Restore-Settings($settings) {
    if (@($settings).Count -ne 3 -or @($settings | Select-Object -ExpandProperty Name -Unique).Count -ne 3) {
        throw 'Invalid registry backup.'
    }
    foreach ($setting in $settings) {
        if ($setting.Name -notin $names) { throw 'Unexpected registry value in backup.' }
    }
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($subkey)
    try {
        foreach ($setting in $settings) {
            if (!$setting.Exists) {
                $key.DeleteValue($setting.Name, $false)
                continue
            }
            $kind = [Microsoft.Win32.RegistryValueKind]$setting.Kind
            $value = switch ($kind) {
                'DWord' { [int]$setting.Value }
                'QWord' { [long]$setting.Value }
                'Binary' { ,([byte[]]$setting.Value) }
                'None' { ,([byte[]]$setting.Value) }
                'MultiString' { ,([string[]]$setting.Value) }
                default { [string]$setting.Value }
            }
            $key.SetValue($setting.Name, $value, $kind)
        }
    } finally { $key.Dispose() }
}

if ($Mode -eq 'Restore') {
    if (!(Test-Path -LiteralPath $BackupPath)) { throw "No backup found: $BackupPath" }
    $backup = Get-Content -LiteralPath $BackupPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Restore-Settings $backup
    Remove-Item -LiteralPath $BackupPath
    Write-Host 'Restored the three Microsoft Pinyin settings from before installation.'
    return
}

$before = @(Read-Settings)
if (!(Test-Path -LiteralPath $BackupPath)) {
    $parent = Split-Path -Parent ([IO.Path]::GetFullPath($BackupPath))
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $before | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $BackupPath -Encoding UTF8
}
try {
    & reg.exe import (Join-Path $PSScriptRoot 'xiaohe-shuangpin.reg')
    if ($LASTEXITCODE -ne 0) { throw "reg.exe import failed with exit code $LASTEXITCODE" }
    $actual = @(Read-Settings)
    for ($i = 0; $i -lt $names.Count; $i++) {
        $kind = if ($i -eq 2) { 'String' } else { 'DWord' }
        if (!$actual[$i].Exists -or $actual[$i].Kind -ne $kind -or $actual[$i].Value -cne $expected[$i]) {
            throw "Registry verification failed: $($names[$i])"
        }
    }
} catch {
    Restore-Settings $before
    throw
}
Write-Host 'Xiaohe Shuangpin is enabled for Microsoft Pinyin for the current user.'
Write-Host 'If the IME has not refreshed, switch input methods or sign out and back in.'
