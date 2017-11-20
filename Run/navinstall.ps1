Write-Host "Building Image"

if (!(Test-Path $navDvdPath -PathType Container)) {
    Write-Error "NAVDVD folder not found
You must map a folder on the host with the NAVDVD content to $navDvdPath"
    exit 1
}

# DUP: SQL Start
if ($databaseServer -eq 'localhost') {
    # start the SQL Server
    Write-Host "Starting Local SQL Server"
    Start-Service -Name $SqlBrowserServiceName -ErrorAction Ignore
    Start-Service -Name $SqlWriterServiceName -ErrorAction Ignore
    Start-Service -Name $SqlServiceName -ErrorAction Ignore
}

# DUP: IIS Start
if (($webClient -ne "N") -or ($httpSite -ne "N")) {
    # start IIS services
    Write-Host "Starting Internet Information Server"
    Start-Service -name $IisServiceName
}

# Prerequisites
if ($webClient -ne "N") {
    Write-Host "Installing Url Rewrite"
    start-process "$NavDvdPath\Prerequisite Components\IIS URL Rewrite Module\rewrite_2.0_rtw_x64.msi" -ArgumentList "/quiet /qn /passive" -Wait

    Write-Host "Installing ReportViewer"
    if (Test-Path "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer" -PathType Container) {
        start-process "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer\SQLSysClrTypes.msi" -ArgumentList "/quiet /qn /passive" -Wait
        start-process "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer\ReportViewer.msi" -ArgumentList "/quiet /qn /passive" -Wait
    }

    if (Test-Path "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer 2015" -PathType Container) {
        start-process "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer 2015\SQLSysClrTypes.msi" -ArgumentList "/quiet /qn /passive" -Wait
        start-process "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer 2015\ReportViewer.msi" -ArgumentList "/quiet /qn /passive" -Wait
    }

    if (Test-Path "$NavDvdPath\Prerequisite Components\DotNetCore" -PathType Container) {
        Write-Host "Installing DotNetCore"
        start-process (Get-ChildItem -Path "$NavDvdPath\Prerequisite Components\DotNetCore" -Filter "*.exe").FullName -ArgumentList "/quiet" -Wait
    }
}

Write-Host "Installing OpenXML"
start-process "$NavDvdPath\Prerequisite Components\Open XML SDK 2.5 for Microsoft Office\OpenXMLSDKv25.msi" -ArgumentList "/quiet /qn /passive" -Wait


# Copy Service Tier in place if we are building a specific image
Write-Host "Copy Service Tier Files"
Copy-Item -Path "$NavDvdPath\ServiceTier\Program Files" -Destination "C:\" -Recurse -Force
Copy-Item -Path "$NavDvdPath\ServiceTier\System64Folder\NavSip.dll" -Destination "C:\Windows\System32\NavSip.dll" -Force -ErrorAction Ignore

Write-Host "Copy Web Client Files"
Copy-Item -Path "$NavDvdPath\WebClient\Microsoft Dynamics NAV" -Destination "C:\Program Files\" -Recurse -Force
if (Test-Path "$navDvdPath\WebClient\inetpub" -PathType Container) {
    Copy-Item -Path "$navDvdPath\WebClient\inetpub" -Destination $runPath -Recurse -Force
}

Write-Host "Copy RTC Files"
Copy-Item -Path "$navDvdPath\RoleTailoredClient\program files\Microsoft Dynamics NAV" -Destination "C:\Program Files (x86)\" -Recurse -Force
Copy-Item -Path "$navDvdPath\RoleTailoredClient\systemFolder\NavSip.dll" -Destination "C:\Windows\SysWow64\NavSip.dll" -Force -ErrorAction Ignore
Copy-Item -Path "$navDvdPath\ClickOnceInstallerTools\Program Files\Microsoft Dynamics NAV" -Destination "C:\Program Files (x86)\" -Recurse -Force
Copy-Item -Path "$navDvdPath\*.vsix" -Destination $runPath

Write-Host "Copy PowerShell Scripts"
Copy-Item -Path "$navDvdPath\WindowsPowerShellScripts\Cloud\NAVAdministration\" -Destination $runPath -Recurse -Force

Write-Host "Copy ClientUserSettings"
Copy-Item (Join-Path (Get-ChildItem -Path "$NavDvdPath\RoleTailoredClient\CommonAppData\Microsoft\Microsoft Dynamics NAV" -Directory | Select-Object -Last 1).FullName "ClientUserSettings.config") $runPath


# DUP: Preset NAV paths
$serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
$roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName
$clickOnceInstallerToolsFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\ClickOnce Installer Tools").FullName
$WebClientFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Web Client")[0]
$NAVAdministrationScriptsFolder = (Get-Item "$runPath\NAVAdministration").FullName


# Due to dependencies from finsql.exe, we have to copy hlink.dll and ReportBuilder in place inside the container
if (!(Test-Path (Join-Path $roleTailoredClientFolder 'hlink.dll'))) {
    Copy-Item -Path (Join-Path $runPath 'Install\hlink.dll') -Destination (Join-Path $roleTailoredClientFolder 'hlink.dll')
}
if (!(Test-Path (Join-Path $serviceTierFolder 'hlink.dll'))) {
    Copy-Item -Path (Join-Path $runPath 'Install\hlink.dll') -Destination (Join-Path $serviceTierFolder 'hlink.dll')
}
$reportBuilderPath = "C:\Program Files (x86)\ReportBuilder"
if (!(Test-Path $reportBuilderPath -PathType Container)) {
    $reportBuilderSrc = ""
    if (Test-Path "$navDvdPath\Prerequisite Components\Microsoft SQL Server 2014 Express" -PathType Container) {
        $reportBuilderSrc = Join-Path $runPath 'Install\ReportBuilder'
    } elseif (Test-Path "$navDvdPath\Prerequisite Components\Microsoft SQL Server" -PathType Container) {
        $msiPath = "$navDvdPath\Prerequisite Components\Microsoft SQL Server\ReportBuilder3.msi"
        if (Test-Path $msiPath -PathType Leaf) {
            $productName = GetMsiProductName -Path $msiPath
            if ($productName -eq "SQL Server Report Builder 3 for SQL Server 2014") {
                $reportBuilderSrc = Join-Path $runPath 'Install\ReportBuilder'
            }
            if ($productName -eq "Microsoft SQL Server 2016 Report Builder") {
                $reportBuilderSrc = Join-Path $runPath 'Install\ReportBuilder2016'
            }
        }
    }
    if ($reportBuilderSrc -eq "") {
        Write-Error "Cannot determine Report Builder Dependency ($msiPath - $productName)"
        exit 1
    }
    if (!(Test-Path $reportBuilderSrc -PathType Container)) {
        Write-Error "$reportBuilderSrc not present"
        exit 1
    }
    Write-Host "Copy ReportBuilder"
    New-Item $reportBuilderPath -ItemType Directory | Out-Null
    Copy-Item -Path "$reportBuilderSrc\*" -Destination "$reportBuilderPath\" -Recurse
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction Ignore | Out-null
    New-Item "HKCR:\MSReportBuilder_ReportFile_32" -itemtype Directory -ErrorAction Ignore | Out-null
    New-Item "HKCR:\MSReportBuilder_ReportFile_32\shell" -itemtype Directory -ErrorAction Ignore | Out-null
    New-Item "HKCR:\MSReportBuilder_ReportFile_32\shell\Open" -itemtype Directory -ErrorAction Ignore | Out-null
    New-Item "HKCR:\MSReportBuilder_ReportFile_32\shell\Open\command" -itemtype Directory -ErrorAction Ignore | Out-null
    Set-Item "HKCR:\MSReportBuilder_ReportFile_32\shell\Open\command" -value "$reportBuilderPath\MSReportBuilder.exe ""%1"""
}


# DUP: Import NAV Mgt Module
Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1"


# DUP: Setup DB
# Setup Database Connection
. (Get-MyFilePath "SetupDatabase.ps1")

if ($databaseServer -ne 'localhost') {
    if ((Get-service -name $SqlServiceName).Status -eq 'Running') {
        Write-Host "Stopping local SQL Server"
        Stop-Service -Name $SqlServiceName -ErrorAction Ignore
        Stop-Service -Name $SqlWriterServiceName -ErrorAction Ignore
        Stop-Service -Name $SqlBrowserServiceName -ErrorAction Ignore
    }
}


# run local installers if present
if (Test-Path "$navDvdPath\Installers" -PathType Container) {
    Get-ChildItem "$navDvdPath\Installers" | Where-Object { $_.PSIsContainer } | % {
        Get-ChildItem $_.FullName | Where-Object { $_.PSIsContainer } | % {
            $dir = $_.FullName
            Get-ChildItem (Join-Path $dir "*.msi") | % {
                $filepath = $_.FullName
                if ($filepath.Contains('\WebHelp\')) {
                    Write-Host "Skipping $filepath"
                } else {
                    Write-Host "Installing $filepath"
                    Start-Process -FilePath $filepath -WorkingDirectory $dir -ArgumentList "/qn /norestart" -Wait
                }
            }
        }
    }
}

# Shared code
Set-NavConfig


# Creating NAV Service
Write-Host "Creating NAV Service Tier"
$serviceCredentials = New-Object System.Management.Automation.PSCredential ("NT AUTHORITY\SYSTEM", (new-object System.Security.SecureString))
$serverFile = "$serviceTierFolder\Microsoft.Dynamics.Nav.Server.exe"
$configFile = "$serviceTierFolder\Microsoft.Dynamics.Nav.Server.exe.config"
New-Service -Name $NavServiceName -BinaryPathName """$serverFile"" `$NAV /config ""$configFile""" -DisplayName 'Microsoft Dynamics NAV Server [NAV]' -Description 'NAV' -StartupType manual -Credential $serviceCredentials -DependsOn @("HTTP") | Out-Null

$serverVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($serverFile)
$versionFolder = ("{0}{1}" -f $serverVersion.FileMajorPart,$serverVersion.FileMinorPart)
$registryPath = "HKLM:\SOFTWARE\Microsoft\Microsoft Dynamics NAV\$versionFolder\Service"
New-Item -Path $registryPath -Force | Out-Null
New-ItemProperty -Path $registryPath -Name 'Path' -Value "$serviceTierFolder\" -Force | Out-Null
New-ItemProperty -Path $registryPath -Name 'Installed' -Value 1 -Force | Out-Null

Install-NAVSipCryptoProvider

# DUP: Start NAV Service
Write-Host "Start NAV Service Tier"
Start-Service -Name $NavServiceName -WarningAction Ignore

# Shared Code
. (Get-MyFilePath "SetupLicense.ps1")

# DUP: www/hhtp vars
$wwwRootPath = Get-WWWRootPath
$httpPath = Join-Path $wwwRootPath "http"