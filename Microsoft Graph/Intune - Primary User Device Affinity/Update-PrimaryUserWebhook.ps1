<#
Name: Update-PrimaryUserWebhook.ps1
Author: Sean Bulger, twitter @managed_blog, http://managed.modernendpoint.com
Version: 1.0
.Synopsis
   This script is designed to run in Azure Automation when called by a WebHook. 
.DESCRIPTION
   Update-PrimaryUserWebhook accepts the value of $WebHookData that is sent in a JSON body from Send-UpdateUserWebhook. 

   Send-UpdateUserWebhook is the first part of a two part solution to update the primary user in Intune based on the Windows Event Log.
   It will collect Event ID 4624 from the Windows Security log since a defined start time, and find all accounts that logged in 
   with a user principal name that matches the domain defined in the $FilterDomain variable. It creates an array of users and selects
   the user who has logged in most frequently.

   It will then check the device registry to find the Intune managed device ID. 

   These values are sent in the body of a POST request to the URI for an Azure Automation runbook webhook. 
   
   Update-PrimaryUserWebhook will accept a list of users who have logged in to a device and a count of their logins. The payload also
   includes the Intune Managed device ID. It gets the primary user of the device via Graph API and then determines if the primary user needs to be
   updated. 

   This script uses the Managed Identity of the workbook to make Graph Calls. Appropriate permissions to Microsoft Graph need to be added to the
   Managed Identity.
#>

#Define parameter to get body from request
[cmdletBinding()]
param(
    [Parameter(Mandatory=$False)]
    [object]$WebHookData
)

#Parse WebHookData to get User list and Device ID
$Payload = $WebhookData.RequestBody | ConvertFrom-Json

Write-Output "Payload is of type $PType"

if ($Payload) { 

	$RequestObject = $Payload

	$UserList = $RequestObject.UserHash

    $UserHash = @{}
    ForEach( $property in $UserList.psobject.properties.name )
    {
        $UserHash[$property] = $UserList.$property
    }

	$ManagedDeviceID = $RequestObject.ManagedDeviceID

    Write-Output "Request object is of type $ROType"
    Write-Output "UserHash is of type $UHType"

    Write-Output "UserList received is $UserList"
    Write-Output "Intune Managed Devices ID is $ManagedDeviceID"


} Else {

	Write-Output "No request body received"

}


#Get bearer token using system managed Identity (Thanks Ben and Jake!)
if ($env:MSI_SECRET) {
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity
}
if ($env:MSI_SECRET) { $token = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/").Token }
else {
  Disable-AzContextAutosave -Scope Process | Out-Null
  $cred = New-Object System.Management.Automation.PSCredential $env:AppID, ($env:ClientSecret | ConvertTo-SecureString -AsPlainText -Force)
  Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $env:TenantID
  $token = (Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com').Token
  $authHeader = @{Authorization = "Bearer $token"}
}

Write-Output $token


#Function to make Microsoft Graph API calls
Function Invoke-MsGraphCall {

    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$AccessToken,
        [Parameter(Mandatory=$True)]
        [string]$URI,
        [Parameter(Mandatory=$True)]
        [string]$Method,
        [Parameter(Mandatory=$False)]
        [string]$Body
    )



    #Create Splat hashtable
    $graphSplatParams = @{
        Headers     = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $($AccessToken)"
        }
        Method = $Method
        URI = $URI
        #ErrorAction = "SilentlyContinue"
    }

    #If method requires body, add body to splat
    If($Method -in ('PUT','PATCH','POST')){

        $graphSplatParams["Body"] = $Body

    }


    #Return API call result to script
    $MSGraphResult = Invoke-RestMethod @graphSplatParams

    #Return status code variable to script
    Return $MSGraphResult

}



$Vals = $UserHash.Values | Measure-Object -Minimum -Maximum
$TopUser = $UserHash.GetEnumerator() | Where-Object Value -eq $Vals.Maximum
$TopName = $TopUser.Name
[int]$TopCount = $TopUser.Value

Write-Output "User with highest logon count is $TopName. Logon Count is $TopCount."

#Get managed device and check for primary user
Write-Output "Managed Device ID is $ManagedDeviceID"
$URI = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$ManagedDeviceID/users"
$Method = "GET"

Write-Output "Calling $URI"

$MSGraphCall = Invoke-MsGraphCall -AccessToken $Token -URI $URI -Method $Method -Body $Body

Write-Output "MSGraphCall result is $MSGraphCall"

$PrimaryUser = $MSGraphCall.value.UserPrincipalName
$PrimaryUserId = $MSGraphCall.value.id
Write-Output "The primary user currently assigned is $PrimaryUser"
Write-Output "The Primary User ID is $PrimaryUserId"

#If primary user, check to see if primary user is in user hash; Get count of logons
If($PrimaryUser){

    If($UserHash.ContainsKey($PrimaryUser)){

        [int]$PrimaryCount = $UserList.$PrimaryUser
		Write-Output "$PrimaryUser has logged in $PrimaryCount times."

    } Else {

		Write-Output "$PrimaryUser not found in user hash table. "

	}

	If($PrimaryCount -eq $null){

		[int]$PrimaryCount = 0.5

	}

    #Compare # of user logons for highest user with current primary user; determine who primary user should be
    $UDAMultiplier = $TopCount/$PrimaryCount
	
    Write-Output "UDA Multiplier is $UDAMultiplier"

} 


If((!$PrimaryUser) -or ($UDAMultiplier -ge 1.5)){

    
    $UserPrincipalName = $TopUser.Name
	Write-Output "User with highest count to be assigned."
	Write-Output "Primary user to be assigned is $UserPrincipalName"

	#Get AAD Id of primary user to assign
	Write-Output "Getting User ID"
	$URI= "https://graph.microsoft.com/beta/users/$UserPrincipalName"
	$Method = "GET"

	$MSGraphCall = Invoke-MsGraphCall -AccessToken $Token -URI $URI -Method $Method -Body $Body
	$UserID = $MSGraphCall.id



	#Update Primary User on Managed Device
	#Create required variables
	Write-Output "Updating primary user on Intune Device ID $ManagedDeviceID. New Primary User is $UserPrincipalName, ID: $UserID"
	$Body = @{ "@odata.id" = "https://graph.microsoft.com/beta/users/$UserId" } | ConvertTo-Json
	$URI = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$ManagedDeviceID')/users/`$ref"
	$Method = "POST"


	#Call Invoke-MsGraphCall
	$MSGraphCall = Invoke-MsGraphCall -AccessToken $Token -URI $URI -Method $Method -Body $Body
	

} else {

	Write-Output = "Primary user will not change."

}
