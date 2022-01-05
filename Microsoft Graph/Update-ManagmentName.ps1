<#
Name: Update-ManagementName
Author: Sean Bulger, twitter @managed_blog, http://managed.modernendpoint.com
Version: 1.0 
.Synopsis
   Script will return all of a user's devices
.DESCRIPTION
   Invoke-MsGraphCall is a function built to call Microsoft Graph and run any approved method.
.EXAMPLE
    .\Update-ManagementName.ps1 -UserPrincipalName user.name@yourdomain.com
#>

[cmdletBinding()]
param(

    [Parameter(Mandatory=$True)]
    [string]$UserPrincipalName

)

#Use a client secret to authenticate to Microsoft Graph using MSAL
$authparams = @{
    ClientId    = '[Your Client Id]'
    TenantId    = 'YourDomain.com'
    ClientSecret = ('[Your Client Secret]' | ConvertTo-SecureString -AsPlainText -Force )
}

$auth = Get-MsalToken @authParams

#Set Access token variable for use when making API calls
$AccessToken = $Auth.AccessToken

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
        ErrorAction = "SilentlyContinue"
        StatusCodeVariable = "scv"
    }

    #If method requires body, add body to splat
    If($Method -in ('PUT','PATCH','POST')){

        $graphSplatParams["Body"] = $Body

    }

    #Return API call result to script
    $MSGraphResult = Invoke-RestMethod @graphSplatParams

    #Return status code variable to script
    Return $SCV, $MSGraphResult

}


#Return user object
#Create parameters to use in Invoke-MSGraphCall
$UserFilter = '?$select=displayName,officeLocation,city,usageLocation,department,mailNickname'
$UserRoot = "https://graph.microsoft.com/v1.0/users"
$URI = "$UserRoot/$UserPrincipalName/$UserFilter"
$Method = "GET"

#Call Invoke-MsGraphCall
$MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

#Parse user object, create management name based on user attributes
$MSGUserResult = $MSGraphCall[1]

#Creat hashtables to assign short values based on Office, department, and city
$OfficeHash=@{"Dunder Mifflin" = "DMIF";"Pawnee Parks and Rec" = "PAWN";"Rosebud Motel" = "ROMO"}
$DepartmentHash=@{ "Payroll" = "CASH" ; "Overlords" = "BOSS" ; "Human Resources" = "HUMR"}
$LocationHash=@{"Houston" = "HOU" ; "Miami" = "MIA"; "Seattle" = "SEA"}

$User = $MSGUserResult.mailNickname
$Office = $officeHash.($MSGUserResult.officeLocation)
$Dept = $DepartmentHash.($MSGUserResult.department)
$Loc = $LocationHash.($MSGUserResult.city)

#Get all devices for user
#Build paramaters for returning user devices
$Devicefilter = "?`$filter=userPrincipalName eq '$userPrincipalName'&`$select=id,deviceName,serialNumber,model"
$ManagedDevicesRoot = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
$URI = "$ManagedDevicesRoot$Devicefilter"
$Method = "GET"

#Call Invoke-MsGraphCall to return user's devices
$MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

#Create list of devices from Graph result
$Devices = $MSGraphCall.value

#Iterate through list of devices, create new management name and PATCH device object.
ForEach($Device in $Devices){

    $serial = $Device.SerialNumber
    $model = $Device.model
    $DevName = $Device.deviceName
    $DevId = $Device.id

    #Check to see if device is virtual or has no serial number, if either are true, use device name in Management Name
    #If serial number exists and device is not virtual, use serial number in management name
    If(!$serial -or ($model -eq 'Virtual Machine')){

        $MgmtAttribute = $DevName

    } Else {

        $MgmtAttribute = $serial

    }

    #Create new management name
    $NewManagementName = "$User-$Office-$Dept-$Loc-$MgmtAttribute"

    #Update the management name of the device at the URI for each device ID
    $URI = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$DevId"
    $Body = @{ "managedDeviceName" = "$NewManagementName" } | ConvertTo-Json  
    $Method = "PATCH"

    #Call Invoke-MsGraphCall to update management name
    $MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

}

