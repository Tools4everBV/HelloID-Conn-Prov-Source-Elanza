##################################################
# HelloID-Conn-Prov-Source-Elanza-Persons
# Version: 1.1.1
##################################################

# Load configuration
$config = $configuration | ConvertFrom-Json

# Verbose logging when debug is enabled
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

# Cache for retrieved products
$retrievedProducts = @{}

#region functions

# Get product details by ID (cached)
function Get-ElanzaProductById {
    [CmdletBinding()]
    param (
        [Parameter()] $Id
    )

    if (-not $retrievedProducts.ContainsKey($Id)) {
        $productDetails = Invoke-ElanzaRestMethod -Uri "product/$Id"
        $retrievedProducts[$Id] = $productDetails
    }
    Write-Output $retrievedProducts[$Id]
}

# Perform Elanza API call
function Invoke-ElanzaRestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Uri
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

# Create readable error object from HTTP errors
function Resolve-ElanzaError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object] $ErrorObject
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
            $httpErrorObj.FriendlyMessage = (($ErrorObject.ErrorDetails.Message | ConvertFrom-Json)).message
        }
        catch {
            $httpErrorObj.FriendlyMessage = "Received an unexpected response: [$($_.Exception.Message)]. Original: [$($ErrorObject.Exception.Message)]"
        }

        Write-Output $httpErrorObj
    }
}
#endregion

try {
    # Retrieve and group departments
    $departments = (Invoke-ElanzaRestMethod -Uri "departments").departments |
    Sort-Object -Property uuid
    $departmentsGrouped = $departments | Group-Object uuid -AsString -AsHashTable

    # Retrieve and group skills
    $skills = (Invoke-ElanzaRestMethod -Uri "skills").skills |
    Sort-Object -Property uuid
    $skillsGrouped = $skills | Group-Object uuid -AsString -AsHashTable

    # Get workers with shifts for defined period
    $historicalDays = (Get-Date).ToUniversalTime().AddDays( - $($config.HistoricalDays))
    $futureDays = (Get-Date).ToUniversalTime().AddDays($($config.FutureDays))
    $workers = (Invoke-ElanzaRestMethod -Uri "plannedWorkers?from=$($historicalDays.ToString('yyyy-MM-ddTHH:mm:ssZ'))&to=$($futureDays.ToString('yyyy-MM-ddTHH:mm:ssZ'))").workers

    foreach ($worker in $workers) {
        # Work with date-only boundaries
        $detailsStartDate = (Get-Date).ToUniversalTime().AddDays( - $($config.ShiftDetailsStart)).Date
        $detailsEndDate = $futureDays.Date
        $historyStartDate = $historicalDays.Date
        $historyEndDate = $detailsStartDate.AddDays(-1)

        # Shifts list
        $contracts = [System.Collections.Generic.List[object]]::new()

        # Historical aggregate (prevents mapping issues on empty dates)
        $historicalShiftContract = @{
            ExternalId            = $worker.worker.workerNumber
            Shifts                = [System.Collections.Generic.List[object]]::new()
            Type                  = 'HistoricalShift'
            startAt               = $historyStartDate.ToString('yyyy-MM-dd')
            endAt                 = $historyEndDate.ToString('yyyy-MM-dd')
            title                 = 'unavailable'
            productUuid           = 'unavailable'
            departmentUuid        = 'unavailable'
            ProductName           = 'unavailable'
            DepartmentName        = 'unavailable'
            DepartmentCode        = 'unavailable'
            SkillNames            = 'unavailable'
            DepartmentBrandName   = 'unavailable'
            ProductHrFunctionCode = 'unavailable'
        }
        $contracts.Add($historicalShiftContract)

        foreach ($shift in $worker.shifts) {
            if ([string]::IsNullOrEmpty($shift.StartAt)) {
                Write-Verbose "Attribute [startAt] is empty for shift [$($shift.uuid)] worker [$($worker.worker.workerNumber)]."
                continue
            }

            # Parse start as date-only
            $shiftStart = [DateTime]::ParseExact($shift.startAt, "MM/dd/yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture).Date

            # Active shifts window
            if ($shiftStart -ge $detailsStartDate -and $shiftStart -le $detailsEndDate) {
                $shift | Add-Member -MemberType NoteProperty -Name ExternalId -Value $shift.uuid
                $shift | Add-Member -MemberType NoteProperty -Name Type       -Value 'ActiveShift'

                # Product info
                if (-not [string]::IsNullOrEmpty($shift.productUuid)) {
                    $shiftProduct = Get-ElanzaProductById -Id $shift.productUuid | Select-Object -First 1
                    if ($null -ne $shiftProduct) {
                        $shift | Add-Member -MemberType NoteProperty -Name ProductName           -Value $shiftProduct.name
                        $shift | Add-Member -MemberType NoteProperty -Name ProductHrFunctionCode -Value $shiftProduct.hrFunctionCode
                    }
                }

                # Department info
                $shiftDepartment = $departmentsGrouped["$($shift.departmentUuid)"] | Select-Object -First 1
                if ($null -ne $shiftDepartment) {
                    $shift | Add-Member -MemberType NoteProperty -Name DepartmentName      -Value $shiftDepartment.name
                    $shift | Add-Member -MemberType NoteProperty -Name DepartmentCode      -Value $shiftDepartment.code
                    $shift | Add-Member -MemberType NoteProperty -Name DepartmentBrandName -Value $shiftDepartment.brandName
                }

                # Skills → explicit collection
                $shiftSkills = [System.Collections.Generic.List[object]]::new()
                foreach ($skillUuid in $shift.skillUuids) {
                    $skill = $skillsGrouped["$($skillUuid)"] | Select-Object -First 1
                    if ($null -ne $skill) {
                        $shiftSkills.Add($skill)
                    }
                }
                $shift | Add-Member -MemberType NoteProperty -Name SkillNames -Value ($shiftSkills.name -join ';')

                # Normalize start/end strings to yyyy-MM-dd from parsed dates
                $shift.startAt = $shiftStart.ToString('yyyy-MM-dd')
                if ($shift.endAt) {
                    $shiftEnd = [DateTime]::ParseExact($shift.endAt, "MM/dd/yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture).Date
                    $shift.endAt = $shiftEnd.ToString('yyyy-MM-dd')
                }

                $contracts.Add($shift)
            }

            # Historical window
            elseif ($shiftStart -ge $historyStartDate -and $shiftStart -le $historyEndDate) {
                $historicalShiftContract['Shifts'].Add($shift)
            }
        }

        # Person object
        $personObj = [PSCustomObject]@{
            ExternalId  = $worker.worker.workerNumber
            DisplayName = "$($worker.worker.firstName) $($worker.worker.lastName) ($($worker.worker.workerNumber))".Trim()
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
