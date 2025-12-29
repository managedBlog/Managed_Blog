<#
.SYNOPSIS
    Updates Microsoft Defender Antivirus definitions.
.DESCRIPTION
    Forces an update of Defender signatures using built-in cmdlets.
#>

try {
    Write-Output "Starting Defender signature update..."
    Update-MpSignature -ErrorAction Stop
    Write-Output "Defender signatures updated successfully."
    exit 0
}
catch {
    Write-Output "Failed to update Defender signatures: $_"
    exit 1
}
