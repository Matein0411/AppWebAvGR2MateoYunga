param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 8090
)

$ErrorActionPreference = 'Stop'
$applicationPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$iisDirectory = Join-Path $env:ProgramFiles 'IIS Express'
if (-not (Test-Path (Join-Path $iisDirectory 'iisexpress.exe'))) {
    throw 'IIS Express no está instalado en Program Files. Usa IIS con la característica ASP Clásico habilitada.'
}

# Configuración propia y temporal: no cambia sitios ni Application Pools del sistema.
$runtimeDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('PoliMusic-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runtimeDirectory | Out-Null
$configurationPath = Join-Path $runtimeDirectory 'applicationhost.config'
[xml]$configuration = Get-Content -LiteralPath (Join-Path $iisDirectory 'AppServer/applicationhost.config')
$site = $configuration.SelectSingleNode('/configuration/system.applicationHost/sites/site')
$site.SetAttribute('name', 'PoliMusic')
$site.application.SetAttribute('applicationPool', 'PoliMusicPool')
$site.application.virtualDirectory.SetAttribute('physicalPath', $applicationPath)
$site.bindings.binding.SetAttribute('bindingInformation', ('*:{0}:localhost' -f $Port))
$pool = $configuration.CreateElement('add')
$pool.SetAttribute('name', 'PoliMusicPool')
$pool.SetAttribute('managedRuntimeVersion', '')
$pool.SetAttribute('managedPipelineMode', 'Integrated')
$configuration.SelectSingleNode('/configuration/system.applicationHost/applicationPools').AppendChild($pool) | Out-Null
$configuration.Save($configurationPath)

Write-Host ('PoliMusic: http://localhost:{0}/login.asp' -f $Port)
Write-Host 'Pulsa Q en IIS Express para detener el servidor.'
try {
    & (Join-Path $iisDirectory 'iisexpress.exe') ('/config:' + $configurationPath) '/site:PoliMusic' '/systray:false'
} finally {
    # Solo borra el archivo generado por este script; no elimina directorios recursivamente.
    Remove-Item -LiteralPath $configurationPath -ErrorAction SilentlyContinue
}
