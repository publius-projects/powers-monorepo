# Organizations Directory

This directory contains modular organization definitions for the Powers protocol deployment system. Each organization is self-contained in a single TypeScript file that defines all aspects of the organization including metadata, form fields, mandate initialization, and mock contract requirements.

## Architecture

### File Structure

```
organisations/
├── types.ts              # Type definitions for organizations
├── index.ts              # Organization registry and helper functions
├── PowerLabs.ts          # Power Base organization implementation
├── README.md            # This file
└── [YourOrg].ts         # Add new organizations here
```

### Key Components

#### 1. Organization Types (`types.ts`)

Defines the structure of an organization:

- **OrganizationMetadata**: Basic info (title, description, banner, etc.)
- **OrganizationField**: Form field definitions for user input
- **MockContract**: Mock contracts needed before deployment
- **Organization**: Complete organization interface

#### 2. Organization Registry (`index.ts`)

Provides:
- Central registry of all organizations
- Helper functions to get organizations by ID, title, or filter criteria
- Re-exports all types for convenience

#### 3. Organization Implementation

Each organization file exports a single `Organization` object with:

```typescript
export const MyOrganization: Organization = {
  metadata: {
    id: "unique-id",
    title: "Display Name",
    uri: "ipfs://...",
    banner: "ipfs://...",
    description: "Description shown to users",
    disabled: false,
    onlyLocalhost: false
  },
  
  fields: [
    // Form fields for user input
  ],
  
  createMandateInitData: (powersAddress, formData, chainId) => {
    // Generate mandate initialization data
    return mandateInitData;
  },
  
  // Optional
  getMockContracts: (formData) => {
    // Return list of mock contracts to deploy
  },
  
  // Optional
  validateFormData: (formData) => {
    // Validate user input
  }
};
```

## Adding a New Organization

### Step 1: Create Organization File

Create a new file in `organisations/` (e.g., `MyDAO.ts`):

```typescript
import { Organization } from "./types";
import { MandateInitData, createConditions } from "@/public/createMandateInitData";
import { getConstants } from "@/context/constants";
import { encodeAbiParameters } from "viem";

export const MyDAO: Organization = {
  metadata: {
    id: "my-dao",
    title: "My DAO",
    uri: "ipfs://your-metadata-uri",
    banner: "ipfs://your-banner-uri",
    description: "Your DAO description",
    disabled: false,
    onlyLocalhost: false
  },

  fields: [
    {
      name: "treasuryAddress",
      placeholder: "Treasury address (0x...)",
      type: "text",
      required: true
    }
  ],

  createMandateInitData: (powersAddress, formData, chainId) => {
    const mandateInitData: MandateInitData[] = [];
    
    // Define your mandates here
    mandateInitData.push({
      nameDescription: "My First Mandate",
      targetMandate: getInitialisedAddress("SomeMandate", chainId),
      config: "0x",
      conditions: createConditions({
        allowedRole: 0n
      })
    });

    return mandateInitData;
  },

  getMockContracts: (formData) => {
    return [
      {
        name: "MyMock",
        contractName: "MockContract"
      }
    ];
  }
};
```

### Step 2: Register in Index

Add your organization to `index.ts`:

```typescript
import { MyDAO } from "./MyDAO";

export const organizations: Organization[] = [
  PowerLabs,
  MyDAO,  // Add your organization here
  // ... more organizations
];
```

### Step 3: Test

Your organization will automatically appear in the deployment carousel!

## Power Base Organization

The **Power Base** organization is the reference implementation. It demonstrates:

- Complex multi-role governance
- Three separate Grant.sol instances for budget separation
- Budget proposal and veto mechanisms
- Grant lifecycle management (submit, approve, release milestones, reject)
- Electoral mandates (GitHub-based roles, funding-based roles)
- Constitutional amendment process

### Key Features

**Roles:**
1. Funders - Fund the protocol to get this role
2. Documentation Contributors - Assigned via GitHub commits to `/gitbook`
3. Frontend Contributors - Assigned via GitHub commits to `/frontend`
4. Protocol Contributors - Assigned via GitHub commits to `/solidity`
5. Members - Anyone with roles 1-4

**Governance Flows:**
- Budget setting for 3 independent areas (Docs, Frontend, Protocol)
- Grant proposals with milestone-based payouts
- Veto mechanisms for budgets and grants
- Role-based approval processes
- Constitutional mandate adoption

**Grant System:**
- Three separate `Grant.sol` instances
- Independent budgets per development area
- Milestone-based payment releases
- Token whitelisting for security
- Proposal → Veto → Approve → Release → End flow

See `PowerLabs.ts` for complete implementation details.

## Helper Functions

### Mandate Address Helpers

```typescript
const getInitialisedAddress = (mandateName: string, chainId: number): `0x${string}` => {
  const constants = getConstants(chainId);
  const address = constants.LAW_ADDRESSES[constants.LAW_NAMES.indexOf(mandateName)];
  if (!address) {
    throw new Error(`Mandate address not found for: ${mandateName}`);
  }
  return address;
};
```

### Time Conversion Helpers

```typescript
const daysToBlocks = (days: number, chainId: number): bigint => {
  const constants = getConstants(chainId);
  return BigInt(Math.floor(days * constants.BLOCKS_PER_HOUR * 24));
};

const minutesToBlocks = (minutes: number, chainId: number): bigint => {
  const constants = getConstants(chainId);
  return BigInt(Math.floor(minutes * constants.BLOCKS_PER_HOUR / 60));
};
```

### Condition Creation

```typescript
import { createConditions } from "@/public/createMandateInitData";

const conditions = createConditions({
  allowedRole: 1n,
  votingPeriod: daysToBlocks(7, chainId),
  quorum: 50n,
  succeedAt: 51n,
  needFulfilled: 2n,
  needNotFulfilled: 3n,
  timelock: daysToBlocks(3, chainId),
  throttleExecution: 100n
});
```

## Benefits of This Architecture

1. **Modularity**: Each organization is self-contained
2. **Clarity**: All organization data in one place
3. **Type Safety**: Full TypeScript support
4. **Reusability**: Share helper functions and patterns
5. **Maintainability**: Easy to add, update, or remove organizations
6. **Testability**: Each organization can be tested independently

## Migration from Old System

The old system split organization data across three files:
- `SectionDeployCarousel.tsx` - UI logic
- `deploymentForms.ts` - Form metadata
- `createMandateInitData.ts` - Mandate generation logic

The new system consolidates this into:
- `organisations/[OrgName].ts` - All organization-specific data
- `SectionDeployCarouselV2.tsx` - Generic UI component
- `organisations/index.ts` - Organization registry

This makes it much clearer where to add new organizations and what data they need.

## Best Practices

1. **Naming**: Use descriptive names for mandates (e.g., "Propose Budget" not "Mandate 2")
2. **Documentation**: Add comments explaining complex governance flows
3. **Validation**: Implement `validateFormData` for user input validation
4. **Testing**: Test mandate generation with different form data combinations
5. **Constants**: Use constants for role IDs and common values
6. **Helpers**: Extract common patterns into helper functions
7. **Dependencies**: Document mandate dependencies in comments (e.g., "needFulfilled: 2n // Requires budget proposal")

## Future Enhancements

Possible additions to the organization system:

- Pre-deployment checks (verify mock contracts exist, check balances)
- Post-deployment validation (verify mandates were adopted correctly)
- Organization migration/upgrade paths
- Deployment history tracking
- Gas estimation for mandate adoption
- Multi-step deployment wizards for complex organizations
- Organization templates/presets
- Visual governance flow diagrams
- Automated testing utilities

## Questions?

For questions about:
- **Organization structure**: See `types.ts`
- **Reference implementation**: See `PowerLabs.ts`
- **Adding organizations**: See "Adding a New Organization" section above
- **Helper functions**: See `@/public/createMandateInitData.ts`
- **Constants**: See `@/context/constants.ts`

