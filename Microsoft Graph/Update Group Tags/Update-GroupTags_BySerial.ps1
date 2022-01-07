
#To use a client secret to authenticate to Microsoft Graph using MSAL, uncomment lines 3-7 and enter your information. Comment out lines 10-14
<# $authparams = @{
    ClientId    = '[Your Client Id]'
    TenantId    = 'YourDomain.com'
    ClientSecret = ('[Your Client Secret]' | ConvertTo-SecureString -AsPlainText -Force )
} #>

#To use device code to authenticate using the well-known client ID, uncomment lines 10-14. Comment out lines 3-7.
$authParams = @{
    ClientId = 'd1ddf0e4-d672-4dae-b554-9d5bdfd93547' #Well-known client ID
    TenantId    = 'modernendpoint.xyz'
    DeviceCode = $true
}


$auth = Get-MsalToken @authParams

#Set Access token variable for use when making API calls
$AccessToken = $Auth.AccessToken

#Get content of CSV containing serial numbers
#This should be a single column with no headers
$Serials = Get-Content "C:\Temp\serials.csv"

#If assigning the same group tag to all devices, update this variable
$NewGroupTag = "Updated-Group-Tag-Friday-2"

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

#For each device listed in serial numbers find the associate Autopilot Device ID, and update the group tag
ForEach($s in $serials){

    #Return Autopilot Device Identity
    #Create parameters to use in Invoke-MSGraphCall
    $URI = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/?`$filter=contains(serialNumber,'$s')"
    $Method = "GET"

    #Call Invoke-MsGraphCall
    $MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body
    
    #Get device ID to use in Graph Call
    $Id = $MSGraphCall[1].value.id 
    
    #Make POST call to update group tag
    $Body = @{ "groupTag" = "$NewGroupTag" } | ConvertTo-Json  
    $URI  = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities/$id/UpdateDeviceProperties"
    $Method = "POST"

    $MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

}
