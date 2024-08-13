Le connecteur source Elanza relie la plateforme médicale Elanza à vos systèmes cibles via la solution de Gestion des Identités et Accès (GIA) HelloID de Tools4ever. Cette intégration améliore la gestion des comptes et des autorisations dans les systèmes cibles utilisés par votre organisation médicale. Elle automatise considérablement le provisioning des comptes. Cela est particulièrement utile étant donné que de nombreuses organisations médicales travaillent avec des employés aux horaires flexibles et des intérimaires, ce qui génère un grand nombre de modifications dans les systèmes cibles. Grâce à la connexion entre Elanza et vos systèmes cibles, vous n'avez plus à vous soucier de de des actions a réaliser. Cet article décrit cette connexion, les possibilités offertes par cette intégration et ses avantages. 

## Qu’est-ce qu’Elanza

Elanza est un outil intelligent pour la gestion des employés dans le secteur médical, offrant aux organisations une maîtrise totale sur la gestion des employés. Au cœur de cet outil se trouve une fonctionnalité de correspondance automatique qui aide les organisations à attirer les meilleurs soignants pour soutenir leurs équipes permanentes. Elanza peut automatiquement partager des services avec différents groupes d'employés, selon l'ordre que vous avez défini, et fournit des analyses précieuses sur l'utilisation, les coûts et la qualité des services. Le système prend en charge également la planification, la communication et la facturation.

## Pourquoi une intégration avec Elanza est-elle utile ?

Gérer les comptes et les autorisations des travailleurs flexibles et intérimaires peut être une tâche chronophage et sujette aux erreurs. Ces travailleurs effectuent souvent des missions diverses et de courte durée, ce qui nécessite des ajustements fréquents des comptes et des autorisations dans vos systèmes. Si un compte ou une autorisation manque, le travailleur ne pourra pas effectuer son travail correctement ni enregistrer ses activités. Si vous ne révoquez pas les comptes ou les autorisations à temps, cela peut poser des problèmes de sécurité et de conformité. Le connecteur Elanza, via HelloID, automatise ce processus, réduisant ainsi votre charge de travail et minimisant les erreurs humaines tout en garantissant que toutes les activités sont correctement enregistrées.

Le connecteur Elanza fonctionne comme une source autonome dans HelloID, permettant d'importer les employés et leurs services. Vous pouvez également l'utiliser en complément un connecteur source RH existant. HelloID traite chaque service comme un contrat avec une date de début et de fin. 

## Les avantages d'HelloID pour Elanza
**Gestion efficace des comptes :** Les employés aux horaires flexibles et intérimaires doivent disposer des bons comptes pour effectuer leur travail. Le taux de rotation élevé entraîne de nombreuses modifications. L'intégration entre Elanza et vos systèmes cibles permet une gestion automatisée des comptes : HelloID attribue ou révoque les autorisations dès que des modifications de services se produisent, garantissant que les travailleurs disposent toujours des bonnes permissions et évitant les accès non autorisés.

**Enregistrement efficace** : Grâce à l'intégration, vous optimisez le processus d'embauche des employés ponctuels et intérimaires sans avoir à les enregistrer dans votre propre système RH, séparant ainsi les informations des employés internes et externes, et simplifiant leur gestion.

**Audit des autorisations** : En tant qu'organisation médicale, vous devez respecter diverses normes et être prêt pour les audits (par exemple la directive NIS ou NIS2). L'intégration entre Elanza et vos systèmes cibles vous fournit un journal d'audit complet des autorisations accordées ou révoquées, vous préparant ainsi parfaitement aux audits.

**Gestion sans erreur des autorisations :** Travailler avec intérimaires entraîne de nombreuses modifications dans vos systèmes cibles, augmentant le risque d'erreurs humaines, comme la non-révocation des autorisations en temps voulu. Grâce à l'intégration entre Elanza et vos systèmes cibles, vous êtes assuré que les autorisations sont toujours révoquées en temps voulu. 

## Comment HelloID s'intègre avec Elanza 
Le connecteur source Elanza permet de relier l'outil de gestion des employés aux divers systèmes cibles utilisés par votre organisation. HelloID utilise les données sources d'Elanza pour automatiser complètement le processus de provisioning des comptes.

| Modification dans Elanza	| Procédure dans les systèmes cibles | 
| ------------------------- | ---------------------------------- | 
| **Nouvel employé planifié**	| Sur la base des informations d'Elanza, HelloID crée un compte utilisateur dans les systèmes cibles connectés, avec les bons droits. En fonction du rôle associé aux services actifs ou futurs du nouvel employé, la solution IAM crée automatiquement les comptes nécessaires et attribue les bonnes autorisations. | 
| **Modification des services de l'employé**	| HelloID modifie automatiquement les comptes et attribue les bonnes autorisations dans les systèmes connectés en fonction des services actifs ou futurs, ou les révoque. Le modèle d'autorisation d'HelloID est toujours prioritaire. | 
| **Départ de l'employé**	| HelloID désactive automatiquement les comptes s'il n'y a pas de services actifs ou futurs. Si aucun nouveau service n'est enregistré dans une certaine période, HelloID peut également supprimer les comptes automatiquement. | 

HelloID utilise les API REST d'Elanza pour importer les données sources et les rendre disponibles dans le coffre-fort HelloID Vault. La solution de GIA ne stocke que les données suffisantes et nécessaires pour le provisioning des comptes. Le connecteur utilise des standards comme HTTPS pour la communication sécurisée et OAuth 2.0 pour l'autorisation. Vous pouvez exécuter le connecteur via un agent sur site ou directement via l'agent cloud de Tools4ever. 

## Connecter Elanza à vos systèmes via HelloID 
Vous pouvez connecter Elanza à un large éventail de systèmes cibles via HelloID. Cette intégration vous libère de nombreuses tâches et améliore la gestion des utilisateurs et des autorisations. Voici quelques exemples d'intégrations courantes :

* **Elanza – Active Directory :** Grâce à cette intégration, vous éliminez la gestion manuelle et évitez les erreurs humaines. La synchronisation automatisée entre Elanza et Active Directory garantit que les comptes et les autorisations sont toujours à jour.
* **Elanza – Entra ID :** Comme pour Active Directory, cette connexion vous libère de nombreuses tâches de gestion manuelle, réduisant les risques d'erreurs humaines et garantissant des comptes et des autorisations à jour.
* **Elanza – GLPI (ITSM en général) :** Cette intégration permet le provisionning automatique des badges des employés, permettant ainsi aux employés ponctuels d'utiliser les processus de gestion des services informatiques de l'organisation.
* **Elanza – Easily (DPI en général) :** L'intégration assure aux soignants les bonnes autorisations dans le dossier électronique du patient, garantissant un accès approprié aux données nécessaires pour les services actifs.

HelloID propose plus de 200 connecteurs, permettant ainsi de relier la solution de GIA de Tools4ever à une grande variété de systèmes sources et cibles. Vous pouvez trouver un aperçu de tous les connecteurs disponibles ici.

