param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 61247
)

$ErrorActionPreference = 'Stop'
$applicationPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$iisDirectory = Join-Path $env:ProgramFiles 'IIS Express'
$iisExecutable = Join-Path $iisDirectory 'iisexpress.exe'
if (-not (Test-Path -LiteralPath $iisExecutable)) {
    throw 'Instala IIS Express con soporte ASP.NET y .NET Framework 3.5 (incluye CLR 2.0).'
}

# A private configuration leaves the Visual Studio and system IIS sites untouched.
$runtimeDirectory = Join-Path ([IO.Path]::GetTempPath()) ('PoliMusicV2-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runtimeDirectory | Out-Null
$configurationPath = Join-Path $runtimeDirectory 'applicationhost.config'
[xml]$configuration = Get-Content -LiteralPath (Join-Path $iisDirectory 'AppServer/applicationhost.config')
$site = $configuration.SelectSingleNode('/configuration/system.applicationHost/sites/site')
$site.SetAttribute('name', 'PoliMusicV2')
$site.application.SetAttribute('applicationPool', 'Clr2IntegratedAppPool')
$site.application.virtualDirectory.SetAttribute('physicalPath', $applicationPath)
$site.bindings.binding.SetAttribute('bindingInformation', ('*:{0}:localhost' -f $Port))
$configuration.Save($configurationPath)
Write-Host ('PoliMusic V2: http://localhost:{0}/Login.aspx' -f $Port)
Write-Host 'Pulsa Q para detener IIS Express.'
try {
    & $iisExecutable ('/config:' + $configurationPath) '/site:PoliMusicV2' '/systray:false'
} finally {
    Remove-Item -LiteralPath $configurationPath -ErrorAction SilentlyContinue
}
