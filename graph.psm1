function Get-AuthTokenUsingCert {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$TenantId,
        [Parameter()]
        [string]$ClientId,        
        [Parameter()]
        [string]$CertThumbprint
    )

    try {
        $cert = Get-ChildItem Cert:\LocalMachine\My\$CertThumbprint -ErrorAction Stop
    }
    catch {
        $message = "Unable to get certificate: $($_.Exception.Message)"
        throw $message
    }

    $connectionDetails = @{
        TenantId           = $TenantId
        ClientId           = $ClientId
        ClientCertificate  = $cert
        AzureCloudInstance = 1
    }

    $token = Get-MsalToken @connectionDetails

    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = $token.CreateAuthorizationHeader()
        'ExpiresOn'     = $token.ExpiresOn
    }

    return $authHeader
}

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
            $filter = "`$filter=contains($($PSCmdlet.MyInvocation.BoundParameters.Keys),'$($PSCmdlet.MyInvocation.BoundParameters.Values -replace '\*')')"
            continue
        }
        { $PSCmdlet.MyInvocation.BoundParameters.Values.EndsWith('*') } { 
            $filter = "`$filter=startswith($($PSCmdlet.MyInvocation.BoundParameters.Keys),'$($PSCmdlet.MyInvocation.BoundParameters.Values -replace '\*')')"
            continue
        }
        { $PSCmdlet.MyInvocation.BoundParameters.Values.StartsWith('*') } {
            $filter = "`$filter=endswith($($PSCmdlet.MyInvocation.BoundParameters.Keys),'$($PSCmdlet.MyInvocation.BoundParameters.Values -replace '\*')')"
            continue
        }
        { $null -ne $PSCmdlet.MyInvocation.BoundParameters.Values } {
            $filter = "`$filter=$($PSCmdlet.MyInvocation.BoundParameters.Keys) eq '$($PSCmdlet.MyInvocation.BoundParameters.Values)'"
        }
    }
    
    $intuneDevices = Invoke-MgGraphRequest -Method GET "https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter"

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
        # { $loopCounter -ge 10 } {
        #    Write-Host "Retry limit reached $loopCounter with no success"
        #
        #    $retVal = 'Retry limit reached'
        # }
    }
    
    return $retVal
}

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

function Get-ConfigProfiles {
    param (
        [Parameter(Mandatory)]
        [string]$IntuneDeviceId,
        [Parameter()]
        [int]$Skip = 0
    )

    $filter = "((PolicyBaseTypeName eq 'Microsoft.Management.Services.Api.DeviceConfiguration') or 
        (PolicyBaseTypeName eq 'DeviceManagementConfigurationPolicy') or 
        (PolicyBaseTypeName eq 'DeviceConfigurationAdmxPolicy') or 
        (PolicyBaseTypeName eq 'Microsoft.Management.Services.Api.DeviceManagementIntent')) and 
        (IntuneDeviceId eq '$IntuneDeviceId')"

    $body = @{
        select  = @('PolicyName')
        filter  = $filter
        skip    = $Skip
        top     = 50
        orderBy = @('PolicyName')
    } | ConvertTo-Json

    $restParams = @{
        Uri     = 'https://graph.microsoft.com/beta/deviceManagement/reports/getConfigurationPoliciesReportForDevice'
        Headers = $authToken
        Method  = 'POST'
        Body    = $body
    }

    $response = Invoke-RestMethod @restParams
    
    if ($response.Values) {
        # Use the output stream to track
        $response.Values | Sort-Object | Get-Unique

        $currentCount = $Skip + $response.Values.Count

        if ($response.TotalRowCount -gt $currentCount) {
            $Skip = $Skip + 50

            Get-ConfigProfiles -IntuneDeviceId $IntuneDeviceId -Skip $Skip
        }
    }
}
