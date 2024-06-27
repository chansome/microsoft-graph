function Get-IntuneDevice {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string]$DeviceName,
        [Parameter(Mandatory, ParameterSetName = 'BySerial')]
        [string]$SerialNumber,
        [Parameter(Mandatory, ParameterSetName = 'ByUPN')]
        [string]$UserPrincipalName      
    )

    switch ($true) {
        { $PSCmdlet.MyInvocation.BoundParameters.Values.EndsWith('*') -and $PSCmdlet.MyInvocation.BoundParameters.Values.StartsWith('*') } {
            $Filter = "`$filter=contains($($PSCmdlet.MyInvocation.BoundParameters.Keys),'$($PSCmdlet.MyInvocation.BoundParameters.Values -replace '\*')')"
            continue
        }
        { $PSCmdlet.MyInvocation.BoundParameters.Values.EndsWith('*') } { 
            $Filter = "`$filter=startswith($($PSCmdlet.MyInvocation.BoundParameters.Keys),'$($PSCmdlet.MyInvocation.BoundParameters.Values -replace '\*')')"
            continue
        }
        { $PSCmdlet.MyInvocation.BoundParameters.Values.StartsWith('*') } {
            $Filter = "`$filter=endswith($($PSCmdlet.MyInvocation.BoundParameters.Keys),'$($PSCmdlet.MyInvocation.BoundParameters.Values -replace '\*')')"
            continue
        }
        { $null -ne $PSCmdlet.MyInvocation.BoundParameters.Values } {
            $Filter = "`$filter=$($PSCmdlet.MyInvocation.BoundParameters.Keys) eq '$($PSCmdlet.MyInvocation.BoundParameters.Values)'"
        }
    }
    
    $intuneDevices = Invoke-MgGraphRequest -Method GET "https://graph.microsoft.com/beta/deviceManagement/managedDevices?$Filter"

    switch ($true) {
        { $intuneDevices.value.Count -gt 0 } {
            Write-Host "$($intuneDevices.value.Count) found: $($intuneDevices.value.deviceName)"
            
            $retVal = $intuneDevices.value

            continue
        }
        { $intuneDevices.value.Count -eq 0 } {
            Write-Host "No Intune devices found with $($PSCmdlet.MyInvocation.BoundParameters.Keys) of '$($PSCmdlet.MyInvocation.BoundParameters.Values)'"

            $retVal = 'No device(s) found'

            continue
        }
        { $loopCounter -ge 10 } {
            Write-Host "Retry limit reached $loopCounter with no success"

            $retVal = 'Retry limit reached'
        }
    }
    
    return $retVal
}
