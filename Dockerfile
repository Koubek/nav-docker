FROM microsoft/dotnet-framework:4.7-windowsservercore

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install the prerequisites first to be able reuse the cache when changing only the scripts.
# Temporary workaround for Windows DNS client weirdness (need to check if the issue is still present or not).
# Remove docker files from Sql server image
RUN Add-WindowsFeature Web-Server,web-AppInit,web-Asp-Net45,web-Windows-Auth,web-Dyn-Compression ; \
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Name ServerPriorityTimeLimit -Value 0 -Type DWord; \
    Invoke-WebRequest -Uri "https://download.microsoft.com/download/9/0/7/907AD35F-9F9C-43A5-9789-52470555DB90/ENU/SQLEXPR_x64_ENU.exe" -OutFile "sqlexpress.exe" ; \
    Start-Process -Wait -FilePath .\sqlexpress.exe -ArgumentList /qs, /x:setup ; \
    .\setup\setup.exe /q /ACTION=Install /INSTANCENAME=SQLEXPRESS /FEATURES=SQLEngine /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\System' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS ; \
    Remove-Item -Recurse -Force sqlexpress.exe, setup ; \
    Stop-Service 'W3SVC' ; \
    Stop-Service 'MSSQL$SQLEXPRESS' ; \
    Set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql13.SQLEXPRESS\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpdynamicports -value '' ; \
    Set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql13.SQLEXPRESS\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpport -value 1433 ; \
    Set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql13.SQLEXPRESS\mssqlserver\' -name LoginMode -value 2 ; \
    Set-Service 'W3SVC' -startuptype "manual" ; \
    Set-Service 'MSSQL$SQLEXPRESS' -startuptype "manual" ; \
    Set-Service 'SQLTELEMETRY$SQLEXPRESS' -startuptype "manual" ; \
    Set-Service 'SQLWriter' -startuptype "manual" ; \
    Set-Service 'SQLBrowser' -startuptype "manual" 
    
COPY Run /Run/

HEALTHCHECK --interval=30s --timeout=10s CMD [ "powershell", ".\\Run\\HealthCheck.ps1" ]

EXPOSE 1433 80 8080 443 7045-7049

CMD .\Run\start.ps1
