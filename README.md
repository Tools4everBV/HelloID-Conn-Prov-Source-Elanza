
# HelloID-Conn-Prov-Source-Elanza


> [!WARNING]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. 

<p align="center">
  <img src="https://elanza.nl/images/landing/logo-white.svg">
</p>

## Table of contents

- [HelloID-Conn-Prov-Source-Elanza](#helloid-conn-prov-source-elanza)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
    - [Endpoints](#endpoints)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Remarks](#remarks)
      - [Logic in-depth](#logic-in-depth)
        - [How does the above translates to code](#how-does-the-above-translates-to-code)
        - [What if the `startAt` is empty?](#what-if-the-startat-is-empty)
      - [`HistoricalDays` \& `FutureDays`](#historicaldays--futuredays)
      - [Empty `workerNumber`](#empty-workernumber)
      - [No API call to get a list of departments and products](#no-api-call-to-get-a-list-of-departments-and-products)
        - [Person import](#person-import)
        - [Department import](#department-import)
      - [Customized error handling](#customized-error-handling)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Source-Elanza_ is a _source_ connector. The purpose of this connector is to import _plannedWorkers_ and their _shifts_. A shift represents a timetable entry and translates into a person contract.

### Endpoints

Currently the following endpoints are being used where the _plannedWorkers_ is custom made for _HelloID_.

| Endpoint         |
| ---------------- |
| /plannedWorkers  |
| /department/{id} |
| /product/{id}    |

>  [Elanzi API documentation](https://app.elanza.nl/rest-api/v1/documentation).

## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting    | Description                                                                            | Mandatory |
| ---------- | -------------------------------------------------------------------------------------- | --------- |
| ApiKey     | The ApiKey to connect to the API                                                       | Yes       |
| BaseUrl    | The URL to the API                                                                     | Yes       |
| HistoricalDays | - The number of days in the past from which the workers and shifts will be imported.<br> - Will be converted to a `[DateTime]` object containing the _current date_ __minus__ the number of days specified. | Yes       |
| FutureDays | - The number of days in the past from which the workers and shifts will be imported.<br> - Will be converted to a `[DateTime]` object containing the _current date_ __plus__ the number of days specified. | Yes       |
| ShiftDetailsStart | The number of days for which the shift details will be added as a contract rule | Yes       |

### Remarks

#### Logic in-depth

The purpose of this connector is to import _plannedWorkers_ and their _shifts_. A shift represents a timetable entry and will result a contract.

Planned workers are imported within a specified timeframe, configured by the `HistoricalDays` and `FutureDays` settings in the configuration.

Each _plannedWorker_ typically has multiple shifts (one per day), we selectively import shifts as contracts from within the defined time frame.

__The logic is as follows:__

Data will be imported within a specified time frame, Controlled by the `$historicalDays` and `$futureDays` settings. Both values in _days_.

For example, if `$historicalDays` is set to _60_ and `$futureDays` is set to _14_, a total of _74_ days will be imported.
As mentioned earlier, each shift corresponds directly to one day, resulting in _74_ shifts and, consequently, _74_ contracts.

However, an additional configuration setting is `$shiftDetailsStart`.
If, for example, this is set to _7_, the last _7_ days of the `$historicalDays` will result in individual contracts.
The remaining shifts will be aggregated into a single contract identified by a unique uuid.

That means that with the settings: `$historicalDays` _60_, `$futureDays` _14_ and `$shiftDetailsStart` _7_, a total of _21_ shifts will result in individual contracts plus one additional contract with the remaining historical data.

- __14__ future contracts.
- __7__ past contracts from the _60_ `$historicalDays`.
- The remainder of _53_ of the _60_ `$historicalDays` aggregated to __1__ contract wit a fixed uuid.

Ultimately, a total of __22__ contracts will be imported.

##### How does the above translates to code

Lets assume we have the following configuration settings:

- `HistoricalDays` _60_.
- `FutureDays` _14_.
- `ShiftDetailsStart` _7_.

The first step is to retrieve all _plannedWorkers_ from within the specified timeframe.

```powershell
$historicalDays = (Get-Date).AddDays(-$($config.HistoricalDays))
$futureDays = (Get-Date).AddDays($($config.FutureDays))

$response = Invoke-ElanzaRestMethod -Uri "plannedWorkers?from=$($historicalDays.ToString("yyyy-MM-ddTHH:mm:ssZ"))&to=$($futureDays.ToString("yyyy-MM-ddTHH:mm:ssZ"))"
```

Next, we loop through each of the _plannedWorkers_ and their shifts based on:

- `$detailsStartDate` which is the __current__ date __minus__ the value from `ShiftDetailsStart`.
- `$detailsEndDate` which is the __current__ date __plus__ the value from `FutureDays`.

> Remember: if the `ShiftDetailsStart` is set to _7_, only the _last_ _7_ days of the _HistoricalDays_ will result in individual contracts. Hence, these _7_ days will be subtracted from the _current_ date.

```powershell
$detailsStartDate = (Get-Date).AddDays(-$($config.ShiftDetailsRange)).Date
$detailsEndDate = (Get-Date).AddDays($($config.FutureDays))
if ($shiftStart -ge $detailsStartDate -and $shiftStart -le $detailsEndDate){
  # Import as regular contract
}
```

The last step is to import the historical data aggregated into one contract object based on:

- `$historyStartDate` which is the __current__ date __minus__ the value from `HistoricalDays`.
- `$historyEndDate` which is the date from the `$detailsStartDate` __minus__ _1_. This prevents importing the last contract both as an individual contract and as part of the aggregated contract object.


```powershell
$historyStartDate = $historicalDays
$historyEndDate = (Get-Date $detailsStartDate).AddDays(-1).Date
if ($shiftStart -ge $historyStartDate -and $shiftStart -le $historyEndDate) {
  # Import as one aggregated contract object
}
```

##### What if the `startAt` is empty?

We made the assumption that this is not possible. Since the _plannedWorkers_ API call is custom made for _HelloID_ and because this call is meant to return shifts within the specified __mandatory__ time frame. However, we added some simple logic in case it happens.

#### `HistoricalDays` & `FutureDays`

The `PastDays` and `FutureDays` configuration settings are used to specify the time range within which the _plannedWorkers_ will be imported. Both will result in `[DateTime]` object formatted as a: _ISO8601_ object. __Example:__ _2023-12-14T11:50:19Z_.

#### Empty `workerNumber`

During testing we sometimes stumbled upon workers without a `workerNumber`. The `workerNumber` is mandatory since its gets mapped to the `ExternalId` within HelloID. We made the assumption that this issue won't occur in a production environment.

#### No API call to get a list of departments and products

Unfortunately there are no API calls to retrieve a list of departments or products. Both can only be retrieved by making an API call using the `uuid` on a worker.shift.

The response to retrieve all _plannedWorkers_ is as follows:

```JSON
[
  {
      "worker": {
      "email": "string",
      "workerNumber": 0
    },
    "shifts": [
      {
        "startAt": "2024-02-04T11:00:00.000Z",
        "endAt": "2024-02-04T17:00:00.000Z",
        "productUuid": "1bd6cd19-1eb2-487e-bd8e-c4f66cb567fa",
        "departmentUuid": "1bd6cd19-1eb2-487e-bd8e-c4f66cb567fa",
      }
    ],
  }
]
```

Both the `productUuid` and `departmentUuid` are part of the _shifts_ object.

- The _product_ returns a string containing the 'competitie' or _skill_ and is mapped to the _title_ attribute within HelloID.
- The _department_ returns the departmental information.
- Both _product_ and _department_ have a __1:N__ relation.

This means that; in both the _person_ and _department_ import scripts, __ALL__ _plannedWorkers_ will be retrieved, looped through and for each `worker.shift`, the product and department data is retrieved.

##### Person import

Because the _product_ and _department_ have a __1:N__ relation, we added some logic to prevent retrieving the same object.

Within the _person_ import, this flow is currently as follows:

- Loop through each of the workers and their shifts.
- Call the function `Get-ElanzaProductById`.
- Verify if the product is already in the `$retrievedProducts` dictionary.
  - __If true:__
    - Return the product from the `$retrievedProducts` dictionary.
  - __If false:__
  - Retrieve the product from the API.
  - Add the product to the `$retrievedProducts` dictionary.
  - Return the product from the `$retrievedProducts` dictionary.

##### Department import

Because the _department_ objects will also need to be extended with additional attributes like the `ExternalId`, the logic to prevent retrieving the same object is a little different in the _department_ import script.

The _department_ import uses a `[System.Collection.Generic.List[object]]` to which a retrieved department will be added. The flow is as follows:

- Loop through each of the workers and their shifts.
- Call the function `Get-ElanzaDepartmentById`.
- Verify if the department is already in the `$retrievedDepartments` list.
  - __If true:__
    - Return the department from the `$retrievedDepartments` list.
  - __If false:__
    - Retrieve the department from the API.
    - Extend the object with the appropriate fields for HelloID.
    - Add the extended department to the `$retrievedDepartments` list.
    - Return the department from the `$retrievedDepartments` list.

#### Customized error handling

The _Elanza_ API does not return a whole lot of error information. The error handling logic is tested on both _Windows PowerShell_ and _PowerShell Core_.

One important thing to note is that the `Invoke-ElanzaRestMethod` function is modified to __NOT__ throw in case a _product_ or _department_ `uuid` does not exist. This way, we ensure that the import does not fail.

## Getting help

> ℹ️ _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> ℹ️ _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

