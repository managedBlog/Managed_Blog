#Set value for registry key to set
$RegKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$RegValName = "ConfigureViewInFileExplorer"
$RegValData = '[{\"cookies\": [\"rtFa\", \"FedAuth\"], \"domain\": \"sharepoint.com\"}]'

#Set Output to 0, change to 1 if any other value is not correct
$Output = 0

#Test to see if Edge key exists
$RegKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$RegKeyPathExists = Test-Path $RegKeyPath
if (!$RegKeyPathExists) {

    $Output = 1
}


#If Edge key exists, check to see if required value exists. If value exists, confirm data is correct
If($RegKeyPathExists){
        
    Try {
        
        $CurrentValue = Get-ItemPropertyValue -Path $RegKeyPath -Name $RegValName 

    } Catch {

        #If value does not exist an error would be thrown, catch error and exit script with code of 1
        $Output = 1
        Exit $Output

    }

    #If value exists with incorrect data, set output to 1
    if ($CurrentValue -ne $RegValData) {
        
        Write-Host "Key does not match"
        $Output = 1

    }

}

#Exit script with value of output. If all settings are correct, it should return a 0
Exit $Output
