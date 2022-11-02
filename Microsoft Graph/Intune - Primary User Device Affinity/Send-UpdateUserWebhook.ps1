#Special thanks to Damien Van Robaeys for the AutoRemove PR script, the full version can be found here: https://github.com/damienvanrobaeys/Intune-Proactive-Remediation-scripts/blob/main/Auto%20remove%20Proactive%20Remediation%20script/Proactive_Remediation_AutoRemove.ps1

<#
Name: Send-UpdateUserWebhook.ps1
Author: Sean Bulger, twitter @managed_blog, http://managed.modernendpoint.com
Version: 1.0
.Synopsis
   This script will identify the user who has signed in to Windows most frequently over the last 7 days
   and make a REST API call to an Azure Automation Runbook that will update the primary user in Intune
.DESCRIPTION
   Send-UpdateUserWebhook is part one of a two part solution to update the primary user in Intune based on the Windows Event Log.
   It will collect Event ID 4624 from the Windows Security log since a defined start time, and find all accounts that logged in 
   with a user principal name that matches the domain defined in the $FilterDomain variable. It creates an array of users and selects
   the user who has logged in most frequently.

   It will then check the device registry to find the Intune managed device ID. 

   These values are sent in the body of a POST request to the URI for an Azure Automation runbook webhook. The AA runbook will update the 
   primary user based on the included values.
#>


#Set variables for script.
#Filter domain will filter all user logon events based on your domain, set the domain to find users in that domain
$FilterDomain = "[Your UPN Suffix]"
$UDAWebhook = "[Your Azure Automation Webhook]"
$StartTime = (Get-Date).AddDays(-7)

#Hash table to filter for logon events in security log
$FilterHash = @{
  Logname='Security'
  ID='4624'
  StartTime=$StartTime
}


#Get all logon events from last 7 days
$LogHistory = Get-WinEvent -FilterHashtable $FilterHash | Select TimeCreated,Properties

#Create empty users array
$Users =  @()

#Find user from each logon event, add any AAD users to Users array
ForEach($Event in $LogHistory){

    $User = $Event.Properties[5].Value.ToString()


    If($User -like "*$FilterDomain"){

        $Users += $User

    }

}

$UserList = $Users | Group-Object | Select Count,Name

$UserHash = @{}
$UserList | ForEach-Object { $UserHash[$_.Name] = $_.Count }



#Get Intune Device ID From registry
$Reg = Get-ChildItem HKLM:\SOFTWARE\Microsoft\Enrollments -Recurse -Include "MS DM Server"
$IntDevID = Get-ItemPropertyValue -Path Registry::$Reg -Name EntDMID

Write-Output "User list to be sent to web app is $UserHash"
Write-Output "Managed Device ID is $IntDevID"

$Body = @{ "ManagedDeviceID" = "$IntDevID" } 
$Body.Add("UserHash",$UserHash)
$Body = $Body | ConvertTo-Json
$URI = $UDAWebhook
$Method = "POST"

$CallAzAutomation = Invoke-RestMethod -Method $Method -Uri $URI -Body $Body -UseBasicParsing

if($CallAzAutomation) {
    Exit 0
 } else {
    Exit 1
 }


# ********************************************************************
# AUTOREMOVE PART
# ********************************************************************

#This section will remove the PR script from the computer after it is finished running.

$mypath = $MyInvocation.MyCommand.Path
$Get_Directory = (Get-Item $mypath | select *).DirectoryName

$Remove_script_Path = "$env:temp\Remove_current_remediation.ps1"
$Remove_script = @"
Do {  
	`$ProcessesFound = gwmi win32_process | where {`$_.commandline -like "*$Get_Directory*"} 
    If (`$ProcessesFound) {
        Start-Sleep 5
    }
} Until (!`$ProcessesFound)
cmd /c "rd /s /q $Get_Directory"
"@
$Remove_script | out-file $Remove_script_Path
start-process -WindowStyle hidden powershell.exe $Remove_script_Path






