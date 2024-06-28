function Get-EntraIdDevice {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string]$DisplayName,
        [Parameter(Mandatory, ParameterSetName = 'ByDeviceID')]
        [string]$DeviceId
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
    
    $EntraIdDevices = Invoke-MgGraphRequest -Method GET "https://graph.microsoft.com/beta/devices?$Filter&`$count=true" -Headers @{ ConsistencyLevel = 'eventual' }

    if ($EntraIdDevices.value.Count -gt 0) {
        $EntraIdDevices.value
    }
    else {
        Write-Host "No Entra ID devices found with $($PSCmdlet.MyInvocation.BoundParameters.Keys) of '$($PSCmdlet.MyInvocation.BoundParameters.Values)'" -ForegroundColor DarkYellow
    }
}
