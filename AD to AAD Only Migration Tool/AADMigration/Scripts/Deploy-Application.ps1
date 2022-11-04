<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall','Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = ''
	[string]$appName = ''
	[string]$appVersion = ''
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = 'XX/XX/20XX'
	[string]$appScriptAuthor = '<author name>'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = 'Azure Active Directory Migration'
	[string]$installTitle = 'AAD Migration Utility'

	$MigrationConfig = Import-LocalizedData -BaseDirectory "C:\ProgramData\AADMigration\scripts\" -FileName "MigrationConfig.psd1"


	# Script variables
	$DomainLeaveUser = $MigrationConfig.DomainLeaveUser
	$DomainLeavePassword = $MigrationConfig.DomainLeavePass
	$TempUser = $MigrationConfig.TempUser
	$TempUserPassword = $MigrationConfig.TempPass
	$PPKGName = $MigrationConfig.ProvisioningPack
	$MigrationPath = $MigrationConfig.MigrationPath
	$DeferDeadline = $MigrationConfig.DeferDeadline
	$OneDriveKFM = $MigrationConfig.UseOneDriveKFM

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.4'
	[string]$deployAppScriptDate = '26/01/2021'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		#Check OneDrive Sync Status prior to prompting user.
		Start-Transcript -Path $MigrationPath\Logs\LaunchMigration.txt -Append -Force


		If($OneDriveKFM){

			Write-Output "OneDriveKFM flag is set to True. Checking Sync Status before continuing."

			#Check the most recent OD4B Sync status. Write error to event log if not healthy and exit
			Try{

				$Events = Get-EventLog -LogName Application -EntryType Information -Source 'AAD_Migration_Script'

				$LastEvent = $Events[0].InstanceId
				$LastEvent

			} Catch {

				Write-Output "No OneDrive Sync status found. Exiting migration utility; will retry on next logon."
				Exit 3

			}

			If($LastEvent -eq 1337){


				Write-Output "OneDrive Sync status is considered healthy, continuing."


			} Else {

				Write-Output "OneDrive sync status returned a value of $LastEvent. Migration will not launch at this time."
				Exit 2

			}

		}


		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -AllowDefer -DeferDeadline $DeferDeadline -PersistPrompt -ForceCountdown 600

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>



		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>
			#Start Transcription
			#Start Transcription
			Start-Transcript -Path $MigrationPath\Logs\AD2AADJ.txt -NoClobber


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


		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>

		## Display a message at the end of the install
		If (-not $useDefaultMsi) { Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>


		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>


	}
	ElseIf ($deploymentType -ieq 'Repair')
	{
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		# <Perform Repair tasks here>

		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>


    }
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
