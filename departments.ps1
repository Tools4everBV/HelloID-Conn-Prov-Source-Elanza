######################################################
# HelloID-Conn-Prov-Source-Elanza-Departments
#
# Version: 1.1.0
######################################################

# Initialize default values
$config = $Configuration | ConvertFrom-Json

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function Invoke-ElanzaRestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Uri
    )
    process {
        try {
            $headers = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
            $headers.Add("elanza-api-key-v1", "$($config.ApiKey)")

            $splatParams = @{
                Uri         = "$($config.BaseUrl)/rest-api/v1/$Uri"
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = $headers
            }
            Invoke-RestMethod @splatParams -Verbose:$false
        }
        catch {
            if (($Uri -like "department/*" -or $Uri -like "product/*") -and $_.Exception.Response.StatusCode -eq 'NotFound') {
                $id = ($Uri -split "/")[-1]
                Write-Warning "A product or department with id: [$id] cannot be found!"
            }
            else {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
    }
}

function Resolve-ElanzaError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }

        try {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
            $errorMessage = (($ErrorObject.ErrorDetails.Message | ConvertFrom-Json)).message
            $httpErrorObj.FriendlyMessage = $errorMessage
        }
        catch {
            $httpErrorObj.FriendlyMessage = "Received an unexpected response. The JSON could not be converted, error: [$($_.Exception.Message)]. Original error from web service: [$($ErrorObject.Exception.Message)]"
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    # Get all departments
    $departments = (Invoke-ElanzaRestMethod -Uri "departments").departments

    # Sort departments on uuid (to make sure the order is always the same)
    $departments = $departments | Sort-Object -Property uuid

    foreach ($department in $departments) {
        # Remove everything before and including the first underscore in the name
        $displayName = $department.name
        if ($displayName -match "_") {
            $displayName = $displayName -replace '^[^_]*_', ''
        }

        $departmentObjectHelloID = [PSCustomObject]@{
            ExternalId        = $department.code # Might want to choose code instead of uuid depending on your needs
            DisplayName       = $displayName.trim();
            ManagerExternalId = "" # Not available in Elanza API
            ParentExternalId  = "" # Not available in Elanza API
        }

        # Sanitize and export the json
        $departmentObjectHelloID = $departmentObjectHelloID | ConvertTo-Json -Depth 10

        Write-Output $departmentObjectHelloID
    }
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-ElanzaError -ErrorObject $ex
        Write-Verbose "Could not import Elanza departments. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Throw "Could not import Elanza departments. Error: $($errorObj.FriendlyMessage)"
    }
    else {
        Write-Verbose "Could not import Elanza departments. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Throw "Could not import Elanza departments. Error: $($errorObj.FriendlyMessage)"
    }
}