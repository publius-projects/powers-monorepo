'use client'

import React, { act, useCallback, useEffect, useMemo } from 'react'
import ReactFlow, {
  Node,
  Edge,
  Background,
  MiniMap,
  useNodesState,
  useEdgesState,
  addEdge,
  Connection,
  ConnectionMode,
  Handle,
  Position,
  NodeProps,
  useReactFlow,
  ReactFlowProvider,
  MarkerType,
} from 'reactflow'
import 'reactflow/dist/style.css'
import { Mandate, Powers, Action, Status } from '@/context/types'
import { toFullDateFormat, toEurTimeFormat } from '@/utils/toDates'
import { useBlocks } from '@/hooks/useBlocks'
import { parseChainId } from '@/utils/parsers'
import { fromFutureBlockToDateTime } from '@/organisations/helpers'
import { getConstants } from '@/context/constants'
import { State, useBlockNumber, useChains } from 'wagmi'
import {
  CalendarDaysIcon,
  QueueListIcon,  
  DocumentCheckIcon,
  ShieldCheckIcon,
  ClipboardDocumentCheckIcon,
  CheckCircleIcon,
  RocketLaunchIcon,
  ArchiveBoxIcon,
  FlagIcon
} from '@heroicons/react/24/outline'
import { useParams, usePathname, useRouter } from 'next/navigation'
import { setAction, useActionStore, usePowersStore } from '@/context/store'
import { bigintToRole, bigintToRoleHolders } from '@/utils/bigintTo'
import HeaderMandate from '@/components/HeaderMandate'
import { hashAction } from '@/utils/hashAction'
import { useChecks } from '@/hooks/useChecks'
import { useWallets } from '@privy-io/react-auth'

// Default colors for all nodes
const DEFAULT_NODE_COLOR = '#475569' // slate-600
const DEFAULT_BORDER_CLASS = 'border-slate-600'
const EXECUTED_BORDER_CLASS = 'border-green-600'

function getNodeBorderClass(action: Action | undefined): string {
  // Check if the action has been successfully executed (fulfilledAt > 0)
  if (action && action.fulfilledAt && action.fulfilledAt > 0n) {
    return EXECUTED_BORDER_CLASS
  }
  return DEFAULT_BORDER_CLASS
}

// Helper function to get action data for all mandates in the dependency chain
function getActionDataForChain(
  selectedAction: Action | undefined,
  mandates: Mandate[],
  powers: Powers
): Map<string, Action> {
  const actionDataMap = new Map<string, Action>()
  
  // If no selected action or no calldata/nonce, return empty map
  if (!selectedAction || !selectedAction.callData || !selectedAction.nonce) {
    return actionDataMap
  }
  
  // For each mandate, calculate the actionId and look up the action data
  mandates.forEach(mandate => {
    const mandateId = mandate.index
    const calculatedActionId = hashAction(mandateId, selectedAction.callData!, BigInt(selectedAction.nonce!))
    
    // Check if this action exists in the Powers object
    const mandateData = powers.mandates?.find(l => l.index === mandateId)
    if (mandateData && mandateData.actions) {
      const action = mandateData.actions.find(a => a.actionId === String(calculatedActionId))
      if (action) {
        actionDataMap.set(String(mandateId), action)
      }
    }
  })
  
  return actionDataMap
}

interface MandateSchemaNodeData {
  powers: Powers
  mandate: Mandate
  roleColor: string
  onNodeClick?: (mandateId: string) => void
  selectedMandateId?: string
  connectedNodes?: Set<string>
  actionDataTimestamp?: number
  selectedAction?: Action
  chainActionData: Map<string, Action>
}

const MandateSchemaNode: React.FC<NodeProps<MandateSchemaNodeData>> = ( {data} ) => {
  const { mandate, roleColor, onNodeClick, selectedMandateId, connectedNodes, powers, chainActionData } = data
  const action  = useActionStore()
  const { timestamps, fetchTimestamps } = useBlocks()
  const chainId = useParams().chainId as string
  const chains = useChains()
  const supportedChain = chains.find(chain => chain.id == parseChainId(chainId))
  const { data: blockNumber } = useBlockNumber()

  // Get action data for this mandate from the chain action data
  const currentMandateAction = chainActionData.get(String(mandate.index))

  // Fetch timestamps for the current mandate's action data
  React.useEffect(() => {
    // console.log("LAW schema node triggered", {mandate, chainActionData})
    const currentMandateAction = chainActionData.get(String(mandate.index))
    // console.log( "@PowersFlow: ", {currentMandateAction} )
    if (currentMandateAction) {
      const blockNumbers: bigint[] = []
      
      // Collect all block numbers that need timestamps
      // proposedAt is used for proposal created, vote started, and calculating vote ended
      if (currentMandateAction.proposedAt && currentMandateAction.proposedAt !== 0n) {
        blockNumbers.push(currentMandateAction.proposedAt)
      }
      if (currentMandateAction.requestedAt && currentMandateAction.requestedAt !== 0n) {
        blockNumbers.push(currentMandateAction.requestedAt)
      }
      if (currentMandateAction.fulfilledAt && currentMandateAction.fulfilledAt !== 0n) {
        blockNumbers.push(currentMandateAction.fulfilledAt)
      }
      
      // Also fetch timestamps for dependent mandates
      if (mandate.conditions) {
        if (mandate.conditions.needFulfilled != null && BigInt(mandate.conditions.needFulfilled) != 0n) {
          const dependentAction = chainActionData.get(String(mandate.conditions.needFulfilled))
          if (dependentAction && dependentAction.fulfilledAt && dependentAction.fulfilledAt != 0n) {
            blockNumbers.push(dependentAction.fulfilledAt)
          }
        }
        if (mandate.conditions.needNotFulfilled != null && BigInt(mandate.conditions.needNotFulfilled) != 0n) {
          const dependentAction = chainActionData.get(String(mandate.conditions.needNotFulfilled))
          if (dependentAction && dependentAction.fulfilledAt && dependentAction.fulfilledAt != 0n) {
            blockNumbers.push(dependentAction.fulfilledAt)
          }
        }
      }
      
      // Fetch timestamps if we have block numbers
      if (blockNumbers.length > 0) {
        fetchTimestamps(blockNumbers, chainId)
      }
    }
  }, [chainActionData, mandate.index, mandate.conditions, chainId, fetchTimestamps])
  
  // Helper function to format block number or timestamp to desired format
  const formatBlockNumberOrTimestamp = (value: bigint | undefined): string | null => {
    if (!value || value === 0n) {
      return null
    }
    
    try {
      // First, check if we have this as a cached timestamp from useBlocks
      const cacheKey = `${chainId}:${value}`
      const cachedTimestamp = timestamps.get(cacheKey)
      
      if (cachedTimestamp && cachedTimestamp.timestamp) {
        // Convert bigint timestamp to number for the utility functions
        const timestampNumber = Number(cachedTimestamp.timestamp)
        const dateStr = toFullDateFormat(timestampNumber)
        const timeStr = toEurTimeFormat(timestampNumber)
        return `${dateStr}: ${timeStr}`
      }
      
      // If not in cache, it might be a direct timestamp (fallback)
      // Check if the value looks like a timestamp (large number) vs block number (smaller)
      const valueNumber = Number(value)
      
      // If it's a very large number, treat as timestamp
      if (valueNumber > 1000000000) { // Unix timestamp threshold
        const dateStr = toFullDateFormat(valueNumber)
        const timeStr = toEurTimeFormat(valueNumber)
        return `${dateStr}: ${timeStr}`
      }
      
      // If it's a smaller number, it's likely a block number that hasn't been fetched yet
      return null
    } catch (error) {
      return null
    }
  }

  // Helper function to get date for each check item
  const getCheckItemDate = (itemKey: string): string | null => {
    const currentMandateAction = chainActionData.get(String(mandate.index))
    // console.log("currentMandateAction", currentMandateAction)
    
    switch (itemKey) {
      case 'needFulfilled':
      case 'needNotFulfilled': {
        // Get executedAt from the dependent mandate - this should work regardless of current mandate's action data
        const dependentMandateId = itemKey == 'needFulfilled' 
          ? mandate.conditions?.needFulfilled 
          : mandate.conditions?.needNotFulfilled
        
        if (dependentMandateId && dependentMandateId != 0n) {
          const dependentAction = chainActionData.get(String(dependentMandateId))
          
          return formatBlockNumberOrTimestamp(dependentAction?.fulfilledAt)
        }
        return null
      }
      
      case 'proposalCreated': {
        // Show proposal creation time - use proposedAt from current mandate's action data
        if (currentMandateAction && currentMandateAction.proposedAt && currentMandateAction.proposedAt != 0n) {
          return formatBlockNumberOrTimestamp(currentMandateAction.proposedAt)
        }
        return null
      }
      
      case 'voteStarted': {
        // Vote started is the same as proposal created (proposedAt)
        if (currentMandateAction && currentMandateAction.proposedAt && currentMandateAction.proposedAt != 0n) {
          return formatBlockNumberOrTimestamp(currentMandateAction.proposedAt)
        }
        return null
      }
      
      case 'voteEnded': {
        // Calculate vote end time using proposedAt + votingPeriod (converted to blocks)
        if (currentMandateAction && currentMandateAction.proposedAt && currentMandateAction.proposedAt != 0n && mandate.conditions?.votingPeriod && blockNumber != null) {
          const parsedChainId = parseChainId(chainId)
          if (parsedChainId == null) return null
          
          // Calculate future block when vote will end
          const voteEndBlock = BigInt(currentMandateAction.proposedAt) + BigInt(mandate.conditions.votingPeriod)
          
          // Use fromFutureBlockToDateTime to get human-readable format
         
          return fromFutureBlockToDateTime(voteEndBlock, BigInt(blockNumber), parsedChainId)
   
        }
        return null
      }

      case 'delay': {
        // Calculate delay pass time using proposedAt + votingPeriod + timelock (converted to blocks)
        if (currentMandateAction && currentMandateAction.proposedAt && currentMandateAction.proposedAt != 0n && mandate.conditions?.votingPeriod && mandate.conditions.timelock != 0n && blockNumber != null) {
          const parsedChainId = parseChainId(chainId)
          if (parsedChainId == null) return null
          
          // Calculate future block when delay will pass
          const delayEndBlock = BigInt(currentMandateAction.proposedAt) + BigInt(mandate.conditions.votingPeriod) + BigInt(mandate.conditions.timelock)
          
          // Use fromFutureBlockToDateTime to get human-readable format
          return fromFutureBlockToDateTime(delayEndBlock, BigInt(blockNumber), parsedChainId)
        }
        // Return null if no action data or no delay condition
        return null
      }
      
      case 'requested': {
        // Use requestedAt field - show when proposal was requested (after vote passed)
        if (currentMandateAction && currentMandateAction.requestedAt && currentMandateAction.requestedAt != 0n) {
          return formatBlockNumberOrTimestamp(currentMandateAction.requestedAt)
        }
        return null
      }
      
      case 'throttle':
        if (mandate.conditions?.throttleExecution && blockNumber != null) {  
          const latestFulfilledAction = mandate.actions ? Math.max(...mandate.actions.map(action => Number(action.fulfilledAt)), 1) : 0
          const parsedChainId = parseChainId(chainId)
          if (parsedChainId == null) return null

          const throttlePassBlock = BigInt(latestFulfilledAction + Number(mandate.conditions.throttleExecution))
          return fromFutureBlockToDateTime(throttlePassBlock, BigInt(blockNumber), parsedChainId)
        }
        
        // Keep as null for now
        return null
      
      case 'fulfilled':        
        // Only show date if actually fulfilled (fulfilledAt > 0)
        if (currentMandateAction && currentMandateAction.fulfilledAt && currentMandateAction.fulfilledAt != 0n) {
          return formatBlockNumberOrTimestamp(currentMandateAction.fulfilledAt)
        }
        return null
      
      default:
        return null
    }
  }

  const handleClick = () => {
    if (onNodeClick) {
      onNodeClick(String(mandate.index))
    }
  }

  const isSelected = selectedMandateId === String(mandate.index)
  const borderThickness = isSelected ? 'border-4' : 'border'
  
  // Apply opacity based on connection to selected node
  const isConnected = !selectedMandateId || !connectedNodes || connectedNodes.has(String(mandate.index))
  const opacityClass = isConnected ? 'opacity-100' : 'opacity-50'

  const checkItems = useMemo(() => {
    const items: { 
      key: string
      label: string
      blockNumber?: bigint
      state?: Status
      hasHandle: boolean
      targetMandate?: bigint
      edgeType?: string
    }[] = []

    // console.log("checkItems triggered", {mandate, chainActionData})
    
    // 1. Dependency checks - show only if dependent mandates exist (condition != 0)
    if (mandate.conditions) {
      if (mandate.conditions.needFulfilled > 0n) {
        const dependentAction = chainActionData.get(String(mandate.conditions.needFulfilled))
        items.push({ 
          key: 'needFulfilled', 
          label: `Mandate ${mandate.conditions.needFulfilled} Fulfilled`, 
          blockNumber: dependentAction?.fulfilledAt,
          state: dependentAction?.fulfilledAt && dependentAction.fulfilledAt > 0n ? "success" : "pending",
          hasHandle: true,
          targetMandate: mandate.conditions.needFulfilled,
          edgeType: 'needFulfilled'
        })
      }
      
      if (mandate.conditions.needNotFulfilled > 0n) {
        const dependentAction = chainActionData.get(String(mandate.conditions.needNotFulfilled))
        // For needNotFulfilled, show green when the dependent mandate is NOT fulfilled (blockNumber is 0 or undefined) 
        items.push({ 
          key: 'needNotFulfilled', 
          label: `Mandate ${mandate.conditions.needNotFulfilled} Not Fulfilled`, 
          blockNumber: dependentAction?.fulfilledAt,
          state: dependentAction?.fulfilledAt && dependentAction.fulfilledAt > 0n ? "error" : "success",
          hasHandle: true,
          targetMandate: mandate.conditions.needNotFulfilled,
          edgeType: 'needNotFulfilled'
        })
      }
    }
    
    // 2. Throttle check - show only if throttle condition exists (throttleExecution > 0)
    if (mandate.conditions && mandate.conditions.throttleExecution != null && mandate.conditions.throttleExecution > 0n) { 
      const latestFulfilledAction = mandate.actions ? Math.max(...mandate.actions.map(action => Number(action.fulfilledAt)), 1) : 0
      const throttledPassed = (latestFulfilledAction + Number(mandate.conditions.throttleExecution)) < Number(blockNumber)

      // console.log("Throttle check", {mandate, latestFulfilledAction, throttledPassed, blockNumber})

      items.push({ 
        key: 'throttle', 
        label: 'Throttle Passed', 
        blockNumber: BigInt(latestFulfilledAction + Number(mandate.conditions.throttleExecution)),
        state: throttledPassed ? "success" : "error",
        hasHandle: false
      })
    }
    
    // 3. Vote flow - show only when quorum > 0
    if (mandate.conditions && mandate.conditions.quorum != null && mandate.conditions.quorum > 0n) {
      items.push({ 
        key: 'proposalCreated', 
        label: 'Proposal Created', 
        blockNumber: currentMandateAction?.proposedAt,
        state: currentMandateAction?.proposedAt && currentMandateAction.proposedAt > 0n ? "success" : "pending",
        hasHandle: false
      })
      
      items.push({ 
        key: 'voteStarted', 
        label: 'Vote Started', 
        // Vote started is the same as proposal created
        blockNumber: currentMandateAction?.proposedAt,
        state: currentMandateAction?.proposedAt && currentMandateAction.proposedAt > 0n ? "success" : "pending",
        hasHandle: false
      })
      
      items.push({ 
        key: 'voteEnded', 
        label: 'Vote Ended', 
        // Show as completed if we have proposedAt (vote will end at proposedAt + votingPeriod)
        blockNumber: currentMandateAction?.proposedAt,
        state: 
          currentMandateAction?.state && currentMandateAction?.state == 4 ? "error" :
          currentMandateAction?.state && currentMandateAction?.state >= 5 ? "success" :
          "pending",
        hasHandle: false
      })

          
      // 4. Delay - show only if timelock > 0
      if (mandate.conditions && mandate.conditions.timelock != null && mandate.conditions?.quorum != null && mandate.conditions.timelock > 0n) {
        items.push({ 
          key: 'delay', 
          label: 'Delay Passed', 
          // For delay, we use proposedAt as the reference block (the delay is calculated from it: proposedAt + votingPeriod + delay)
          blockNumber: currentMandateAction?.proposedAt,
          state: currentMandateAction?.proposedAt ? currentMandateAction?.proposedAt + mandate.conditions.votingPeriod + mandate.conditions.timelock < BigInt(blockNumber || 0) ? "success" : "pending" : "pending",
          hasHandle: false
        })
      }
      
      items.push({ 
        key: 'requested', 
        label: 'Requested', 
        // Show green if action has been requested (requestedAt > 0)
        blockNumber: currentMandateAction?.requestedAt || 0n,
        state: currentMandateAction?.requestedAt && currentMandateAction.requestedAt > 0n ? "success" : "pending",
        hasHandle: false
      })
    }

    // 5. Fulfilled - always show
    items.push({ 
      key: 'fulfilled', 
      label: 'Fulfilled', 
      blockNumber: currentMandateAction?.fulfilledAt,
      state: currentMandateAction?.fulfilledAt && currentMandateAction.fulfilledAt > 0n ? "success" : "pending",
      hasHandle: false
    })
    
    return items
  }, [currentMandateAction, mandate.conditions, chainActionData])

  const roleBorderClass = getNodeBorderClass(currentMandateAction)

  // Helper values for HeaderMandate
  const mandateName = mandate.nameDescription ? `#${Number(mandate.index)}: ${mandate.nameDescription.split(':')[0]}` : `#${Number(mandate.index)}`;
  const roleName = mandate.conditions && powers ? bigintToRole(mandate.conditions.allowedRole, powers) : '';
  const numHolders = mandate.conditions && powers ? bigintToRoleHolders(mandate.conditions.allowedRole, powers) : '';
  const description = mandate.nameDescription ? mandate.nameDescription.split(':')[1] || '' : '';
  const contractAddress = mandate.mandateAddress;
  const blockExplorerUrl = supportedChain?.blockExplorers?.default.url;

  return (
    <div 
      className={`shadow-lg rounded-lg bg-white ${borderThickness} min-w-[300px] max-w-[380px] w-[380px] overflow-hidden ${roleBorderClass} cursor-pointer hover:shadow-xl transition-shadow ${opacityClass} relative`}
      help-nav-item="flow-node"
      onClick={handleClick}
    >        
        {/* Mandate Header - replaced with HeaderMandate */}
        <div className="px-4 py-3 border-b border-gray-300 bg-slate-100" style={{ borderBottomColor: roleColor }}>
          <HeaderMandate
            powers={powers as Powers}
            mandateName={mandateName}
            roleName={roleName}
            numHolders={numHolders}
            description={description}
            contractAddress={contractAddress}
            blockExplorerUrl={blockExplorerUrl}
          />
        </div>
        
        {/* Action Steps Section */}
        {checkItems.length > 0 && (
          <div className="relative bg-slate-50">
            {checkItems.map((item, index) => {
              // Determine if this step is completed based on blockNumber
              const iconColor = item.state === "success" ? 'text-green-600' : item.state === "error" ? 'text-red-600' : 'text-black'

              return (
              <div key={item.key} className="relative">
                <div className="px-4 py-2 flex items-center justify-between text-xs relative">
                <div className="flex items-center space-x-2 flex-1">
                    <div className="w-6 h-6 flex justify-center items-center relative">
                      {item.key === 'fulfilled' ? (
                        <div className="w-6 h-6 rounded-full border border-black flex items-center justify-center bg-white relative z-10">
                          <RocketLaunchIcon className={`w-4 h-4 ${iconColor}`} />
                        </div>
                      ) : item.key === 'requested' ? (
                        <div className="w-6 h-6 rounded-full border border-black flex items-center justify-center bg-white relative z-10">
                          <CheckCircleIcon className={`w-4 h-4 ${iconColor}`} />
                        </div>
                      ) : item.key === 'delay' ? (
                        <div className="w-6 h-6 rounded-full border border-black flex items-center justify-center bg-white relative z-10">
                          <CalendarDaysIcon className={`w-4 h-4 ${iconColor}`} />
                        </div>
                      ) : item.key === 'throttle' ? (
                        <div className="w-6 h-6 rounded-full border border-black flex items-center justify-center bg-white relative z-10">
                          <QueueListIcon className={`w-4 h-4 ${iconColor}`} />
                        </div>
                      ) : item.key === 'needFulfilled' || item.key === 'needNotFulfilled' ? (
                        <div className="w-6 h-6 rounded-full border border-black flex items-center justify-center bg-white relative z-10">
                          <DocumentCheckIcon className={`w-4 h-4 ${iconColor}`} />
                        </div>
                      ) : item.key === 'voteStarted' ? (
                        <div className="w-6 h-6 rounded-full border border-black flex items-center justify-center bg-white relative z-10">
                          <ArchiveBoxIcon className={`w-4 h-4 ${iconColor}`} />
                        </div>
                      ) : item.key === 'voteEnded' ? (
                        <div className="w-6 h-6 rounded-full border border-black flex items-center justify-center bg-white relative z-10">
                          <FlagIcon className={`w-4 h-4 ${iconColor}`} />
                        </div>
                      ) : item.key === 'proposalCreated' ? (
                        <div className="w-6 h-6 rounded-full border border-black flex items-center justify-center bg-white relative z-10">
                          <ClipboardDocumentCheckIcon className={`w-4 h-4 ${iconColor}`} />
                        </div>
                      ) : (
                        <div className="w-6 h-6 rounded-full border border-black flex items-center justify-center bg-white relative z-10">
                          <ShieldCheckIcon className={`w-4 h-4 ${iconColor}`} />
                        </div>
                      )}
                    </div>
                    <div className="flex-1 flex flex-col min-w-0">
                      {getCheckItemDate(item.key) && (
                        <div className="text-[10px] text-gray-400 mb-0.5">{getCheckItemDate(item.key)}</div>
                      )}
                      <span className="text-gray-700 font-medium break-words">{item.label}</span>
                    </div>
                </div>
                
                {/* Connection handle for dependency checks */}
                {item.hasHandle && (
                  <Handle
                    type="source"
                    position={Position.Left}
                    id={`${item.key}-handle`}
                    style={{ 
                      background: roleColor, // Use role color instead of gray
                      width: 8,
                      height: 8,
                      left: -4,
                      top: '50%',
                      transform: 'translateY(-50%)'
                      }}
                    />
                  )}
                  
                  {/* Target handle for fulfilled check */}
                  {item.key === 'fulfilled' && (
                    <Handle
                      type="target"
                      position={Position.Right}
                      id="fulfilled-target"
                      style={{ 
                        background: roleColor, // Use role color instead of gray
                        width: 10,
                        height: 10,
                        right: -5,
                        top: '50%',
                        transform: 'translateY(-50%)'
                      }}
                    />
                  )}
                </div>
                
                {/* Vertical connecting line to next item */}
                {index < checkItems.length - 1 && (
                  <div 
                    className="absolute w-px bg-black"
                    style={{ 
                      left: '28px', // 16px padding + 12px (half of 24px circle width)
                      top: 'calc(50% + 12px)', // Start from bottom of current circle
                      height: 'calc(100% - 12px)', // Extend to top of next circle
                    }}
                  />
                )}
              </div>
            )})}
          </div>
        )}
      </div>
  )
}

const nodeTypes = {
  mandateSchema: MandateSchemaNode,
}

// Helper function to find all nodes connected to a selected node through dependencies
function findConnectedNodes(powers: Powers, selectedMandateId: string): Set<string> {
  const connected = new Set<string>()
  const visited = new Set<string>()

  const mandates = powers?.mandates || []

  // Build dependency maps
  const dependencies = new Map<string, Set<string>>()
  const dependents = new Map<string, Set<string>>()
  
  mandates.forEach(mandate => {
    const mandateId = String(mandate.index)
    dependencies.set(mandateId, new Set())
    dependents.set(mandateId, new Set())
  })
  
  // Populate dependency relationships
  mandates.forEach(mandate => {
    const mandateId = String(mandate.index)
    if (mandate.conditions) {
      if (mandate.conditions.needFulfilled != null && mandate.conditions.needFulfilled !== 0n) {
        const targetId = String(mandate.conditions.needFulfilled)
        if (dependencies.has(targetId)) {
        dependencies.get(mandateId)?.add(targetId)
        dependents.get(targetId)?.add(mandateId)
        }
      }
      if (mandate.conditions.needNotFulfilled != null && mandate.conditions.needNotFulfilled !== 0n) {
        const targetId = String(mandate.conditions.needNotFulfilled)
        if (dependencies.has(targetId)) {
        dependencies.get(mandateId)?.add(targetId)
        dependents.get(targetId)?.add(mandateId)
        }
      }
    }
  })
  
  // Recursive function to find all connected nodes
  const traverse = (nodeId: string) => {
    if (visited.has(nodeId)) return
    visited.add(nodeId)
    connected.add(nodeId)
    
    // Add all dependencies
    const deps = dependencies.get(nodeId) || new Set()
    deps.forEach(depId => traverse(depId))
    
    // Add all dependents  
    const dependentNodes = dependents.get(nodeId) || new Set()
    dependentNodes.forEach(depId => traverse(depId))
  }
  
  traverse(selectedMandateId)
  return connected
}

// Helper function to create a compact layered tree layout based on dependencies
function createHierarchicalLayout(mandates: Mandate[], savedLayout?: Record<string, { x: number; y: number }>): Map<string, { x: number; y: number }> {
  const positions = new Map<string, { x: number; y: number }>()

  // If we have saved layout, use it first
  if (savedLayout) {
    mandates.forEach(mandate => {
      const mandateId = String(mandate.index)
      if (savedLayout[mandateId]) {
        positions.set(mandateId, savedLayout[mandateId])
      }
    })
    if (positions.size === mandates.length) {
      return positions
    }
  }

  // Build dependency and dependent maps
  const dependencies = new Map<string, Set<string>>()
  const dependents = new Map<string, Set<string>>()
  mandates.forEach(mandate => {
    const mandateId = String(mandate.index)
    dependencies.set(mandateId, new Set())
    dependents.set(mandateId, new Set())
  })
  mandates.forEach(mandate => {
    const mandateId = String(mandate.index)
    if (mandate.conditions) {
      if (mandate.conditions.needFulfilled != null && mandate.conditions.needFulfilled !== 0n) {
        const targetId = String(mandate.conditions.needFulfilled)
        if (dependencies.has(targetId)) {
          dependencies.get(mandateId)?.add(targetId)
          dependents.get(targetId)?.add(mandateId)
        }
      }
      if (mandate.conditions.needNotFulfilled != null && mandate.conditions.needNotFulfilled !== 0n) {
        const targetId = String(mandate.conditions.needNotFulfilled)
        if (dependencies.has(targetId)) {
          dependencies.get(mandateId)?.add(targetId)
          dependents.get(targetId)?.add(mandateId)
        }
      }
    }
  })

  // Find root nodes (no dependencies)
  const allMandateIds = mandates.map(mandate => String(mandate.index))
  const rootNodes = allMandateIds.filter(mandateId => (dependencies.get(mandateId)?.size || 0) === 0)

  // Layout constants (flipped axes)
  const NODE_SPACING_X = 500 // Now used for depth (main flow, horizontal)
  const NODE_SPACING_Y = 450 // Now used for siblings (vertical stack)

  // Track placed nodes to avoid cycles
  const placed = new Set<string>()

  // Compute the size (number of rows) of each subtree
  const subtreeSize = new Map<string, number>()
  function computeSubtreeSize(mandateId: string, visiting: Set<string> = new Set()): number {
    if (visiting.has(mandateId)) return 0; // Prevent cycles
    visiting.add(mandateId);
    const children = Array.from(dependents.get(mandateId) || [])
    if (children.length === 0) {
      subtreeSize.set(mandateId, 1)
      visiting.delete(mandateId);
      return 1
    }
    // Compute size for all children
    const sizes = children.map(childId => computeSubtreeSize(childId, visiting))
    const total = sizes.reduce((a, b) => a + b, 0)
    subtreeSize.set(mandateId, total)
    visiting.delete(mandateId);
    return total
  }
  rootNodes.forEach(rootId => computeSubtreeSize(rootId))

  // Track the next available y row
  let nextY = 0

  // Recursive function to place nodes (cycle-safe)
  function placeNode(mandateId: string, x: number, y: number, visiting: Set<string> = new Set()) {
    if (placed.has(mandateId)) return;
    if (visiting.has(mandateId)) return; // Prevent cycles
    placed.add(mandateId);
    positions.set(mandateId, { x: x * NODE_SPACING_X, y: y * NODE_SPACING_Y });

    visiting.add(mandateId);
    const children = Array.from(dependents.get(mandateId) || []);
    if (children.length === 0) {
      visiting.delete(mandateId);
      return;
    }
    // Sort children by subtree size descending, so the largest is the 'main' child
    children.sort((a, b) => (subtreeSize.get(b) || 1) - (subtreeSize.get(a) || 1));
    let childY = y;
    for (let i = 0; i < children.length; i++) {
      const childId = children[i];
      placeNode(childId, x + 1, childY, visiting);
      childY += subtreeSize.get(childId) || 1;
    }
    visiting.delete(mandateId);
  }

  // Place all root nodes, respecting sequence and grouping singletons
  let processingSingletons = false
  let singletonX = 0

  rootNodes.forEach(rootId => {
    // A singleton here is a root node with no dependents (no outgoing connections)
    // It is "unconnected" because it is a root (no incoming) and has no dependents (no outgoing)
    const isSingleton = (dependents.get(rootId)?.size || 0) === 0

    if (isSingleton) {
      if (!processingSingletons) {
        // Start a new singleton row
        processingSingletons = true
        singletonX = 0
        // We use the current nextY for this row
      }
      // Place singleton at current singletonX, nextY
      placeNode(rootId, singletonX, nextY)
      singletonX++
    } else {
      // It is a chain (connected root)
      if (processingSingletons) {
        // Finish the previous singleton row
        nextY += 1
        processingSingletons = false
      }
      
      // Place the chain starting at the new line
      placeNode(rootId, 0, nextY)
      nextY += subtreeSize.get(rootId) || 1
    }
  })

  // If we ended while processing singletons, we need to account for that row
  if (processingSingletons) {
    nextY += 1
  }

  // Place any unplaced nodes (disconnected cycles that are not roots)
  allMandateIds.forEach(mandateId => {
    if (!placed.has(mandateId)) {
      positions.set(mandateId, { x: 0, y: nextY * NODE_SPACING_Y })
      nextY += 1
      placed.add(mandateId)
    }
  })

  // --- COMPACTION PASS ---
  // Find all used y rows, sort, and remap to compact (no gaps)
  const usedYRows = Array.from(new Set(Array.from(positions.values()).map(pos => pos.y / NODE_SPACING_Y))).sort((a, b) => a - b)
  const yRowMap = new Map<number, number>()
  usedYRows.forEach((row, idx) => yRowMap.set(row, idx))
  // Shift all nodes up to fill gaps
    positions.forEach((pos, mandateId) => {
      const oldRow = pos.y / NODE_SPACING_Y
      const newRow = yRowMap.get(oldRow)
      if (newRow !== undefined) {
        positions.set(mandateId, { x: pos.x, y: newRow * NODE_SPACING_Y })
      }
    })

  return positions
}

// Store for viewport state persistence using localStorage
const VIEWPORT_STORAGE_KEY = 'powersflow-viewport'

const getStoredViewport = () => {
  if (typeof window === 'undefined') return null
  try {
    const stored = localStorage.getItem(VIEWPORT_STORAGE_KEY)
    return stored ? JSON.parse(stored) : null
  } catch {
    return null
  }
}

const setStoredViewport = (viewport: { x: number; y: number; zoom: number }) => {
  if (typeof window === 'undefined') return
  try {
    localStorage.setItem(VIEWPORT_STORAGE_KEY, JSON.stringify(viewport))
  } catch {
    // Ignore localStorage errors
  }
}

const FlowContent: React.FC = () => {
  const { getNodes, getViewport, setViewport } = useReactFlow()
  const { mandateId: selectedMandateId } = useParams<{mandateId: string }>()  
  const router = useRouter()
  const action = useActionStore()
  const [userHasInteracted, setUserHasInteracted] = React.useState(false)
  const reactFlowInstanceRef = React.useRef<ReturnType<typeof useReactFlow> | null>(null)
  const pathname = usePathname()
  const powers = usePowersStore()
  
  // Debounced layout saving
  const saveTimeoutRef = React.useRef<NodeJS.Timeout | null>(null)

  // Function to load saved layout from localStorage
  const loadSavedLayout = React.useCallback((): Record<string, { x: number; y: number }> | undefined => {
    try {
      const localStore = localStorage.getItem("powersProtocols")
      if (!localStore || localStore === "undefined") return undefined
      
      const saved: Powers[] = JSON.parse(localStore)
      const existing = saved.find(item => item.contractAddress === powers?.contractAddress as `0x${string}`)
      
      if (existing && existing.layout) {
        return existing.layout
      }
      
      return undefined
    } catch (error) {
      console.error('Failed to load layout from localStorage:', error)
      return undefined
    }
  }, [powers?.contractAddress])

  // Function to save powers object to localStorage (similar to usePowers.ts)
  const savePowersToLocalStorage = React.useCallback((updatedPowers: Powers) => {
    try {
      const localStore = localStorage.getItem("powersProtocols")
      const saved: Powers[] = localStore && localStore != "undefined" ? JSON.parse(localStore) : []
      const existing = saved.find(item => item.contractAddress === updatedPowers.contractAddress)
      if (existing) {
        saved.splice(saved.indexOf(existing), 1)
      }
      saved.push(updatedPowers)
      localStorage.setItem("powersProtocols", JSON.stringify(saved, (key, value) =>
        typeof value === "bigint" ? value.toString() : value,
      ))
    } catch (error) {
      console.error('Failed to save layout to localStorage:', error)
    }
  }, [])

  // Function to extract current layout from ReactFlow nodes
  const extractCurrentLayout = React.useCallback(() => {
    const nodes = getNodes()
    const layout: Record<string, { x: number; y: number }> = {}
    
    nodes.forEach(node => {
      layout[node.id] = {
        x: node.position.x,
        y: node.position.y
      }
    })
    
    return layout
  }, [getNodes])

  // Function to save layout to powers object and localStorage
  const saveLayout = React.useCallback(() => {
    const currentLayout = extractCurrentLayout()
    
    // Create updated powers object with layout data
    const updatedPowers: Powers = {
      ...powers as Powers,
      layout: currentLayout
    }
    
    // Save to localStorage
    savePowersToLocalStorage(updatedPowers)
  }, [powers, extractCurrentLayout, savePowersToLocalStorage])

  // Debounced save function
  const debouncedSaveLayout = React.useCallback(() => {
    // Clear existing timeout
    if (saveTimeoutRef.current) {
      clearTimeout(saveTimeoutRef.current)
    }
    
    // Set new timeout for 0.5 seconds
    saveTimeoutRef.current = setTimeout(() => {
      saveLayout()
    }, 500)
  }, [saveLayout])

  // Cleanup timeout on unmount
  React.useEffect(() => {
    return () => {
      if (saveTimeoutRef.current) {
        clearTimeout(saveTimeoutRef.current)
      }
    }
  }, [])


  // Helper function to calculate fitView options accounting for panel width
  const calculateFitViewOptions = useCallback(() => {
    return {
      padding: 0.2,
      duration: 800,
      includeHiddenNodes: false,
      minZoom: 0.1,
      maxZoom: 1.2,
    }
  }, [])

  // Custom fitView function that accounts for the side panel
  const fitViewWithPanel = useCallback(() => {
    const nodes = getNodes()
    if (nodes.length === 0) return

    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight
    const expandedPanelWidth = Math.min(640, viewportWidth - 40)
    const isSmallScreen = viewportWidth <= 2 * expandedPanelWidth
    // Calculate the available area for the flow chart (excluding panel)
    const availableWidth = isSmallScreen ? viewportWidth : viewportWidth - expandedPanelWidth
    const availableHeight = viewportHeight

    // Find the bounds of all nodes
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    nodes.forEach(node => {
      const nodeWidth = 380 // Node width from the component
      const nodeHeight = 300 // Approximate node height
      minX = Math.min(minX, node.position.x)
      minY = Math.min(minY, node.position.y)
      maxX = Math.max(maxX, node.position.x + nodeWidth)
      maxY = Math.max(maxY, node.position.y + nodeHeight)
    })
    // Add padding
    const padding = 100
    const contentWidth = maxX - minX + 2 * padding
    const contentHeight = maxY - minY + 2 * padding
    // Calculate zoom to fit content in available area
    const zoomX = availableWidth / contentWidth
    const zoomY = availableHeight / contentHeight
    const zoom = Math.min(zoomX, zoomY, 1.2) // Cap at max zoom
    // Calculate center position
    const contentCenterX = (minX + maxX) / 2
    const contentCenterY = (minY + maxY) / 2
    let x, y
    if (isSmallScreen) {
      // Center in the middle of the viewport
      x = -contentCenterX * zoom + viewportWidth / 2
      y = -contentCenterY * zoom + availableHeight / 2
    } else {
      // Offset for the panel as before
      const availableAreaCenterX = expandedPanelWidth + availableWidth / 2
      x = -contentCenterX * zoom + availableAreaCenterX
      y = -contentCenterY * zoom + availableHeight / 2
    }
    setViewport({ x, y, zoom }, { duration: 800 })
  }, [getNodes, setViewport])

  const handleNodeClick = useCallback((mandateId: string) => {
    // Store current viewport before navigation
    const currentViewport = getViewport()
    setStoredViewport(currentViewport)
    // console.log("@handleNodeClick: waypoint 0", {mandateId, action})
    // Navigate to the mandate page within the flow layout
    setAction({
      ...action,
      mandateId: BigInt(mandateId),
      upToDate: false
    })
    router.push(`/protocol/${powers?.chainId}/${powers?.contractAddress}/mandates/${mandateId}`)
    // console.log("@handleNodeClick: waypoint 1", {action})
  }, [router, powers?.contractAddress, action, getViewport])

  // Handle ReactFlow initialization
  const onInit = useCallback((reactFlowInstance: ReturnType<typeof useReactFlow>) => {
    reactFlowInstanceRef.current = reactFlowInstance
    
    const storedViewport = getStoredViewport()
    
    // Only fit view on initial page load (no selected mandate and no stored viewport)
    if (!action.mandateId && !selectedMandateId && !storedViewport) {
      setTimeout(() => {
        fitViewWithPanel()
        // Save the fitted viewport
        setTimeout(() => {
          const currentViewport = getViewport()
          setStoredViewport(currentViewport)
        }, 900)
      }, 100)
    } else if (storedViewport) {
      // Restore stored viewport
      setTimeout(() => {
        setViewport(storedViewport, { duration: 0 })
      }, 100)
    }
  }, [setViewport, getViewport, action.mandateId, selectedMandateId, fitViewWithPanel])


  // Reset user interaction flag when navigating to home page
  React.useEffect(() => {
    const isHomePage = !pathname.includes('/mandates/')
    if (isHomePage) {
      setUserHasInteracted(false)
    }
  }, [pathname])



  // Create nodes and edges from mandates
  const { initialNodes, initialEdges } = useMemo(() => {
    if (!powers?.mandates) return { initialNodes: [], initialEdges: [] }
    const ActiveMandates = powers?.mandates.filter(mandate => mandate.active)
    if (!ActiveMandates) return { initialNodes: [], initialEdges: [] }
    
    const nodes: Node[] = []
    const edges: Edge[] = []
    
    // Use hierarchical layout instead of simple grid
    const savedLayout = loadSavedLayout()
    const positions = createHierarchicalLayout(ActiveMandates || [], savedLayout)
    
    // Find connected nodes if a mandate is selected
    const selectedMandateIdFromStore = action.mandateId !== 0n ? String(action.mandateId) : undefined
    const connectedNodes = selectedMandateIdFromStore 
      ? findConnectedNodes(powers as Powers, selectedMandateIdFromStore as string)
      : undefined
    
    // Get the selected action from the store
    const selectedAction = action.actionId !== "0" ? action : undefined
    
    // Get action data for all mandates in the chain
    const chainActionData = getActionDataForChain(
      selectedAction,
      ActiveMandates || [],
      powers
    )
    
    ActiveMandates?.forEach((mandate) => {
      const roleColor = DEFAULT_NODE_COLOR
      const mandateId = String(mandate.index)
      const position = positions.get(mandateId) || { x: 0, y: 0 }
      
      // Create mandate schema node
      nodes.push({
        id: mandateId,
        type: 'mandateSchema',  
        position,
        data: {
          powers,
          mandate,
          roleColor,
          onNodeClick: handleNodeClick,
          selectedMandateId: selectedMandateIdFromStore,
          connectedNodes,
          actionDataTimestamp: Date.now(),
          selectedAction,
          chainActionData,
        },
      })
      
      // Create edges from dependency checks to target mandates
      if (mandate.conditions) {
        const sourceId = mandateId
        
        // Check if the source mandate's action is fulfilled
        const sourceAction = chainActionData.get(sourceId)
        const isSourceFulfilled = sourceAction && sourceAction.fulfilledAt && sourceAction.fulfilledAt > 0n
        const edgeColor = '#6B7280' // green-600 if fulfilled, gray otherwise // turned off for now: isSourceFulfilled ? '#16a34a' :
        
        // Edge from needFulfilled check to target mandate
        if (mandate.conditions.needFulfilled != null && mandate.conditions.needFulfilled !== 0n) {
          const targetId = String(mandate.conditions.needFulfilled)
          // Determine if this edge should be highlighted (connected to selected node)
          const isEdgeConnected = !connectedNodes || connectedNodes.has(sourceId) || connectedNodes.has(targetId)
          const edgeOpacity = isEdgeConnected ? 1 : 0.5
          
          edges.push({
            id: `${sourceId}-needFulfilled-${targetId}`,
            source: sourceId,
            sourceHandle: 'needFulfilled-handle',
            target: targetId,
            targetHandle: 'fulfilled-target',
            type: 'smoothstep',
            label: 'Needs Fulfilled',
            style: { stroke: edgeColor, strokeWidth: 2, opacity: edgeOpacity },
            labelStyle: { fontSize: '10px', fontWeight: 'bold', fill: edgeColor, opacity: edgeOpacity },
            labelBgStyle: { fill: '#f1f5f9', fillOpacity: 0.8 * edgeOpacity },
            markerStart: {
              type: MarkerType.ArrowClosed,
              color: edgeColor,
              width: 20,
              height: 20,
            },
            zIndex: 10,
          })
        }
        
        // Edge from needNotFulfilled check to target mandate
        if (mandate.conditions.needNotFulfilled != null && mandate.conditions.needNotFulfilled != 0n) {
          const targetId = String(mandate.conditions.needNotFulfilled)
          // Determine if this edge should be highlighted (connected to selected node)
          const isEdgeConnected = !connectedNodes || connectedNodes.has(sourceId) || connectedNodes.has(targetId)
          const edgeOpacity = isEdgeConnected ? 1 : 0.5
          
          edges.push({
            id: `${sourceId}-needNotFulfilled-${targetId}`,
            source: sourceId,
            sourceHandle: 'needNotFulfilled-handle',
            target: targetId,
            targetHandle: 'fulfilled-target',
            type: 'smoothstep',
            label: 'Needs Not Fulfilled',
            style: { stroke: edgeColor, strokeWidth: 2, strokeDasharray: '6,3', opacity: edgeOpacity },
            labelStyle: { fontSize: '10px', fontWeight: 'bold', fill: edgeColor, opacity: edgeOpacity },
            labelBgStyle: { fill: '#f1f5f9', fillOpacity: 0.8 * edgeOpacity },
            markerStart: {
              type: MarkerType.ArrowClosed,
              color: edgeColor,
              width: 20,
              height: 20,
            },
            zIndex: 10,
          })
        }
        
      
      }
    })
    
    return { initialNodes: nodes, initialEdges: edges }
  }, [
    powers,
    handleNodeClick, 
    selectedMandateId, 
    action.mandateId, 
    loadSavedLayout
  ])

  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes)
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges)

  const onConnect = useCallback(
    (params: Connection) => setEdges((eds) => addEdge(params, eds)),
    [setEdges],
  )

  // Save viewport state when user manually pans/zooms
  const onMoveEnd = useCallback(() => {
    const currentViewport = getViewport()
    setStoredViewport(currentViewport)
    // Mark that user has interacted with viewport
    setUserHasInteracted(true)
    // Trigger debounced layout save when viewport changes
    debouncedSaveLayout()
  }, [getViewport, debouncedSaveLayout])

  // Track user interactions with viewport
  const onMoveStart = useCallback(() => {
    setUserHasInteracted(true)
  }, [])

  // Reset user interaction flag after a period of inactivity
  React.useEffect(() => {
    if (userHasInteracted) {
      const timer = setTimeout(() => {
        setUserHasInteracted(false)
      }, 3000) // Reset after 3 seconds of no interaction
      
      return () => clearTimeout(timer)
    }
  }, [userHasInteracted])

  // Update nodes when props change
  React.useEffect(() => {
    setNodes(initialNodes)
  }, [initialNodes, setNodes])

  // Update edges when props change
  React.useEffect(() => {
    setEdges(initialEdges)
  }, [initialEdges, setEdges])

  // Node drag handlers to trigger layout saving
  const onNodeDragStop = useCallback(() => {
    setUserHasInteracted(true) // Mark interaction when dragging nodes
    debouncedSaveLayout()
  }, [debouncedSaveLayout])

  const onNodesChangeWithSave = useCallback((changes: { type: string; dragging?: boolean; id?: string }[]) => {
    onNodesChange(changes as any[])
    // Check if any node was dragged
    const hasDragChange = changes.some((change) => change.type === 'position' && change.dragging === false)
    if (hasDragChange) {
      setUserHasInteracted(true) // Mark interaction when dragging nodes
      debouncedSaveLayout()
    }
  }, [onNodesChange, debouncedSaveLayout])
  
  const ActiveMandates = powers?.mandates?.filter(mandate => mandate.active)
  if (!ActiveMandates || ActiveMandates.length === 0) {
    return (
      <div className="w-full h-full flex items-center justify-center bg-gray-50 rounded-lg">
        <div className="text-center">
          <div className="text-gray-500 text-lg mb-2">No active mandates found</div>
          <div className="text-gray-400 text-sm">Deploy some mandates to see the visualization</div>
          <div className="text-gray-400 text-sm">Or press the refresh button to load the latest mandates</div>
        </div>
      </div>
    )
  }

  return (
    <div className="w-full h-full bg-slate-100 overflow-hidden">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChangeWithSave}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
        nodeTypes={nodeTypes}
        connectionMode={ConnectionMode.Loose}
        fitView={false}
        fitViewOptions={calculateFitViewOptions()}
        attributionPosition="bottom-left"
        nodesDraggable={true}
        nodesConnectable={false}
        elementsSelectable={true}
        maxZoom={1.2} // Also set global max zoom
        minZoom={0.1} // Global min zoom
        panOnDrag={true}
        zoomOnScroll={true}
        zoomOnPinch={true}
        zoomOnDoubleClick={true}
        panOnScroll={false}
        preventScrolling={true}
        onMoveStart={onMoveStart}
        onMoveEnd={onMoveEnd}
        onInit={onInit}
        onNodeDragStop={onNodeDragStop}
      >
        <Background />
        <MiniMap 
          nodeColor={(node) => {
            const nodeData = node.data as MandateSchemaNodeData
            return nodeData.roleColor
          }}
          nodeStrokeWidth={3}
          nodeStrokeColor="#000000"
          nodeBorderRadius={8}
          maskColor="rgba(50, 50, 50, 0.6)"
          position="bottom-right"
          pannable={true}
          zoomable={true}
          ariaLabel="Flow diagram minimap"
        />
      </ReactFlow>
    </div>
  )
}

export const PowersFlow: React.FC = React.memo(() => {
  return (
    <ReactFlowProvider>
      <FlowContent />
    </ReactFlowProvider>
  )
})

export default PowersFlow
