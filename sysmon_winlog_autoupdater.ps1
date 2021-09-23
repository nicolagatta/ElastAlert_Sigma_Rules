$MyHost=[System.NET.DNS]::GetHostByName($null)

# Setting up email params
$Email_From='INSERT_MAIL_FROM'
$Email_To='INSERT_MAIL_RECIPIENT'
$Email_Subject="["+$MyHost.HostName+"] - ELK Update"
$SMTP_Server="__YourSMTP__"

# Setting up sysmon install params
$Local_Dir='C:\tools\sysmon\'
$Remote_Dir='\\yourserver\Sysmon\'

$VersionFile='version.txt'
$Config_File=$Local_Dir+'sysmon_config.xml'
$Sysmon_File=$Local_Dir+'sysmon64.exe'

$Local_File=$Local_Dir+$VersionFile
$Remote_File=$Remote_Dir+$VersionFile


$Sysmon_version=(get-content $Remote_File)

if ((get-content $Local_File) -ne (get-content $Remote_File)) {
    $update_sysmon=1 
    $message="Updating Sysmon version to " + $Sysmon_version + " on host"+  $MyHost.HostName
    
    
    # Uninstall Current sysmon installation
    Start-Process -FilePath $Sysmon_File -ArgumentList "-u force" -wait

    # Copy new sysmon folder 
    Copy-Item $Remote_Dir\* -Destination $Local_Dir -Recurse
    
    # Install new sysmon version

    Start-Process -FilePath $Sysmon_File -ArgumentList "-accepteula -i $Config_File"

} else {
    $update_sysmon=0
}


$Local_Dir='C:\tools\winlogbeat'
$Remote_Dir='\\yourserver\winlogbeat\'

$VersionFile='\version.txt'
$Config_File=$Local_Dir+'\winlogbeat.yml'
$Winlogbeat_File=$Local_Dir+'\winlogbeat.exe'

$Local_File=$Local_Dir+$VersionFile
$Remote_File=$Remote_Dir+$VersionFile


$MyHost=[System.NET.DNS]::GetHostByName($null)

$winlog_version=(get-content $Remote_File)

if ((get-content $Local_File) -ne (get-content $Remote_File)) {
    $update_winlog=1
    $message= $message + "`n`nUpdating Winlogbeat version to " + $winlog_version + " on host" + $MyHost.HostName
    
    # Uninstall Current sysmon installation
    if (Get-Service winlogbeat -ErrorAction SilentlyContinue) {
        $service = Get-WmiObject -Class Win32_Service -Filter "name='winlogbeat'"
        $service.StopService()
        Start-Sleep -s 5
        $service.delete()
    }


    
    # Copy new winlogbeat folder 
    Copy-Item $Remote_Dir\* -Destination $Local_Dir -Recurse -Force
    
    # Install new sysmon version
    if (Get-Service winlogbeat -ErrorAction SilentlyContinue) {
        $service = Get-WmiObject -Class Win32_Service -Filter "name='winlogbeat'"
        $service.StopService()
        Start-Sleep -s 1
        $service.delete()
    }
   

    # Create the new service.
    New-Service -name winlogbeat -displayName 'Winlogbeat' -binaryPathName "`"$Winlogbeat_file`" --environment=windows_service -c `"$Config_File`" --path.home `"$Local_Dir`" --path.data `"$env:PROGRAMDATA\winlogbeat`" --path.logs `"$env:PROGRAMDATA\winlogbeat\logs`" -E logging.files.redirect_stderr=true"

    # Attempt to set the service to delayed start using sc config.
    Try {
        Start-Process -FilePath sc.exe -ArgumentList 'config winlogbeat start= delayed-auto'
    }
    Catch { 
        $message= $message + "`nAn error occured setting the service to delayed start." 
    }

    
    Try {
        Start-Process -FilePath sc.exe -ArgumentList 'start winlogbeat'
    }
    Catch { 
        $message=$message + "`nAn error occured starting Winlogbeat service to delayed start." 
    }
} else {
    $update_winlog=0
}



if ($update_winlog -eq 1 -or $update_winlog -eq 1) {
    Send-MailMessage -From $Email_From -To $Email_To -Body $message -Subject $Email_Subject  -Priority High -dno onSuccess, onFailure -SmtpServer $SMTP_Server
}

