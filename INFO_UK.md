## Elanza Source Connector

The Elanza Source Connector links the Elanza healthcare platform to your target systems via Tools4ever’s identity & access management (IAM) solution HelloID. This integration enhances the management of accounts and authorisations in the target systems used by your healthcare organisation. It significantly automates account provisioning, which is especially beneficial given the high turnover of flexible and temporary staff in many healthcare organisations, which requires a large number of mutations in your target systems. Thanks to the integration between Elanza and your target systems, you won’t need to worry about managing these changes. This article provides more information about the connector, its capabilities and benefits.

##  What is Elanza?

Elanza is an intelligent tool for flexible working in healthcare, giving organisations control over the deployment of flexible and temporary staff. Central to this is the automatic match tool, which helps organisations attract the best healthcare providers to support their permanent teams. Among other things, Elanza can automatically share shifts with various flexible staff layers, allowing you to set the desired order and generate smart insights into all deployments, costs and quality across all layers. The system also offers support in planning, communication and invoicing.

## Why is an Elanza integration useful?

Managing user accounts and authorisations for flexible and temporary staff is an essential, yet time-consuming and error-prone task. These workers often have diverse and short-term shifts, which means the accounts and authorisations in target systems require frequent updates. If an account or authorisation is missing, the flexible or temporary worker cannot perform their tasks properly or log their work accurately. Failing to revoke accounts or authorisations in a timely manner can lead to security and compliance issues. The integration between Elanza and your target systems via HelloID automates account provisioning, relieving you of this workload and preventing human errors and missed work registrations that could affect production norms and revenue.

The Elanza connector is deployed in HelloID as an independent source connector, allowing for the processing of flexible and temporary workers and their shifts. You can also use Elanza in addition to an existing HR source connector. HelloID treats each shift as a contract with its own start and end date.

## HelloID for Elanza helps you with

**Efficient account management:** Flexible and temporary staff needs the right accounts to perform their tasks. High turnover and frequent changes lead to many updates. The integration between Elanza and your target systems enables automated account management. HelloID assigns or revokes authorisations as soon as changes in shifts occur. This ensures that flexible and temporary staff always has the correct permissions within target systems, preventing unauthorised access.

**Efficient registration of flexible and temporary staff:** The integration allows you to efficiently and accurately register the hiring of flexible and temporary staff without needing to record this data in your own HRM system. This keeps information about your own staff and external hires separate and simplifies management.

**Audit logs of authorisations:** As a healthcare organisation, you need to comply with various standards and demonstrating this compliance through audits is crucial. The integration between Elanza and your target systems provides a complete audit log of all authorisations granted or revoked. This ensures you are well-prepared for audits and can pass them without issues.

**Error-free management of authorisations:** Working with flexible and temporary staff results in many updates in your target systems, increasing the risk of human errors, such as failing to revoke authorisations when employment is terminated. The integration between Elanza and your target systems ensures you don’t have to worry about this, as authorisations are always revoked in a timely manner when flexible and temporary staff is no longer active in your organisation.

## How HelloID integrates with Elanza
	
A source connector is available for Elanza, linking the tool for flexible working in healthcare to the various target systems used by your organisation. This integration allows HelloID to obtain the necessary source data from Elanza to fully automate the provisioning process. This means you won’t have to worry about managing accounts and authorisations in your target systems.

| Change in Elanza |  	Procedure in target systems | 
| ------------------- | ---------------------------- | 
| **New staff is scheduled** |	Based on information from Elanza, HelloID automatically creates a user account in linked target systems with the correct group memberships. Depending on the role associated with the new staff’s active or future shifts, the IAM solution automatically creates the necessary user accounts in your target systems and assigns the correct authorisations. | 
| **Staff shifts change** |	HelloID automatically updates user accounts and assigns or revokes the correct authorisations in linked target systems based on the registered active or future shifts. HelloID’s authorisation model always takes precedence. | 
| **Staff leaves the organisation** |	The IAM solution automatically deactivates user accounts if no active or future shifts are registered. If no new shifts are registered within a certain period of time, HelloID can also automatically delete accounts. |  

HelloID uses Elanza’s REST APIs to read source data and make it available in the HelloID Vault. The IAM solution only stores data necessary for account provisioning. The connector uses industry standards like HTTPS for encrypted communication and OAuth 2.0 for authorisation. The connector can be executed via an on-premises agent or directly via Tools4ever’s cloud agent.

## Connecting Elanza to target systems via HelloID

You can link Elanza to a wide range of target systems via HelloID. This integration relieves you of significant work and enhances the management of both users and authorisations. Among other things, it automates updates in your target systems based on information from Elanza. Some common integrations include:

**Elanza – Active Directory integration:** The integration between Elanza and Active Directory eliminates manual management and prevents human errors. Automated synchronisation between Elanza and Active Directory ensures that accounts and authorisations are always up-to-date.

**Elanza – Entra ID integration:** Like the Active Directory integration, the Entra ID integration reduces manual management tasks and minimises the risk of human errors. It also ensures that accounts and authorisations are always up-to-date.

**Elanza – TOPdesk integration:** This integration allows for the fully automatic provisioning of personal cards. This is beneficial as it enables flexible and temporary staff to use the IT Service Management processes within the organisation.

**Elanza – Nedap ONS integration:** This integration ensures that healthcare workers always have the correct authorisations within the Electronic Client Record. This guarantees that staff with active shifts always has access to the necessary information.

More than 200 connectors are available for HelloID. You can link the Tools4ever IAM solution to a wide range of source and target systems. The extensive integration possibilities enable you to connect Elanza to almost all popular target systems. An overview of all connectors is available here.
