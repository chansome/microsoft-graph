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
