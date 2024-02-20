######################################################
# HelloID-Conn-Prov-Source-Elanza-Departments
#
# Version: 1.0.0
######################################################

# Initialize default value's
$config = $Configuration | ConvertFrom-Json

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

# Keep track of retrieved departments
$retrievedDepartments = [System.Collections.Generic.List[object]]::new()

#region functions
function Get-ElanzaDepartmentById {
    [CmdletBinding()]
    param (
        [Parameter()]
        $Id
    )

    if (-not ($retrievedDepartments | Where-Object { $_.uuid -eq $Id })) {
        $departmentDetails = Invoke-ElanzaRestMethod -Uri "department/$Id"
        $departmentDetails | Add-Member -MemberType 'NoteProperty' -Name 'ExternalId' -Value $departmentDetails.uuid
        $departmentDetails | Add-Member -MemberType 'NoteProperty' -Name 'DisplayName' -Value $departmentDetails.name
        $retrievedDepartments.Add($departmentDetails)
    }
}


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
                Headers     =  $headers
            }
            Invoke-RestMethod @splatParams -Verbose:$false
        } catch {
            if (($Uri -like "department/*" -or $Uri -like "product/*") -and $_.Exception.Response.StatusCode -eq 'NotFound') {
                $id = ($Uri -split "/")[-1]
                Write-Warning "A product or department with id: [$id] cannot be found!"
            } else {
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
        } catch {
            $httpErrorObj.FriendlyMessage = "Received an unexpected response. The JSON could not be converted, error: [$($_.Exception.Message)]. Original error from web service: [$($ErrorObject.Exception.Message)]"
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    $historicalDays = (Get-Date).ToUniversalTime().AddDays(-$($config.HistoricalDays))
    $futureDays = (Get-Date).ToUniversalTime().AddDays($($config.FutureDays))
    $response = Invoke-ElanzaRestMethod -Uri "plannedWorkers?from=$($historicalDays.ToString('yyyy-MM-ddTHH:mm:ssZ'))&to=$($futureDays.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    foreach ($worker in $response.workers) {
        foreach ($shift in $worker.shifts){
            if (-not[string]::IsNullOrEmpty($shift.departmentUuid)){
               Get-ElanzaDepartmentById -Id $shift.departmentUuid
            }
        }

        foreach ($department in $retrievedDepartments){
            Write-Output $department | ConvertTo-Json -Depth 10
        }
    }
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-ElanzaError -ErrorObject $ex
        Write-Verbose "Could not import Elanza departments. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Throw "Could not import Elanza departments. Error: $($errorObj.FriendlyMessage)"
    } else {
        Write-Verbose "Could not import Elanza departments. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Throw "Could not import Elanza departments. Error: $($errorObj.FriendlyMessage)"
    }
}


