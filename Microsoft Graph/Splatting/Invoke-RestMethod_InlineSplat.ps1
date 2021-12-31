#Use a client secret to authenticate to Microsoft Graph
$authparams = @{
    ClientId    = '[App Registration Client ID]'
    TenantId    = 'yourdomain.xyz'
    ClientSecret = ('[YourClientSecret]' | ConvertTo-SecureString -AsPlainText -Force )
}

$auth = Get-MsalToken @authParams

$AccessToken = $Auth.AccessToken

#Create MS Graph Splats
#Create GET splat
$graphGetParams = @{
    Headers     = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Bearer $($AccessToken)"
    }
    Method      = "GET"
    ErrorAction = "SilentlyContinue"
    StatusCodeValue = "SCV"
}

#Create POST splat
$graphPostParams = @{
    Headers     = @{
        "Authorization" = "Bearer $($AccessToken)"
        "Accept"        = "application/json"
        "Content-Type"  = "application/json"
    }
    Method      = "POST"
    ErrorAction = "SilentlyContinue"
    StatusCodeValue = "SCV"
}

#Create PATCH splat
$graphPatchParams = @{
    Headers     = @{
        "Authorization" = "Bearer $($AccessToken)"
        "Content-Type"  = "application/json"
    }
    Method      = "PATCH"
    ErrorAction = "SilentlyContinue"
    StatusCodeValue = "SCV"
}


$graphGetParams["URI"]= “https://graph.microsoft.com/beta/users”

$Result = Invoke-RestMethod @graphGetParams

$Result