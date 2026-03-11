# **The Cultural Stewardship DAO \- Specification**

| WARNING: Cultural Stewardship DAO is under development. The organisational specs and deployment addresses are subject to change. This document serves as an initial specification based on the ecosystem architecture. |
| :---- |

[comment]: <> (Important: This is how you leave a comment, it will not be included in the rendered text.) 

## **Context**

### ***The Vision & Mission:***

The Cultural Stewardship DAO is a multi-layered ecosystem designed to foster an interplay between  ideational concepts, physical spaces, and digital manifestations. Its primary aim is to act as a steward for cultural assets through a "Layered Approach", ensuring a clear separation between different activities while facilitating their interactions to foster cultural activities.

It aims to teach digital literacy skills and openly **facilitate a continuous conversation around blockchain governance experiments in the cultural realm.** It exists to make DAO tools more accessible, translating complex technological processes into understandable concepts; and hopes to foster meaningful contributions by creating a circular community ecosystem that brings tangible assets to Participants.

* **ONBOARDING:** To bring Participants into the ecosystem. 
* **LEARNING:** To teach Participants about the ecosystem and how it functions.  
* **DISCOVERING:** To allow Participants to jump across various different clusters in the ecosystem, transparently seeing what others have built within the ecosystem (as sub-DAOs).  
* **VOTING:** To give Participants the decision inside the ecosystem, whether they vote on large-scale DAO-wide effects or small-scale local sub-DAO effects.  
* **BUILDING:** To supply Participants with Powers Protocols tools to re-use templates within the ecosystem, building their own structures, thus creating a wide fractal pattern of DAOs and sub-DAOs across an interoperable ecosystem.  
* **PARTICIPATING:** The more the Participants thrive inside the ecosystem, the more successful the ecosystem will be, the more resources the ecosystem has to build with.  
* **VISITING:** Anyone can experience the ecosystem and watch it evolve as an outside visitor. There is no pressure to participate in decision making processes, but visitors do have the ability to claim rewards for their time exploring the ecosystem. Alternatively, those interested can visit a physical pop-up event to discover more about the digital layers and meet other Participants IRL. 

***What this could look like, in a practical sense:***   
**www.enterhere.io is a website / dApp** for individuals, organisations, or brands with distinct communities (interested in cultural topics such as arts, intangible heritage, media, music, visuals, books, magazines, publications, and exhibitions) who are open to involve their communities in the decentralised decision making process. It is a home base, a platform and a portal; it is the layered over front-end control panel for the back-end blockchain-integrated layers beneath. It is the main point of contact to begin exploring the ecosystem of The Cultural Stewardship DAO. 

[comment]: <> (Did not implement these elements. Checkpoints and user portals are easy to implement, but assessment on when to pass through is a tricky thing) 
The UX/UI includes interactive elements taken from **game theory**, such as earning internal currency, progressing by going to checkpoints (digital and physical), working in teams, exploring other user-created portals built on its open-source infrastructure. Other elements are taken from **social media**; making it a platform to have your own customisable profile, discuss in forums and threads, vote on polls, and visually view alignment metrics such as ‘upvotes’ ‘likes’ ‘reposts’ \-- even having a ‘timeline’ to scroll through to get a birds eye view of events happening within the ecosystem. This is all to foster active participation; Participants who are active by minting participation tokens as they interact within the ecosystem, and those who vote on mandates are the ones who become the cultural stewards.

[comment]: <> (This has been implemented :) 
**Through the digital component, which is remotely accessible, the physical components are manifested.** The ecosystem has the functionality for physical spaces to spawn from ideas. This functionality is central to the DAO, and acts as a very important tangible concept space; it has blank walls that can be morphed to fit the current circumstances, where Participants can walk into and interact with the digital layers via the physical components in the space (such as a QR code where you scan and are airdropped a POAP token from the ecosystem,which may grant special access or permissions to participate further in the project). It is symbolic of the work that is being done in the digital cultural realm which has real-world impact. It’s an optional **IRL ‘checkpoint’** that works in tandem with the digital checkpoints.

## **Definitions**

* **Split Ratio**: A governance-defined percentage (e.g., 20/20/60) determining the division of funds between the Artist, Local Safe and the Primary DAO Treasury.
* **Primary DAO**: The central governance hub (`Powers.sol`) that holds the treasury, mints tokens, and orchestrates the creation of sub-DAOs.
* **Digital Sub-DAO**: A unique sub-DAO (`Powers.sol`) responsible for the digital infrastructure, code repositories, and online interfaces.
* **Ideas Sub-DAO**: A type of sub-DAO (`PowersFactory` instance) focused on ideation, incubation of new concepts, and proposing new Physical Sub-DAOs. Multiple instances can exist.
* **Physical Sub-DAO**: A type of sub-DAO (`PowersFactory` instance) that manages real-world assets, events, and physical spaces. Multiple instances can exist.
* **Executives**: Elected leaders of the Primary DAO who execute high-level decisions and manage the treasury.
* **Conveners**: Elected operational leaders within Sub-DAOs (Digital, Ideas, Physical) who manage day-to-day activities.
* **Moderators**: Appointed roles within Ideas Sub-DAOs responsible for managing membership and community standards.
* **Repository Admins**: Elected as admins of the DAO repository, managedin the Digital sub-DAO. 
* **Legal Representatives**: Individuals assigned to Physical Sub-DAOs to handle off-chain legal responsibilities and act as a bridge between the DAO and real-world legal frameworks.
* **Members/Attendees**: Participants with voting rights in their respective DAOs.

## **Assets and Tokens**

The ecosystem utilises a combination of standard and soulbound tokens to manage governance, reputation, and access:

* **Treasury (Safe)**: A centralized Safe smart wallet controlled by the Primary DAO, holding the organization's financial assets. Sub-DAOs operate via allowances rather than holding their own funds.
* **Activity Token (`Soulbound1155`)**: A non-transferable token contract used to track participation and grant access. It acts as a reputation system (e.g., POAPs).
    * **Minting**: Controlled by the Primary DAO, but minting rights can be mandated to Sub-DAOs (e.g., Physical Sub-DAOs minting POAPs).
    * **Utility**: Used for gating access to roles (e.g., becoming a Member or Attendee).
* **Merit Badges (`Soulbound1155`)**: Specific tokens used within Physical Sub-DAOs to recognise and reward contributions.
* **Real World Assets (Cultural Artifcatcs - Art works) (`Governed721`)**: An externally governed token that can be used to link an NFT through its metadata to an real world art work, and manages distribution of income at the point of Sale. It does not use the ERC-3643 RWA Tokenization standard at the moment, but this can be integrated at a later date. 
 
## **Structure**

***The Architecture of Primary & Sub-DAOs:***  
The organisation operates through a federated structure comprising a **Primary DAO** and three distinct types of **Sub-DAOs**:

1. **Primary DAO**: The central authority and root of the ecosystem.
    *   **Role**: Governance of the Treasury, creation/deactivation of Sub-DAOs, and high-level dispute resolution.
    *   **Treasury**: Controls the central Safe.
    *   **Governance**: Elected Executives, with checks and balances from Members.
2. **Digital Sub-DAO** (Type 1): A singleton entity.
    *   **Role**: Manages the digital realm—code, UI, and online presence.
    *   **Treasury**: Has an allowance from the Primary DAO's Safe.
    *   **Governance**: Elected Conveners, subject to Member oversight and Primary DAO veto.
3. **Ideas Sub-DAO** (Type 2): Multiple instances possible (Factory-deployed).
    *   **Role**: Incubator for new initiatives. It is the birthplace of Physical Sub-DAOs.
    *   **Treasury**: Does *not* typically hold an allowance. Operates on social capital and ideas.
    *   **Governance**: Moderators (appointed) and Conveners (elected). Highly autonomous, with minimal interference from the Primary DAO.
4. **Physical Sub-DAO** (Type 3): Multiple instances possible (Factory-deployed).
    *   **Role**: Manages physical assets (spaces, events). Initiated by an Ideas Sub-DAO but operates independently once created.
    *   **Treasury**: Has an allowance from the Primary DAO's Safe.
    *   **Governance**: Conveners (selected via peer review/voting) and Legal Representatives (assigned for compliance).

### ***Treasury Management:***

* **Centralised Treasury**: The Primary DAO’s Safe acts as the single source of truth for funds.
* **Allowance Module**: The Primary DAO uses a Safe Allowance Module to delegate spending power.
    *   **Digital & Physical Sub-DAOs**: Assigned spending limits (allowances) rather than direct funds.
    *   **Request Flow**: Sub-DAOs propose budgets/expenses. If approved (via internal Sub-DAO vote and Primary DAO executive execution), the allowance is updated or a transfer is executed.
* **Recovery**: The Primary DAO retains the ultimate power to recover funds or revoke allowances in case of emergencies or disputes.

### ***Deployed Mandates:*** 

Below are the details for the deployed mandates for each DAO. The section summarises the mission of the DAO, the assets it controls and the actions it can take. Subsequently, it outlines the roles the mandates have, and gives outline the executive, electoral, and reform mandates. Executive mandates execute a specific action. Electoral mandates assign accounts to roles. Reform mandates manage the adoption and/or revoking of mandates.

## Primary DAO

### ***Mission***

The central governance body holding the Treasury (Safe), where the DAO’s assets are stored on-chain.  

### ***Assets*** 

The Primary DAO controls the following assets: 

* It is the owner of the treasury (a Safe smart wallet with an allowance module).  
* It is the owner of the ERC-1155 token contract that registers participants' activity.  
* It is the owner of two PowersFactory’s: One that creates new Ideas sub-DAOs, and one that creates new Physical sub-DAOs. PowersFactory is a smart contract that deploys bespoke Powers instance. The owner of the contract can save mandates to the contract, and when they call the createPowers function, the contract deploys a Powers instance with these mandates. 


### ***Actions*** 

The Primary DAO can take the following actions:

* It can create new ideas sub-DAOs and confirms the creation of physical sub-DAOs. But Physical Sub-DAOs can only be created after a proposal from Ideas sub-DAOs.   
* It has the power to deactivate both types of Sub-DAOs. It also (re)assigns allowances to its ‘digital’ DAO and its ‘physical' DAOs.   
* It can set an allowance to the Digital sub-DAO and Physical sub-DAOs, but only after a proposal was submitted by either Digital or Physical sub-DAOs.   
* It can update its own URI.   
* It can transfer tokens accidentally sent to its address to the Safe Treasury.  
* It can assign a membership role to public accounts.   
* It can elect Executives from among DAO members.   
* It can remove inactive elected executives.   
* It can adopt new mandates (and as a consequence also revoke old ones). 

### ***Roles*** 

| Role Id | Role name | Selection criteria |
| :---- | :---- | :---- |
| 0 | Admin | Revoked at construction. |
| 1 | Members | Membership in Sub-DAO \#1, \#2, or \#3). [comment]: <> (strange, shouldn't there also be a membership role for PrimaryDAO?)
 |
| 2 | Executives | Elected every N-months from among Members. |
| 3 | Physical Sub-DAOs | Assigned at creation of a Sub-DAO. Can be removed by Executives. |
| 4 | Ideas Sub-DAOs | Assigned at creation of a Sub-DAO. Can be removed by Executives. |
| 5 | Digital Sub-DAOs | Assigned at creation of a DAO. Only 1 Digital Sub-DAO at all times. |
| … | Public | Everyone. |

### 

### ***Executive Mandates***

#### Create and revoke Ideas Sub-DAO

Members have the right to initiate new Ideas Sub-DAOs, while each idea has to be ok-ed by elected executives. [comment]: <> (unsure of this one, it is not clear what 'veto' refers to)   

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Initiate Ideas Sub-DAO creation | StatementOfIntent.sol | "string name, string uri" | none | Initiates creation proposal. Vote, normal threshold. |
| Executives | Execute Ideas Sub-DAO creation | BespokeActionSimple.sol | (same as above) | Creates Ideas Sub-DAO | Vote \+ proposal exists (No allowance assigned) |
| Executives | Assign role Id to Ideas Sub-DAO | BespokeActionOnReturnValue.sol | (same as above) | Assigns role to return value of previous mandate. | None. Any executive can execute. |
| Members | Veto revoking Ideas Sub-DAO | StatementOfIntent.sol | (same as above) | none | Vote, high threshold. |
| Executives | Revoke Ideas Sub-DAO (Role) | BespokeActionOnReturnValue.sol | (same as above) | Revokes roleId from DAO. | DAO creation should have executed, members should not have vetoed. |

#### Create and revoke Physical Sub-DAO

Ideas-DAOs can initiate the creation of a Physical-DAO. The Primary DAO will be assigned as admin of the new Physical DAO and hold veto power of adopting of new mandates. 

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Ideas Sub-DAO | Initiate Physical Sub-DAO Creation | StatementOfIntent.sol | "string name, string uri" | none | Any Ideas Sub-DAO can propose. |
| Executives | Deploy Merit Badge Contract | BespokeAction_Advanced.sol | (same as above) | Deploys Soulbound1155 | Any executive can execute. |
| Executives | Add Dependency | BespokeAction_OnReturnValue.sol | (same as above) | Adds dependency to factory | Any executive can execute. |
| Executives | Execute Physical Sub-DAO Creation | BespokeActionSimple.sol | (same as above) | Creates Physical Sub-DAO | Proposal exists, veto does not exist |
| Executives | Assign role Id to Physical Sub-DAO | BespokeActionOnReturnValue.sol | (same as above) | Assigns role to return value of previous mandate. | Any executive can execute. Previous action executed. |
| Executives | Assign Delegate status | SafeExecTransactionOnReturnValue.sol | (same as above) | Assigns delegate status at Safe treasury. | Any executive can execute. Previous action executed. |
| Members | Veto revoking Physical Sub-DAO | StatementOfIntent.sol | (same as above) | none | Vote, high threshold. |
| Executives | Revoke Physical Sub-DAO (Role) | BespokeActionOnReturnValue.sol | (same as above) | Revokes roleId. | DAO creation should have executed, members should not have vetoed. |
| Executives | Revoke Delegate status | SafeExecTransaction.sol | (same as above) | Revokes delegate status. | Any executive can execute. Previous action executed. |

#### Assign Legal Representative to Physical Sub-DAO

Process for vetting and assigning legal representatives to Physical Sub-DAOs.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Public | ZKP Check Age | ZKPassport_Check.sol | "address PhysicalSubDAO, uint16 assignRepMandateId" | Verifies age > 18 | Anyone can execute. |
| Public | ZKP Check Country | ZKPassport_Check.sol | (same as above) | Verifies country is GBR | Must have passed age check. |
| Ideas Sub-DAO | Propose Legal Representative | StatementOfIntent.sol | "address PhysicalSubDAO, uint16 assignRepMandateId, address ProposedLegalRep" | None | Proposal from Ideas Sub-DAO. |
| Executives | Assign Legal Representative Role | PowersAction_Flexible.sol | "address ProposedLegalRep" | Assigns role 3 in Physical DAO | Proposal must exist. |

#### Assign additional allowances to Physical Sub-DAO or Digital Sub-DAO

Physical and Digital sub-DAOs can request allowances for their address in the Safe treasury. Physical Sub-DAOs can veto allowances for both.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Physical Sub-DAO | Veto allowance | StatementOfIntent.sol | "address Sub-DAO, address Token, uint96 allowanceAmount, uint16 resetTimeMin, uint32 resetBaseMin" | none | Vote, high threshold. |
| Physical Sub-DAO | Request additional allowance | StatementOfIntent.sol | (same as above) | none | Initiates allowance proposal. |
| Executives | Grant Allowance to Physical Sub-DAO | SafeAllowance_Action.sol | (same as above) | Safe.approve(subDao, amount) | Proposal exists, vote, no Physical Sub-DAO veto. |
| Digital Sub-DAO | Request additional allowance | StatementOfIntent.sol | (same as above) | none | Initiates allowance proposal. |
| Executives | Grant Allowance to Digital Sub-DAO | SafeAllowance_Action.sol | (same as above) | Safe.approve(subDao, amount) | Proposal exists, vote, no Physical Sub-DAO veto. |

#### Veto Calls to Sub-DAOs

The Primary DAO can block mandate reforms at Digital and Physical DAOs. It does this by calling the mandateId of the veto law at the target Powers implementation.  

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Executives | Veto Call to sub-Dao | PowersAction_Flexible.sol | "Address PowersTarget, uint16 MandateIdTarget,  uint16[] MandateId, uint256[] roleIds" | Calls to sub-DAOs | Executioners can veto calls to Powers instances in other sub-DAOs. |

#### Update uri

The URI contains all the metadata of the organisation, including designations of sub- and primary-DAOs needed in the front end. In other words, to show new sub-DAOs in the frontend, the URI needs to be updated separately.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Veto update URI | StatementOfIntent.sol | "string new URI" | none | Vote. |
| Executives | Update URI | BespokeAction_Simple.sol | (same as above) | setUri call | Ideas Sub-DAOs did not veto, timelock. |

#### Mint NFTs Physical Sub-DAO

Physical Sub-DAOs can mint NFTs (POAPs) via the Primary DAO.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Physical Sub-DAO | Mint token Physical sub-DAO | GovernedToken_MintEncodedToken.sol | "address to" | Mint function ERC 1155 | None. |

#### Transfer tokens to treasury

It is very likely that someone will, by accident, transfer tokens to the address of the DAO instead of its treasury. This is a major issue, because the DAO has no way of transferring this tokens out. As a backup, there is a mandate that lets DAOs transfer tokens (of which they have an allowance) back to the treasury. 

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Executive | Transfer tokens to treasury | Safe_RecoverTokens.sol | "address treasury, address allowanceModule" | Goes through tokens of which the DAO has an allowance, and if the DAO has any, transfers them to the treasury | None, absolutely anyone can call this mandate and pay for the check & transfer. |

### 

### ***Electoral Mandates***

#### Claim membership Primary DAO

This is a two step process to gain membership to the Primary DAO. First an Ideas Sub-DAO forwards a request, then the public user claims membership by proving ownership of required tokens (POAPs/Activity Tokens).

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Ideas Sub-DAO | Request Membership Step 1 | StatementOfIntent.sol | "uint256[] TokenIds" | Forwards request | Ideas Sub-DAO vote. |
| Public | Request Membership Step 2 | GovernedToken_GatedAccess.sol | (same as above) | Checks ownership of tokens and Assigns Role | Previous step must be executed. Any public address can request. |

#### Revoke Membership

Members can veto revocation, Executives can execute revocation.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Veto Revoke Membership | StatementOfIntent.sol | "address MemberAddress" | None | Vote. |
| Executives | Revoke Membership | BespokeAction_Advanced.sol | (same as above) | Revokes role | Vote. Timelock. No veto. |

#### Elect Executives

This is an electoral flow for assigning executives. First an election is created, it includes a start and end block of the election. Before the election starts, members can nominate themselves. After the start block passes, the electoral vote can be called: it creates a bespoke mandate that contains a list of candidates on which accounts can vote. After the end block passes a tally is taken, old executive roles revoked and new ones assigned. Through a final mandate the electoral vote mandate can be cleaned up.   

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Member | Create election | BespokeActionSimple.sol | "string Title, uint48 StartBlock, uint48 EndBlock" | Creates election helper | Throttled. |
| Member | Open voting for Executive election | ElectionList_CreateVoteMandate.sol | (same as above) | Creates vote mandate | Previous executed. |
| Member | Tally Executive elections | ElectionList_Tally.sol | None | Tallys vote | Previous executed. |
| Member | Clean up Executive election | BespokeActionOnReturnValue.sol | None | Clean up | Previous executed. |
| Member | Vote of No Confidence | RevokeAccountsRoleId.sol | "string Title, uint48 StartBlock, uint48 EndBlock" | Revokes all Executive roles | High threshold, high quorum. |
| Member | Nominate | ElectionList_Nominate.sol | (bool, nominateMe) | Nomination logged at ElectionList | None, any member can nominate |
| Member | Revoke Nomination | ElectionList_Nominate.sol | (bool, nominateMe) | Nomination revoked at ElectionList | None, any member can revoke nomination |

### 

### ***Reform Mandates***

#### Adopt mandate

This process allows the Primary DAO to upgrade its governance by adopting new mandates. It initiates a proposal that must pass a member veto and receive approval from Sub-DAOs before being executed by Executives.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Executives | Initiate mandate adoption | StatementOfIntent.sol | "address[] mandates, uint256[] roleids" | None | None. Any Executive can initiate call for mandate reform. |
| Members | Veto Adoption | StatementOfIntent.sol | (same as above) | None | Vote, high threshold + quorum |
| Digital Sub-DAO | Veto Adoption | StatementOfIntent.sol | (same as above) | None | Vote. |
| Ideas Sub-DAO | Veto Adoption | StatementOfIntent.sol | (same as above) | None | Vote. |
| Physical Sub-DAO | Veto Adoption | StatementOfIntent.sol | (same as above) | None | Vote. |
| Executives | Checkpoint 1 | StatementOfIntent.sol | None | Confirms Members did not veto | Check prev veto not fulfilled. |
| Executives | Checkpoint 2 | StatementOfIntent.sol | None | Confirms Digital did not veto | Check prev veto not fulfilled. |
| Executives | Checkpoint 3 | StatementOfIntent.sol | None | Confirms Ideas did not veto | Check prev veto not fulfilled. |
| Executives | Execute mandate Adoption | Mandates_Adopt.sol | (same as above) | mandate is adopted. | Vote, high threshold + quorum. Confirm Physical did not veto. |

## 

## Digital Sub-DAO

### ***Mission***

Manages code repositories, commits, and digital representation of the organisation and its Sub-DAOs.

### ***Assets*** 

The Digital Sub-DAO owns the github repository that includes: 

* The code base for online UI interfaces for all (Sub-)DAOs that make up the organisation. These are managed in a single repository.  
* This includes the code base for physical UI digital experiences used by physical Sub-DAOs. 

### ***Actions*** 

The Digital sub-DAO can take the following actions:

* The public can submit receipts with the request for payment for digital work completed.  
* Members can propose funding for projects to be implemented.  
* It can request an allowance from the Primary DAO.    
  * Note: Payments are transferred from the central Safe treasury and have to be within the allowance set by the Primary DAO.  
* It can update its own URI.   
* It can transfer tokens accidentally sent to its address to the Safe Treasury.  
* It can assign a membership role to public accounts if they made successful commits to the repository.    
* It can elect Repository Admins from among sub-DAO members.
* It can adopt new mandates (and as a consequence also revoke old ones) \- but only if no veto was cast from the Primary DAO. 

### ***Roles***

| Role Id | Role name | Selection criteria |
| :---- | :---- | :---- |
| 0 | Admin | Revoked at setup |
| 1 | Members | Proof of Activity \- role by git commit |
| 2 | Repository Admins | Elected every N-months from among Members. |
| 6 | Primary DAO | Assigned at creation. Can only be single address. |
| … | Public | Everyone. |

### 

### ***Executive Mandates***

#### Request Allowances from Prime DAO

The Digital Sub-DAO can request additional allowances from the Primary DAO Safe Treasury.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Veto request allowance | StatementOfIntent.sol | "address Sub-DAO, address Token, uint96 allowanceAmount, uint16 resetTimeMin, uint32 resetBaseMin" | none | Vote. |
| Repository Admins | Request allowance | PowersAction_Simple.sol | (same as above) | Calls Primary DAO | Vote, high threshold. Proposal must exist, no veto. |

#### Payment of receipts

Meant for expenses that have already been made. Payment after completion.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Public | Submit receipt | StatementOfIntent.sol | "address Token, uint256 Amount, address PayableTo" | None | None. Anyone (also non-members) can submit a receipt. |
| Repository Admins | Ok-receipt | StatementOfIntent.sol | (Same as above) | None | None. Any Repository Admin can ok a receipt. |
| Repository Admins | Approve Payment of Receipt | SafeAllowance_Transfer.sol | (Same as above) | Call to safe allowance module: transfer | Vote, ok-receipt executed. |

#### 

#### Payment of projects

Meant for expenses that will be made in future. Payment before completion.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Submit a project for Funding | StatementOfIntent.sol | (Same as above) | None | Vote. Low threshold and quorum. |
| Repository Admins | Approve funding of project | SafeAllowance_Transfer.sol | (Same as above) | Call to safe allowance module: transfer | Vote, project should have been submitted. |

#### 

#### Update uri

Allows the Repository Admins to update the DAO's metadata URI, ensuring that the organization's public profile (links, description) remains current.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Repository Admins | Update URI | BespokeAction_OnOwnPowers.sol | "string new URI" | setUri call | Vote, high threshold and quorum. |

#### 

#### Transfer tokens to treasury

A recovery mechanism ensuring that any assets accidentally sent to the Sub-DAO's address (instead of the Treasury) can be recovered and moved to the central Safe Treasury.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Repository Admins | Transfer tokens to treasury | Safe\_RecoverTokens.sol | None | Goes through whitelisted tokens, and if DAO has any, transfers them to the treasury | None, any Repository Admin can call this mandate and pay for the transfer. |

### 

### ***Electoral Mandates***

#### Assign membership

Membership in the Digital Sub-DAO is meritocratic, based on verified code contributions. Contributors can claim their role by proving ownership of their GitHub commits.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Public | Apply for member role | Github\_ClaimRoleWithSig.sol | Branch, paths, roleIds, signature | None | None \- anyone can call. |
| Public | Claim Member role | Github\_AssignRoleWithSig.sol | None | Assigns role. | Previous mandate needs to have passed. |

#### Revoke Membership

Repository Admins can revoke membership, subject to Member veto.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Veto Revoke Membership | StatementOfIntent.sol | "address MemberAddress" | None | Vote. |
| Repository Admins | Revoke Membership | BespokeAction_OnOwnPowers_Advanced.sol | (same as above) | Revokes role | Vote. Timelock. No veto. |

#### Elect Repository Admins

A democratic process where Members elect leadership (Repository Admins) to manage the Sub-DAO's operations. Repository Admins are automatically assigned admin rights to the Cultural Stewards DAO repo. If an account loses the Repository Admin role, their admin rights will be automatically revoked. 

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Member | Create election | BespokeActionSimple.sol | "string Title, uint48 StartBlock, uint48 EndBlock" | Creates election helper | Throttled. |
| Member | Nominate | BespokeActionSimple.sol | (bool, nominateMe) | Nomination logged at Nominees.sol helper contract | None, any member can nominate |
| Member | Revoke Nomination | BespokeActionSimple.sol | (bool, nominateMe) | Nomination revoked at Nominees.sol helper contract | None, any member can revoke nomination |
| Members | Call election | OpenElectionStart.sol | None | Creates an election vote list | Throttled: every N blocks, for the rest none: any member can call the mandate. |
| Member | Vote in Election | OpenElectionVote.sol | (bool\[\]. vote\] | Logs a vote | None, any member can vote. This mandate ONLY appear by calling call election. |
| Members | Tally election | OpenElectionEnd.sol | None | Counts vote, revokes and assigns role accordingly | OpenElectionStart needs to have been executed. Any Member can call this. |
| Members | Clean up election | BespokeActionOnReturnValue.sol | None | Cleans up election mandates | Tally needs to have been executed. |

### 

#### Vote of No Confidence

A fail-safe mechanism allowing Members to revoke the power of all current Repository Admins if they fail to perform their duties, immediately triggering a new election.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Member | Vote of No Confidence | RevokeAccountsRoleId.sol | "string Title, uint48 StartBlock, uint48 EndBlock" | Revokes all Executive roles | High threshold, high quorum. |
| Member | Create election | BespokeActionSimple.sol | (same as above) | Creates election helper | Previous mandate executed. |
| Member | Nominate | BespokeActionSimple.sol | (bool, nominateMe) | Nomination logged at Nominees.sol helper contract | None, any member can nominate |
| Member | Revoke Nomination | BespokeActionSimple.sol | (bool, nominateMe) | Nomination revoked at Nominees.sol helper contract | None, any member can revoke nomination |
| Members | Call election | OpenElectionStart.sol | None | Creates an election vote list | Throttled: every N blocks, for the rest none: any executive can call the mandate. |
| Member | Vote in Election | OpenElectionVote.sol | (bool\[\]. vote\] | Logs a vote | None, any member can vote. This mandate ONLY appear by calling call election. |
| Members | Tally election | OpenElectionEnd.sol | None | Counts vote, revokes and assigns role accordingly | OpenElectionStart needs to have been executed. Any Member can call this. |
| Members | Clean up election | BespokeActionOnReturnValue.sol | None | Cleans up election mandates | Tally needs to have been executed. |

### 

### ***Reform Mandates***

#### Adopt mandate

Members can initiate mandate adoption, Primary DAO can veto, and Repository Admins execute.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Initiate Adopting Mandates | StatementOfIntent.sol | "address[] mandates, uint256[] roleIds" | None | Vote, high threshold \+ quorum |
| Primary DAO | Veto Adopting Mandates | StatementOfIntent.sol | (same as above) | None | Proposal must exist. |
| Repository Admins | Adopt new Mandates | Mandates_Adopt.sol | (same as above) | mandate is adopted. | Vote, high threshold  \+ quorum. No veto |

## 

## Ideas Sub-DAO

### ***Mission***

Manages concepts, ideas and discussions around ecosystem initiatives. Because role designations define access to the Ideas sub-DAO forum, granting and revoking roles defines who is given a voice in the sub-DAO. It also defines who has the power to initiate the creation of a physical sub-DAO.   

### ***Assets*** 

Intangible assets in relation to cultural initiatives: 

* Ideas, knowledge.   
* Social networks, interaction.   
* Engagement, memes. 

### ***Actions*** 

The Ideas sub-DAO can take the following actions:

* Initiate the creation of Physical Sub-DAOs.
* Update its own URI.
* Transfer tokens accidentally sent to its address to the Safe Treasury.  
* Moderators can assess and assign membership to applicants.  
* Moderators can revoke membership.
* Members can apply for membership of the Primary DAO.
* Conveners can assign and revoke Moderator roles.
* Elect Conveners from among DAO members.  
* Adopt new mandates (and as a consequence also revoke old ones). There is no veto possible from the Primary DAO. 

### ***Roles***

| Role Id | Role name | Selection criteria |
| :---- | :---- | :---- |
| 0 | Admin | Revoked at setup |
| 1 | Members | Assigned by Moderators after application. |
| 2 | Conveners | Elected every N-months from among Members. |
| 3 | Moderators  | Assigned by Conveners. |
| 6 | Primary DAO | Assigned at setup. |
| … | Public | Everyone. |

### 

### ***Executive Mandates***

#### Request new Physical Sub-DAO

Gives the Ideas Sub-DAO the power to incubate new physical 'pop-up' initiatives. Members can initiate the request, Moderators can veto it, and Conveners can request the creation at the Primary DAO.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Initiate request for new Physical sub-DAO | StatementOfIntent.sol | "address Admin" | None | Vote, simple majority. |
| Moderators | Veto request for new Physical sub-DAO | StatementOfIntent.sol | (same as above) | None | Vote. |
| Conveners | Request new Physical sub-DAO | PowersAction_Simple.sol | (same as above) | Requests mandate at Parent DAO | Vote, simple majority. Proposal must exist, no veto. |

#### 

#### Update uri

Allows Conveners to update the DAO's metadata URI.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Conveners | Update URI | BespokeAction.sol | "string new URI" | setUri call | Vote, high threshold and quorum. |

#### 

#### Transfer tokens to treasury

Recovers assets sent to the DAO address to the central Treasury.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Conveners | Transfer tokens to treasury | Safe\_RecoverTokens.sol | None | Goes through whitelisted tokens, and if DAO has any, transfers them to the treasury | None, any convener can call this mandate and pay for the transfer. |

### 

### ***Electoral Mandates***

#### Assign membership

Membership is assigned by Moderators following an application by a public participant.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Public | Apply for Membership | StatementOfIntent.sol | "address ApplicantAddress, string ApplicationURI" | None | Throttled. |
| Moderators | Assess and Assign Membership | BespokeAction_OnOwnPowers_Advanced.sol | (same as above) | Assigns role | Proposal must exist. |

#### Revoke membership

Moderators can revoke membership following bad behaviour, subject to a Member veto.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Veto Revoke Membership | StatementOfIntent.sol | "address MemberAddress" | None | Vote. |
| Moderators | Revoke Membership | BespokeAction_OnOwnPowers_Advanced.sol | (same as above) | Revokes role | Vote. Timelock. No veto. |

#### Request Membership of Primary DAO

Members can apply for membership of the Primary DAO, which Moderators can then forward to the Primary DAO.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Apply for Membership of Primary DAO | StatementOfIntent.sol | "uint256[] TokenIds" | None | None. |
| Moderators | Request Membership of Primary DAO | PowersAction_Simple.sol | (same as above) | Calls Primary DAO | Vote. Proposal must exist. |

#### Assign and Revoke Moderators

Conveners can assign and revoke Moderator roles, subject to Member veto.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Veto Assign Moderator Role | StatementOfIntent.sol | "address Account" | None | Vote. |
| Conveners | Assign Moderator Role | BespokeAction_OnOwnPowers_Advanced.sol | (same as above) | Assigns role | Vote. No veto. |
| Members | Veto Revoke Moderator Role | StatementOfIntent.sol | (same as above) | None | Vote. |
| Conveners | Revoke Moderator Role | BespokeAction_OnOwnPowers_Advanced.sol | (same as above) | Revokes role | Vote. No veto. |

#### Elect Conveners

Election flow similar to electing Repository Admins at the Digital sub-DAO for electing Conveners.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Member | Create election | BespokeActionSimple.sol | "string Title, uint48 StartBlock, uint48 EndBlock" | Creates election helper | Throttled. |
| Member | Nominate | BespokeActionSimple.sol | (bool, nominateMe) | Nomination logged at Nominees.sol helper contract | None, any member can nominate |
| Member | Revoke Nomination | BespokeActionSimple.sol | (bool, nominateMe) | Nomination revoked at Nominees.sol helper contract | None, any member can revoke nomination |
| Members | Call election | OpenElectionStart.sol | None | Creates an election vote list | Throttled: every N blocks, for the rest none: any member can call the mandate. |
| Member | Vote in Election | OpenElectionVote.sol | (bool\[\]. vote\] | Logs a vote | None, any member can vote. This mandate ONLY appear by calling call election. |
| Members | Tally election | OpenElectionEnd.sol | None | Counts vote, revokes and assigns role accordingly | OpenElectionStart needs to have been executed. Any member can call this. |
| Members | Clean up election | ElectionList\_CleanUpVoteMandate.sol | None | Cleans up election mandates | Tally needs to have been executed. |

### 

#### Vote of No Confidence

A fail-safe mechanism allowing Members to revoke the power of all current Conveners if they fail to perform their duties, immediately triggering a new election. Same as at the Digital sub-DAO. 

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Member | Vote of No Confidence | RevokeAccountsRoleId.sol | "string Title, uint48 StartBlock, uint48 EndBlock" | Revokes all Executive roles | High threshold, high quorum. |
| Member | Create election | BespokeActionSimple.sol | (same as above) | Creates election helper | Previous mandate executed. |
| Member | Nominate | BespokeActionSimple.sol | (bool, nominateMe) | Nomination logged at Nominees.sol helper contract | None, any member can nominate |
| Member | Revoke Nomination | BespokeActionSimple.sol | (bool, nominateMe) | Nomination revoked at Nominees.sol helper contract | None, any member can revoke nomination |
| Members | Call election | OpenElectionStart.sol | None | Creates an election vote list | Throttled: every N blocks, for the rest none: any executive can call the mandate. |
| Member | Vote in Election | OpenElectionVote.sol | (bool\[\]. vote\] | Logs a vote | None, any member can vote. This mandate ONLY appear by calling call election. |
| Members | Tally election | OpenElectionEnd.sol | None | Counts vote, revokes and assigns role accordingly | OpenElectionStart needs to have been executed. Any Member can call this. |
| Members | Clean up election | BespokeActionOnReturnValue.sol | None | Cleans up election mandates | Tally needs to have been executed. |

### ***Reform mandates***

#### Adopt mandate

Note: no veto from outside parties. Ideas Sub-DAOs can create their own mandates and roles. Because they do not control any funds, they can be very freewheeling.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Veto Adoption | StatementOfIntent.sol | "address[] mandates, uint256[] roleIds" | None | Vote, high threshold \+ quorum |
| Conveners | Adopt Mandates | Mandates_Adopt.sol | (same as above) | mandate is adopted. | Vote, high threshold \+ quorum. |

## 

## Physical Sub-DAO

### ***Mission***

Manages physical pop-up events. This involves sale of physical artifacts (such as art works), managing access to physical spaces, compliance to local jurisdictions, etc. Physical sub-DAOs are initiated by Ideas sub-DAOs.

### ***Assets*** 

The Physical Sub-DAO manages any kind of Real World Asset in relation to the event:  

* (Rented, bought) Physical space.   
* Access to this space.   
* Any type of physical items to be used in conferences, meetings, exhibitions, etc.   
* Cars, bicycle, public transport cards, wheelchairs, on-ramps, or any other physical item needed for mobility and accessibility.
* **Merit Tokens:** A locally deployed Soulbound1155 token contract used for rewarding contributions.

### ***Actions*** 

The Physical sub-DAO can take the following actions:

* Conveners can sell NFT artwork. (Artists can do so as well independently from the Physical sub-DAO). 
* Conveners can submit and approve payment of receipts. This includes payments for work done by conveners. 
* Conveners can mint POAPs (via Primary DAO). In actual events this will be replaced with the use of QR codes + external protocol. 
* Attendees can vote to mint 'Merit' NFTs to other attendees.
[comment]: <> (Note the following three governance flows. What do you think of this as type of tokenomics?) 
* Attendees can vote on artists to elect them to a 'winner' role. (TBI)  
* Attendees can vote on a convener to elect them to a 'winner' role. (TBI)
* Following the end of the event, accounts that have been elected to a winner role, can claim Merit NFTs (TBI)  
[comment]: <> (Until here.) 
* Public can redeem 'Merit' NFTs for rewards.
* Legal Representatives can adopt/revoke executive mandates (pausing mechanism).
* Update its own URI.   
* Transfer tokens accidentally sent to its address to the Safe Treasury.  
* Select Conveners (Through a Peer Select mechanism, assigned by legal reps).
* Adopt new mandates (and as a consequence also revoke old ones) \- but only if no veto was cast from the Primary DAO. 

### ***Roles***

| Role Id | Role name | Selection criteria |
| :---- | :---- | :---- |
| 0 | Admin | Revoked at setup |
| 1 | Attendee | Proof of Activity \- POAP/Token check |
| 2 | Convener | Selected via Peer Selection. |
| 3 | Legal Representative | Assigned by Primary DAO. |
| 6 | Primary DAO | Assigned at setup. |
| … | Public | Everyone. |

###  

### ***Executive Mandates***

#### Sell NFT Artwork

Conveners can force sell NFT artworks, distributing payment according to splits set by the Governed721 contract.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Conveners | Sell NFT artwork | BespokeAction_Simple.sol | "address oldOwner, address newOwner, uint256 TokenId, bytes Data" | Transfers NFT | Vote. |

#### Payment of receipts

Meant for expenses that have already been made. Payment after completion.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Conveners | Submit & Approve payment of receipt | SafeAllowance_Transfer.sol | "address Token, uint256 Amount, address PayableTo" | Call to safe allowance module: transfer | Vote. |

#### Mint POAPS

Enables Conveners to issue Proof of Attendance (POAP) tokens via the Primary DAO.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Convener | Mint POAP | PowersAction_Simple.sol | "address To" | Calls Primary DAO to mint | Vote. |

#### Merit NFTs for Attendees

System for recognizing contributions. Conveners propose, Attendees vote to mint.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Conveners | Propose minting 'Merit' NFTs | StatementOfIntent.sol | "address Attendee" | None | Vote. |
| Attendees | Vote on 'Merit' NFT proposals | BespokeAction_Advanced.sol | (same as above) | Mints Merit Token | Vote. |

#### Redeem Rewards

Holders of Merit NFTs can redeem them for rewards.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Public | Redeem 'Merit' NFTs | GovernedToken_BurnToAccess.sol | "address PayableTo" | Burns token | None. |
| Public | Claim payment | SafeAllowance_PresetTransfer.sol | (same as above) | Transfers reward | Previous executed. |

#### Update uri

Allows the Conveners to update the DAO's metadata URI.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Conveners | Update URI | BespokeAction_OnOwnPowers.sol | "string new URI" | setUri call | Vote, high threshold and quorum. |

#### Transfer tokens to treasury

Recovers assets sent to the DAO address.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Conveners | Transfer tokens to treasury | Safe_RecoverTokens.sol | "address treasury, address allowanceModule" | Goes through whitelisted tokens, and if DAO has any, transfers them to the treasury | None, any convener can call this mandate. |

### 

### ***Electoral Mandates***

#### Claim membership (Attendee)

Grants governance rights to individuals who have attended physical events (hold tokens).

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Public | Request Membership | GovernedToken_GatedAccess.sol | None | Assigns role | The caller needs to own 1 token minted by the DAO in last 15 days. |

#### Select Conveners

Process for selecting conveners involving ZKP checks and peer selection.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Public | ZKP Check Age | ZKPassport_Check.sol | "bool Nominate" | Verifies age > 18 | Anyone can execute. |
| Public | Nominate for selection | Nominate.sol | (same as above) | Logs nomination | Previous executed. |
| Legal Rep | Revoke nomination | BespokeAction_Advanced.sol | "address Nominee" | Revokes nomination | Vote. |
| Legal Rep | Adopt Peer Select Mandate | Mandates_Adopt_Prepackaged.sol | None | Adopts Peer Select | Vote. |

#### Assign Legal Representatives

Primary DAO assigns Legal Representatives.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Primary DAO | Assign Legal Representatives | BespokeAction_OnOwnPowers_Advanced.sol | "address Representative" | Assigns Role | Vote. |

### 

### ***Reform Mandates***

#### Adopt mandate

Attendees can initiate, Primary DAO can veto, Conveners adopt.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Attendees | Initiate Adopting Mandates | StatementOfIntent.sol | "address[] mandates, uint256[] roleIds" | None | Vote, high threshold \+ quorum |
| Primary DAO | Veto Adopting Mandates | StatementOfIntent.sol | (same as above) | None | Proposal must exist. |
| Conveners | Adopt new Mandates | Mandates_Adopt.sol | (same as above) | mandate is adopted. | Vote, high threshold  \+ quorum. No veto |

#### Legal Reps Adopt & Revoke

Legal Representatives have the power to adopt or revoke the set of executive mandates, effectively acting as a pause/unpause mechanism for the DAO's operations.

| Role | Name | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Legal Rep | Adopt Executive Mandates | Mandates_Adopt_Prepackaged.sol | None | Adopts mandates | Vote. |
| Legal Rep | Revoke Executive Mandates | Mandates_Revoke_Prepackaged.sol | None | Revokes mandates | Vote. |


## 

## Off-chain Operations

### ***Dispute Resolution***

Disputes regarding ambiguous mandate conditions or malicious actions by role-holders will be addressed through community discussion in the official communication channels. Final arbitration lies with the **Admin role** of the Parent Organisation if consensus cannot be reached.

### ***Code of Conduct***

All participants are expected to act in good faith to further the mission of the Cultural Stewardship DAO. The ecosystem relies on the harmonic interaction between the physical, ideational, and digital layers; disruption in one layer may affect the others.

### ***Communication Channels***

Official proposals, discussions, and announcements take place on the DAO's Discord server and community forum. Note: Sub-DAOs may maintain their own specific channels for "Physical" (Space logistics), "Ideational" (Brainstorming), and "Digital" (Code reviews).

## Description of Governance

The Cultural Stewardship DAO implements a federated governance model.

* **Remit**: To manage a shared treasury (Parent) while empowering specialised Sub-DAOs to operate with autonomy in their respective domains (Physical, Ideational, Digital).  
* **Separation of Powers**:  
  * **Financial Control**: Centralised at the Parent level to ensure security.  
  * **Operational Control**: Decentralised to Sub-DAOs to ensure agility.  
  * **Checks and Balances**: Most Sub-DAO actions (like mandates or physical access) are executable by local Conveners but subject to Veto by the Parent Executives.  
* **Executive Paths**:  
  * **Funding**: Sub-DAOs do not hold funds. They act as "cost centres" that request payment execution from the Parent.  
  * **Legislation**: Sub-DAOs can create their own internal mandates and roles, provided they are not vetoed by the Parent DAO.  
* **Summary**: This structure allows for a "Physical manifestation DAO" to worry about rent and keys, while a "Digital manifestation DAO" worries about commits and code, all bound by a common economic and constitutional framework.

## Risk Assessment

### ***Dependency Chains***

The "Digital Sub-DAO" (\#3) relies on the recognition of sub-DAOs (\#1 & \#2) to execute payments. If recognition logic fails or desynchronises, operations may stall.

