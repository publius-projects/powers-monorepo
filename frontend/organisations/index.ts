import { Organization } from "./types";
import { Powers101 } from "./Powers101";  
import { OptimisticExecution } from "./OptimisticExecution";
import { Bicameralism } from "./Bicameralism";

/**
 * Registry of all available organizations
 * Add new organizations here to make them available for deployment
 */
export const organizations: Organization[] = [
  Powers101,
  OptimisticExecution,  
  Bicameralism
  // Add more organizations here as they are implemented
];

/**
 * Get an organization by its ID
 */
export function getOrganizationById(id: string): Organization | undefined {
  return organizations.find(org => org.metadata.id === id);
}

/**
 * Get an organization by its title
 */
export function getOrganizationByTitle(title: string): Organization | undefined {
  return organizations.find(org => org.metadata.title === title);
}

/**
 * Get all organizations that should be visible on localhost
 */
export function getLocalHostOrganizations(): Organization[] {
  return organizations.filter(org => org.metadata.onlyLocalhost);
}

/**
 * Get all organizations that should be visible everywhere
 */
export function getPublicOrganizations(): Organization[] {
  return organizations.filter(org => !org.metadata.onlyLocalhost);
}

/**
 * Get all enabled organizations
 */
export function getEnabledOrganizations(isLocalhost: boolean = false): Organization[] {
  return organizations.filter(org => 
    !org.metadata.disabled && 
    (!org.metadata.onlyLocalhost || (org.metadata.onlyLocalhost && isLocalhost))
  );
}

// Re-export types for convenience
export type { Organization, OrganizationField, OrganizationMetadata, DeployableContract } from "./types";

