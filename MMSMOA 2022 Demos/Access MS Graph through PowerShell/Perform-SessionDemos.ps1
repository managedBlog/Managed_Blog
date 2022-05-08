#This file includes the PowerShell SDK cmdlets that were used in the demonstrations
#How do we install the module
#The following cmdlets will install all of the SDK modules
Import-Module Microsoft.Graph
Install-Module Microsoft.Graph

#Connecting to the SDK can be done interactively or using a certificate on an app registration
#For this demo we used interactive authentication
#Selecting profile - API version (maybe discuss v1.0 or beta)
Select-MgProfile -name "beta"

#Connect to graph interactively with requested scopes.
#Adding scopes to the Connect-MgGraph cmdlet will add them to the Microsoft Graph PowerShell enterprise application
Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.ReadWrite.All","DeviceManagementManagedDevices.ReadWrite.All" -

#Once you know the Graph API endpoint you want to run a cmdlet against, you can find the cmdlet by searching for the endpoint
#The following will return GET and POST cmdlets to return or create new managed devices
Find-MgGraphCommand -URI '/DeviceManagement/ManagedDevices/'

#By returning a specific device object we also have the option to make a PATCH request
Find-MgGraphCommand -URI '/DeviceManagement/ManagedDevices/{id}'

#Similarly, we can see the same with users
Find-MgGraphCommand -Uri '/Users/'

#Returning a single user gives us a cmdlet to update a single user
Find-MgGraphPermission -URI '/DeviceManagement/ManagedDevices/{id}'

#Return all users
Get-MgUser

#Return a specific user
Get-MgUser -UserId 'labuser02@modernendpoint.xyz'


#Return User devices
$Devices = Get-MgDeviceManagementManagedDevice -Filter "UserPrincipalName eq 'labuser02@modernendpoint.xyz'"


################
#The following section will be used to update a device management name using the SDK
#Return all devices for the user labuser02@modernendpoint.xyz
$Devices = Get-MgDeviceManagementManagedDevice -Filter "UserPrincipalName eq 'labuser02@modernendpoint.xyz'" | Select-Object DeviceName,UserPrincipalName,Id,SerialNumber,ManagedDeviceName,OperatingSystem

#For each returned device, update the device management name
ForEach($Device in $Devices){

    $UPNPrefix = $Device.UserPrincipalName.split("@")[0]
    $OS = $Device.operatingSystem
    $Serial = $Device.SerialNumber
    $Id = $Device.Id

    $NewManagementName = "$($UPNPrefix)_$($OS)_$($Serial)"

    Update-MgDeviceManagementManagedDevice -ManagedDeviceId $Id -ManagedDeviceName $NewManagementName

}

#Wait 15 seconds and query the user's devices to check results
Start-Sleep -Seconds 15

Get-MgDeviceManagementManagedDevice -Filter "UserPrincipalName eq 'labuser02@modernendpoint.xyz'" | Select-Object DeviceName,UserPrincipalName,Id,SerialNumber,ManagedDeviceName,OperatingSystem

