#Import OneDriveLib.dll to check current OneDrive Sync Status
Import-Module C:\ProgramData\AADMigration\Files\OneDriveLib.dll
$Status = Get-ODStatus

#Create objects with known statuses listed.
$Success = @( "Shared" , "UpToDate" , "Up To Date" )
$InProgress = @( "SharedSync" , "Shared Sync" , "Syncing" )
$Failed = $( "Error" , "ReadOnly" , "Read Only" , "OnDemandOrUnknown" , "On Demand or Unknown" , "Paused")

#Multiple OD4B accounts may be found. Consider adding logic to identify correct OD4B. Iterate through all accounts to check status and write to event log.
ForEach($s in $Status){

    $StatusString = $s.StatusString
    $DisplayName = $s.DisplayName
    $User = $s.UserName

    If($s.StatusString -in $Success){ 

        Write-EventLog -LogName 'Application' -Source 'AAD_Migration_Script' -EntryType Information -EventId 1337 `
            -Message "The OneDrive sync status is healthy. The following values were returned: OneDrive Display Name: $DisplayName, User: $User, Status: $StatusString"


    } elseif ($s.StatusString -in $InProgress) {
        
        Write-EventLog -LogName 'Application' -Source 'AAD_Migration_Script' -EntryType Information -EventId 1338 `
        -Message "The OneDrive sync status is currently syncing. The following values were returned: OneDrive Display Name: $DisplayName, User: $User, Status: $StatusString"

    } elseif ($s.StatusString -in $Failed) {

        Write-EventLog -LogName 'Application' -Source 'AAD_Migration_Script' -EntryType Information -EventId 1339 `
        -Message "The OneDrive sync status is in a known error state. The following values were returned: OneDrive Display Name: $DisplayName, User: $User, Status: $StatusString"

    } elseif(!($s.StatusString)){
        
        Write-EventLog -LogName 'Application' -Source 'AAD_Migration_Script' -EntryType Information -EventId 1340 `
        -Message "Unable to get OneDrive Sync Status."

    }

    If(!($Status.StatusString)){

        Write-EventLog -LogName 'Application' -Source 'AAD_Migration_Script' -EntryType Information -EventId 1340 `
            -Message "Unable to get OneDrive Sync Status."


    }

}