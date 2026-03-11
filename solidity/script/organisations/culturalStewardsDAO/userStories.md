# **The Cultural Stewardship DAO \- User stories**

| WARNING: Cultural Stewardship DAO is under development. The user stories and scenarios are subject to change. |
| :---- |

[comment]: <> (Important: This is how you leave a comment, it will not be included in the rendered text.) 

[comment]: <> (I refer directly to the specs so we only have one source of truth.)
## **Context**

For more context, please see `specs.md`. 

This resource aims to create a bridge between the institutional design and user experience of the organisation. 

The idea behind these user stories is to translate complex technological processes into human-readable language by giving fictional storytelling examples that explain the available actions that are done via mandates within the DAO, and how they link to www.enterhere.io, which is the 'DAO Portal' user interface (created from the 'Blank forum' template) for Cultural Stewards DAO.

Character names in the stories:
- Founder 1
- Founder 2 
- Visitor 1 
- PrimaryDAO Member 1
- PrimaryDAO Member 2
- IdeasDAO 'Project Orange' Member 1
- ...
- ...
- ...

Note: There user stories are in quotion marks after the character name, in italics. There is other text in-between these user stories, not in italics, which supplies more context to the stories. 



## StewardsDAO's 'PrimaryDAO'

### ***A. User interfaces***

### **1. Publius Projects - Blank Forum:**


Founder 1: _"Me and my team want to deploy a DAO. Part of that process is to create a DAO Portal. We will use the 'Blank Forum' component to create the basis of our DAO Portal, but we want to add some extra bespoke features"_

The ‘Blank Forum’ template component is a standardised dynamic website that DAOs can clone and customise to make their own 'DAO Portal'. It is a front-end website build on XMTP, and has two main features: 

- Voting - on mandates to control decisions within the DAO.
- Forum / Chatrooms - to interact with other members inside the DAO’s ecosystem.

This ‘blank forum’ is an integral part of the ‘Powers Protocol - Starter Pack'. It is open source, and so any DAO based on Powers Protocol will be able to host their own customisable user interface using this ‘blank forum’ that will become the DAO’s Portal; all activity will become centralised onto this platform. We made this decision because we believed it to be of paramount importance that the DAO’s communication and voting take place on the same plane; no additional communication channels such as email, social media, chat apps or Discord are required for the DAO to proceed. The ‘Blank Forum’ frontend plugs directly into the Powers Protocol and is fully blockchain integrated. 

The 'Blank Forum' structures its chatroom threads along the mandates and governance flows of the DAO's organisation struction. Every mandate has a dedicated page with more information about what that mandate does and what roles are allowed to interact with it. Also within the same page is a 'mandate chatroom' where users can chat about the mandates that exist within the DAO, and a 'start new action' button feature where users can generate a new action by inputting parameters into a popup box and it will submit a new action to be executed within the DAO. 

New actions also have their own dedicated page, so that when a new mandate is submitted users can go to the 'vote page' where they will see more information about the mandate, what parameters were given when it was generated, how long the voting will be active for, and the quorum that much be hit for a vote to qualify. There is also a 'vote chatroom' where users can discuss that specific vote, and a 'vote panel' where they can submit their vote directly through the forum interface. 

Except from rare exceptions, mandates are almost always part of a 'mandate flow', meaning, more than one mandate must be part of the governance process. This is why a third chatroom feature exists, on its own page titled 'flow sequence' is a 'flow chatroom' where users will see a visualisation of all the mandates belonging inside that flow. Each governance flow has a combined chatroom where all roles involed in that flow can chat together.

To summarise, the three main basic feaures on a DAO's or SubDAO's overview page are: 
- Mandate page --> Mandate chatroom + 'start a new action' button
- Vote page --> Vote chatroom + blockchain-integrated voting panel 
- Flow Sequence page --> Flow chatroom + View entire mandate flow visualisation, and switch between active vote pages inside the governance flow.

---------------------------------------------------

### ***2. www.enterhere.io - A bespoke website for StewardsDAO:***

Founder 2: _"We've got the basis of our DAO Portal figured out, all we needed to do was copy the code from the 'Blank Forum' in Publius Project's repository and follow the instructions in the 'Powers Protocol - Starter Pack'. Once we decided on our organisation's architectural structure, we assessed what additional features we needed to build for our DAO Portal to accomodate these processes. One of our core team members, @Gary, who is an Admin and is in charge of the Github repository was able to code in all these bespoke features that we needed - we did all of this before we even depolyed the DAO on-chain, because we knew that once it was deployed, the DigitalDAO governance structure would restrict any DAO Portal bespoke customisation changes or new additons to only being able to execute new actions via making decisions through voting. In essence, we wanted to set all the features up for the DAO Portal to be able to do the basic functions of what we indended, before we handed it over to the community to experiment with."_

Each organisation built on Powers Protocol has its own dedicated website for actions that are not directly governance related. These can include but are not limited to: 
- minting tokens, claiming rewards. 
- minting NFTs and linking them to RWAs. 
- ... In this case, the bespoke website for StewardsDAO is www.enterhere.io. When you go onto this URL, you will see a front page with information about the DAO, and also see a poster titled 'The DAO Architecture Visualisation' which is a blueprint of how the organisation is structured (going into detail about IdeasDAO, PhysicalDAO and DigitalDAO). There are some onboarding resources on there such as 'getting started', 'community guidelines' and 'etherium wallet setup'. There will also be all information about 'IRL (in-real-life) events', such as dates and location of where to attend. There will be a button titled 'GO TO DAO PORTAL' which will lead the user to the 'blank forum' component of their DAO Portal website. 

[comment]: <> (more features pending, I will circle back to these bullet points later.)


[comment]: <> (a more clear overview of enterhere.io is     pending, I will circle back to this paragraph later.)

### ***B. PrimaryDAO - User stories***   
[comment]: <> (EXAMPLE COMMENT: translate them and link them with the functionalities cover as many functionalities inside stories - if something is missing in the flow, highlight it.) 

Visitor 1: _"I go to www.enterhere.io and read through the 'StewardsDAO - About' page. There were also some really good onboarding resources, like a really colourful explorable 'DAO Architecture Visualisation' map, but I skip over it because a big button that says 'GO TO DAO PORTAL' catches my attention, so I click it. I didn't know what on earth 'connect wallet' meant (I thought the website was trying to steal my money) so I clicked 'view only'. It took me to a page titled 'ALL DAOs' and I just clicked on the first one, it was called 'PrimaryDAO'. After clicking, it took me to a page where I saw a summary of what PrimaryDAO is, and it had an interesting panel titled 'Activity Overview' where I could see loads of mandates and options to click further to view other pages...it seemed all those buttons took me to different chatrooms, but I wasn't able to view the content inside the chatrooms because it told me that I had not connected my wallet yet. All I could see was loads of users casting votes...it was all live...I guess I need to go back to www.enterhere.io to read more about 'wallet connections' and 'voting' inside the 'onboarding documents' section...perhaps they have a video resource that will show me how all this works?"_

#### Flow: 'Create and revoke IdeasDAO'

What is IdeasDAO? 
- IdeasDAO is focused on ideation, incubation of new concepts, and proposing new Physical Sub-DAOs. 
- Multiple instances of IdeasDAO can exist.
- Members have the right to initiate new IdeasDAOs, while each idea has to be ok-ed by elected executives. Executives give the final say on creating new ideas sub-DAOs and confirms the creation of physical sub-DAOs. 
- PhysicalDAOs (please refer to 'PhysicalDAO section of this document) can only be created after a proposal from IdeasDAOs.

#### Mandate: 'Initiate Ideas Sub-DAO creation' 

PrimaryDAO Member 1: 
_"I went onto the 'Activity Overview' panel inside the PrimaryDAO page, selected the mandate 'Initiate Ideas Sub-DAO creation' and started chatting with other members about an idea to start a new IdeasDAO titled 'Project Orange'. I clicked the 'Start a new action' button, it then prompted me to add in the parameters 'string name' and 'string uri', and I also pasted an achor hash of a message I wrote inside the mandate chatroom. The message read "ok guys, thanks for your input, it seems like the members believe that the topic of orange is an important one, so I will initiate the mandate now". The anchor hash provided a record of what chatroom and around what time we began deliberating the idea, and serves as important documentation in case we want to look back on that message thread in the future. Anyway, after that, all members were allowed to vote on the mandate titled 'Initiate Ideas Sub-DAO creation titled 'Project Orange' - it got lots of votes and successfully passed. When clicking 'flow sequence', I could see that the next mandate that was triggered inside the governance flow was an action only executable by Executives, it was titled 'Execute Ideas Sub-DAO creation'. They were deliberating in the 'flow chatroom' about whether or not they thought this was on-brand for the StewardsDAO...they sounded unsure."_

#### Mandate: 'Execute Ideas Sub-DAO creation' 

[comment]: <> (note to self: in this line I realised that I think I need to do seperate user stories for the roles, seperating the mandates and having the mandates themselves be the titles for each user story instead of having the titles structures as the governance flows...) 

Executive 1:
_"I saw in the 'Activity Overview' panel, that a new action had been submitted titled 'Initiate Ideas Sub-DAO creation titled 'Project Orange', and that the vote from members came back as successfully passed. I could see a pulsating notification message that says 'the next mandate in this flow has become active' with a button 'flow -->' which took me to the flow sequence page. It indicated that this mandate was relevant to my role, so I clicked on 'view action chatroom' and it took me to an action chatroom where the other PrimaryDAO executives were discussing the vote; they still sounded unsure if it would fit the branding of the StewardsDAO, but I could see that the 'yes' votes increasing. Votes eventually reached threshold and the mandated passed successfully."_ 

#### Mandate: 'Assign Role ID to IdeasDAO' 

Executive 2: _"I assigned role ID to @name "_ 

[comment]: <> (unsure of this one - how will it work with user interface? is this a bespoke feature or does it need to be worked into the 'blank forum')  

PrimaryDAO Member 2: _"I really didn't like how people were speaking in the IdeasDAO 'Project Orange'. My favourite colour is green, so I wasn't really resonating with it much. I scrolled the 'Activity Overview' panel on the PrimaryDAO page, and I found the mandate ??? is this a revoke IdeasDAO existence proposal?'

#### Veto Calls to Sub-DAOs ????? 
shouldn't i change the title to 'Veto revoking Ideas Sub-DAO' 

'Revoke Ideas Sub-DAO (Role)' ....




#### Update Uri Primary DAO. 
- IMAGE / BANNER of org 
- has info on where documentation / communication channels are 
- its the metadata 

#### Claim membership Primary DAO and Revoke. 

#### Elect Executives

#### Assign Legal Representative to Physical Sub-DAO

#### Adopt new mandates

#### NB: Any missing functionality? 

Add new stories here, with clear note that it has not been implemented yet. 

#### Transfer tokens to treasury


## Digital sub-DAO

### ***User interfaces***

#### Publius' Blank Canvas Forum 

#### Github repository of Cultural Stewards DAO

### ***User stories***  

#### Request Additional Allowances. 

#### Merit badges getting handed out to attendees who make a good contribution: 
"Specific tokens are used within Physical Sub-DAOs to recognise and reward contributions. These are NFTs (Soulbound NFT-1155 tokens) that are locally deployed by the StewardsDAO." 

#### User story 3: A participant tells DAO members that they are able to build a cool new feature for the DAO to be used at IRL events, and the DAO members approve this feature to begin being built. The participant contributes their code to the Github repo (their commits are accepted) and then they get awarded merits as payment. Not only that; once they begin sending Github commits, they are granted access in the DigitalDAO and can therefore now vote on governance decisions concerning the DigitalDAO. 

#### NB: Any missing functionality? 


Add new stories here, with clear note that it has not been implemented yet. 


## Ideas sub-DAO

### ***User interfaces***

#### Publius' Blank Canvas Forum 

#### Bespoke website of the ideas sub-DAO. 
This might be a generic one that is shared between Idea sub-DAOs. For us to decide.  

[comment]: <> (Note: sub-titles are the same as thre governance flows in `specs.md`.) 
### ***User stories***  

#### Membership is assigned by Moderators following an application by a public participant

A few hours went by and I received an email to say that my DAO Membership had been accepted! I then went back onto the “VIEW ACTIVE MANDATES” page, refreshed it, and saw a few items listed which apparently needed my attention. 

I clicked on the top one…it was a vote for ‘Open new Ideas Sub-DAO titled: Project Orange’. After clicking it, the screen split into two. On one side, I could see all the blockchain transactions for that mandate with a quota which was still in the red…and the left side of the page was instructing me to vote, so that the quota would turn green. On the right hand side, I could see a live chat, and the textbox was not grey which meant I was able to type into it and send messages. In there, I saw messages from DAO members who were discussing that they wanted to deeply explore the theme of ‘orange’ by escalating their thoughts into a newly created IdeasSub-DAO…

I wondered why the people chatting were so enthusiastic about this colour. I randomly clicked on one of the messages from a user, and it expanded into a thread; there, multiple people were discussing exactly why they liked the colour orange, sharing their experiences on it. It was captivating.” 


#### Request new Physical Sub-DAO (?) 

“After reading all the messages inside the IDEAS SUB-DAO #3 about forming a dedicated space to discuss the colour orange, I really got into the idea and felt inspired. I voted ‘yes’ in the proposal mandate, to open a new IdeasSub-DAO #7 titled ‘Project Orange’. My vote was the last vote before the vote reached the required quota of 100/100. As soon as it was cast, on my screen I had a popup which said “Voting quota fulfilled, IdeasSub-DAO creation accepted! You have 3 days from now until this chat threadroom expires.” I click ‘OK’.”

Part 6 → “After refreshing the mandate’s page, the left side (the governance side) got greyed out. The right hand side (the chatroom side) had messages beginning to pop up…people were congratulating each other that the IdeasSub-DAO creation proposal was successful. The ‘LIVE INFORMATION’ page posted a bulletin to inform others that the chatroom was closing in 3 days, and that they could continue the conversation in the new IdeasSub-DAO chatroom which had automatically spawned. They even shared the link to it…I clicked it, and it took me to the page where I was able to begin chatting; it even asked me if I wanted to ‘Join IdeasSub-DAO Titled: Project Orange’, so I clicked ‘yes’. I now was not only a DAO member, but also a IdeasSub-DAO member”

#### Update uri

New story here.


#### NB: Any missing functionality? 

Add new stories here, with clear note that it has not been implemented yet. 

## Physical sub-DAO

### ***User interfaces***

#### Publius' Blank Canvas Forum 

#### A local physical space / exhibition. 

### ***User stories***  

#### User story 1: 'PhysicalDAO Convenor Role' issues a POAP token via the PrimaryDAO. 

#### User story 2: Convenors propose what contributions were made at an IRL event. Attendees at the IRL event then vote via the DAO Portal on who had the best contributions. The 'winning' contributors gain merit tokens.  

#### User story 3: Redeem Merit tokens for payment. Merit gets sent to burn address, and a preset Safe transfer goes to the user. 

#### NB: Any missing functionality? 

Add new stories here, with clear note that it has not been implemented yet. 











miscellaneous stuff / notes: 

Flowchart component: Each chatroom has its own unique ID code. The 'blank forum' will only show the latest activity happening inside the DAO; once an action becomes inactive, after some time, it moves into the 'Flowchart'. The 'Flowchart' is an explorer where someone can view all historical data of a DAO. 

