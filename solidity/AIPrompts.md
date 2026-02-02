# AI Prompts 

## create role thumbnails. 
You are helping me to build a frontend UI for a role based protocol that governs on-chain (blockchain based) organisations. 

I need thumbnails for various roles. They need to be colorful, simple, usable at small scale and reflect the type of role they are assigned to. 

Can you give me a thumbnail for the following role: documentation contributor

Thank you very much! 

## Update constants.ts after deployment new mandates. 
[ the ref needs to be broadcast/DeployMandates/31337/run-latest.json]
Can you check the @run-latest.json for chains 31337, 421614, 11155111 and 11155420 and update the LAW_NAMES and LAW_ADDRESSES accordingly in @constants.ts ? You can the necessary data in "returns" in the file.  

[ the ref needs to be broadcast/InitialiseHelpers/31337/run-latest.json]
Can you check the @run-latest.json for chains 31337, 421614, 11155111 and 11155420 and update the MOCK_NAMES and MOCK_ADDRESSES accordingly in @constants.ts ? You can the necessary data in "returns" in the file.  

## Update Docs after deployment new mandates.  
[ the ref needs to be broadcast/DeployMandates/421614/run-latest.json]
Can you check the @run-latest.json for chains 421614, 11155111 and 11155420 please? 

In the run-latest.json files, there is a section "returns". For each mandate mentioned there, can you go to the gitbook documentation, search for the documentation on this mandate, and update the deployment table in the 'Current Deployments' section? Thank you! 

## Update refs in metadata json to mock contracts and treasuries.  
[ the ref needs to be broadcast/InitialiseHelpers/421614/run-latest.json]
Can you check the @run-latest.json for chain 421614 please? We will use this file to update all the .json files in @/orgMetadatas.

There is a section "returns" in run-latest.json. Use this data to do the following: 
- Please check take the addresses with the same index as Erc20VotesMock, Erc20TaxedMock and replace the addresses in the `erc20s` field with these addresses.   
- Please check take the address with the same index as Erc721Mock and replace the addresses in the `erc721s` field with this addresses. 
- Please check take the address with the same index as Erc1155Mock and replace the addresses in the `erc1155s` field with this addresses. 

Please note: do this for each and every .json file in @/orgMetadatas. Thank you! 

## Refactor test
Please refactor the existing tests in LimitExecutionsTest in Mandate.t.sol according to the changes made to Mandate.sol and Powers.sol Please keep in mind the following: 
- You can use the DeployTest contract in the same file as an example.
- Mandate contracts have already been initiated through TestSetup.t.sol and the function initiateMandateTestConstitution in ConstitutionsMock.sol. 
- Variables have already been initiated through the function setUpVariables() in TestSetup.t.sol

## Create Unit test 1
Please write a comprehensive unit test for HolderSelect.sol at contract HolderSelectTest in Electoral.t.sol. You can use DelegateSelect.sol as an example. Please keep in mind that all mandates and mocks have been through DeployAnvilMocks.s.sol and that the test setup can be found in TestSetup.s.sol. Thank you!  

(Do not forget to put in all the context files.... )
## Create Unit test 1
Using the other tests in @State.t.sol and @Executive.t.sol as examples, can you write a comprehensive unit test for @TaxSelect.sol ? Please take into account the test setup at @TestSetup.t.sol and the deployment of mandates in @ConstitutionsMock.sol . Thank you 


## Refactor Constitution. 
Can you refactor the constitution in the function 'createConstitution' in DeployBasicDao.s.sol. Please take into account the following: 
- Mandates have been deployed through DeployMandates.s.sol. 
- Similar functions can be found in the initiateMandateTestConstitution and initiatePowersConstitution functions of ConstitutionMock.sol. Please use these functions as example. 
- DO NOT create a new file, refactor the existing DeployBasicDao.s.sol file! please. 

## Refactor a mandate, after breaking changes to protocol. 
Can you create a mandate at HolderSelect.sol, using TaxSelect as example, that allows accounts to self select for a predefined goal, but will only assign this role if the account holds more than a specified amount of tokens. thank you

## Create mandate based on example + logic description. 
Can you create a mandate at HolderSelect.sol, using TaxSelect as example, that allows accounts to self select for a predefined goal, but will only assign this role if the account holds more than a specified amount of tokens. thank you

## Create deploy script for new Powers protocol. Using previous deploy scripts as an example. 
Using DeploySeparatedPowers.s.sol and DeployPowers101.s.sol as example, Please write a deploy script at DeployGovernedUpgrades.s.sol. It should have the following mandates: 
Executive mandates: 
 - A mandate to adopt a mandate. Access role = previous DAO 
 - A mandate to revoke a mandate. Access role = previous DAO 
 - A mandate to veto adopting a mandate. Access role = delegates
 - A mandate to veto revoking a mandate. Access role = delegates
 - A preset mandate to Exchange tokens at uniswap or sth similar chain. Access role = delegates
 - A preset mandate to to veto Exchange tokens at uniswap or sth similar chain veto. Access role = previous DAO.

 Electoral mandates: (possible roles: previous DAO, delegates)
 - a mandate to nominate oneself for a delegate role. Access role: public.
 - a mandate to assign a delegate role to a nominated account. Access role: delegate, using delegate election vote. Simple majority vote.
 - a preset self destruct mandate to assign role to previous DAO. Access role = admin. 

Please take into account that mandates are deployed using DeployMandates.s.sol. They do not need to be deployed in this script. 

Thank you

### additional note
Do not forget to put the mentioned files in the context. It will not load them into context automatically.  

## ... 
... 