#When authenticating to Microsoft Graph in PowerShell, use the Microsoft Authentication librabry, the module is MSAL.ps
#Install MSAL.ps module
Install-Module MSAL.ps


#Connecting through MSAL can be done interactively or programmatically
#In the sessions we wil demonstrate Interactive Authentication
#Authentication is also covered in this blog post: https://www.modernendpoint.com/managed/connecting-to-microsoft-graph-with-powershell/
$authParams = @{
    ClientId    = '[Enter your App Registration Client ID here]'
    TenantId    = '[Enter your tenant ID or primary domain here]'
    Interactive = $true
}
$auth = Get-MsalToken @authParams


$AccessToken = $auth.AccessToken



#Invoke-MsGraphCall is a function created to be able to easily pass in all required parameters to Invoke-RestMethod
#I covered it more in depth as part of this blog post: https://www.modernendpoint.com/managed/PowerShell-tips-for-accessing-Microsoft-Graph-in-PowerShell/
#It is included in the script located in my GitHub here: https://github.com/managedBlog/Managed_Blog/blob/main/Microsoft%20Graph/Splatting/Invoke-MsGraphCall.ps1

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

#The following example will return all users from Microsoft Graph
$URI = "https://graph.microsoft.com/v1.0/users"
$Method = "GET"

$MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

$MSGraphCall.Value 

#the following example will return a specific user, labuser02@modernendpoint.xyz
$URI = "https://graph.microsoft.com/v1.0/users/labuser02@modernendpoint.xyz"
$Method = "GET"

$MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

$MSGraphCall

#The next example will return all devices for our demo user, labuser02@modernendpoint.xyz
$URI = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=userPrincipalName eq 'labuser02@modernendpoint.xyz'"
$Method = "GET"

$MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

$MSGraphCall.Value




################
#The following exmaple is an end to end example of how to update the management name on all devices belonging to a specific user.
#This use case is covered in more detail in the following blog post: https://www.modernendpoint.com/managed/Updating-device-management-name-in-PowerShell-with-Microsoft-Graph/
$UserPrincipalName = "labuser02@modernendpoint.xyz"


#Get all devices for user, returning only the necessary properties with a select statement
#Build paramaters for returning user devices
$Devicefilter = "?`$filter=userPrincipalName eq '$userPrincipalName'&`$select=id,deviceName,serialNumber,model,OperatingSystem,ManagedDeviceName,UserPrincipalName"
$ManagedDevicesRoot = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
$URI = "$ManagedDevicesRoot$Devicefilter"
$Method = "GET"

#Call Invoke-MsGraphCall (Remember this was done during the demo, so make sure you run the function above to get it into memory)
#$Devices will hold all of the values returned in a JSON array
$MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

$Devices = $MSGraphCall.Value


#Iterate through all devices, updating the management name
ForEach($Device in $Devices){

    $UPNPrefix = $Device.UserPrincipalName.split("@")[0]
    $OS = $Device.operatingSystem
    $Serial = $Device.SerialNumber
    $Id = $Device.Id

    $NewManagementName = "$($UPNPrefix)_$($OS)_$($Serial)"


        #Update the management name of the device at the URI for each device ID
        #In this call we are creating a JSON body with a single Key/value pair and converting it to JSON
        #The PATCH method requires a body, so this will add it to the splat hashtable in the function
        $URI = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$Id"
        $Body = @{ "managedDeviceName" = "$NewManagementName" } | ConvertTo-Json  
        $Method = "PATCH"
    
        #Call Invoke-MsGraphCall to update management name
        $MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body
}


#Sleep after running the above example, then return devices to show update device management names
Start-Sleep -Seconds 15

#Return devices to demonstrate updated management names
$Devicefilter = "?`$filter=userPrincipalName eq '$userPrincipalName'&`$select=id,deviceName,serialNumber,model,OperatingSystem,ManagedDeviceName,UserPrincipalName"
$ManagedDevicesRoot = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
$URI = "$ManagedDevicesRoot$Devicefilter"
$Method = "GET"

#Call Invoke-MsGraphCall
$MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

$Devices = $MSGraphCall.Value

