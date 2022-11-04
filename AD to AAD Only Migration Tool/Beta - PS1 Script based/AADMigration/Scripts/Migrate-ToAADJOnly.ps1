<#
Name: Migrate-ToAADJOnly
Author: Sean Bulger, twitter @managed_blog, http://managed.modernendpoint.com
Credits: This script is adapted from Adam Nichols' AD to AADJ Migration script, which can be found at https://mauvtek.com/home/active-directory-join-to-azure-ad-join. Follow Adam on Twitter @mauvlan
This is meant to be used as part of a migration package which includes a provisioning pack, additional scripts, and utilities. 
It can be launched independently or using another packaging tool like PS App Deploy Toolkit to provide a better end user experience.

.Synopsis
   Launches a process to migrate a domain joined computer to AAD only join
.DESCRIPTION
   Additional comments will be added soon.
#>


#Start Transcription
Start-Transcript -Path C:\ProgramData\AADMigration\Logs\AD2AADJ.txt -NoClobber
$MigrationConfig = Import-LocalizedData -BaseDirectory "C:\ProgramData\AADMigration\scripts\" -FileName "MigrationConfig.psd1"


# Script variables
$DomainLeaveUser = $MigrationConfig.DomainLeaveUser
$DomainLeavePassword = $MigrationConfig.DomainLeavePass
$TempUser = $MigrationConfig.TempUser
$TempUserPassword = $MigrationConfig.TempPass
$PPKGName = $MigrationConfig.ProvisioningPack

function Test-ProvisioningPack {

    #Test to see if the provisioning package was previously installed on this system. If it did, remove it prior to continuing
    Write-Output "Testing to see if provisioning package previously installed"
    $PPKGStatus = Get-ProvisioningPackage | Where PackagePath -like "*$PPKGName*"


    If($PPKGStatus){

        Write-Output "Provisioning package previously installed. Removing PPKG."
        $PPKGID = $PPKGStatus.PackageID
        Remove-ProvisioningPackage $PPKGID

    }


}

function Add-LocalUser {

    # Create Local Account 
    Write-Output "Creating Local User Account"
    $Password = ConvertTo-SecureString -AsPlainText $TempUserPassword -force
    New-LocalUser -Name $TempUser -Password $Password -Description "account for autologin" -AccountNeverExpires
    Add-LocalGroupMember -Group "Administrators" -Member $TempUser
    
}

function Set-Autologin {

    # Set Auto login Registry
    Write-Output "Setting user account to Auto Login" 
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String -Verbose
    Set-ItemProperty $RegPath "DefaultUsername" -Value $TempUser -type String -Verbose
    Set-ItemProperty $RegPath "DefaultPassword" -Value $TempUserPassword -type String -Verbose

}

function Disable-OOBEPrivacy  {

    #Disable privacy experience
    $RegistryPath = 'HKLM:\Software\Policies\Microsoft\Windows\OOBE'
    $Name = 'DisablePrivacyExperience'
    $Value = '1'
    # Create the key if it does not exist
    If (-NOT (Test-Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }  
    # Now set the value
    New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force -Verbose

    #Disable first logon animation
    $AnimationRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $AnimationName = 'EnableFirstLogonAnimation'
    $AnimationValue = '0'
    # Create the key if it does not exist
    If (-NOT (Test-Path $AnimationRegistryPath)) {
        New-Item -Path $AnimationRegistryPath -Force | Out-Null
    }  
    # Now set the value
    New-ItemProperty -Path $AnimationRegistryPath -Name $AnimationName -Value $AnimationValue -PropertyType DWORD -Force -Verbose

    #Remove lock screen
    $LockRegPath = "HKLM:\Software\Policies\Microsoft\Windows\Personalization"
    $LockRegName = "NoLockScreen"
    $LockValue = "1"

    If (-NOT (Test-Path $LockRegPath)) {
        New-Item -Path $LockRegPath -Force | Out-Null
    }  
    New-ItemProperty -Path $LockRegPath -Name $LockRegName -Value $LockValue -PropertyType DWORD -Force -Verbose

}

function Set-RunOnce {
    
    # Set Run Once Regestry
    Write-Host "Changing RunOnce script." 

    $RunOnceKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"

    set-itemproperty $RunOnceKey "NextRun" ('C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe -executionPolicy Unrestricted -File ' + "C:\ProgramData\AADMigration\Scripts\PostRunOnce.ps1") -Verbose

}

function Set-Bitlocker {

    #Check to see if disk is encrypted, if not skip this step
    Suspend-BitLocker -MountPoint "C:" -RebootCount 3 -Verbose

}


function Remove-IntuneMgmt {
    
    #Check to see if device is enrolled in Intune, if it is unenroll it by clearing registry keys, deleting scheduled task, and deleting enrollment certificates
    #Special thanks to  @philhelming. This function was borrowed from his Intune to WS1 Migration script, which can be found here: https://github.com/helmlingp/apps_WS1UEMWin10Migration/blob/master/IntunetoWS1Win10Migration.ps1
    $OMADMPath = "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\*"
    $Account = (Get-ItemProperty -Path $OMADMPath -ErrorAction SilentlyContinue).PSChildname

    $Enrolled = $true
    $EnrollmentPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Enrollments\$Account"
    $EnrollmentUPN = (Get-ItemProperty -Path $EnrollmentPath -ErrorAction SilentlyContinue).UPN
    $ProviderID = (Get-ItemProperty -Path $EnrollmentPath -ErrorAction SilentlyContinue).ProviderID

    if(!($EnrollmentUPN) -or $ProviderID -ne "MS DM Server") {
        $Enrolled = $false
    }

    If($Enrolled){

        #Delete Task Schedule tasks
        Get-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\$Account\*" | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

        #Delete reg keys
        Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Enrollments\$Account" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Enrollments\Status\$Account" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\$Account" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled\$Account" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\Providers\$Account" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$Account" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\$Account" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\$Account" -Recurse -Force -ErrorAction SilentlyContinue
        
        #Delete Enrolment Certificates
        $UserCerts = get-childitem cert:"CurrentUser" -Recurse
        $IntuneCerts = $UserCerts | Where-Object {$_.Issuer -eq "CN=SC_Online_Issuing"}
        foreach ($Cert in $IntuneCerts) {
            $cert | Remove-Item -Force
        }
        $DeviceCerts = get-childitem cert:"LocalMachine" -Recurse
        $IntuneCerts = $DeviceCerts | Where-Object {$_.Issuer -eq "CN=Microsoft Intune Root Certification Authority" -OR $_.Issuer -eq "CN=Microsoft Intune MDM Device CA"}
        foreach ($Cert in $IntuneCerts) {
            $cert | Remove-Item -Force -ErrorAction SilentlyContinue
        }

        #Delete Intune Company Portal App
        Get-AppxPackage -AllUsers -Name "Microsoft.CompanyPortal" | Remove-AppxPackage -Confirm:$false

    }

}

function Remove-Hybrid {

    #Check to see if device is Azure AD joined. If yes, remove hybrid join. Added check to prevent error in logs when running /leave on device that is not joined.
    $Dsregcmd = New-Object PSObject ; Dsregcmd /status | Where {$_ -match ' : '}|ForEach {$Item = $_.Trim() -split '\s:\s'; $Dsregcmd|Add-Member -MemberType NoteProperty -Name $($Item[0] -replace '[:\s]','') -Value $Item[1] -EA SilentlyContinue}

    $AzureADJoined = $DSRegCmd.AzureAdJoined
    
    If($AzureADJoined -eq 'Yes'){

        .\C:\Windows\System32\dsregcmd.exe /leave

    }

    
}

function Remove-ADJoin {
    
    
    #Check if device is domain joined, if joined remove from domain
    $ComputerDomain = Get-WmiObject -Class Win32_ComputerSystem | Select-Object PartOfDomain,domain
    $Domain = $ComputerDomain.domain
    $PartOfDomain = $ComputerDomain.PartOfDomain
    If($PartOfDomain){
    
        Write-Output "Computer is domain member, removing domain membership"          
        If(Test-Connection $domain){
    
            #If connected to domain, leave domain
            Write-Output "Connected to domain, attempting to leave domain."
    
            #If there is a value in $DomainLeaveUser, attempt to leave the domain with network credentials
            #If this is successful, the computer will immediately reboot, if not it will continue with the function
            If($DomainLeaveUser){

                $pw = $DomainLeavePassword | ConvertTo-SecureString -asPlainText -Force
                $usr = $DomainLeaveUser
                $creds = New-Object System.Management.Automation.PSCredential($usr, $pw)
                $pc = "localhost"

                Try {

                    Remove-Computer -ComputerName $PC -credential $creds -Verbose -Force -ErrorAction Stop
                    Disable-ScheduledTask -TaskName "AADM Launch PSADT for Interactive Migration"
                    Stop-Transcript
                    Restart-Computer

                } Catch {

                    Write-Output "Leaving domain with domain credentials failed. Will leave domain with local account."
                    #$DomainLeaveUser = $null

                }

            } 

            #If there is no $DomainLeaveUser or if leaving with domain credentials fails, try with local account
            #Disable network adapters and try again
            $pw = $TempUserPassword | ConvertTo-SecureString -asPlainText -Force
            $usr = $TempUser
            $creds = New-Object System.Management.Automation.PSCredential($usr, $pw)
            $pc = "localhost"

            Write-Output "Leaving domain with local admin account after disconnecting from network."

            $ConnectedAdapters = Get-NetAdapter | Where-Object MediaConnectionState -eq "Connected"
            
            ForEach ($Adapter in $ConnectedAdapters){
    
                Write-Output "Disabling network adapter $($Adapter.name)"
                Disable-NetAdapter -Name $Adapter.Name -Confirm:$false
                
            } 
    
            Start-Sleep -Seconds 5
    
            #Network adapters disabled, remove computer from domain. 
            $pc = "localhost"
            Remove-Computer -ComputerName $pc -Credential $creds -Verbose -Force
                
            ForEach ($Adapter in $ConnectedAdapters){
    
                Write-Output "Enabling network adapter $($Adapter.name)"
                Enable-NetAdapter -Name $Adapter.Name -Confirm:$false
                
            }        
    
            Start-Sleep -Seconds 15
    
            Write-Output "Computer removed from domain. Network adapters re-enabled. Restarting."
            Disable-ScheduledTask -TaskName "AADM Launch PSADT for Interactive Migration"
            Stop-Transcript
            Restart-Computer
    
    
        } Else {
    
            # Remove Machines from AD
            Write-Verbose "Removing computer from domain and forcing restart"
    
            Write-Output "Stopping transcript and calling Remove-Computer with -Restart switch."
            Stop-Transcript
            Remove-Computer -ComputerName $PC -credential $creds -Verbose -Force -ErrorAction Stop
            Disable-ScheduledTask -TaskName "AADM Launch PSADT for Interactive Migration"
            Stop-Transcript
            Restart-Computer
    
        }
    
    }	Else {
    
        Write-Output "Computer is not a domain member, restarting computer."
        Disable-ScheduledTask -TaskName "AADM Launch PSADT for Interactive Migration"
        Stop-Transcript
        Restart-Computer
    
    }

}


# Main Logic
Test-ProvisioningPack

Add-LocalUser

Set-Autologin

Disable-OOBEPrivacy

Set-RunOnce

Set-Bitlocker

Remove-IntuneMgmt

Remove-Hybrid

Remove-ADJoin