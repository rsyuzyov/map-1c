# Сборка .cfe из XML-исходников src/ через временную файловую ИБ. Результат - dist/<Расширение>-<версия>.cfe.
# Платформа должна читать формат выгрузки (атрибут version в шапке src/Configuration.xml).
param(
    [Parameter(Mandatory = $true)][string]$Platform,
    [string]$Extension = 'КартаОбъектов'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$sourcePath = Join-Path $repositoryRoot 'src'
$distPath = Join-Path $repositoryRoot 'dist'
$infobasePath = Join-Path $env:TEMP ('ib-map-1c-' + $PID)
$logPath = Join-Path $infobasePath 'out.log'

function Invoke-Platform([string[]]$ArgumentList, [int]$TimeoutMs, [string]$StepName) {
    $platformProcess = Start-Process -FilePath $Platform -ArgumentList $ArgumentList -PassThru -WindowStyle Hidden
    if (-not $platformProcess.WaitForExit($TimeoutMs)) {
        try { Stop-Process -Id $platformProcess.Id -Force } catch {}
        throw "$StepName : таймаут (модальное окно платформы или зависание)"
    }
    if (Test-Path $logPath) { Get-Content $logPath }
    if ($platformProcess.ExitCode -ne 0) { throw "$StepName : exit=$($platformProcess.ExitCode)" }
    Write-Host "$StepName : ok"
}

$version = ([xml](Get-Content -Encoding UTF8 (Join-Path $sourcePath 'Configuration.xml'))).MetaDataObject.Configuration.Properties.Version
if (-not $version) { throw 'не прочитал <Version> из src/Configuration.xml' }

New-Item -ItemType Directory -Force $infobasePath | Out-Null
New-Item -ItemType Directory -Force $distPath | Out-Null
$cfePath = Join-Path $distPath "$Extension-$version.cfe"

try {
    Invoke-Platform @('CREATEINFOBASE', "File=`"$infobasePath`"", '/DisableStartupDialogs') 180000 'CREATEINFOBASE'
    Invoke-Platform @('DESIGNER', '/F', "`"$infobasePath`"", '/LoadConfigFromFiles', "`"$sourcePath`"", '-Extension', $Extension,
                      '/Out', "`"$logPath`"", '/DisableStartupDialogs', '/DisableStartupMessages') 600000 'LoadConfigFromFiles'
    Invoke-Platform @('DESIGNER', '/F', "`"$infobasePath`"", '/DumpCfg', "`"$cfePath`"", '-Extension', $Extension,
                      '/Out', "`"$logPath`"") 600000 'DumpCfg'
    Write-Host "готово: $cfePath ($((Get-Item $cfePath).Length) байт), версия $version"
} finally {
    if (Test-Path $infobasePath) { Remove-Item $infobasePath -Recurse -Force -ErrorAction SilentlyContinue }
}
