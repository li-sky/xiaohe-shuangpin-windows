#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Run this integration test only on a disposable GitHub Actions Windows runner.' }
$root = (Get-Location).Path
New-Item -ItemType Directory -Force .test | Out-Null
$subkey = 'Software\Microsoft\InputMethod\Settings\CHS'
$regPath = 'HKCU\Software\Microsoft\InputMethod\Settings\CHS'
$names = @('Enable Double Pinyin', 'DoublePinyinScheme', 'UserDefinedDoublePinyinScheme0')
$scheme = '小鹤双拼*2*^*iuvdjhcwfg^xmlnpbksqszxkrltvyovt'
$existing = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($subkey)
$hadKey = $null -ne $existing
if ($existing) { $existing.Dispose(); & reg.exe export $regPath "$root/.test/original.reg" /y | Out-Null }
$key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($subkey)
$server = $null
function Assert($ok, $message) { if (!$ok) { throw $message } }
function Assert-Enabled {
    Assert ($key.GetValue($names[0]) -eq 1) 'Double Pinyin not enabled'
    Assert ($key.GetValue($names[1]) -eq 10) 'Custom scheme not selected'
    Assert ($key.GetValue($names[2]) -ceq $scheme) 'Incorrect Chinese scheme value or mapping'
    Assert ($key.GetValueKind($names[0]) -eq 'DWord') 'Incorrect DWORD type'
    Assert ($key.GetValueKind($names[2]) -eq 'String') 'Incorrect string type'
    Assert ($key.GetValue('ScoopXiaoheTestSentinel') -eq 'keep') 'Unrelated value changed'
}
function Set-Fixture {
    $key.SetValue($names[0], 0, [Microsoft.Win32.RegistryValueKind]::DWord)
    $key.SetValue($names[1], 2, [Microsoft.Win32.RegistryValueKind]::DWord)
    $key.SetValue($names[2], 'original-user-scheme', [Microsoft.Win32.RegistryValueKind]::String)
    $key.SetValue('ScoopXiaoheTestSentinel', 'keep')
}
function Assert-Fixture {
    Assert ($key.GetValue($names[0]) -eq 0) 'Original enable flag was not restored'
    Assert ($key.GetValue($names[1]) -eq 2) 'Original scheme selector was not restored'
    Assert ($key.GetValue($names[2]) -eq 'original-user-scheme') 'Original custom scheme was not restored'
}
try {
    $bytes = [IO.File]::ReadAllBytes("$root/xiaohe-shuangpin.reg")
    Assert ($bytes[0] -eq 255 -and $bytes[1] -eq 254) 'REG must be UTF-16 LE with BOM'
    Set-Fixture
    $backup = "$root/.test/backup.json"
    & ./configure.ps1 -BackupPath $backup
    Assert-Enabled
    $firstHash = (Get-FileHash $backup).Hash
    & ./configure.ps1 -BackupPath $backup
    Assert ((Get-FileHash $backup).Hash -eq $firstHash) 'Repeated import overwrote original backup'
    & ./configure.ps1 -Mode Restore -BackupPath $backup
    Assert-Fixture
    Assert (!(Test-Path $backup)) 'Used backup was not cleared'
    foreach ($name in $names) { $key.DeleteValue($name, $false) }
    & ./configure.ps1 -BackupPath $backup
    Assert-Enabled
    & ./configure.ps1 -Mode Restore -BackupPath $backup
    foreach ($name in $names) { Assert ($key.GetValueNames() -notcontains $name) "Originally absent value was not removed: $name" }
    Assert ($key.GetValue('ScoopXiaoheTestSentinel') -eq 'keep') 'Restore removed unrelated values'

    $manifest = Get-Content scoop/xiaohe-shuangpin.json -Raw | ConvertFrom-Json
    $archive = "xiaohe-shuangpin-$($manifest.version).zip"
    Assert ((Get-FileHash "dist/$archive" -Algorithm SHA256).Hash.ToLowerInvariant() -eq $manifest.hash) 'Release archive does not match manifest hash'
    Invoke-WebRequest https://raw.githubusercontent.com/ScoopInstaller/Scoop/master/schema.json -OutFile .test/schema.json -UseBasicParsing
    python -m pip install --quiet jsonschema
    if ($LASTEXITCODE) { throw 'Cannot install schema validator' }
    python -c "import json,jsonschema; jsonschema.validate(json.load(open('scoop/xiaohe-shuangpin.json')),json.load(open('.test/schema.json')))"
    if ($LASTEXITCODE) { throw 'Invalid Scoop manifest schema' }
    $env:SCOOP = Join-Path $env:RUNNER_TEMP 'scoop'
    $scoopRoot = Join-Path $env:SCOOP 'apps/scoop/current'
    git clone --depth 1 https://github.com/ScoopInstaller/Scoop.git $scoopRoot
    if ($LASTEXITCODE) { throw 'Cannot fetch Scoop' }
    New-Item -ItemType Directory -Force "$env:SCOOP/shims", "$env:SCOOP/buckets" | Out-Null
    $scoop = Join-Path $scoopRoot 'bin/scoop.ps1'
    & $scoop config aria2-enabled false
    $manifest.url = "http://127.0.0.1:18765/$archive"
    $manifest | ConvertTo-Json -Depth 10 | Set-Content .test/xiaohe-shuangpin.json -Encoding UTF8
    $server = Start-Process python -ArgumentList '-m', 'http.server', '18765', '--bind', '127.0.0.1' -WorkingDirectory "$root/dist" -PassThru -RedirectStandardOutput "$root/.test/http.log" -RedirectStandardError "$root/.test/http-error.log"
    $ready = $false
    for ($i = 0; $i -lt 20; $i++) {
        try { Invoke-WebRequest http://127.0.0.1:18765/ -UseBasicParsing | Out-Null; $ready = $true; break }
        catch { Start-Sleep -Milliseconds 500 }
    }
    Assert $ready 'Package server did not start'
    Set-Fixture
    & $scoop install --no-update-scoop "$root/.test/xiaohe-shuangpin.json"
    Assert-Enabled
    $installed = Join-Path $env:SCOOP 'apps/xiaohe-shuangpin/current'
    $persistBackup = Join-Path $env:SCOOP 'persist/xiaohe-shuangpin/data/registry-backup.json'
    Assert (Test-Path $persistBackup) 'Backup was not persisted by Scoop'
    $firstHash = (Get-FileHash $persistBackup).Hash
    Assert (Test-Path "$env:SCOOP/shims/xiaohe-shuangpin.ps1") 'Restore command shim missing'
    & $scoop uninstall xiaohe-shuangpin
    Assert (!(Test-Path $installed)) 'Uninstall failed'
    Assert-Enabled
    Assert (Test-Path $persistBackup) 'Uninstall lost backup'
    & $scoop install --no-update-scoop "$root/.test/xiaohe-shuangpin.json"
    Assert ((Get-FileHash $persistBackup).Hash -eq $firstHash) 'Reinstall overwrote original backup'
    & "$env:SCOOP/shims/xiaohe-shuangpin.ps1" -Mode Restore
    Assert-Fixture
    Write-Host "PASS ($($PSVersionTable.PSVersion)): REG encoding, import, exact mapping, backup, restore, absent values, Scoop automatic import and uninstall/reinstall persistence."
} finally {
    if ($server) { Stop-Process -Id $server.Id -ErrorAction SilentlyContinue }
    foreach ($name in $names + @('ScoopXiaoheTestSentinel')) { $key.DeleteValue($name, $false) }
    $key.Dispose()
    if ($hadKey) { & reg.exe import "$root/.test/original.reg" | Out-Null }
}
