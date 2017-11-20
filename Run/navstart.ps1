# This script is multi-purpose
#
# $buildingImage is true when called during build of specific NAV image (with CRONUS Demo Database and CRONUS license)
# $restartingInstance is true when called due to Docker restart of a running image
# $runningSpecificImage is true when running a specific image (which had buildingImage set true true during image build)

# This script should contaian and invoke a runtime code only!!!
# We know if we modify this script we should be OK with the rebuilding the top layer only.

Write-Host "Initializing..."

$runPath = "c:\Run"
$myPath = Join-Path $runPath "my"
$navDvdPath = "C:\NAVDVD"

$publicDnsNameFile = "$RunPath\PublicDnsName.txt"
$publicDnsNameChanged = $false
$restartingInstance = Test-Path -Path $publicDnsNameFile -PathType Leaf

function Get-MyFilePath([string]$FileName)
{
    if ((Test-Path $myPath -PathType Container) -and (Test-Path (Join-Path $myPath $FileName) -PathType Leaf)) {
        (Join-Path $myPath $FileName)
    } else {
        (Join-Path $runPath $FileName)
    }
}

$hostname = hostname

. (Get-MyFilePath "HelperFunctions.ps1")
. (Get-MyFilePath "New-SelfSignedCertificateEx.ps1")
. (Get-MyFilePath "SetupVariables.ps1")

Write-Host "Hostname is $hostname"
Write-Host "PublicDnsName is $publicDnsName"

# Ensure correct casing
if ($auth -eq "" -or $auth -eq "navuserpassword") {
    $auth = "NavUserPassword"
} elseif ($auth -eq "windows") {
    $auth = "Windows"
}
$windowsAuth = ($auth -eq "Windows")

$NavServiceName = 'MicrosoftDynamicsNavServer$NAV'
$SqlServiceName = 'MSSQL$SQLEXPRESS'
$SqlWriterServiceName = "SQLWriter"
$SqlBrowserServiceName = "SQLBrowser"
$IisServiceName = "W3SVC"

if ($WindowsAuth) {
    $navUseSSL = $false
} else {
    $navUseSSL = $true
}

if ($useSSL -eq "") {
    $servicesUseSSL = $navUseSSL
} elseif ($useSSL -eq "Y") {
    $servicesUseSSL = $true
} elseif ($useSSL -eq "N") {
    $servicesUseSSL = $false
} else {
    throw "Illegal value for UseSSL"
}

if ($servicesUseSSL) {
    $protocol = "https://"
    $webClientPort = 443
} else {
    $protocol = "http://"
    $webClientPort = 80
}

# Default public ports
if ($publicWebClientPort -ne "") { $publicWebClientPort = ":$publicWebClientPort" }
if ($publicFileSharePort -eq "") { $publicFileSharePort = "8080" }
if ($publicWinClientPort -eq "") { $publicWinClientPort = "7046" }
if ($publicSoapPort      -eq "") { $publicSoapPort      = "7047" }
if ($publicODataPort     -eq "") { $publicODataPort     = "7048" }

if ($restartingInstance) {
    Write-Host "Restarting Instance"
    $prevPublicDnsName = Get-Content -Path $publicDnsNameFile
    if ($prevPublicDnsName -ne $publicDnsName) {
        $publicDnsNameChanged = $true
        Write-Host "PublicDnsName changed"
    }
}

Set-Content -Path $publicDnsNameFile -Value $publicDnsName

$runningSpecificImage = (!$restartingInstance)
if ($runningSpecificImage) { Write-Host "Running Specific Image" }

if ($restartingInstance + $runningSpecificImage -ne 1) {
    Write-Error "Cannot determine reason for running script."
    exit 1
}

if ($runningSpecificImage -and $Accept_eula -ne "Y")
{
    Write-Error "You must accept the End User License Agreement before this container can start.
Use Docker inspect to locate the Url for the EULA under Labels/legal.
set the environment variable ACCEPT_EULA to 'Y' if you accept the agreement."
    exit 1
}

$containerAge = [System.DateTime]::Now.Subtract((Get-Item "C:\RUN").CreationTime).Days
if (($runningSpecificImage -or $buildingImage) -and ($containerAge -gt 90)) {
    if ($Accept_outdated -ne "Y") {
        Write-Error "You are trying to run a container which is more than 90 days old.
Microsoft recommends that you always run the latest version of our containers.
Set the environment variable ACCEPT_OUTDATED to 'Y' if you want to run this container anyway."
        exit 1
    }
}

if ($runningSpecificImage) {
    Write-Host "Using $auth Authentication"
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

# DUP: Preset NAV paths
$serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
$roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName
$clickOnceInstallerToolsFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\ClickOnce Installer Tools").FullName
$WebClientFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Web Client")[0]
$NAVAdministrationScriptsFolder = (Get-Item "$runPath\NAVAdministration").FullName

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

# Shared code
if ($runningSpecificImage) {
    Set-NavConfig
}

if ($runningSpecificImage -or $publicDnsNameChanged) {

    # Certificate
    if ($navUseSSL -or $servicesUseSSL) {
        . (Get-MyFilePath "SetupCertificate.ps1")
    }
    
    . (Get-MyFilePath "SetupConfiguration.ps1")
}

if ($runningSpecificImage) {

    . (Get-MyFilePath "SetupAddIns.ps1")
}

# DUP: Start NAV Service
Write-Host "Start NAV Service Tier"
Start-Service -Name $NavServiceName -WarningAction Ignore

# Shared Code
. (Get-MyFilePath "SetupLicense.ps1")

# DUP: www/hhtp vars
$wwwRootPath = Get-WWWRootPath
$httpPath = Join-Path $wwwRootPath "http"

if ($runningSpecificImage -or $publicDnsNameChanged) {

    if ($webClient -ne "N") {

        . (Get-MyFilePath "SetupWebClient.ps1")
        . (Get-MyFilePath "SetupWebConfiguration.ps1")
    }

}

if ($runningSpecificImage) {

    if ($httpSite -ne "N") {
        Write-Host "Creating http download site"
        New-Item -Path $httpPath -ItemType Directory | Out-Null
        New-Website -Name http -Port 8080 -PhysicalPath $httpPath | Out-Null
    
        $webConfigFile = Join-Path $httpPath "web.config"
        Copy-Item -Path (Join-Path $runPath "web.config") -Destination $webConfigFile
        get-item -Path $webConfigFile | % { $_.Attributes = "Hidden" }
    
        . (Get-MyFilePath "SetupFileShare.ps1")
    }

    . (Get-MyFilePath "SetupWindowsUsers.ps1")
    . (Get-MyFilePath "SetupSqlUsers.ps1")
    . (Get-MyFilePath "SetupNavUsers.ps1")
}

if (($runningSpecificImage -or $publicDnsNameChanged) -and ($httpSite -ne "N") -and ($clickOnce -eq "Y")) {
    Write-Host "Creating ClickOnce Manifest"
    . (Get-MyFilePath "SetupClickOnce.ps1")
}

if ($runningSpecificImage) {
    . (Get-MyFilePath "AdditionalSetup.ps1")
}


$CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
$CustomConfig = [xml](Get-Content $CustomConfigFile)

$ip = (Get-NetIPAddress | Where-Object { $_.AddressFamily -eq "IPv4" -and $_.IPAddress -ne "127.0.0.1" })[0].IPAddress
Write-Host "Container IP Address: $ip"
Write-Host "Container Hostname  : $hostname"
Write-Host "Container Dns Name  : $publicDnsName"
if ($webClient -ne "N") {
    $publicWebBaseUrl = $CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value
    Write-Host "Web Client          : $publicWebBaseUrl"
}
if ($auth -ne "Windows" -and !$passwordSpecified -and !$restartingInstance) {
    Write-Host "NAV Admin Username  : $username"
    Write-Host ("NAV Admin Password  : "+[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)))
}
if ($httpSite -ne "N") {
    if (Test-Path -Path (Join-Path $httpPath "*.vsix")) {
        Write-Host "Dev. Server         : $protocol$publicDnsName"
        Write-Host "Dev. ServerInstance : NAV"
    }
    if ($clickOnce -eq "Y") {
        Write-Host "ClickOnce Manifest  : http://${publicDnsName}:$publicFileSharePort/NAV"
    }
}

. (Get-MyFilePath "AdditionalOutput.ps1")

Write-Host 
if ($httpSite -ne "N") {
    Write-Host "Files:"
    Get-ChildItem -Path $httpPath -file | % {
        Write-Host "http://${publicDnsName}:$publicFileSharePort/$($_.Name)"
    }
    Write-Host 
}

if ($containerAge -gt 60) {
    Write-Host "You are running a container which is $containerAge days old.
Microsoft recommends that you always run the latest version of our containers."
    Write-Host
}

Write-Host "Ready for connections!"


if ("$securepassword") {
    Clear-Variable -Name "securePassword"
}