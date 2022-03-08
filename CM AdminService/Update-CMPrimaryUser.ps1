<#
Name: Set-CMPrimaryUser
Author: Sean Bulger, twitter @managed_blog, http://managed.modernendpoint.com
Version: 0.1
.Synopsis
   This script will set the primary user in Configuration Manager using the AdminService. It requires the device name and UserPrincipalName. It will find the Resource ID of the device and user's unique user name, and then update the primary user based on that information.
.DESCRIPTION
   Set-CMPrimaryUser is a script built to call the Microsoft Configuration Manager AdminService and update a device's primary user. It was built primarily for use in an Azure Automation runbook #>

#Get input parameters and set the base URI to query the Admin Service
[cmdletBinding()]
param(
    [Parameter(Mandatory=$True)]
    [string]$UPN,
    [Parameter(Mandatory=$True)]
    [string]$DeviceName
)

$BaseURI = "https://mme-memcm01.mme-lab.com/AdminService"

#Create function to call the Admin Service
Function Invoke-AdminServiceCall {

    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$URI,
        [Parameter(Mandatory=$True)]
        [string]$Method,
        [Parameter(Mandatory=$False)]
        [string]$Body
    )


    #Create Splat hashtable
    $SplatParams = @{
        Headers     = @{
            "Content-Type"  = "application/json"
                    }
        Method = $Method
        URI = $URI
        UseDefaultCredentials = $True

    }

    #If method requires body, add body to splat
    If($Method -in ('PUT','PATCH','POST')){

        $SplatParams["Body"] = $Body

    }

    Write-Output $SplatParams

    #Return API call result to script
    $AsInvokeResult = Invoke-RestMethod @SplatParams #-UseDefaultCredentials

    #Return status code variable to script
    Return $AsInvokeResult

}


#Set values to return device
$DeviceExtension = "wmi/SMS_R_System?`$filter=Name eq `'$DeviceName`'"
$URI = "$BaseURI/$DeviceExtension"
$Method = "GET"

#Get device from AdminService, set ResourceID from results
$AdminServiceCall =  Invoke-AdminServiceCall -URI $URI -Method $Method -Body $BodyJson
$DeviceResult  = $AdminServiceCall.value 
$ResourceID = $DeviceResult.ResourceId 
Write-Output $ResourceID


#Get Specific User
$UserExtension = "wmi/SMS_R_User?`$filter=UserPrincipalName eq `'$($UPN)`'"
$URI = "$BaseURI/$UserExtension"
$Method = "GET"

$AdminServiceCall = Invoke-AdminServiceCall -URI $URI -Method $Method -Body $BodyJson
$UserResult = $AdminServiceCall.value 
$UniqueUserName = $UserResult.UniqueUserName
Write-Output $UniqueUserName



#Assign primary user
$UDARequestExtension = "wmi/SMS_UserMachineRelationship.CreateRelationship" 
$URI=  "$BaseURI/$UDARequestExtension"
$Method = "POST"

$Params = @{
    MachineResourceId = $ResourceId
    SourceId = 6
    TypeId = 1
    UserAccountName = "$($UniqueUserName)"
}

$BodyJson = $Params | ConvertTo-Json 
Write-Output $BodyJson

$AdminServiceCall = Invoke-AdminServiceCall -URI $URI -Method $Method -Body $BodyJson

Write-Output $AdminServiceCall