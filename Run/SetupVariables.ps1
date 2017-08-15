$username = "$env:username"
if ($username -eq "ContainerAdministrator") {
    $username = ""
}
$password = "$env:password"
$licensefile = "$env:licensefile"
$bakfile = "$env:bakfile"
if ($bakfile -ne "") {
    $databaseServer = "localhost"
    $databaseInstance = ""
    $databaseName = ""
} else {
    $databaseServer = "$env:databaseServer"
    $databaseInstance = "$env:databaseInstance"
    $databaseName = "$env:databaseName"
    if ($databaseServer -eq "") {
        $databaseServer = "localhost"
    }
}

$Accept_eula = "$env:Accept_eula"
$useSSL = "$env:UseSSL"
$auth = "$env:Auth"
if ($auth -eq "") {
    if ("$env:WindowsAuth" -eq "Y") {
        $auth = "Windows"
    }
}
$clickOnce = "$env:ClickOnce"
$SqlTimeout = "$env:SqlTimeout"
if ($SqlTimeout -eq "") {
    $SqlTimeout = "300"
}

$portNavMgtSvc = if ([System.String]::IsNullOrEmpty($env:portNavMgtSvc)) { 7045 } else { $env:portNavMgtSvc }
$portNavSvc = if ([System.String]::IsNullOrEmpty($env:portNavSvc)) { 7046 } else { $env:portNavSvc }
$portNavSoapSvc = if ([System.String]::IsNullOrEmpty($env:portNavSoapSvc)) { 7047 } else { $env:portNavSoapSvc } 
$portNavODataSvc = if ([System.String]::IsNullOrEmpty($env:portNavODataSvc)) { 7048 } else { $env:portNavODataSvc } 
$portNavDevSvc = if ([System.String]::IsNullOrEmpty($env:portNavDevSvc)) { 7049 } else { $env:portNavDevSvc }

$portNavWebClient = if ([System.String]::IsNullOrEmpty($env:portNavWebClient)) { 80 } else { $env:portNavWebClient }
$portNavWebClientSsl = if ([System.String]::IsNullOrEmpty($env:portNavWebClientSsl)) { 443 } else { $env:portNavWebClientSsl }

$sslPorts = { $portNavMgtSvc, $portNavSvc, $portNavSoapSvc, $portNavODataSvc, $portNavDevSvc }