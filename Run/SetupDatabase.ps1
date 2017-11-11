﻿# INPUT
#     $bakFile (optional)
#     $runningSpecificImage (not building or restarting)
#
# OUTPUT
#     $databaseServer
#     $databaseInstance
#     $databaseName
#

$restoreDb = $false
if ($restartingInstance) {

    # Nothing to do

} elseif ($bakfile -ne "") {

    # .bak file specified - restore and use
    # if bakfile specified, download, restore and use
    
    if ($bakfile.StartsWith("https://") -or $bakfile.StartsWith("http://"))
    {
        $bakfileurl = $bakfile
        $databaseFile = (Join-Path $runPath "mydatabase.bak")
        Write-Host "Downloading database backup file '$bakfileurl'"
        (New-Object System.Net.WebClient).DownloadFile($bakfileurl, $databaseFile)
    
    } else {
        Write-Host "Using Database .bak file '$bakfile'"
        if (!(Test-Path -Path $bakfile -PathType Leaf)) {
        	Write-Error "ERROR: Database Backup File not found."
            Write-Error "The file must be uploaded to the container or available on a share."
            exit 1
        }
        $databaseFile = $bakFile
    }
    $databaseName = "mydatabase"
    $restoreDb = $true

} elseif ($buildingImage) {

    # Restore CRONUS Demo database to databases folder

    Write-Host "Restore CRONUS Demo Database"
    $databaseName = "CRONUS"
    $bak = (Get-ChildItem -Path "$navDvdPath\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\*\Database\*.bak")[0]
    $databaseFile = $bak.FullName
    $restoreDb = $true

} elseif ($databaseServer -ne "localhost" -or $databaseInstance -ne "SQLEXPRESS" -or $databaseName -ne "") {

    Write-Host "Using Database Connection $DatabaseServer/$DatabaseInstance [$DatabaseName]"

} else {
    
    Write-Error "ERROR: Internal Error"
    exit 1
    
}

if ($restoreDb) {

    # Restore database
    $databaseServer = "localhost"
    $databaseInstance = "SQLEXPRESS"
    $databaseFolder = "c:\databases"
    if (!(Test-Path -Path $databaseFolder -PathType Container)) {
        New-Item -Path $databaseFolder -itemtype Directory | Out-Null
    }

    New-NAVDatabase -DatabaseServer $databaseServer `
                    -DatabaseInstance $databaseInstance `
                    -DatabaseName "$databaseName" `
                    -FilePath "$databaseFile" `
                    -DestinationPath "$databaseFolder" `
                    -Timeout $SqlTimeout | Out-Null
}