"use client";

import React, { ChangeEvent, useEffect, useState } from "react";
import { parseInput } from "@/utils/parsers";
import { DataType, InputType } from "@/context/types";
import { 
 MinusIcon,
 PlusIcon
} from '@heroicons/react/24/outline';
import { setAction, useActionStore } from "@/context/store";
import { setError } from "@/context/store";

type InputProps = {
  dataType: DataType;
  varName: string;
  values: InputType | InputType[]
  onChange: (input: InputType | InputType[]) => void;
  index: number;
}

export function DynamicInput({dataType, varName, values, onChange, index}: InputProps) {
  const [inputArray, setInputArray] = useState<InputType[]>(values instanceof Array ? values : [values ?? ""])
  const [itemsArray, setItemsArray] = useState<number[]>([0])
  const action = useActionStore()

  // Sync local state with global action store
  useEffect(() => {
    if (action.paramValues && action.paramValues.length > 0) {
      const newValues = values instanceof Array ? values : [values ?? ""]
      setInputArray(newValues)
      setItemsArray([...Array(newValues.length).keys()])
    }
  }, [action.paramValues, values])

  // console.log("@dynamicInput: ", {error, inputArray, dataType, varName, values, itemsArray, inputValue})

  const inputType = 
    dataType.indexOf('int') > -1 ? "number"
    : dataType.indexOf('bool') > -1 ? "boolean"
    : dataType.indexOf('string') > -1 ? "string"
    : dataType.indexOf('address') > -1 ? "string"
    : dataType.indexOf('bytes') > -1 ? "string"
    : dataType.indexOf('empty') > -1 ? "empty"
    : "unsupported"
  
  const array = 
    dataType.indexOf('[]') > -1 ? true : false

  const handleChange=({event, item}: {event:ChangeEvent<HTMLInputElement>, item: number}) => {
    const currentInput = parseInput(event, dataType)
    if (currentInput == 'Incorrect input data') {
      setError({error: currentInput}) 
    } else if(typeof onChange === 'function') {
      setError({error: "no error"})
      const currentArray = [...inputArray] // Create a copy to avoid mutating state
      if (array) {  
        currentArray[item] = currentInput
        setInputArray(currentArray)
        onChange(currentArray)
      } else {
        currentArray[0] = currentInput
        setInputArray(currentArray)
        onChange(currentArray[0])
      }
      // Update global action store with new param values
      const newParamValues = [...(action.paramValues || [])]
      newParamValues[index] = array ? currentArray : currentArray[0]
      setAction({...action, paramValues: newParamValues, upToDate: false})   
    }    
  }

  const handleResizeArray = (event: React.MouseEvent<HTMLButtonElement>, expand: boolean, arrayIndex?: number) => {
    if (arrayIndex === undefined) {
      arrayIndex = itemsArray.length - 1
    }
    event.preventDefault() 

    if (expand) {
      const newItemsArray = [...Array(itemsArray.length + 1).keys()]
      const newInputArray = [...inputArray, ""]
      setItemsArray(newItemsArray) 
      setInputArray(newInputArray)
      // Update global action store
      const newParamValues = [...(action.paramValues || [])]
      newParamValues[index] = newInputArray
      setAction({...action, paramValues: newParamValues, upToDate: false})
    } else {
      const newItemsArray = [...Array(itemsArray.length - 1).keys()]
      const newInputArray = inputArray.slice(0, arrayIndex)
      setItemsArray(newItemsArray) 
      setInputArray(newInputArray)
      // Update global action store
      const newParamValues = [...(action.paramValues || [])]
      newParamValues[index] = newInputArray
      setAction({...action, paramValues: newParamValues, upToDate: false})
    }
  }

  return (
    <div className="w-full flex flex-col justify-center items-center">
      {itemsArray.map((item, i) => {
        // console.log("@inputArray", {inputArray, item, test: inputArray[item], values, index})  
        return (
          <section className="w-full mt-4 flex flex-row justify-center items-center gap-4 px-6" key = {i}>
            <div className="text-xs block min-w-24 font-medium text-slate-600">
              {`${varName.length > 16 ? `${varName.slice(0, 16)  }..` : varName}`}
            </div>

            {
            inputType  == "string" ? 
                <div className="w-full flex text-xs items-center rounded-md bg-white pl-2 outline outline-1 outline-gray-300">  
                  <input 
                    type= "text" 
                    name={`input${item}`} 
                    id={`input${item}`}
                    value = {typeof inputArray[item] != "boolean" && inputArray[item] ? String(inputArray[item]) : ""}
                    className="w-full h-8 pe-2 text-xs font-mono text-slate-500 placeholder:text-gray-400 focus:outline focus:outline-0" 
                    placeholder={`Enter ${dataType.replace(/[\[\]']+/g, '')} here.`}
                    onChange={(event) => handleChange({event, item})}
                    />
                </div>
            : 
            inputType == "number" ? 
              <div className="w-full flex text-xs items-center rounded-md bg-white pl-2 outline outline-1 outline-gray-300">  
                <input 
                  type="text" 
                  inputMode="numeric"
                  pattern="[0-9]*"
                  name={`input${item}`} 
                  id={`input${item}`}
                  value = {inputArray[item] ? inputArray[item].toString() : "0"}
                  className="w-full h-8 pe-2 text-xs font-mono text-slate-500 placeholder:text-gray-400 focus:outline focus:outline-0" 
                  placeholder={`Enter ${dataType.replace(/[\[\]']+/g, '')} value here.`}
                  onChange={(event) => handleChange({event, item})}
                  />
              </div>  
            :
            inputType == "boolean" ? 
                <div className="w-full flex text-xs items-center rounded-md bg-white pl-2 outline outline-1 outline-gray-300">  
                  <div className="flex flex-row items-center gap-2 h-8">
                    <input 
                      type="checkbox" 
                      name={`input${item}`} 
                      id={`input${item}`}
                      value={inputArray[item] === true ? "false" : "true"} 
                      checked = {inputArray[item] === true}
                      className="h-4 w-4 text-slate-500 focus:ring-slate-300" 
                      onChange={(event) => handleChange({event, item})}
                    />
                    <span className="text-xs font-mono text-slate-500">
                      {inputArray[item] === true ? "true" : "false"}
                    </span>
                  </div>
                </div>
            :
            <div className="w-full flex items-center rounded-md bg-white pl-3 outline outline-1 outline-gray-300 text-sm text-red-400 py-1">  
              error: data not recognised.
            </div>  
            }
            {
              array && item == itemsArray.length - 1 ?
                <div className = "flex flex-row gap-2">
                  <button 
                    className = "h-8 w-8 grow py-2 flex flex-row items-center justify-center  rounded-md bg-white outline outline-1 outline-gray-300"
                    onClick = {(event) => handleResizeArray(event, true)}
                    > 
                    <PlusIcon className = "h-4 w-4"/> 
                  </button>
                  {
                  item > 0 ? 
                    <button className = "h-8 w-8 grow py-2 flex flex-row items-center justify-center  rounded-md bg-white outline outline-1 outline-gray-300"
                    onClick = {(event) => handleResizeArray(event, false, item)}
                    > 
                      <MinusIcon className = "h-4 w-4"/> 
                    </button>
                  : null 
                  }
                </div>
              :
              null
            } 

          </section>
        )
      })}
    </div>
  )
}