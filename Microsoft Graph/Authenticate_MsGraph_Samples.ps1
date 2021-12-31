#Authenticate to graph using interactive authentication (user credentials)
$authParams = @{
    ClientId    = '[Your App Registration Client ID]'
    TenantId    = 'YourDomain.xyz'
    Interactive = $true
}
$auth = Get-MsalToken @authParams
$auth

#Authenticate to graph using interactive authentication (device code)
$authParams = @{
    ClientId    = '[Your App Registration Client ID]'
    TenantId    = 'YourDomain.xyz'
    DeviceCode = $true
}
$auth = Get-MsalToken @authParams
$auth

#Authenticate to Graph using a client secret 
$authparams = @{
    ClientId    = '[Your App Registration Client ID]'
    TenantId    = 'YourDomain.xyz'
    ClientSecret = ('YourClientSecret' | ConvertTo-SecureString -AsPlainText -Force )
}
$auth = Get-MsalToken @authParams
$auth
