<#
Name: Import-AutopilotHashFromPpkg
Author: Sean Bulger, twitter @managed_blog, http://managed.modernendpoint.com
Version: 1.0 
.Synopsis
   This script is meant to be used as part of provisioning package to automate importing autopilot hashes. It can be run from within the full OS or from the OOBE experience. 
.DESCRIPTION
   Import-AutopilotHashFromPpkg is part of a solution to autopmatically upload autopilot hashes directly to Microsoft Intune without direct interaction. 

    Full documentation can be found on my blog at https://www.modernendpoint.com/managed

    It was created to be used as part of a provisioning package to allow hashes to be uploaded from the Out of Box experience with little to no interaction. After running the computer
    will return to the out of box experience and the user can continue to log in or a technician can take it through pre-provisioning. Please note that this script will exit once the first stage
    of the import has been completed. I recommend checking the Autopilot devices list to know when they upload has been completed.

    This script will install and import the MSAL.ps module. It was built for authentication with a client secret, but could be adjusted to allow for certificate based authentication. Since the
    client secret is hardcoded in the script, I recommend password protecting the PPKG file. The app registration used should also have limited permissions to limit it to being used for the 
    specific purpose.
.
#>

#Install MSAL.ps module if not currently installed
If(!(Get-Module MSAL.ps)){
    
    Write-Host "Installing Nuget"
    Install-PackageProvider -Name NuGet -Force

    Write-Host "Installing module"
    Install-Module MSAL.ps -Force 

    Write-Host "Importing module"
    Import-Module MSAL.ps -Force

}    

#Use a client secret to authenticate to Microsoft Graph using MSAL
$authparams = @{
    ClientId    = '[ClientID]'
    TenantId    = '[YourTenant]'
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
        #StatusCodeVariable = "scv"
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


#Gather Autopilot details
$session = New-CimSession
$serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
$devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
$hash = $devDetail.DeviceHardwareData


#Create required variables
#The following example will update the management name of the device at the following URI
$URI = "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities"
$Body = @{ "serialNumber" = "$serial"; "hardwareIdentifier" = "$hash" } | ConvertTo-Json
$Method = "POST"

Try{

    #Call Invoke-MsGraphCall
    $MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

    } Catch {

        Write-Output "An error occurred:"
        Write-Output $_
        Exit 1

    }

If($MSGraphCall){

    Write-Output $MSGraphCall
    Exit 0

}