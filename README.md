
# HelloID-Conn-Prov-Source-Elanza


| :information_source: Information                                                                                                                                                                                                                                                                                                                                                       |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

<p align="center">
  <img src="https://elanza.nl/images/landing/logo-white.svg">
</p>

## Table of contents

- [HelloID-Conn-Prov-Source-Elanza](#helloid-conn-prov-source-elanza)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Remarks](#remarks)
      - [`PastDays` \& `FutureDays`](#pastdays--futuredays)
      - [Empty `workerNumber`](#empty-workernumber)
      - [No API call to get a list of departments and products](#no-api-call-to-get-a-list-of-departments-and-products)
        - [Person import](#person-import)
        - [Department import](#department-import)
      - [Customized error handling](#customized-error-handling)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Source-Elanza_ is a _source_ connector. _Elanza_ provides a set of REST API's that allow you to programmatically interact with its data. The HelloID connector uses the API endpoints listed in the table below.

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
| PastDays   | Specify the number of days in the past from which the plannedWorkers will be imported. | Yes       |
| FutureDays | Specify the number of days in the future until the plannedWorkers will be imported.    | Yes       |

### Remarks

#### `PastDays` & `FutureDays`

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

Because the _product_ and _department_ have a __1:N__ relation, we added some logic to prevent retrieving the same object for each worker.

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

