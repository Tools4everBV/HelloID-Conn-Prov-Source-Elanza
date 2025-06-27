##################################################
# HelloID-Conn-Prov-Source-Elanza-Persons
#
# Version: 1.1.0
##################################################
# Initialize default values
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

    # Group on uuid (to match to shifts)
    $departmentsGrouped = $departments | Group-Object uuid -AsString -AsHashTable

    # Get all skills
    $skills = (Invoke-ElanzaRestMethod -Uri "skills").skills

    # Sort skills on uuid (to make sure the order is always the same)
    $skills = $skills | Sort-Object -Property uuid

    # Group on uuid (to match to shifts)
    $skillsGrouped = $skills | Group-Object uuid -AsString -AsHashTable

    # Get all workers with their shifts
    $historicalDays = (Get-Date).ToUniversalTime().AddDays( - $($config.HistoricalDays))
    $futureDays = (Get-Date).ToUniversalTime().AddDays($($config.FutureDays))
    $workers = (Invoke-ElanzaRestMethod -Uri "plannedWorkers?from=$($historicalDays.ToString('yyyy-MM-ddTHH:mm:ssZ'))&to=$($futureDays.ToString('yyyy-MM-ddTHH:mm:ssZ'))").workers

    foreach ($worker in $workers) {
        $detailsStartDate = (Get-Date).ToUniversalTime().AddDays( - $($config.ShiftDetailsStart)).Date
        $detailsEndDate = $futureDays

        $historyStartDate = $historicalDays
        $historyEndDate = (Get-Date $detailsStartDate).ToUniversalTime().AddDays(-1).Date

        # Create an empty list that will hold all shifts (contracts)
        $contracts = [System.Collections.Generic.List[object]]::new()

        # Create the object that will hold all historical data as one aggregated object with a custom type
        $historicalShiftContract = @{
            ExternalId            = $($worker.worker.workerNumber)
            Shifts                = [System.Collections.Generic.List[object]]::new()
            Type                  = 'HistoricalShift'

            # Add the same fields as for shift. Otherwise, the HelloID mapping will fail
            # The value of both the 'startAt' and 'endAt' cannot be null. If empty, HelloID is unable
            # to determine the start/end date, resulting in the contract marked as 'active'.
            startAt               = $historyStartDate.ToString('yyyy-MM-dd')
            endAt                 = $historyEndDate.ToString('yyyy-MM-dd')
            title                 = 'unavailable'
            productUuid           = 'unavailable'
            departmentUuid        = 'unavailable'
            ProductName           = 'unavailable'
            DepartmentName        = 'unavailable'
            DepartmentCode        = 'unavailable'
            SkillName             = 'unavailable'
            DepartmentBrandName   = 'unavailable'
            ProductHrFunctionCode = 'unavailable'
        }
        $contracts.Add($historicalShiftContract)

        foreach ($shift in $worker.shifts) {
            if (![string]::IsNullOrEmpty($shift.StartAt)) {
                $shiftStart = [DateTime]::ParseExact($shift.startAt, "MM/dd/yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)

                if ($shiftStart -ge $detailsStartDate -and $shiftStart -le $detailsEndDate) {
                    $shift | Add-Member -MemberType 'NoteProperty' -Name 'ExternalId'  -Value $shift.uuid
                    $shift | Add-Member -MemberType 'NoteProperty' -Name 'Type'        -Value 'ActiveShift'

                    # Enhance shift with product for extra information, such as: name - adjust to meet your needs
                    # As there is no 'Get all' API for products, we need to call the API for each product
                    if (-not[string]::IsNullOrEmpty($shift.productUuid)) {
                        $shiftProduct = Get-ElanzaProductById -Id $shift.productUuid
                    }
                    if ($null -ne $shiftProduct) {
                        # In case multiple are found with the same ID, we always select the first one in the array
                        $shiftProduct = $shiftProduct | Select-Object -First 1

                        if (![string]::IsNullOrEmpty($shiftProduct)) {
                            $shift | Add-Member -MemberType 'NoteProperty' -Name 'ProductName' -Value $shiftProduct.name
                            $shift | Add-Member -MemberType 'NoteProperty' -Name 'ProductHrFunctionCode' -Value $shiftProduct.hrFunctionCode
                        }
                    }

                    # Enhance shift with department for extra information, such as: name and code - adjust to meet your needs
                    $shiftDepartment = $departmentsGrouped["$($shift.departmentUuid)"]
                    if ($null -ne $shiftDepartment) {
                        # In case multiple are found with the same ID, we always select the first one in the array
                        $shiftDepartment = $shiftDepartment | Select-Object -First 1

                        if (![string]::IsNullOrEmpty($shiftDepartment)) {
                            $shift | Add-Member -MemberType 'NoteProperty' -Name 'DepartmentName' -Value $shiftDepartment.name
                            $shift | Add-Member -MemberType 'NoteProperty' -Name 'DepartmentCode' -Value $shiftDepartment.code
                            $shift | Add-Member -MemberType 'NoteProperty' -Name 'DepartmentBrandName' -Value $shiftDepartment.brandName
                        }
                    }

                    # Enhance shift with skills for extra information, such as: name - adjust to meet your needs
                    $shiftSkills = [System.Collections.Generic.List[object]]::new()
                    foreach ($skillUuid in $shift.skillUuids) {
                        $shiftSkill = $skillsGrouped["$($skillUuid)"]
                        if ($null -ne $shiftSkill) {
                            # In case multiple are found with the same ID, we always select the first one in the array
                            $shiftSkill = $shiftSkill | Select-Object -First 1
                        
                            if (![string]::IsNullOrEmpty($shiftSkill)) {
                                $shiftSkills.Add($shiftSkill)
                            }
                        }
                    }
                    $shift | Add-Member -MemberType 'NoteProperty' -Name 'SkillNames' -Value ($shiftSkills.name -join ';')

                    $contracts.Add($shift)
                }
                elseif ($shiftStart -ge $historyStartDate -and $shiftStart -le $historyEndDate) {
                    $historicalShiftContract['Shifts'].Add($shift)
                }
            }
            else {
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
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-ElanzaError -ErrorObject $ex
        Write-Verbose "Could not import Elanza persons. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Could not import Elanza persons. Error: $($errorObj.FriendlyMessage)"
    }
    else {
        Write-Verbose "Could not import Elanza persons. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import Elanza persons. Error: $($ex.Exception.Message)"
    }
}