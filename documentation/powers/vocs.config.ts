import { defineConfig } from 'vocs'

export default defineConfig({
  title: 'Powers',
  theme: {
    variables: {
      content: {
        horizontalPadding: '1.5rem',
        verticalPadding: '3rem'
      },
    },
  },
  sidebar: [
    {
      text: 'Welcome',
      link: '/welcome',
    },
    {
      text: 'Use Cases',
      link: '/use-cases',
    },
    {
      text: 'Development',
      link: '/development',
    },
    { 
      text: 'For Developers', 
      collapsed: false, 
      items: [ 
        {
          text: 'Litepaper',
          link: '/for-developers/litepaper',
        },
        { 
          text: 'Architecture', 
          link: '/for-developers/architecture', 
        }, 
        { 
          text: 'Powers.sol', 
          link: '/for-developers/powers', 
        },
        { 
          text: 'Mandate.sol', 
          link: '/for-developers/mandate', 
        },
        { 
          text: 'Deploy your Powers', 
          link: '/for-developers/deploy-your-powers', 
        },
        { 
          text: 'Creating a mandate', 
          link: '/for-developers/creating-a-mandate', 
        },
      ], 
    }, 
    { 
      text: 'Mandates', 
      collapsed: false, 
      items: [ 
        { 
          text: 'Async', 
          collapsed: true, 
          items: [ 
            { 
              text: 'CheckExternalState', 
              link: '/to-do', 
            },
            { 
              text: 'AssignRoleWithGitCommit', 
              link: '/to-do', 
            },
            { 
              text: 'ClaimRoleWithGitCommit', 
              link: '/to-do', 
            },
            { 
              text: 'Snapshot_CheckSnapExists', 
              link: '/mandates/Snapshot_CheckSnapExists', 
            },
            { 
              text: 'Snapshot_CheckSnapPassed', 
              link: '/mandates/Snapshot_CheckSnapPassed', 
            },
            { 
              text: 'ZKPassportSelect', 
              link: '/to-do', 
            },
          ], 
        },
        { 
          text: 'Electoral', 
          collapsed: true, 
          items: [ 
            { 
              text: 'OpenElectionEnd', 
              link: '/mandates/OpenElectionEnd', 
            },
            { 
              text: 'NStrikesRevokesRoles', 
              link: '/mandates/NStrikesRevokesRoles', 
            },
            { 
              text: 'PeerSelect', 
              link: '/mandates/PeerSelect', 
            },
            { 
              text: 'RenounceRole', 
              link: '/mandates/RenounceRole', 
            },
            { 
              text: 'RoleByRoles', 
              link: '/mandates/RoleByRoles', 
            },
            { 
              text: 'SelfSelect', 
              link: '/mandates/SelfSelect', 
            },
            { 
              text: 'TaxSelect', 
              link: '/mandates/TaxSelect', 
            },
            { 
              text: 'OpenElectionVote', 
              link: '/mandates/OpenElectionVote', 
            },
          ], 
        },
        { 
          text: 'Executive', 
          collapsed: true, 
          items: [ 
            { 
              text: 'AdoptMandates', 
              link: '/mandates/AdoptMandates', 
            },
            { 
              text: 'BespokeActionAdvanced', 
              link: '/mandates/BespokeActionAdvanced', 
            },
            { 
              text: 'BespokeActionSimple', 
              link: '/mandates/BespokeActionSimple', 
            },
            { 
              text: 'OpenAction', 
              link: '/mandates/OpenAction', 
            },
            { 
              text: 'PresetMultipleActions', 
              link: '/mandates/PresetMultipleActions', 
            },
            { 
              text: 'PresetSingleAction', 
              link: '/mandates/PresetSingleAction', 
            },
            { 
              text: 'StatementOfIntent', 
              link: '/mandates/StatementOfIntent', 
            },
          ], 
        }, 
        { 
          text: 'Integrations', 
          collapsed: true, 
          items: [ 
            { 
              text: 'AlloCreateRPFGPool', 
              link: '/to-do', 
            },
            { 
              text: 'AlloDistribute', 
              link: '/to-do', 
            },
            { 
              text: 'AlloRPFGGovernance', 
              link: '/to-do', 
            },
            { 
              text: 'Governor_CreateProposal', 
              link: '/mandates/Governor_CreateProposal', 
            },
            { 
              text: 'Governor_ExecuteProposal', 
              link: '/mandates/Governor_ExecuteProposal', 
            },
            { 
              text: 'TreasuryPoolGovernance', 
              link: '/to-do', 
            },
            { 
              text: 'TreasuryPoolTransfer', 
              link: '/to-do', 
            },
            { 
              text: 'TreasuryRoleWithTransfer', 
              link: '/to-do', 
            },
          ], 
        },
      ], 
    }, 
    { 
      text: 'Organisations', 
      collapsed: false, 
      items: [ 
        {
          text: 'Power 101',
          link: '/organisations/powers101',
        },
        {
          text: 'Power 102',
          link: '/organisations/powers102',
        },
        { 
          text: 'Power Base', 
          link: '/organisations/powerLabs', 
        }, 
        { 
          text: 'Powers To Nouns', 
          link: '/organisations/powers2Nouns', 
        },
        { 
          text: 'Bridged Powers', 
          link: '/organisations/bridgedPowers', 
        },
      ], 
    }, 
  ],
})
