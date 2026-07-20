'use client'

import React, { useMemo } from 'react'
import {
  Handle,
  Position,
  NodeProps,
} from 'reactflow'
import { Mandate, Powers, Action, Status, Flow } from '@/context/types'
import { toFullDateFormat, toEurTimeFormat } from '@/utils/toDates'
import { useBlocks, L2_TO_L1_CHAIN_MAP } from '@/hooks/useBlocks'
import { parseChainId } from '@/utils/parsers'
import { fromFutureBlockToDateTime } from '@/public/organisations/helpers'
import { useBlockNumber } from 'wagmi'
import {
  CalendarDaysIcon,
  QueueListIcon,
  DocumentCheckIcon,
  ClipboardDocumentCheckIcon,
  CheckCircleIcon,
  RocketLaunchIcon,
  FlagIcon,
} from '@heroicons/react/24/outline'
import { bigintToRole } from '@/utils/bigintTo'
import { hashAction } from '@/utils/hashAction'

// Node dimensions
export const NODE_WIDTH = 220
export const NODE_HEIGHT = 200      // estimated mandate node height for bounding box calc
export const NODE_SPACING_X = 280
export const NODE_SPACING_Y = 260

// Flow group layout constants
export const FLOW_PADDING = 40
export const FLOW_HEADER_HEIGHT = 52
export const FLOW_SPACING_Y = 80
export const FLOW_SPACING_X = 40

// Handle styling
const HANDLE_STYLE = {
  width: 7,
  height: 7,
  background: 'hsl(var(--muted-foreground))',
  border: 'none',
}

// Helper function to get action data for all mandates in the dependency chain
export function getActionDataForChain(
  selectedAction: Action | undefined,
  mandates: Mandate[],
  powers: Powers
): Map<string, Action> {
  const actionDataMap = new Map<string, Action>()

  if (!selectedAction || !selectedAction.callData || !selectedAction.nonce) {
    return actionDataMap
  }

  mandates.forEach(mandate => {
    const mandateId = mandate.index
    const calculatedActionId = hashAction(mandateId, selectedAction.callData!, BigInt(selectedAction.nonce!))

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

// FlowGroupNode — renders a labeled bounding box for a flow
export const FlowGroupNode: React.FC<NodeProps<{ nameDescription: string; isDimmedGroup?: boolean }>> = ({ data }) => {
  const parts = (data.nameDescription ?? '').split(':')
  const name = parts[0]?.trim() ?? 'Flow'
  const description = parts.slice(1).join(':').trim()
  const dimmed = data.isDimmedGroup ?? false

  return (
    <div className={`w-full h-full border border-dashed rounded-sm bg-muted/15 transition-all ${dimmed ? 'border-border/30' : 'border-border'}`}>
      <div className={`px-3 py-2.5 border-b border-dashed transition-all ${dimmed ? 'border-border/30' : 'border-border'}`}>
        <span className={`text-xs font-mono font-semibold uppercase tracking-wide transition-all ${dimmed ? 'text-foreground/30' : 'text-foreground'}`}>
          {name}
        </span>
        {description && (
          <p className={`text-[11px] font-mono mt-0.5 line-clamp-2 transition-all ${dimmed ? 'text-foreground/20' : 'text-foreground/70'}`}>
            {description}
          </p>
        )}
      </div>
    </div>
  )
}

export interface MandateSchemaNodeData {
  mandate: Mandate
  powers: Powers
  onNodeClick: (mandateId: string) => void
  chainActionData: Map<string, Action>
  chainId: string
  isHighlighted?: boolean
  isDimmed?: boolean
}

const MandateSchemaNode: React.FC<NodeProps<MandateSchemaNodeData>> = ({ data }) => {
  const { mandate, powers, onNodeClick, chainActionData, chainId, isHighlighted, isDimmed } = data
  const { timestamps, fetchTimestamps } = useBlocks()
  const parsedChainIdForBlock = parseChainId(chainId) as number
  const blockChainId = (L2_TO_L1_CHAIN_MAP[parsedChainIdForBlock] ?? parsedChainIdForBlock) as number
  const { data: blockNumber } = useBlockNumber({ chainId: blockChainId })
  const cond = mandate.conditions

  const nameParts = mandate.nameDescription?.split(':') ?? []
  const mandateName = nameParts[0]?.trim() ?? `Mandate ${mandate.index}`
  const mandateDescription = nameParts.slice(1).join(':').trim()
  const roleName = cond ? bigintToRole(cond.allowedRole, powers) : ''

  const hasVote = cond?.quorum != null && cond.quorum > 0n
  const hasTimelock = cond?.timelock != null && cond.timelock > 0n
  const hasThrottle = cond?.throttleExecution != null && cond.throttleExecution > 0n
  const needsFulfilled = !!(cond?.needFulfilled && cond.needFulfilled !== 0n)
  const needsNotFulfilled = !!(cond?.needNotFulfilled && cond.needNotFulfilled !== 0n)

  const currentMandateAction = chainActionData.get(String(mandate.index))

  React.useEffect(() => {
    if (currentMandateAction) {
      const blockNumbers: bigint[] = []

      if (currentMandateAction.proposedAt && currentMandateAction.proposedAt !== 0n) {
        blockNumbers.push(currentMandateAction.proposedAt)
      }
      if (currentMandateAction.requestedAt && currentMandateAction.requestedAt !== 0n) {
        blockNumbers.push(currentMandateAction.requestedAt)
      }
      if (currentMandateAction.fulfilledAt && currentMandateAction.fulfilledAt !== 0n) {
        blockNumbers.push(currentMandateAction.fulfilledAt)
      }

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

      if (blockNumbers.length > 0) {
        fetchTimestamps(blockNumbers, chainId)
      }
    }
  }, [chainActionData, mandate.index, mandate.conditions, chainId, fetchTimestamps, currentMandateAction])

  const formatBlockNumberOrTimestamp = (value: bigint | undefined): string | null => {
    if (!value || value === 0n) return null

    try {
      const cacheKey = `${chainId}:${value}`
      const cachedTimestamp = timestamps.get(cacheKey)

      if (cachedTimestamp && cachedTimestamp.timestamp) {
        const timestampNumber = Number(cachedTimestamp.timestamp)
        return `${toFullDateFormat(timestampNumber)}: ${toEurTimeFormat(timestampNumber)}`
      }

      const valueNumber = Number(value)
      if (valueNumber > 1000000000) {
        return `${toFullDateFormat(valueNumber)}: ${toEurTimeFormat(valueNumber)}`
      }

      return null
    } catch {
      return null
    }
  }

  const getCheckItemDate = (itemKey: string): string | null => {
    switch (itemKey) {
      case 'needFulfilled':
      case 'needNotFulfilled': {
        const dependentMandateId = itemKey === 'needFulfilled'
          ? mandate.conditions?.needFulfilled
          : mandate.conditions?.needNotFulfilled
        if (dependentMandateId && dependentMandateId != 0n) {
          return formatBlockNumberOrTimestamp(chainActionData.get(String(dependentMandateId))?.fulfilledAt)
        }
        return null
      }
      case 'proposalCreated':
        return currentMandateAction?.proposedAt && currentMandateAction.proposedAt != 0n
          ? formatBlockNumberOrTimestamp(currentMandateAction.proposedAt)
          : null
      case 'voteEnded': {
        if (currentMandateAction?.proposedAt && currentMandateAction.proposedAt != 0n && mandate.conditions?.votingPeriod && blockNumber != null) {
          const parsedChainId = parseChainId(chainId)
          if (!parsedChainId) return null
          return fromFutureBlockToDateTime(
            BigInt(currentMandateAction.proposedAt) + BigInt(mandate.conditions.votingPeriod),
            BigInt(blockNumber),
            parsedChainId
          )
        }
        return null
      }
      case 'delay': {
        if (currentMandateAction?.proposedAt && currentMandateAction.proposedAt != 0n && mandate.conditions?.timelock && mandate.conditions.timelock != 0n && blockNumber != null) {
          const parsedChainId = parseChainId(chainId)
          if (!parsedChainId) return null
          return fromFutureBlockToDateTime(
            BigInt(currentMandateAction.proposedAt) + BigInt(mandate.conditions.timelock),
            BigInt(blockNumber),
            parsedChainId
          )
        }
        return null
      }
      case 'requested':
        return currentMandateAction?.requestedAt && currentMandateAction.requestedAt != 0n
          ? formatBlockNumberOrTimestamp(currentMandateAction.requestedAt)
          : null
      case 'throttle': {
        if (mandate.conditions?.throttleExecution && blockNumber != null) {
          const latestFulfilledAction = mandate.actions
            ? Math.max(...mandate.actions.map(a => Number(a.fulfilledAt)), 1)
            : 0
          const parsedChainId = parseChainId(chainId)
          if (!parsedChainId) return null
          return fromFutureBlockToDateTime(
            BigInt(latestFulfilledAction + Number(mandate.conditions.throttleExecution)),
            BigInt(blockNumber),
            parsedChainId
          )
        }
        return null
      }
      case 'fulfilled':
        return currentMandateAction?.fulfilledAt && currentMandateAction.fulfilledAt != 0n
          ? formatBlockNumberOrTimestamp(currentMandateAction.fulfilledAt)
          : null
      default:
        return null
    }
  }

  const getCheckItemStatus = (itemKey: string): Status => {
    switch (itemKey) {
      case 'needFulfilled': {
        const a = chainActionData.get(String(mandate.conditions?.needFulfilled))
        return a?.fulfilledAt && a.fulfilledAt > 0n ? "success" : "pending"
      }
      case 'needNotFulfilled': {
        const a = chainActionData.get(String(mandate.conditions?.needNotFulfilled))
        return a?.fulfilledAt && a.fulfilledAt > 0n ? "error" : "success"
      }
      case 'throttle': {
        const latest = mandate.actions
          ? Math.max(...mandate.actions.map(a => Number(a.fulfilledAt)), 1)
          : 0
        return (latest + Number(mandate.conditions?.throttleExecution || 0)) < Number(blockNumber || 0)
          ? "success" : "error"
      }
      case 'proposalCreated':
        return currentMandateAction?.proposedAt && currentMandateAction.proposedAt > 0n ? "success" : "pending"
      case 'voteEnded':
        return currentMandateAction?.state === 4 ? "error" :
               currentMandateAction?.state != null && currentMandateAction.state >= 5 ? "success" : "pending"
      case 'delay':
        return currentMandateAction?.proposedAt && mandate.conditions?.timelock
          ? currentMandateAction.proposedAt + mandate.conditions.timelock < BigInt(blockNumber || 0)
            ? "success" : "pending"
          : "pending"
      case 'requested':
        return currentMandateAction?.requestedAt && currentMandateAction.requestedAt > 0n ? "success" : "pending"
      case 'fulfilled':
        return currentMandateAction?.fulfilledAt && currentMandateAction.fulfilledAt > 0n ? "success" : "pending"
      default:
        return "pending"
    }
  }

  const checkItems = useMemo(() => {
    const items: { key: string; label: string; icon: React.ElementType }[] = []
    if (needsFulfilled) items.push({ key: 'needFulfilled', label: `#${cond!.needFulfilled.toString()} fulfilled`, icon: DocumentCheckIcon })
    if (needsNotFulfilled) items.push({ key: 'needNotFulfilled', label: `#${cond!.needNotFulfilled.toString()} not fulfilled`, icon: DocumentCheckIcon })
    if (hasThrottle) items.push({ key: 'throttle', label: 'Throttle passed', icon: QueueListIcon })
    if (hasVote || hasTimelock) items.push({ key: 'proposalCreated', label: 'Proposal created', icon: ClipboardDocumentCheckIcon })
    if (hasVote) items.push({ key: 'voteEnded', label: 'Vote ended', icon: FlagIcon })
    if (hasTimelock) items.push({ key: 'delay', label: 'Delay passed', icon: CalendarDaysIcon })
    items.push({ key: 'requested', label: 'Requested', icon: CheckCircleIcon })
    items.push({ key: 'fulfilled', label: 'Fulfilled', icon: RocketLaunchIcon })
    return items
  }, [needsFulfilled, needsNotFulfilled, hasThrottle, hasVote, hasTimelock, cond])

  return (
    <div
      className={`bg-background border font-mono transition-all ${
        isHighlighted ? 'border-primary/60 border-2' : 'border-border'
      } ${
        !mandate.active || isDimmed ? 'opacity-50' : 'cursor-pointer hover:border-primary'
      } ${
        !mandate.active ? 'cursor-not-allowed' : ''
      }`}
      style={{ width: NODE_WIDTH }}
      onClick={() => {
        if (mandate.active) onNodeClick(String(mandate.index))
      }}
    >
      <div className="px-3 py-2 border-b border-border bg-muted/50">
        <div className="flex items-baseline gap-1.5">
          <span className="text-[10px] text-muted-foreground shrink-0">
            #{mandate.index.toString()}
          </span>
          <span className="text-xs font-semibold text-foreground truncate">{mandateName}</span>
        </div>
        {mandateDescription && (
          <p className="text-[9px] text-muted-foreground/70 mt-0.5 line-clamp-2">{mandateDescription}</p>
        )}
        {roleName && (
          <span className="text-[10px] text-muted-foreground">{roleName}</span>
        )}
      </div>

      <div className="px-3 py-2 space-y-1.5 text-[10px] text-muted-foreground">
        {checkItems.map((item) => {
          const status = getCheckItemStatus(item.key)
          const date = getCheckItemDate(item.key)
          const Icon = item.icon
          const iconColor = status === "success" ? 'text-foreground' : status === "error" ? 'text-red-600' : 'text-muted-foreground/70'

          return (
            <div key={item.key} className="relative flex flex-col gap-0.5">
              {date && (
                <div className="text-[9px] text-muted-foreground/70">{date}</div>
              )}
              <div className="flex items-center gap-1.5">
                {needsFulfilled && item.key === 'needFulfilled' && (
                  <Handle
                    type="source"
                    position={Position.Left}
                    id="needFulfilled-handle"
                    style={{ ...HANDLE_STYLE, left: -18, background: 'transparent', border: 'none' }}
                  />
                )}
                {needsNotFulfilled && item.key === 'needNotFulfilled' && (
                  <Handle
                    type="source"
                    position={Position.Left}
                    id="needNotFulfilled-handle"
                    style={{ ...HANDLE_STYLE, left: -18, background: 'transparent', border: 'none' }}
                  />
                )}
                <Icon className={`w-3 h-3 shrink-0 ${iconColor}`} />
                <span className={iconColor}>{item.label}</span>
                {item.key === 'fulfilled' && (
                  <Handle
                    type="target"
                    position={Position.Right}
                    id="fulfilled-target"
                    style={{ ...HANDLE_STYLE, right: -4 }}
                  />
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

export const nodeTypes = {
  mandateSchema: MandateSchemaNode,
  flowGroup: FlowGroupNode,
}

// Returns mandates grouped into horizontal rows: each linear dependency chain becomes
// one row (left-to-right), independent mandates each get their own row.
function computeChainRows(mandates: Mandate[]): Mandate[][] {
  const ids = new Set(mandates.map(m => String(m.index)))
  const outEdges = new Map<string, string[]>()
  const inEdges = new Map<string, string[]>()

  mandates.forEach(m => {
    outEdges.set(String(m.index), [])
    inEdges.set(String(m.index), [])
  })

  mandates.forEach(m => {
    const id = String(m.index)
    ;[m.conditions?.needFulfilled, m.conditions?.needNotFulfilled]
      .filter((d): d is bigint => d != null && d !== 0n && ids.has(String(d)))
      .forEach(d => {
        const depId = String(d)
        outEdges.get(depId)!.push(id)
        inEdges.get(id)!.push(depId)
      })
  })

  const sorted = [...mandates].sort((a, b) => Number(a.index) - Number(b.index))
  const assigned = new Set<string>()
  const rows: Mandate[][] = []

  sorted.forEach(startMandate => {
    const startId = String(startMandate.index)
    if (assigned.has(startId)) return
    if (inEdges.get(startId)!.length > 0) return // reached later via chain tracing

    const row: Mandate[] = [startMandate]
    assigned.add(startId)

    let current = startId
    while (true) {
      const succs = outEdges.get(current)!
      if (succs.length !== 1) break
      const nextId = succs[0]
      if (assigned.has(nextId)) break
      if (inEdges.get(nextId)!.length !== 1) break // join node — start new row

      const nextMandate = sorted.find(m => String(m.index) === nextId)
      if (!nextMandate) break
      row.push(nextMandate)
      assigned.add(nextId)
      current = nextId
    }

    rows.push(row)
  })

  // Handle cycles or unreachable nodes
  const unvisited = sorted.filter(m => !assigned.has(String(m.index)))
  if (unvisited.length > 0) rows.push(unvisited)

  // Merge consecutive single-mandate rows into one row
  const merged: Mandate[][] = []
  let i = 0
  while (i < rows.length) {
    if (rows[i].length === 1) {
      const group: Mandate[] = [rows[i][0]]
      while (i + 1 < rows.length && rows[i + 1].length === 1) {
        i++
        group.push(rows[i][0])
      }
      merged.push(group)
    } else {
      merged.push(rows[i])
    }
    i++
  }

  return merged
}

export interface FlowGroupLayoutData {
  id: string
  nameDescription: string
  x: number
  y: number
  width: number
  height: number
}

// Build layout positions from the flows struct.
// Returns mandate positions (relative to their group) and group positions/sizes (absolute).
export function createAllFlowsLayout(
  mandates: Mandate[],
  flows: Flow[]
): {
  mandatePositions: Map<string, { x: number; y: number }>
  flowGroupData: FlowGroupLayoutData[]
} {
  const mandatePositions = new Map<string, { x: number; y: number }>()
  const flowGroupData: FlowGroupLayoutData[] = []

  type GroupInfo = { id: string; nameDescription: string; mandates: Mandate[] }
  const assignedIds = new Set<string>()
  const groups: GroupInfo[] = []

  flows.forEach((flow, idx) => {
    const flowMandates = flow.mandateIds
      .map(id => mandates.find(m => m.index === id))
      .filter((m): m is Mandate => m !== undefined)
    if (flowMandates.length === 0) return
    flowMandates.forEach(m => assignedIds.add(String(m.index)))
    groups.push({ id: `flow-${idx}`, nameDescription: flow.nameDescription, mandates: flowMandates })
  })

  const orphans = mandates.filter(m => !assignedIds.has(String(m.index)))
  if (orphans.length > 0) {
    groups.push({ id: 'flow-orphan', nameDescription: 'Other', mandates: orphans })
  }

  const singleGroups = groups.filter(g => g.mandates.length === 1)
  const multiGroups = groups.filter(g => g.mandates.length > 1)

  // Single-mandate flows: horizontal row at top
  let singleRowMaxHeight = 0
  let currentX = 0

  singleGroups.forEach(fg => {
    const mandate = fg.mandates[0]
    const groupWidth = NODE_WIDTH + 2 * FLOW_PADDING
    const groupHeight = NODE_HEIGHT + FLOW_HEADER_HEIGHT + 2 * FLOW_PADDING

    mandatePositions.set(String(mandate.index), {
      x: FLOW_PADDING,
      y: FLOW_HEADER_HEIGHT + FLOW_PADDING,
    })

    flowGroupData.push({
      id: fg.id,
      nameDescription: fg.nameDescription,
      x: currentX,
      y: 0,
      width: groupWidth,
      height: groupHeight,
    })

    singleRowMaxHeight = Math.max(singleRowMaxHeight, groupHeight)
    currentX += groupWidth + FLOW_SPACING_X
  })

  // Multi-mandate flows: stacked vertically below single row
  let currentY = singleGroups.length > 0 ? singleRowMaxHeight + FLOW_SPACING_Y : 0

  multiGroups.forEach(fg => {
    const rows = computeChainRows(fg.mandates)
    const maxCols = Math.max(...rows.map(r => r.length), 1)

    let localMaxY = 0
    rows.forEach((row, rowIdx) => {
      row.forEach((mandate, colIdx) => {
        const relX = FLOW_PADDING + colIdx * NODE_SPACING_X
        const relY = FLOW_HEADER_HEIGHT + FLOW_PADDING + rowIdx * NODE_SPACING_Y
        mandatePositions.set(String(mandate.index), { x: relX, y: relY })
        localMaxY = Math.max(localMaxY, relY + NODE_HEIGHT)
      })
    })

    const groupWidth = (maxCols - 1) * NODE_SPACING_X + NODE_WIDTH + 2 * FLOW_PADDING
    const groupHeight = localMaxY + FLOW_PADDING

    flowGroupData.push({
      id: fg.id,
      nameDescription: fg.nameDescription,
      x: 0,
      y: currentY,
      width: groupWidth,
      height: groupHeight,
    })

    currentY += groupHeight + FLOW_SPACING_Y
  })

  return { mandatePositions, flowGroupData }
}
