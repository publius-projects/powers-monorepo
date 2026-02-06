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
              text: 'Github_AssignRoleWithSig', 
              link: '/mandates/async/Github_AssignRoleWithSig', 
            },
            { 
              text: 'Github_ClaimRoleWithSig', 
              link: '/mandates/async/Github_ClaimRoleWithSig', 
            },
            { 
              text: 'Snapshot_CheckSnapExists', 
              link: '/mandates/async/Snapshot_CheckSnapExists', 
            },
            { 
              text: 'Snapshot_CheckSnapPassed', 
              link: '/mandates/async/Snapshot_CheckSnapPassed', 
            },
            { 
              text: 'ZKPassport_Select', 
              link: '/mandates/async/ZKPassport_Select', 
            },
          ], 
        },
        { 
          text: 'Electoral', 
          collapsed: true, 
          items: [ 
            { 
              text: 'AssignExternalRole', 
              link: '/mandates/electoral/AssignExternalRole', 
            },
            { 
              text: 'DelegateTokenSelect', 
              link: '/mandates/electoral/DelegateTokenSelect', 
            },
            { 
              text: 'Nominate', 
              link: '/mandates/electoral/Nominate', 
            },
            { 
              text: 'NStrikesRevokesRoles', 
              link: '/mandates/electoral/NStrikesRevokesRoles', 
            },
            { 
              text: 'PeerSelect', 
              link: '/mandates/electoral/PeerSelect', 
            },
            { 
              text: 'RenounceRole', 
              link: '/mandates/electoral/RenounceRole', 
            },
            { 
              text: 'RevokeAccountsRoleId', 
              link: '/mandates/electoral/RevokeAccountsRoleId', 
            },
            { 
              text: 'RevokeInactiveAccounts', 
              link: '/mandates/electoral/RevokeInactiveAccounts', 
            },
            { 
              text: 'RoleByRoles', 
              link: '/mandates/electoral/RoleByRoles', 
            },
            { 
              text: 'RoleByTransaction', 
              link: '/mandates/electoral/RoleByTransaction', 
            },
            { 
              text: 'SelfSelect', 
              link: '/mandates/electoral/SelfSelect', 
            },
            { 
              text: 'TaxSelect', 
              link: '/mandates/electoral/TaxSelect', 
            },
          ], 
        },
        { 
          text: 'Executive', 
          collapsed: true, 
          items: [ 
            { 
              text: 'BespokeAction_Advanced', 
              link: '/mandates/executive/BespokeAction_Advanced', 
            },
            { 
              text: 'BespokeAction_OnOwnPowers', 
              link: '/mandates/executive/BespokeAction_OnOwnPowers', 
            },
            { 
              text: 'BespokeAction_OnReturnValue', 
              link: '/mandates/executive/BespokeAction_OnReturnValue', 
            },
            { 
              text: 'BespokeAction_Simple', 
              link: '/mandates/executive/BespokeAction_Simple', 
            },
            { 
              text: 'CheckExternalActionState', 
              link: '/mandates/executive/CheckExternalActionState', 
            },
            { 
              text: 'Mandates_Adopt', 
              link: '/mandates/executive/Mandates_Adopt', 
            },
            { 
              text: 'Mandates_Prepackaged', 
              link: '/mandates/executive/Mandates_Prepackaged', 
            },
            { 
              text: 'Mandates_Revoke', 
              link: '/mandates/executive/Mandates_Revoke', 
            },
            { 
              text: 'OpenAction', 
              link: '/mandates/executive/OpenAction', 
            },
            { 
              text: 'PowersAction_Flexible', 
              link: '/mandates/executive/PowersAction_Flexible', 
            },
            { 
              text: 'PowersAction_Simple', 
              link: '/mandates/executive/PowersAction_Simple', 
            },
            { 
              text: 'PresetActions_Multiple', 
              link: '/mandates/executive/PresetActions_Multiple', 
            },
            { 
              text: 'PresetActions_OnOwnPowers', 
              link: '/mandates/executive/PresetActions_OnOwnPowers', 
            },
            { 
              text: 'PresetActions_Single', 
              link: '/mandates/executive/PresetActions_Single', 
            },
            { 
              text: 'StatementOfIntent', 
              link: '/mandates/executive/StatementOfIntent', 
            },
          ], 
        }, 
        { 
          text: 'Integrations', 
          collapsed: true, 
          items: [ 
            { 
              text: 'ElectionList_CleanUpVoteMandate', 
              link: '/mandates/integrations/ElectionList_CleanUpVoteMandate', 
            },
            { 
              text: 'ElectionList_CreateVoteMandate', 
              link: '/mandates/integrations/ElectionList_CreateVoteMandate', 
            },
            { 
              text: 'ElectionList_Nominate', 
              link: '/mandates/integrations/ElectionList_Nominate', 
            },
            { 
              text: 'ElectionList_Tally', 
              link: '/mandates/integrations/ElectionList_Tally', 
            },
            { 
              text: 'ElectionList_Vote', 
              link: '/mandates/integrations/ElectionList_Vote', 
            },
            { 
              text: 'Governor_CreateProposal', 
              link: '/mandates/integrations/Governor_CreateProposal', 
            },
            { 
              text: 'Governor_ExecuteProposal', 
              link: '/mandates/integrations/Governor_ExecuteProposal', 
            },
            { 
              text: 'PowersFactory_AddSafeDelegate', 
              link: '/mandates/integrations/PowersFactory_AddSafeDelegate', 
            },
            { 
              text: 'PowersFactory_AssignRole', 
              link: '/mandates/integrations/PowersFactory_AssignRole', 
            },
            { 
              text: 'Safe_ExecTransaction_OnReturnValue', 
              link: '/mandates/integrations/Safe_ExecTransaction_OnReturnValue', 
            },
            { 
              text: 'Safe_ExecTransaction', 
              link: '/mandates/integrations/Safe_ExecTransaction', 
            },
            { 
              text: 'Safe_RecoverTokens', 
              link: '/mandates/integrations/Safe_RecoverTokens', 
            },
            { 
              text: 'Safe_Setup', 
              link: '/mandates/integrations/Safe_Setup', 
            },
            { 
              text: 'SafeAllowance_Action', 
              link: '/mandates/integrations/SafeAllowance_Action', 
            },
            { 
              text: 'SafeAllowance_Transfer', 
              link: '/mandates/integrations/SafeAllowance_Transfer', 
            },
            { 
              text: 'Soulbound1155_GatedAccess', 
              link: '/mandates/integrations/Soulbound1155_GatedAccess', 
            },
            { 
              text: 'Soulbound1155_MintEncodedToken', 
              link: '/mandates/integrations/Soulbound1155_MintEncodedToken', 
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
          text: 'Bicameralism', 
          link: '/organisations/bicameralism', 
        }, 
        { 
          text: 'Election List DAO', 
          link: '/organisations/electionListsDao', 
        }, 
        { 
          text: 'Token Delegates', 
          link: '/organisations/tokenDelegates', 
        }, 
        { 
          text: 'Power Base',
          link: '/organisations/powerBase', 
        }, 
        { 
          text: 'Cultural Stewards DAO', 
          link: '/organisations/culturalStewardshipDao', 
        }, 
      ], 
    }, 
  ],
})
