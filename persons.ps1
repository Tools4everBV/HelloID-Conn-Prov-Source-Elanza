##################################################
# HelloID-Conn-Prov-Source-Elanza-Persons
#
# Version: 1.0.0
##################################################
# Initialize default value's
$config = $configuration | ConvertFrom-Json

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

# Keep track of retrieved products
$retrievedProducts = @{}

#region functions
function Get-ElanzaProductById {
    [CmdletBinding()]
    param (
        [Parameter()]
        $Id
    )

    if (-not $retrievedProducts.ContainsKey($Id)) {
        $productDetails = Invoke-ElanzaRestMethod -Uri "product/$Id"
        $retrievedProducts[$Id] = $productDetails
    }
    Write-Output $retrievedProducts[$Id]
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

        $detailsStartDate = (Get-Date).ToUniversalTime().AddDays(-$($config.ShiftDetailsStart)).Date
        $detailsEndDate = $futureDays

        $historyStartDate = $historicalDays
        $historyEndDate = (Get-Date $detailsStartDate).ToUniversalTime().AddDays(-1).Date

        # Create an empty list that will hold all shifts (contracts)
        $contracts = [System.Collections.Generic.List[object]]::new()

        # Create the object that will hold all historical data as one aggregated object with a custom type
        $historicalShiftContract = @{
            ExternalId  = $($worker.worker.workerNumber)
            Shifts      = [System.Collections.Generic.List[object]]::new()
            Type        = 'HistoricalShift'
            ProductName = 'unavailable'

            # Add the same fields as for shift. Otherwise, the HelloID mapping will fail
            # The value of both the 'startAt' and 'endAt' cannot be null. If empty, HelloID is unable
            # to determine the start/end date, resulting in the contract marked as 'active'.
            startAt        = $historyStartDate.ToString('yyyy-MM-ddTHH:mm:ssZ')
            endAt          = $historyEndDate.ToString('yyyy-MM-ddTHH:mm:ssZ')
            title          = 'unavailable'
            productUuid    = 'unavailable'
            departmentUuid = 'unavailable'
        }
        $contracts.Add($historicalShiftContract)

        foreach ($shift in $worker.shifts){
            if (![string]::IsNullOrEmpty($shift.StartAt)){
                $shiftStart = [DateTime]::Parse($shift.startAt)

                if ($shiftStart -ge $detailsStartDate -and $shiftStart -le $detailsEndDate) {
                    if (-not[string]::IsNullOrEmpty($shift.productUuid)){
                        $productDetails = Get-ElanzaProductById -Id $shift.productUuid
                    }
                    $shift | Add-Member -MemberType 'NoteProperty' -Name 'ExternalId'  -Value $shift.uuid
                    $shift | Add-Member -MemberType 'NoteProperty' -Name 'ProductName' -Value $productDetails.name
                    $shift | Add-Member -MemberType 'NoteProperty' -Name 'Type'        -Value 'ActiveShift'
                    $contracts.Add($shift)
                } elseif ($shiftStart -ge $historyStartDate -and $shiftStart -le $historyEndDate) {
                    $historicalShiftContract['Shifts'].Add($shift)
                }
            } else {
                Write-Verbose "Attribute: [startAt] is empty. Import failed for shift with id: [$($shift.uuid)] and worker: [$($worker.worker.workerNumber)]."
            }
        }

        $personObj = [PSCustomObject]@{
            ExternalId  = $worker.worker.workerNumber
            DisplayName = "$($worker.worker.firstName) $($worker.worker.lastName)".Trim(' ')
            FirstName   = $worker.worker.firstName
            LastName    = $worker.worker.lastName
            Email       = $worker.worker.email
            PhoneNumber = $worker.worker.phoneNumber
            Contracts   = $contracts
        }

        Write-Output $personObj | ConvertTo-Json -Depth 20
    }
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-ElanzaError -ErrorObject $ex
        Write-Verbose "Could not import Elanza persons. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Could not import Elanza persons. Error: $($errorObj.FriendlyMessage)"
    } else {
        Write-Verbose "Could not import Elanza persons. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import Elanza persons. Error: $($errorObj.FriendlyMessage)"
    }
}

