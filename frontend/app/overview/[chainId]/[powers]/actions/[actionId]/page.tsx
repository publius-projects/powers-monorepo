"use client";

import React, { useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { setAction, usePowersStore, useUIStateStore } from "@/context/store";
import { Action } from "@/context/types";
import { parseProposalStatus, shorterDescription } from "@/utils/parsers";
import { toFullDateFormat, toEurTimeFormat } from "@/utils/toDates";
import { useBlocks } from "@/hooks/useBlocks";
import { OrgBanner } from "@/components/OrgBanner";
import { callDataToActionParams } from "@/utils/callDataToActionParams";

const STATE_STYLES: Record<number, string> = {
  0: 'text-muted-foreground bg-muted',
  1: 'text-blue-600 bg-blue-100',
  2: 'text-red-600 bg-red-100',
  3: 'text-orange-600 bg-orange-100',
  4: 'text-red-600 bg-red-100',
  5: 'text-green-600 bg-green-100',
  6: 'text-blue-600 bg-blue-100',
  7: 'text-green-800 bg-green-200',
}

export default function ActionDetailPage() {
  const { actionId, chainId, powers: powersAddress } = useParams<{ actionId: string; chainId: string; powers: string }>()
  const router = useRouter()
  const powers = usePowersStore()
  const { setHighlightMode } = useUIStateStore()
  const { timestamps, fetchTimestamps } = useBlocks()

  // Find all occurrences of this actionId across all mandates
  const occurrences = React.useMemo(() => {
    if (!powers?.mandates || !actionId) return []
    const results: { mandateId: bigint; mandateName: string; action: Action }[] = []
    powers.mandates.forEach(mandate => {
      const found = mandate.actions?.find(a => a.actionId === actionId)
      if (found) {
        results.push({
          mandateId: mandate.index,
          mandateName: shorterDescription(mandate.nameDescription, 'short') ?? `Mandate ${mandate.index}`,
          action: found,
        })
      }
    })
    return results
  }, [powers?.mandates, actionId])

  // First occurrence with param data for the inputs panel
  const primaryOccurrence = occurrences[0]?.action
  const primaryMandate = powers?.mandates?.find(m => m.index === occurrences[0]?.mandateId)

  // Decode the encoded callData into displayable input values against the mandate's params
  const decodedInputs = React.useMemo(() => {
    if (!primaryOccurrence?.callData || !primaryMandate?.params?.length) return []
    try {
      return callDataToActionParams(primaryOccurrence, powers)
    } catch {
      return []
    }
  }, [primaryOccurrence?.callData, primaryMandate?.index, powers])

  useEffect(() => {
    if (occurrences.length > 0) {
      setHighlightMode({
        type: 'action',
        mandateIds: new Set(occurrences.map(o => String(o.mandateId))),
      })
    }
  }, [actionId, occurrences.length])

  useEffect(() => {
    if (primaryOccurrence) {
      setAction({ ...primaryOccurrence, upToDate: true })
    }
  }, [primaryOccurrence?.actionId])

  useEffect(() => {
    return () => { setAction({ actionId: "0" }) }
  }, [])

  useEffect(() => {
    const blockNums = occurrences.flatMap(o => {
      const a = o.action
      return [a.proposedAt, a.requestedAt, a.fulfilledAt, a.cancelledAt].filter((b): b is bigint => !!b && b > 0n)
    })
    if (blockNums.length > 0) fetchTimestamps(blockNums, chainId)
  }, [occurrences, chainId, fetchTimestamps])

  const formatTs = (block: bigint | undefined): string => {
    if (!block || block === 0n) return '—'
    const cached = timestamps.get(`${chainId}:${block}`)
    if (!cached?.timestamp || cached.timestamp <= 0n) return 'Loading...'
    try { return `${toFullDateFormat(Number(cached.timestamp))}: ${toEurTimeFormat(Number(cached.timestamp))}` }
    catch { return 'Date error' }
  }

  if (!actionId) return null

  return (
    <main className="w-full h-full flex flex-col bg-background pb-16">
      <OrgBanner title="Action" subtitle={actionId ?? ''} backButton={{ label: "ALL ACTIONS", href: `/overview/${chainId}/${powersAddress}/actions` }} />
      <div className="px-4 flex flex-col gap-6 mt-6">

      {/* Input parameters */}
      {primaryMandate && primaryOccurrence && (primaryMandate.params?.length ?? 0) > 0 && (
        <div className="flex flex-col gap-2">
          <span className="text-[10px] font-mono text-muted-foreground uppercase tracking-wider">Inputs</span>
          <div className="border border-border divide-y divide-border">
            {primaryMandate.params?.map((param, i) => (
              <div key={i} className="flex flex-row items-center gap-3 px-3 py-2 font-mono text-xs">
                <span className="text-muted-foreground w-32 truncate">{param.varName}</span>
                <span className="text-foreground/50 text-[10px]">{param.dataType}</span>
                <span className="text-foreground ml-auto truncate max-w-48">
                  {decodedInputs[i] !== undefined ? String(decodedInputs[i]) : '—'}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Action State */}
      <div className="flex flex-col gap-2">
        <span className="text-[10px] font-mono text-muted-foreground uppercase tracking-wider">
          Action State
        </span>
        {occurrences.length === 0 ? (
          <p className="text-xs text-muted-foreground font-mono">No mandate occurrences found.</p>
        ) : (
          <div className="border border-border divide-y divide-border">
            {occurrences.map(({ mandateId, mandateName, action: a }) => (
              <div key={String(mandateId)} className="flex flex-col gap-1.5 px-3 py-3 font-mono text-xs">
                <div className="flex items-center justify-between">
                  <button
                    className="text-foreground hover:text-primary hover:underline transition-colors text-left"
                    onClick={() => router.push(`/overview/${chainId}/${powersAddress}/mandates/${mandateId}`)}
                  >
                    #{String(mandateId)} {mandateName}
                  </button>
                  <span className={`px-2 py-0.5 text-[10px] ${STATE_STYLES[a.state ?? 0] ?? STATE_STYLES[0]}`}>
                    {parseProposalStatus(String(a.state))}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-x-4 gap-y-0.5 text-[10px] text-muted-foreground">
                  {(a.proposedAt ?? 0n) > 0n && (
                    <><span>Proposed</span><span>{formatTs(a.proposedAt)}</span></>
                  )}
                  {(a.requestedAt ?? 0n) > 0n && (
                    <><span>Requested</span><span>{formatTs(a.requestedAt)}</span></>
                  )}
                  {(a.fulfilledAt ?? 0n) > 0n && (
                    <><span>Fulfilled</span><span>{formatTs(a.fulfilledAt)}</span></>
                  )}
                  {(a.cancelledAt ?? 0n) > 0n && (
                    <><span>Cancelled</span><span>{formatTs(a.cancelledAt)}</span></>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
      </div>
    </main>
  )
}
