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
