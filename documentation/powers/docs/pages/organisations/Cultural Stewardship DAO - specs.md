# **The Cultural Stewardship DAO \- Specification**

| WARNING: Cultural Stewardship DAO is under development. The organisational specs and deployment addresses are subject to change. This document serves as an initial specification based on the ecosystem architecture. |
| :---- |

**Latest deployments:** 

| Primary DAO | [https://powers-protocol.vercel.app/protocol/11155420/0x1b2a79Dfe1C06Bc8D270914942A490dC56dF0E60](https://powers-protocol.vercel.app/protocol/11155420/0x1b2a79Dfe1C06Bc8D270914942A490dC56dF0E60) |
| :---- | :---- |
| Digital Sub-DAO | [https://powers-protocol.vercel.app/protocol/11155420/0x3C1D05E9ACa0Ff198Dc9C0DD8Dcf5Ce3Ec9E4b83](https://powers-protocol.vercel.app/protocol/11155420/0x3C1D05E9ACa0Ff198Dc9C0DD8Dcf5Ce3Ec9E4b83)  |

## **Organisational Structure & Context**

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

The UX/UI includes interactive elements taken from **game theory**, such as earning internal currency, progressing by going to checkpoints (digital and physical), working in teams, exploring other user-created portals built on its open-source infrastructure. Other elements are taken from **social media**; making it a platform to have your own customisable profile, discuss in forums and threads, vote on polls, and visually view alignment metrics such as ‘upvotes’ ‘likes’ ‘reposts’ \-- even having a ‘timeline’ to scroll through to get a birds eye view of events happening within the ecosystem. This is all to foster active sparticipation; Participants who are active by minting participation tokens as they interact within the ecosystem, and those who vote on mandates are the ones who become the cultural stewards.

**Through the digital component, which is remotely accessible, the physical components are manifested.** The ecosystem has the functionality for physical spaces to spawn from ideas. This functionality is central to the DAO, and acts as a very important tangible concept space; it has blank walls that can be morphed to fit the current circumstances, where Participants can walk into and interact with the digital layers via the physical components in the space (such as a QR code where you scan and are airdropped a POAP token from the ecosystem,which may grant special access or permissions to participate further in the project). It is symbolic of the work that is being done in the digital cultural realm which has real-world impact. It’s an optional **IRL ‘checkpoint’** that works in tandem with the digital checkpoints.

***The Architecture of Primary & Sub-DAOs:***  
The organisation operates through a **Primary DAO** and three distinct types of **Sub-DAOs**:

1. **Primary DAO**: The central governance body holding the Treasury (Safe), where the DAO’s assets\* are stored on-chain. It can create new ‘ideational’ DAOs and confirms the creation of ‘physical’ DAOs. It has the power to deactivate both types of Sub-DAOs. It also (re)assigns allowances to its ‘digital’ DAO and its ‘physical' DAOs. It does not manage any of the organization’s activities directly.  
2. **Sub-DAO type \#1 (Digital)**: Manages code repositories, commits, and digital representation and interfaces of the organisation and its Sub-DAOs. From here on referred to as ‘**Digital Sub-DAO**’. The parent DAO holds some veto powers over this DAO.  
3. **Sub-DAO type \#2 (Ideational)**: Manages concepts, ideas and discussions around ecosystem initiatives. It has the power to creates its own working groups and initiate the creation (in collaboration with other Ideas DAOs) of Physical Sub-DAOs. This type of Sub-DAO is from here on referred to as ‘**Ideas Sub-DAO**’. It does not have an allowance at the Primary DAO. In return, the Parent DAO holds very little veto power over these types of Sub-DAOs.  
4. **Sub-DAO type \#3 (Physical)**: Manages physical manifestations (e.g., access to spaces, rent, legal logs). Physical sub-DAOs are initiated by Ideas sub-DAOs but not linked to a specific one. From here on referred these sub-DAOs are referred to as ‘**Physical Sub-DAO**’. It has an allowance at the parent DAO.

### ***Treasury Management:***

* **Centralised Treasury**: The Primary DAO’s Safe acts as the central treasury for the whole organisation. Physical Sub-DAOs and the Digital Sub-DAO are assigned allowances at time of creation that they can spend from the central treasury at the moment of their creation.  
* **Fund Flow**: Physical Sub-DAOs and the Digital Sub-DAO can request additional allowances on the Primary DAO’s Safe. The Parent Organisation processes these requests through a governance flow involving Executive execution and Member vetoes.

Multiple instances of Ideas Sub-DAOs and Physical Sub-DAOs can exist at the same time. They can be spawned and closed. In contrast, only a single instance of a Digital Sub-DAO can exist at any one time. It cannot be spawned or closed.

### ***Deployed Mandates:*** 

Below are the details for the deployed mandates for each DAO. The section summarises the mission of the DAO, the assets it controls and the actions it can take. Subsequently, it outlines the roles the mandates have, and gives outline the executive, electoral, and reform mandates. Executive mandates execute a specific action. Electoral mandates assign accounts to roles. Reform mandates manage the adoption and/or revoking of mandates.

## Primary DAO

### ***Mission***

The central governance body holding the Treasury (Safe), where the DAO’s assets\* are stored on-chain.  

### ***Assets*** 

The Primary DAO controls the following assets: 

* It is the owner of the treasury (a Safe smart wallet with an allowance module).  
* It is the owner of the ERC-1155 token contract that registers participants activity.  
* It is the owner of two PowersFactory’s: One that creates new Ideas sub-DAOs, and one that creates new Physical sub-DAOs. 

### ***Actions*** 

The Primary DAO can take the following actions

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
| 1 | Members | Membership in Sub-DAO \#1, \#2, or \#3). |
| 2 | Executives | Elected every N-months from among Members. |
| 3 | Physical Sub-DAO | Assigned at creation of a Sub-DAO. Can be removed by ideational DAO \+ executives. |
| 4 | Ideas Sub-DAO | Assigned at creation of a Sub-DAO. Can be removed by executives. |
| 5 | Digital Sub-DAO | Assigned at creation of a DAO. Only 1 Digital Sub-DAO at all times. |
| … | Public | Everyone. |

### 

### ***Executive Mandates***

#### Create and revoke Ideas Sub-DAO

Members have the right to initiate new Ideas Sub-DAOs, while each idea has to be ok-ed by elected executives.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Initiate Ideas Sub-DAO creation | StatementOfIntent.sol | "string name, string uri" | none | Initiates creation proposal. Vote, normal threshold. |
| Executives | Execute Ideas Sub-DAO creation | BespokeActionSimple.sol | (same as above) | Creates Ideas Sub-DAO | Vote \+ proposal exists (No allowance assigned) |
| Executives | Assign role Id to Ideas Sub-DAO | BespokeActionOnReturnValue.sol | (same as above) | Assigns role to return value of previous mandate. | None. Any executive can execute. |
| Members | Veto revoking Ideas Sub-DAO | StatementOfIntent.sol | (same as above) | none | Vote, high threshold. |
| Executives | Revoke Ideas Sub-DAO (Role) | BespokeActionOnReturnValue.sol | (same as above) | Revokes roleId from DAO. | DAO creation should have executed, members should not have vetoed. |

#### 

#### Create and revoke Physical Sub-DAO

Ideas-DAOs can initiate the creation of a Physical-DAO. The Primary DAO will be assigned as admin of the new Physical DAO and hold veto power of adopting of new mandates. 

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Ideas Sub-DAO | Initiate Physical Sub-DAO Creation | StatementOfIntent.sol | "string name, string uri" | none | Any Ideas Sub-DAO can propose. |
| Executives | Execute Physical Sub-DAO Creation | BespokeActionSimple.sol | (same as above) | Creates Physical Sub-DAO | Proposal exists, veto does not exist |
| Executives | Assign role Id to Physical Sub-DAO | BespokeActionOnReturnValue.sol | (same as above) | Assigns role to return value of previous mandate. | Any executive can execute. Previous action executed. |
| Executives | Assign Delegate status | SafeExecTransactionOnReturnValue.sol | (same as above) | Assigns delegate status at Safe treasury. | Any executive can execute. Previous action executed. |
| Members | Veto revoking Physical Sub-DAO | StatementOfIntent.sol | (same as above) | none | Vote, high threshold. |
| Executives | Revoke Physical Sub-DAO (Role) | BespokeActionOnReturnValue.sol | (same as above) | Revokes roleId. | DAO creation should have executed, members should not have vetoed. |
| Executives | Revoke Delegate status | SafeExecTransaction.sol | (same as above) | Revokes delegate status. | Any executive can execute. Previous action executed. |

#### 

#### Assign additional allowances to Physical Sub-DAO or Digital Sub-DAO

Physical and Digital sub-DAOs can request allowances for their address in the Safe treasury. Without an allowance set, they will not be able to transfer any assets from the treasury. 

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Physical Sub-DAO | Veto additional allowance | StatementOfIntent.sol | "address Sub-DAO, address Token, uint96 allowanceAmount, uint16 resetTimeMin, uint32 resetBaseMin" | none | Vote, high threshold. |
| Physical Sub-DAO | Request additional allowance | StatementOfIntent.sol | (same as above) | none | Initiates allowance proposal.  Note: NOT a vote: any Physical Sub-DAO can submit. |
| Executives | Grant Allowance to Physical Sub-DAO | SafeAllowance\_Action.sol | (same as above) | Safe.approve(subDao, amount) | Proposal exists, vote, no Physical Sub-DAO veto. |
| Digital Sub-DAO | Request additional allowance | StatementOfIntent.sol | (same as above) | none | Initiates allowance proposal. |
| Executives | Grant Allowance to Digital Sub-DAO | SafeAllowance\_Action.sol | (same as above) | Safe.approve(subDao, amount) | Proposal exists, vote, no Physical Sub-DAO veto. |

#### 

#### Update uri

The URI contains all the metadata of the organisation, including designations of sub- and primary-DAOs needed in the front end. In other words, to show new sub-DAOs in the frontend, the URI needs to be updated separately.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Executives | Veto Call to sub-Dao | PowersAction\_Flexible.sol | "uint16[] MandateId, uint256[] roleIds" | Calls to sub-DAOs | Executioners can veto calls to Powers instances in other sub-DAOs. |
| Members | Veto update URI | StatementOfIntent.sol | "string new URI" | none | Vote. |
| Executives | Update URI | BespokeAction.sol | (same as above) | setUri call | Ideas Sub-DAOs did not veto, timelock. |

#### 

#### Mint NFTs Ideas Sub-DAO \- ERC 1155

The token Id that is minted, is the uin256 representation of the caller. This means that every DAO mints a unique token Id.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Ideas Sub-DAO | Mint token | BespokeActionSimple.sol | ‘address to’ | Mint function ERC 1155 | None. |

#### 

#### Mint NFTs Physical Sub-DAO \- ERC 1155

The token Id that is minted, is the uin256 representation of the caller. This means that every DAO mints a unique token Id.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Physical Sub-DAO | Mint token | BespokeActionSimple.sol | ‘address to’ | Mint function ERC 1155 | None. |

#### 

#### Transfer tokens to treasury

It is very likely that someone will, by accident, transfer tokens to the address of the DAO instead of its treasury. This is a major issue, because the DAO has no way of transferring this tokens out. As a backup, there is a mandate that lets DAOs transfer tokens (of which they have an allowance) back to the treasury. 

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Executive | Transfer tokens to treasury | Safe\_RecoverTokens.sol | None | Goes through tokens of which the DAO has an allowance, and if the DAO has any, transfers them to the treasury | None, absolutely anyone can call this mandate and pay for the check & transfer. |

### 

### ***Electoral Mandates***

#### Claim membership Primary DAO

This is a two step process to gain membership to the Primary DAO. An account provides a list of at least 22 token IDs. First there is a check if the list includes 2 POAPS that are owned by the account. Second, there is a check if the account owns 20 activity tokens from Ideas DAOs. These tokens cannot be older than 6 months. If the checks pass, the account is assigned a membership role.     

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Public | Request Membership Step 1 | Soulbound1155\_GatedAccess.sol | ‘address Account’ | Checks ownership of 2 POAPS | None. Any public address can request. |
| Public | Request Membership Step 2 | Soulbound1155\_GatedAccess.sol | ‘address Account’ | Checks ownership of 20 Activity tokens and Assigns Role | Previous step must be executed. Any public address can request. |

#### 

#### Elect Executives

This is an electoral flow for assigning executives. First an election is created, it includes a start and end block of the election. Before the election starts, members can nominate themselves. After the start block passes, the electoral vote can be called: it creates a bespoke mandate that contains a list of candidates on which accounts can vote. After the end block passes a tally is taken, old executive roles revoked and new ones assigned. Through a final mandate the electoral vote mandate can be cleaned up.   

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Member | Create election | BespokeActionSimple.sol | "string Title, uint48 StartBlock, uint48 EndBlock" | Creates election helper | Throttled. |
| Member | Nominate | BespokeActionSimple.sol | (bool, nominateMe) | Nomination logged at Nominees.sol helper contract | None, any member can nominate |
| Member | Revoke Nomination | BespokeActionSimple.sol | (bool, nominateMe) | Nomination revoked at Nominees.sol helper contract | None, any member can revoke nomination |
| Members | Call election | OpenElectionStart.sol | None | Creates an election vote list | Throttled: every N blocks, for the rest none: any executive can call the mandate. |
| Member | Vote in Election | OpenElectionVote.sol | (bool\[\]. vote\] | Logs a vote | None, any member can vote. This mandate ONLY appear by calling call election. |
| Members | Tally election | OpenElectionEnd.sol | None | Counts vote, revokes and assigns role accordingly | OpenElectionStart needs to have been executed. Any Member can call this. |
| Members | Clean up election | BespokeActionOnReturnValue.sol | None | Cleans up election mandates | Tally needs to have been executed. |

### 

#### Vote Of No Confidence 

If for any reason (inactivity, abuse of power) members loose confidence in executives, they can remove all executives and call new elections. Subject to a high threshold, but not throttled: it can be called at any time.  

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
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

This process allows the Primary DAO to upgrade its governance by adopting new mandates. It initiates a proposal that must pass a member veto and receive approval from Sub-DAOs before being executed by Executives.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Executives | Initiate mandate adoption | StatementOfIntent.sol | \`address\[\] mandates, uint256\[\] roleids\` | None | None. Any Executive can initiate call for mandate reform. |
| Members | Veto Adoption | StatementOfIntent.sol | (same as above) | None | Vote, high threshold \+ quorum |
| Physical Sub-DAO | Ok adoption | StatementOfIntent.sol | (same as above) | None | Vote, low threshold \+ quorum. Veto should not have passed. |
| Ideas Sub-DAO | Ok adoption | StatementOfIntent.sol | (same as above) | None | Vote, low threshold \+ quorum. |
| Digital Sub-DAO | Ok adoption | StatementOfIntent.sol | (same as above) | None | Vote, low threshold \+ quorum. |
| Executives | Execute mandate Adoption | AdoptMandates.sol | (same as above) | mandate is adopted. | Vote, high threshold \+ quorum. |

## 

## Digital Sub-DAO

### ***Mission***

Manages code repositories, commits, and digital representation of the organisation and its Sub-DAOs.

### ***Assets*** 

The Digital Sub-DAO owns the github repository that includes: 

* The code base for online UI interfaces for all (Sub-)DAOs that make up the organisation.   
* The code base for physical UI digital experiences used by physical Sub-DAOs. 

### ***Actions*** 

The Digital sub-DAO can take the following actions

* The public can submit receipts with the request for payment for digital work completed.  
* Members can propose funding for projects to be implemented.  
* It can request an allowance from the Primary DAO.    
  * Note: Payments are transferred from the central Safe treasury and have to be within the allowance set by the Primary DAO.  
* It can update its own URI.   
* It can transfer tokens accidentally sent to its address to the Safe Treasury.  
* It can assign a membership role to public accounts if they made successful commits to the repository.    
* It can elect Executives from among DAO members  
* It can adopt new mandates (and as a consequence also revoke old ones) \- but only if no veto was cast from the Primary DAO. 

### ***Roles***

| Role Id | Role name | Selection criteria |
| :---- | :---- | :---- |
| 0 | Admin | Revoked at setup |
| 1 | Members | Proof of Activity \- role by git commit |
| 2 | Conveners | Elected every N-months from among Members. |
| 3 | Parent DAO | Assigned at creation. Can only be single address. |
| … | Etc | Additional roles can be created by sub-DAO. |
| … | Public | Everyone. |

### 

### ***Executive Mandates***

#### Payment of receipts

Meant for expenses that have already been made. Payment after completion.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Veto request allowance | StatementOfIntent.sol | "address Sub-DAO, address Token, uint96 allowanceAmount, uint16 resetTimeMin, uint32 resetBaseMin" | none | Vote, high threshold. |
| Conveners | Request allowance | PowersAction\_Simple.sol | (same as above) | Calls Primary DAO | Vote, high threshold. |
| Public | Submit receipt | StatementOfIntent.sol | \`address Token, uint256 Amount, address PayableTo\` | None | None. Anyone (also non-members) can submit a receipt. |
| Conveners | Ok-receipt | StatementOfIntent.sol | (Same as above) | None | None. Any convener can ok a receipt. |
| Conveners | Execute payment | SafeAllowance\_Transfer.sol | (Same as above) | Call to safe allowance module: transfer | Vote, ok-receipt executed, no veto should have been cast. |

#### 

#### Payment of projects

Meant for expenses that will be made in future. Payment before completion.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Member | Submit project | StatementOfIntent.sol | (Same as above) | None | Vote. Low threshold and quorum, |
| Conveners | Execute payment | SafeAllowance\_Transfer.sol | (Same as above) | Call to safe allowance module: transfer | Vote, project should have been submitted. |

#### 

#### Update uri

Allows the Conveners to update the DAO's metadata URI, ensuring that the organization's public profile (links, description) remains current.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Conveners | Update URI | BespokeAction.sol | "string new URI" | setUri call | Vote, high threshold and quorum. |

#### 

#### Transfer tokens to treasury

A recovery mechanism ensuring that any assets accidentally sent to the Sub-DAO's address (instead of the Treasury) can be recovered and moved to the central Safe Treasury.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Executive | Transfer tokens to treasury | Safe\_RecoverTokens.sol | None | Goes through whitelisted tokens, and if DAO has any, transfers them to the treasury | None, absolutely anyone can call this mandate and pay for the transfer. |

### 

### ***Electoral Mandates***

#### Assign membership

Membership in the Digital Sub-DAO is meritocratic, based on verified code contributions. Contributors can claim their role by proving ownership of their GitHub commits.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Public | Apply for member role | Github\_ClaimRoleWithSig.sol | Branch, paths, roleIds, signature | None | None \- anyone can call. |
| Public | Claim Member role | Github\_AssignRoleWithSig.sol | None | Assigns role. | Previous mandate needs to have passed. |

#### 

#### Elect Conveners

A democratic process where Members elect leadership (Conveners) to manage the Sub-DAO's operations.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
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

A fail-safe mechanism allowing Members to revoke the power of all current Conveners if they fail to perform their duties, immediately triggering a new election.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Member | Vote of No Confidence | RevokeAccountsRoleId.sol | "string Title, uint48 StartBlock, uint48 EndBlock" | Revokes all Executive roles | High threshold, high quorum. |
| Member | Create election | BespokeActionSimple.sol | (same as above) | Creates election helper | Previous mandate executed. |
| Member | Nominate | BespokeActionSimple.sol | (bool, nominateMe) | Nomination logged at Nominees.sol helper contract | None, any member can nominate |
| Member | Revoke Nomination | BespokeActionSimple.sol | (bool, nominateMe) | Nomination revoked at Nominees.sol helper contract | None, any member can revoke nomination |
| Members | Call election | OpenElectionStart.sol | None | Creates an election vote list | Throttled: every N blocks, for the rest none: any executive can call the mandate. |
| Member | Vote in Election | OpenElectionVote.sol | (bool\[\]. vote\] | Logs a vote | None, any member can vote. This mandate ONLY appear by calling call election. |
| Members | Tally election | OpenElectionEnd.sol | None | Counts vote, revokes and assigns role accordingly | OpenElectionStart needs to have been executed. Any Member can call this. |
| Members | Clean up election | BespokeActionOnReturnValue.sol | None | Cleans up election mandates | Tally needs to have been executed. |

### ***Reform Mandates***

#### Adopt mandate

Note 1: no veto from outside parties. Ideas Sub-DAOs can create their own mandates and roles. Because they do not control any funds, they can be very freewheeling.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Initiate Adoption | StatementOfIntent.sol | \`address mandateAddress\` | None | Vote, high threshold \+ quorum |
| Parent DAO | Veto Adoption | StatementOfIntent.sol | (same as above) | None | none |
| Executives | Execute mandate Adoption | BespokeActionSimple.sol | (same as above) | mandate is adopted. | Vote, high threshold  \+ quorum, timelock. No veto |

## 

## Ideas Sub-DAO

### ***Mission***

Manages concepts, ideas and discussions around ecosystem initiatives.

### ***Assets*** 

Intangible assets in relation to cultural initiatives: 

* Ideas, knowledge.   
* Social networks, interaction.   
* Engagement, memes. 

### ***Actions*** 

The Ideas sub-DAO can take the following actions

* Assign its own labels to roleIds.   
* Create its own working groups   
* Initiate the creation of Physical Sub-DAOs.   
* It can update its own URI.   
* It can transfer tokens accidentally sent to its address to the Safe Treasury.  
* It can elect conveners and working group participants from among its members.  
* It can adopt new mandates (and as a consequence also revoke old ones). There is no veto possible from the Primary DAO. 

### ***Roles***

| Role Id | Role name | Selection criteria |
| :---- | :---- | :---- |
| 0 | Admin | Revoked at setup |
| 1 | Members (NOT assigned at initialisation)  | Proof of Activity \- through proof of on-chain interaction |
| 2 | Conveners (NOT assigned at initialisation)  | Elected every N-months from among Members. |
| … | Etc | Additional roles can be created by sub-DAO. |
| … | Public | Everyone. |

### 

### ***Executive Mandates***

#### Setup and Mint activity token

Administrative mandates to configure role labels and the public interface for minting Activity Tokens, which track participation.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Role 1 (Members) | Veto setting role labels | StatementOfIntent.sol | "uint256 RoleId, string Label" | None | Vote. |
| Role 2 (Conveners) | Set role labels | BespokeAction_OnOwnPowers.sol | (same as above) | Sets role label | Vote. |
| Public | Mint activity NFT | BespokeActionSimple.sol | None | Mints Ideas Sub-DAO specific token Id  at Parent DAO, and sends to the caller. | Throttled. For the rest nothing |

#### 

#### Request new Physical Sub-DAO and Working Groups

Empowers the Ideas Sub-DAO to incubate new initiatives. Conveners can propose the creation of distinct Physical Sub-DAOs or internal Working Groups to focus on specific cultural projects.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Conveners | Request new Physical Sub-DAO | StatementOfIntent.sol | "string name, string uri" | Requests mandate at Parent DAO | None |
| Conveners | Create new Working group | Mandates_Prepackaged.sol | (same as above) | Installs Working Group Flow | Vote. Includes: Request new Physical Sub-DAO, Election for WG members. |

#### 

#### Update uri

Allows Conveners to update the DAO's metadata.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Conveners | Update URI | BespokeAction.sol | "string new URI" | setUri call | Vote, high threshold and quorum. |

#### 

#### Transfer tokens to treasury

Recovers assets sent to the DAO address to the central Treasury.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Executive | Transfer tokens to treasury | Safe\_RecoverTokens.sol | None | Goes through whitelisted tokens, and if DAO has any, transfers them to the treasury | None, absolutely anyone can call this mandate and pay for the transfer. |

### 

### 

### ***Electoral Mandates***

#### Assign membership

Membership is automatic for active participants who hold a specific number of Activity Tokens minted within a recent timeframe.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Public | Claim Member role | MemberRoleByOrgNFT.sol | None | Assigns role | The caller needs to own 5 (soulbound) NFTs, minted within the last 30 days and minted via the org. |

#### 

#### Elect Conveners

Standard election flow for choosing Sub-DAO leadership.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Member | Create election | BespokeActionSimple.sol | "string Title, uint48 StartBlock, uint48 EndBlock" | Creates election helper | Throttled. |
| Member | Nominate | BespokeActionSimple.sol | (bool, nominateMe) | Nomination logged at Nominees.sol helper contract | None, any member can nominate |
| Member | Revoke Nomination | BespokeActionSimple.sol | (bool, nominateMe) | Nomination revoked at Nominees.sol helper contract | None, any member can revoke nomination |
| Members | Call election | OpenElectionStart.sol | None | Creates an election vote list | Throttled: every N blocks, for the rest none: any member can call the mandate. |
| Member | Vote in Election | OpenElectionVote.sol | (bool\[\]. vote\] | Logs a vote | None, any member can vote. This mandate ONLY appear by calling call election. |
| Members | Tally election | OpenElectionEnd.sol | None | Counts vote, revokes and assigns role accordingly | OpenElectionStart needs to have been executed. Any member can call this. |
| Members | Clean up election | ElectionList\_CleanUpVoteMandate.sol | None | Cleans up election mandates | Tally needs to have been executed. |

### Vote of No Confidence

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
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

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Veto Adoption | StatementOfIntent.sol | (same as above) | None | Vote, high threshold \+ quorum |
| Executives | Execute mandate Adoption | BespokeActionSimple.sol | (same as above) | mandate is adopted. | Vote, high threshold  \+ quorum, timelock. |

## 

## Physical Sub-DAO

Manages physical manifestations (e.g., access to spaces, rent, legal logs). These Real World Assets are managed through a mock helper protocol that mimics the functionality of the T-REX (ERC-3643) standard and protocol. Physical sub-DAOs are initiated by Ideas sub-DAOs but not linked to a specific one. 

### ***Assets*** 

The Physical Sub-DAO can own any kind of Real World Asset:  

* (Rented, bought) Physical space.   
* Keys to this space.   
* Any type of physical items to be used in conferences, meetings, exhibitions, etc.   
* Cars, bicycle, public transport cards, wheelchairs, on-ramps, or any other physical item needed for mobility and accessibility. 

### ***Actions*** 

The Physical sub-DAO can take the following actions

* The public can submit receipts with the request for payment for digital work completed.  
* It can request an allowance from the Primary DAO.    
  * Note: Payments are transferred from the central Safe treasury and have to be within the allowance set by the Primary DAO.  
* It can tokenise assets: create a new token for any physical asset and mint these assets to the Safe treasury.    
* It can link a legal conditional regime to a tokenised asset.  
* It can transfer tokenised assets to a third party, and force transfer items back to the Safe treasury.     
* It can update its own URI.   
* It can transfer tokens accidentally sent to its address to the Safe Treasury.  
* It can elect Conveners from among DAO members  
* It can adopt new mandates (and as a consequence also revoke old ones) \- but only if no veto was cast from the Primary DAO. 

### ***Roles***

| Role Id | Role name | Selection criteria |
| :---- | :---- | :---- |
| 0 | Admin | Revoked at setup |
| 1 | Members | Proof of Activity \- POAP |
| 2 | Conveners | Elected every N-months from among Members. |
|  | HasAccess | A role to denote who has access to physical space. |
| 3 | Ideas Sub-DAO | The Ideas-DAO that spawned the Physical Sub-DAO. This can potentially be expanded to include multiple DAOs. |
| 4 | Parent DAO | Speaks for itself. |
| … | Etc | Additional roles can be created by sub-DAO. |
| … | Public | Everyone. |

### 

### ***Executive Mandates***

#### Setup Flow and Labels

Initial configuration mandates to establish payment workflows and customize role definitions.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Conveners | Setup Payment Flow | Mandates_Prepackaged.sol | (same as above) | Installs Payment mandates. | None. |
| Members | Veto setting role labels | StatementOfIntent.sol | "uint256 RoleId, string Label" | None | Vote. |
| Conveners | Set role labels | BespokeAction_OnOwnPowers.sol | (same as above) | Sets role label | Vote. |

#### Real World Asset (RWA) Management

A robust framework for managing Real World Assets (RWAs) on-chain. Includes creating asset tokens, setting compliance rules, and managing transfers, ensuring digital tokens correctly reflect physical ownership and legal status.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Veto creating new RWA item | StatementOfIntent.sol | "string Name" | None | Vote. |
| Conveners | Creating RWA token | BespokeActionSimple.sol | (same as above) | Creates RWA token | Vote. |
| Members | Veto setting compliance token | StatementOfIntent.sol | "uint256 tokenId, address from, address to, uint256 amount, uint256 currentToBalance, uint256 currentTotalSupply" | None | Vote. |
| Conveners | Setting compliance token | BespokeActionSimple.sol | (same as above) | Sets compliance rules | Vote. |
| Members | Veto minting RWA token to treasury | StatementOfIntent.sol | "address To, uint256 TokenId, uint256 Amount" | None | Vote. |
| Conveners | Minting RWA token to treasury | BespokeActionSimple.sol | (same as above) | Mints RWA token | Vote. |
| Members | Veto transfer RWA token to third party | StatementOfIntent.sol | "address From, address To, uint256 TokenId, uint256 Amount, bytes Data" | None | Vote. |
| Conveners | Transfer RWA token to third party | BespokeActionSimple.sol | (same as above) | Transfers RWA token | Vote. |
| Members | Veto forced transfer RWA token to treasury | StatementOfIntent.sol | "address From, address To, uint256 TokenId, uint256 Amount" | None | Vote. |
| Conveners | Forced transfer RWA token to treasury | BespokeActionSimple.sol | (same as above) | Force transfers RWA token | Vote. |

#### Mint POAPS

Enables Conveners to issue Proof of Attendance (POAP) tokens, serving as on-chain verification of a user's presence at physical events.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Convener | Mint POAP | BespokeActionSimple.sol | \`address Account\` | Mints Ideas Sub-DAO specific token Id  at Parent DAO, and sends to the account. | Any convener can mint POAPS. |

#### 

#### Update uri

Note that the URI includes all metadata of the organisation. In this case this will also include references to any legal (rental, etc) documents.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Conveners | Update URI | BespokeAction.sol | "string new URI" | setUri call | Vote, high threshold and quorum. |

#### 

#### Transfer tokens to treasury

Recovers assets sent to the DAO address.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Executive | Transfer tokens to treasury | Safe\_RecoverTokens.sol | None | Goes through whitelisted tokens, and if DAO has any, transfers them to the treasury | None, absolutely anyone can call this mandate and pay for the transfer. |

#### 

### ***Electoral Mandates***

#### Assign membership

Grants governance rights to individuals who have attended physical events, verified by their ownership of recent POAPs.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Public | Claim Member role | MemberRoleByOrgNFT.sol | None | Assigns role | The caller needs to own 1 (soulbound) POAP, minted within the last 15 days and minted via the org. |

#### 

#### Elect Conveners

Standard election flow for choosing Sub-DAO leadership.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Member | Create election | BespokeActionSimple.sol | "string Title, uint48 StartBlock, uint48 EndBlock" | Creates election helper | Throttled. |
| Member | Nominate | BespokeActionSimple.sol | (bool, nominateMe) | Nomination logged at Nominees.sol helper contract | None, any member can nominate |
| Member | Revoke Nomination | BespokeActionSimple.sol | (bool, nominateMe) | Nomination revoked at Nominees.sol helper contract | None, any member can revoke nomination |
| Members | Call election | OpenElectionStart.sol | None | Creates an election vote list | Throttled: every N blocks, for the rest none: any member can call the mandate. |
| Member | Vote in Election | OpenElectionVote.sol | (bool\[\]. vote\] | Logs a vote | None, any member can vote. This mandate ONLY appear by calling call election. |
| Members | Tally election | OpenElectionEnd.sol | None | Counts vote, revokes and assigns role accordingly | OpenElectionStart needs to have been executed. Any member can call this. |
| Members | Clean up election | ElectionList\_CleanUpVoteMandate.sol | None | Cleans up election mandates | Tally needs to have been executed. |

### Vote of No Confidence

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Member | Vote of No Confidence | RevokeAccountsRoleId.sol | "string Title, uint48 StartBlock, uint48 EndBlock" | Revokes all Executive roles | High threshold, high quorum. |
| Member | Create election | BespokeActionSimple.sol | (same as above) | Creates election helper | Previous mandate executed. |
| Member | Nominate | BespokeActionSimple.sol | (bool, nominateMe) | Nomination logged at Nominees.sol helper contract | None, any member can nominate |
| Member | Revoke Nomination | BespokeActionSimple.sol | (bool, nominateMe) | Nomination revoked at Nominees.sol helper contract | None, any member can revoke nomination |
| Members | Call election | OpenElectionStart.sol | None | Creates an election vote list | Throttled: every N blocks, for the rest none: any executive can call the mandate. |
| Member | Vote in Election | OpenElectionVote.sol | (bool\[\]. vote\] | Logs a vote | None, any member can vote. This mandate ONLY appear by calling call election. |
| Members | Tally election | OpenElectionEnd.sol | None | Counts vote, revokes and assigns role accordingly | OpenElectionStart needs to have been executed. Any Member can call this. |
| Members | Clean up election | BespokeActionOnReturnValue.sol | None | Cleans up election mandates | Tally needs to have been executed. |

### ***Reform Mandates***

#### Adopt mandate

Note: no veto from outside parties. Ideas Sub-DAOs can create their own mandates and roles. Because they do not control any funds, they can be very freewheeling.

| Role | Name & Description | Base contract | User Input | Executable Output | Conditions |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Members | Initiate Adoption | StatementOfIntent.sol | \`address mandateAddress\` | None | Vote, high threshold \+ quorum |
| Parent DAO | Veto Adoption | StatementOfIntent.sol | (same as above) | None | none |
| Executives | Execute mandate Adoption | BespokeActionSimple.sol | (same as above) | mandate is adopted. | Vote, high threshold  \+ quorum, timelock. No veto |

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

The "Digital Sub-DAO" (\#3) relies on the recognition of Sibling DAOs (\#1 & \#2) to execute payments. If recognition logic fails or desynchronises, operations may stall.
