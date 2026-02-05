"use client";

import React, { useEffect, useState } from "react";
import { MandateBox } from "@/components/MandateBox";
import { setAction, setError, useActionStore, useStatusStore } from "@/context/store";
import { Action, Powers } from "@/context/types";
import { useParams } from "next/navigation"; 
import { MandateActions } from "./MandateActions";
import { TitleText } from "@/components/StandardFonts";
import { Voting } from "@/components/Voting"; 
import { usePowersStore  } from "@/context/store";

const Page = () => {
  const action = useActionStore();  
  const { mandateId } = useParams<{ mandateId: string }>()  
  const powers = usePowersStore();
  const statusPowers = useStatusStore();
  const mandate = powers?.mandates?.find(mandate => BigInt(mandate.index) == BigInt(mandateId)) 
  const [populatedAction, setPopulatedAction] = useState<Action | undefined>();

  // console.log("@Page: waypoint 0", {populatedAction, action})

  // Helper function to map state numbers to their labels
  const getStateLabel = (state: number | undefined): string => {
    switch (state) {
      case 0: return "Non Existent"
      case 1: return "Proposed"
      case 2: return "Cancelled"
      case 3: return "Active Vote"
      case 4: return "Defeated"
      case 5: return "Succeeded"
      case 6: return "Requested"
      case 7: return "Fulfilled"
      default: return "Non Existent"
    }
  }

  useEffect(() => {
    if (mandateId) {
      setAction({
        ...action, 
        actionId: '',
        mandateId: BigInt(mandateId),
        state: 0,
        upToDate: false
      })
      setPopulatedAction(action);
    }
  }, [mandateId])

  // resetting action state when action is changed,
  useEffect(() => {
    if (action) {
      const newPopulatedAction = mandate?.actions?.find(a => BigInt(a.actionId) == BigInt(action.actionId));
      setPopulatedAction(newPopulatedAction);
    }
  }, [action.actionId, mandate]);

  // resetting DynamicForm and fetching executions when switching mandates: 
  useEffect(() => {
    if (mandate) {
      const mandateParams = mandate.params || [];
      const mandateDataTypes = mandateParams.map(param => param.dataType);
      const actionDataTypes = action.dataTypes || [];

      // Check if data types are different
      const isDifferentLength = actionDataTypes.length !== mandateDataTypes.length;
      const isDifferentContent = !isDifferentLength && actionDataTypes.some((type, index) => type !== mandateDataTypes[index]);
      const shouldReset = isDifferentLength || isDifferentContent;
      
      console.log("useEffect triggered at Mandate page:", {shouldReset, action, mandate})
      
      if (shouldReset) {
        console.log("useEffect triggered at Mandate page, action.dataTypes != dataTypes")
        setAction({
          mandateId: mandate.index,
          dataTypes: mandateDataTypes,
          paramValues: [],
          nonce: '0',
          callData: '0x0',
          upToDate: false
        })
      } else {
        console.log("useEffect triggered at Mandate page, action.dataTypes == dataTypes")
        setAction({
          ...action,  
          mandateId: mandate.index,
          upToDate: false
        })
      }
      setError({error: null})
    }
  }, [mandate])

  return (
    <main className="w-full h-full flex flex-col justify-start items-center gap-2 pt-16">
        {/* title */}
        <div className="w-full flex flex-col justify-start items-center px-4">
          <TitleText 
            title="Act"
            subtitle="Create a new action. Execution is restricted by the conditions of the mandate."
            size={2}
          />
        </div>

        {/* Action info - shown only when action is up to date */}
        
          <div className="w-full flex flex-row justify-between items-end ps-4 pe-12 py-2 text-sm text-slate-600">
            <div className="flex flex-col gap-1">
              <div className="flex flex-row gap-2">
                <span className="font-semibold">ActionId:</span>
                <span className="font-mono">
                  {action?.actionId ? `${action?.actionId.slice(0, 10)}...${action?.actionId.slice(-8)}` : '-'}
                </span>
              </div>
              <div className="flex flex-row gap-2">
                <span className="font-semibold">Status:</span>
                <span className={`px-2 rounded ${
                  populatedAction?.state === undefined ? 'text-slate-500 bg-slate-100' : // NonExistent
                  populatedAction?.state === 1 ? 'text-blue-600 bg-blue-100' : // Proposed
                  populatedAction?.state === 2 ? 'text-red-600 bg-red-100' : // Cancelled  
                  populatedAction?.state === 3 ? 'text-orange-600 bg-orange-100' : // Active
                  populatedAction?.state === 4 ? 'text-red-600 bg-red-100' : // Defeated
                  populatedAction?.state === 5 ? 'text-green-600 bg-green-100' : // Succeeded
                  populatedAction?.state === 6 ? 'text-blue-600 bg-blue-100' : // Requested
                  populatedAction?.state === 7 ? 'text-green-800 bg-green-200' : // Fulfilled
                  'text-slate-500 bg-slate-100'
                }`}>
                  {getStateLabel(populatedAction?.state)}
                </span>
              </div>
            </div>
          </div>

        <div className="w-full flex min-h-fit ps-4 pe-12"> 
          {  
          mandate && 
          <MandateBox 
              powers = {powers as Powers}
              mandate = {mandate}
              params = {mandate.params || []}
              status = {statusPowers.status}
              /> 
            }
        </div>

        {/* Voting, Latest Actions section */}
        <div className="w-full flex flex-col gap-3 justify-start items-center ps-4 pe-12 pb-20"> 
          {/* Conditional if a mandate.condition.quorum >0 && action.state != 0 && action.upToDate: show vote and voting */}
          {Number(mandate?.conditions?.quorum) > 0 && populatedAction?.state != 0 && populatedAction?.state != 8 && (
              <Voting powers={powers} />
          )}
          
          {/* Latest actions */}
          {mandate && <MandateActions mandateId = {mandate.index} powers = {powers} />}
        </div>        
    </main>
  )

}

export default Page

