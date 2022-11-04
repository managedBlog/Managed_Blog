Start-Transcript -Path C:\ProgramData\AADMigration\Logs\AD2AADJ-R3.txt -Append -Force
$MigrationConfig = Import-LocalizedData -BaseDirectory "C:\ProgramData\AADMigration\scripts\" -FileName "MigrationConfig.psd1"
$TempUser = $MigrationConfig.TempUser

#Function to set registry values
function Set-RegistryValue {

  [cmdletBinding()]
  param(
      [Parameter(Mandatory=$True)]
      [string]$RegKeyPath,
      [Parameter(Mandatory=$True)]
      [string]$RegValueName,
      [Parameter(Mandatory=$True)]
      [string]$RegValType,
      [Parameter(Mandatory=$False)]
      [string]$RegValData
  )


  #Test to see if Edge key exists, if it does not exist create it
  $RegKeyPathExists = Test-Path $RegKeyPath
  Write-Host "$RegKeyPath Exists"
  if (!$RegKeyPathExists) {
      New-Item -Path $RegKeyPath -Force | Out-Null
  }


  #Check to see if value exists
  Try {
           $CurrentValue = Get-ItemPropertyValue -Path $RegKeyPath -Name $RegValName 
  } Catch {       
      #If value does not exist an error would be thrown, catch error and create key
      Set-ItemProperty -Path $RegKeyPath  -Name $RegValName -Type $RegValType -Value $RegValData -Force
  }


  IF($CurrentValue -ne $RegValData){
      #If value exists but data is wrong, update the value
      Set-ItemProperty -Path $RegKeyPath  -Name $RegValName -Type $RegValType -Value $RegValData -Force
  } 


} 

#Clean up after ourselves

#Remove localuser account created for Migration
Remove-LocalUser -name $TempUser

#Remove autologon settings and default user and password from registrt
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty $RegPath "AutoAdminLogon" -Value "0" -type String
Set-ItemProperty $RegPath "DefaultUsername" -Value $null -type String 
Set-ItemProperty $RegPath "DefaultPassword" -Value $null -type String

#Remove setting to not show local user
Write-Output "Setting key to show last logged in user" 
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\"
$RegValName = "dontdisplaylastusername"
$RegValType = "DWORD"
$RegValData = "0"

Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData

#Clear legal notice caption
Write-Output "Setting legal notice caption" 
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\"
$RegValName = "legalnoticecaption"
$RegValType = "String"
$RegValData = $null

Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData

#Clear legal notice text
Write-Output "Setting legal notice text" 
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\"
$RegValName = "legalnoticetext"
$RegValType = "String"
$RegValData = $null

Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData

#Re-enable lock screen
Write-Output "Re-enable lock screen"
$RegKeyPath = "HKLM:\Software\Policies\Microsoft\Windows\Personalization"
$RegValName = "NoLockScreen"
$RegValType = "DWORD"
$RegValData = "0"

Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData



#Enumerate local user accounts and disable them
$Users = Get-LocalUser | Where-Object { $_.Enabled -eq $True -and $_.Name -notlike 'default*'}

ForEach($User in $Users){

  Write-Output "Disabling local user account $User"
  Disable-LocalUser $User

}

#Delete scheduled tasks created for migration
$taskPath = "AAD Migration"
$tasks = Get-ScheduledTask -TaskPath "\$taskpath\"
ForEach($Task in $Tasks){

    Unregister-ScheduledTask -TaskName $Task.TaskName -Confirm:$false
    
}

$scheduler = new-object -com("Schedule.Service")
$scheduler.Connect()
$rootFolder = $scheduler.GetFolder("\")
$rootFolder.DeleteFolder("$taskPath",$null)

#Delete migration files, leave log folder
#Remove PPKG files, which include nested credentials
$FileName = "C:\ProgramData\AADMigration\Files"
if (Test-Path $FileName) {
  Remove-Item $FileName -Recurse -Force
}

$FileName = "C:\ProgramData\AADMigration\Scripts"
if (Test-Path $FileName) {
  Remove-Item $FileName -Recurse -Force
}

$FileName = "C:\ProgramData\AADMigration\Toolkit"
if (Test-Path $FileName) {
  Remove-Item $FileName -Recurse -Force
}


#Launch OneDrive
#Start-Process -FilePath "C:\Program Files (x86)\Microsoft OneDrive\OneDrive.exe"

Stop-Transcript
