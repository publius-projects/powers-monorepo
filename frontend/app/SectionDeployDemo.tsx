"use client";

import { Button } from "@/components/Button"; 
import { ConnectButton } from "@/components/ConnectButton";
import { useCallback, useEffect, useState } from "react";
import { ChevronLeftIcon, ChevronRightIcon, ChevronUpIcon } from '@heroicons/react/24/outline';
import { useSwitchChain, useAccount } from "wagmi";
import { useRouter } from "next/navigation";
import { powersAbi } from "@/context/abi";
import { Status } from "@/context/types";
import { wagmiConfig } from "@/context/wagmiConfig";
import { deployContract, waitForTransactionReceipt, writeContract } from "@wagmi/core";
import { usePrivy } from "@privy-io/react-auth";
import { TwoSeventyRingWithBg } from "react-svg-spinners";
import { getEnabledOrganizations } from "@/organisations";
import { isDeployableContract, isFunctionCallDependency } from "@/organisations/types";
import Image from "next/image";
import { sepolia, arbitrumSepolia, optimismSepolia, mantleSepoliaTestnet, foundry } from "@wagmi/core/chains";

type DeployStatus = {
  powersCreate: Status;
  mocksDeploy: { name: string; status: Status }[];
  finalTransactions: { name: string; status: Status }[];
}

export function SectionDeployDemo() {
  const [deployStatus, setDeployStatus] = useState<DeployStatus>({
    powersCreate: "idle",
    mocksDeploy: [],
    finalTransactions: []
  });
  const [currentOrgIndex, setCurrentOrgIndex] = useState(0);
  const [formData, setFormData] = useState<Record<string, string>>({});
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<Error | null>(null);
  const [dependencyReceipts, setDependencyReceipts] = useState<Record<string, any>>({});
  const [deployedPowersAddress, setDeployedPowersAddress] = useState<`0x${string}` | undefined>();
  const [constituteCompleted, setConstituteCompleted] = useState(false);
  const [bytecodePowers, setBytecodePowers] = useState<`0x${string}` | undefined>();
  const [deployedMandates, setDeployedMandates] = useState<Record<string, `0x${string}`>>({});
  const { ready, authenticated } = usePrivy();
  const { chain } = useAccount();
  const { switchChain } = useSwitchChain();
  const router = useRouter();

  const isLocalhost = typeof window !== 'undefined' && window.location.hostname === 'localhost';
  
  const [isChainMenuOpen, setIsChainMenuOpen] = useState(false);
  const [selectedChain, setSelectedChain] = useState("Optimism Sepolia");

  // console.log("@SectionDeployDemo: formData", formData);
  // console.log("test formData", formData["docsPoolId"]);

  // Get available organizations based on localhost condition
  const availableOrganizations = getEnabledOrganizations(isLocalhost);

  // Mapping of chain IDs to chain info
  const allChains = [
    { name: "Ethereum Sepolia", id: sepolia.id },
    { name: "Optimism Sepolia", id: optimismSepolia.id },
    { name: "Arbitrum Sepolia", id: arbitrumSepolia.id },
    { name: "Mantle Sepolia", id: mantleSepoliaTestnet.id },
    { name: "Foundry", id: foundry.id }
  ];

  // Get chains allowed for current organization
  const currentOrg = availableOrganizations[currentOrgIndex];
  const allowedChainIds = isLocalhost ? currentOrg.allowedChainsLocally : currentOrg.allowedChains;
  const chains = allChains.filter(chain => allowedChainIds.includes(chain.id));

  // Get the current selected chain ID
  const selectedChainId = chains.find(c => c.name === selectedChain)?.id;

  const getPowered = useCallback(async (chainId: number) => {
    try {
      const response = await fetch(`/powered/${chainId}.json`);
      if (!response.ok) {
        throw new Error(`Failed to fetch powered data for chain ${chainId}`);
      }
      const data = await response.json();
      setBytecodePowers(data.powers as `0x${string}`);
      setDeployedMandates(data.mandates as Record<string, `0x${string}`>);
    } catch (error) {
      console.error('Error loading powered data:', error);
      setBytecodePowers(undefined);
      setDeployedMandates({});
    }
  }, []);

  // console.log("@SectionDeployDemo: deployedMandates", deployedMandates);

  // Ensure selected chain is valid when organization changes
  useEffect(() => {
    const isSelectedChainAvailable = chains.some(c => c.name === selectedChain);
    if (!isSelectedChainAvailable && chains.length > 0) {
      setSelectedChain(chains[0].name);
    }
  }, [currentOrgIndex, isLocalhost]);

  // Switch chain when selected chain changes
  useEffect(() => {
    if (selectedChainId && chain?.id !== selectedChainId) {
      switchChain({ chainId: selectedChainId });
    }
    if (selectedChainId) {
      getPowered(selectedChainId);
    }
  }, [selectedChainId, chain?.id, switchChain]);

  const handleInputChange = (fieldName: string, value: string) => {
    // console.log("@SectionDeployDemo: handleInputChange", { fieldName, value });
    setFormData(prev => ({
      ...prev,
      [fieldName]: value
    }));
  };

  // Function to check if all required fields are filled
  const areRequiredFieldsFilled = () => {
    return currentOrg.fields
      .filter(field => field.required)
      .every(field => formData[field.name] && formData[field.name].trim() !== '');
  };

  // Check if there are any required fields
  const hasRequiredFields = currentOrg.fields.some(field => field.required);

  // Main deploy sequence handler
  const handleDeploySequence = useCallback(async () => {
    if (!bytecodePowers || !selectedChainId) return;

    try {
      setStatus("pending");
      setError(null);
      setConstituteCompleted(false);

      // Helper function to add delay for Anvil 
      const isAnvil = selectedChainId === 31337;
      const delayIfNeeded = async () => {
        if (selectedChainId === 31337 || selectedChainId === 11155111 || selectedChainId === 421614 || selectedChainId === 11155420) {
          await new Promise(resolve => setTimeout(resolve, 500)); // 500ms delay for Anvil
        }
      };

      // Initialize all status items upfront
      const dependencies = currentOrg.dependencies || [];
      
      // Build complete list of final transactions
      const finalTransactionsList: { name: string; status: Status }[] = [
        { name: "Constitute Powers", status: "idle" },
        { name: "Close Constitute", status: "idle" }
      ];
      
      // Add ownership transfer transactions
      for (const dep of dependencies) {
        if (dep.ownable) {
          finalTransactionsList.push({ name: `Transfer ownership to Powers: ${dep.name}`, status: "idle" });
        }
      }

      // Set all deployment statuses upfront
      setDeployStatus({
        powersCreate: "idle",
        mocksDeploy: dependencies.map(dep => ({ name: dep.name, status: "idle" as Status })),
        finalTransactions: finalTransactionsList
      });

      // STEP 1: Deploy Powers contract
      console.log("Step 1: Deploying Powers contract...", { bytecodePowers, powersAbi, formData, selectedChainId, currentOrg });
      setDeployStatus(prev => ({ ...prev, powersCreate: "pending" }));
      
      const powersTxHash = await deployContract(wagmiConfig, {
        abi: powersAbi,
        bytecode: bytecodePowers,
        args: [currentOrg.metadata.title, currentOrg.metadata.uri, 10_000n, 10_000n, 25n]
      });

      console.log("Powers deployment tx:", powersTxHash);

      await delayIfNeeded();
      
      const powersReceipt = await waitForTransactionReceipt(wagmiConfig, {
        hash: powersTxHash,
        confirmations: isAnvil ? 1 : 2
      });

      await delayIfNeeded();

      const powersAddress = powersReceipt.contractAddress;
      if (!powersAddress) {
        throw new Error("Failed to get Powers contract address from receipt");
      }

      console.log("Powers deployed at:", powersAddress);
      setDeployedPowersAddress(powersAddress);
      setDeployStatus(prev => ({ ...prev, powersCreate: "success" }));
      
      await delayIfNeeded();

      // STEP 2: Execute dependencies (contract deployments or function calls)
      console.log("Step 2: Executing dependencies...");

      const dependencyReceiptsMap: Record<string, any> = {};

      for (let i = 0; i < dependencies.length; i++) {
        const dep = dependencies[i];
        console.log(`Executing ${dep.name}...`);
        
        setDeployStatus(prev => ({
          ...prev,
          mocksDeploy: prev.mocksDeploy.map((m, idx) => 
            idx === i ? { ...m, status: "pending" } : m
          )
        }));

        let txHash: `0x${string}`;
        let receipt: any;

        if (isDeployableContract(dep)) {
          // Deploy contract
          console.log(`Deploying contract ${dep.name}...`);
          txHash = await deployContract(wagmiConfig, {
            abi: dep.abi,
            bytecode: dep.bytecode,
            args: dep.args || []
          });
        } else if (isFunctionCallDependency(dep)) {
          // Execute function call
          console.log(`Calling function ${dep.functionName} on ${dep.target}...`);
          txHash = await writeContract(wagmiConfig, {
            address: dep.target,
            abi: dep.abi,
            functionName: dep.functionName,
            args: dep.args || []
          });
        } else {
          const depName = (dep as any).name || 'Unknown';
          throw new Error(`Unknown dependency type for ${depName}`);
        }

        console.log(`${dep.name} transaction:`, txHash);

        receipt = await waitForTransactionReceipt(wagmiConfig, {
          hash: txHash,
          confirmations: isAnvil ? 1 : 2
        });

        // Store the full receipt for later processing
        dependencyReceiptsMap[dep.name] = receipt;
        console.log(`${dep.name} executed successfully:`, receipt);

        setDeployStatus(prev => ({
          ...prev,
          mocksDeploy: prev.mocksDeploy.map((m, idx) => 
            idx === i ? { ...m, status: "success" } : m
          )
        }));

        await delayIfNeeded();
      }

      setDependencyReceipts(dependencyReceiptsMap);

      // STEP 3: Create mandate init data with dependency receipts
      console.log("Step 3: Creating mandate init data...", {powersAddress, formData, deployedMandates, dependencyReceiptsMap, selectedChainId});
      const mandateInitData = currentOrg.createMandateInitData(
        powersAddress,
        formData,
        deployedMandates,
        dependencyReceiptsMap,
        selectedChainId
      );
      console.log("Mandate init data created:", mandateInitData);

      // STEP 4: Execute constitute + transfer ownership (sequential for all chains)
      console.log("Step 4: Executing transactions sequentially...");

      await delayIfNeeded();

      let currentTxIndex = 0;

      // 4a: Execute constitute
      console.log("Calling constitute...");
      setDeployStatus(prev => ({
        ...prev,
        finalTransactions: prev.finalTransactions.map((tx) =>
          tx.name === "Constitute Powers" ? { ...tx, status: "pending" as Status } : tx
        )
      }));

      const constituteTxHash = await writeContract(wagmiConfig, {
        address: powersAddress,
        abi: powersAbi,
        functionName: 'constitute',
        args: [mandateInitData]
      });
      
      console.log("Waiting for constitute transaction:", constituteTxHash);
      const constituteReceipt = await waitForTransactionReceipt(wagmiConfig, { 
        hash: constituteTxHash,
        confirmations: isAnvil ? 1 : 2
      });
      console.log("Constitute completed successfully!", { 
        txHash: constituteTxHash, 
        status: constituteReceipt.status,
        receipt: constituteReceipt
      });

      setDeployStatus(prev => {
        console.log("Updating constitute status to success", { 
          prevFinalTransactions: prev.finalTransactions,
          totalTransactions: prev.finalTransactions.length 
        });
        const updated = {
          ...prev,
          finalTransactions: prev.finalTransactions.map((tx) =>
            tx.name === "Constitute Powers" ? { ...tx, status: "success" as Status } : tx
          )
        };
        console.log("Updated final transactions:", updated.finalTransactions);
        return updated;
      });

      await delayIfNeeded();
      currentTxIndex++;
      console.log("Moving to next transaction, currentTxIndex:", currentTxIndex);

      // 4b: Execute closeConstitute
      console.log("Calling closeConstitute...");
      setDeployStatus(prev => ({
        ...prev,
        finalTransactions: prev.finalTransactions.map((tx) =>
          tx.name === "Close Constitute" ? { ...tx, status: "pending" as Status } : tx
        )
      }));

      const closeConstituteTxHash = await writeContract(wagmiConfig, {
        address: powersAddress,
        abi: powersAbi,
        functionName: 'closeConstitute',
        args: []
      });
      
      console.log("Waiting for closeConstitute transaction:", closeConstituteTxHash);
      const closeConstituteReceipt = await waitForTransactionReceipt(wagmiConfig, { 
        hash: closeConstituteTxHash,
        confirmations: isAnvil ? 1 : 2
      });
      console.log("Close Constitute completed successfully!", { 
        txHash: closeConstituteTxHash, 
        status: closeConstituteReceipt.status,
        receipt: closeConstituteReceipt
      });

      setDeployStatus(prev => ({
        ...prev,
        finalTransactions: prev.finalTransactions.map((tx) =>
          tx.name === "Close Constitute" ? { ...tx, status: "success" as Status } : tx
        )
      }));

      await delayIfNeeded();
      currentTxIndex++;

      // 4c: Execute transferOwnership for ownable contracts
      for (const dep of dependencies) {
        if (dep.ownable) {
          let depAddress: `0x${string}`;
          
          if (isDeployableContract(dep)) {
            // For deployed contracts, get address from receipt
            const receipt = dependencyReceiptsMap[dep.name];
            depAddress = receipt.contractAddress;
            if (!depAddress) {
              console.error(`Missing contract address in receipt for ${dep.name}, skipping ownership transfer`);
              continue;
            }
          } else if (isFunctionCallDependency(dep)) {
            // For function calls, use the target address
            depAddress = dep.target;
          } else {
            const depName = (dep as any).name || 'Unknown';
            console.error(`Unknown dependency type for ${depName}, skipping ownership transfer`);
            continue;
          }

          console.log(`Transferring ownership of ${dep.name} to Powers...`);
          
          const transferTxName = `Transfer ownership: ${dep.name}`;
          console.log(`Setting ${transferTxName} to pending...`);
          
          setDeployStatus(prev => ({
            ...prev,
            finalTransactions: prev.finalTransactions.map((tx) =>
              tx.name === transferTxName ? { ...tx, status: "pending" as Status } : tx
            )
          }));

          const transferTxHash = await writeContract(wagmiConfig, {
            address: depAddress,
            abi: dep.abi,
            functionName: 'transferOwnership',
            args: [powersAddress]
          });
          
          console.log(`Waiting for ${dep.name} ownership transfer:`, transferTxHash);
          await waitForTransactionReceipt(wagmiConfig, { 
            hash: transferTxHash,
            confirmations: isAnvil ? 1 : 2
          });
          console.log(`${dep.name} ownership transferred:`, transferTxHash);

          console.log(`Setting ${transferTxName} to success...`);
          setDeployStatus(prev => {
            const updated = {
              ...prev,
              finalTransactions: prev.finalTransactions.map((tx) =>
                tx.name === transferTxName ? { ...tx, status: "success" as Status } : tx
              )
            };
            console.log(`Updated final transactions after ${transferTxName}:`, updated.finalTransactions);
            return updated;
          });

          await delayIfNeeded();
          currentTxIndex++;
        }
      }

      // All done!
      console.log("All transactions completed! Setting final status...");
      setStatus("success");
      setConstituteCompleted(true);
      console.log("Deploy sequence completed successfully!", {
        deployedPowersAddress: powersAddress,
        constituteCompleted: true,
        finalStatus: "success"
      });

    } catch (error) {
      console.error("Deploy sequence error:", error);
      setStatus("error");
      setError(error as Error);
      
      // Update failed status for current step
      setDeployStatus(prev => {
        if (prev.powersCreate === "pending") {
          return { ...prev, powersCreate: "error" };
        } else if (prev.mocksDeploy.some(m => m.status === "pending")) {
          return {
            ...prev,
            mocksDeploy: prev.mocksDeploy.map(m => 
              m.status === "pending" ? { ...m, status: "error" } : m
            )
          };
        } else if (prev.finalTransactions.some(tx => tx.status === "pending")) {
          return {
            ...prev,
            finalTransactions: prev.finalTransactions.map(tx => 
              tx.status === "pending" ? { ...tx, status: "error" } : tx
            )
          };
        }
        return prev;
      });
    }
  }, [bytecodePowers, selectedChainId, currentOrg, deployedMandates, formData]);

  const handleSeeYourPowers = () => {
    if (deployedPowersAddress && selectedChainId) {
      router.push(`/protocol/${selectedChainId}/${deployedPowersAddress}`);
    }
  };

  const resetFormData = () => {
    setConstituteCompleted(false);
    setStatus("idle");
    setError(null);
    setDeployedPowersAddress(undefined);
    setDependencyReceipts({});
    setFormData({});
    setDeployStatus({
      powersCreate: "idle",
      mocksDeploy: [],
      finalTransactions: []
    });
  };

  const nextOrg = () => {
    setCurrentOrgIndex((prev) => (prev + 1) % availableOrganizations.length);
    resetFormData();
  };

  const prevOrg = () => {
    setCurrentOrgIndex((prev) => (prev - 1 + availableOrganizations.length) % availableOrganizations.length);
    resetFormData();
  };

  return (
    <section id="deploy" className="min-h-screen grow flex flex-col justify-start items-center pb-20 px-4 snap-start snap-always bg-gradient-to-b from-slate-100 to-slate-50 sm:pt-16 pt-4">
      <div className="w-full flex flex-col gap-4 justify-start items-center">
        <section className="flex flex-col justify-center items-center"> 
          <div className="w-full flex flex-row justify-center items-center md:text-4xl text-2xl text-slate-600 text-center max-w-4xl text-pretty font-bold px-4">
            Deploy a Demo
          </div>
          <div className="w-full flex flex-row justify-center items-center md:text-2xl text-xl text-slate-600 max-w-3xl text-center text-pretty py-2 px-4">
            Choose a template to try out the Powers protocol
          </div>
        </section>

        <section className="w-full grow sm:max-h-[80vh] flex flex-col justify-start items-center bg-white border border-slate-200 rounded-md overflow-hidden max-w-4xl shadow-sm">
          {/* Carousel Header */}
          <div className="w-full flex flex-row justify-between items-center py-4 px-6 border-b border-slate-200 flex-shrink-0">
            <button
              onClick={prevOrg}
              className="p-2 rounded-md hover:bg-slate-100 transition-colors"
            >
              <ChevronLeftIcon className="w-6 h-6 text-slate-600" />
            </button>
            
            <div className="flex flex-col items-center">
              <h3 className="text-xl font-semibold text-slate-800 text-center">{currentOrg.metadata.title}</h3>
              <div className="flex gap-1 mt-2">
                {availableOrganizations.map((_, index) => (
                  <div
                    key={index}
                    className={`w-2 h-2 rounded-full ${
                      index === currentOrgIndex ? 'bg-slate-600' : 'bg-slate-300'
                    }`}
                  />
                ))}
              </div>
            </div>

            <button
              onClick={nextOrg}
              className="p-2 rounded-md hover:bg-slate-100 transition-colors"
            >
              <ChevronRightIcon className="w-6 h-6 text-slate-600" />
            </button>
          </div>

          {/* Form Content */}
          <div className="w-full py-6 px-6 flex flex-col overflow-y-auto flex-1">
            {/* Image Display */}
            {currentOrg.metadata.banner && (
              <div className="mb-4 flex justify-center">
                <div className="relative w-full h-48 sm:h-64">
                  <Image
                    src={currentOrg.metadata.banner} 
                    alt={`${currentOrg.metadata.title} template`}
                    fill
                    className="rounded-lg object-cover"
                    onError={(e) => {
                      e.currentTarget.style.display = 'none';
                    }}
                  />
                </div>
              </div>
            )}
            
            <div className="mb-4">
              <p className="text-slate-600 text-sm leading-relaxed">
                {currentOrg.metadata.description}
              </p>
            </div>

            <div className="space-y-3">
              {currentOrg.fields.map((field) => (
                <div key={field.name} className="flex flex-col">
                  <label className="text-sm font-medium text-slate-700 mb-1">
                    {field.name.charAt(0).toUpperCase() + field.name.slice(1).replace(/([A-Z])/g, ' $1')}
                    {field.required && <span className="text-red-500 ml-1">*</span>}
                  </label>
                  <input
                    type={field.type}
                    name={field.name}
                    placeholder={field.placeholder}
                    className="w-full h-12 px-3 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent border border-slate-300"
                    value={formData[field.name] || ''}
                    onChange={(e) => handleInputChange(field.name, e.target.value)}
                    required={field.required}
                  />
                </div>
              ))}
            </div>

            {/* Required fields indicator */}
            {hasRequiredFields && (
              <div className="text-red-500 text-sm font-medium pt-2">
                * Required
              </div>
            )}

            <div className="mt-4 flex flex-col sm:flex-row justify-between items-center gap-4 flex-shrink-0">
              {/* Deploy/See Your Powers button - positioned below on small screens, left on large screens */}
              <div className="w-full sm:w-fit h-12 order-2 sm:order-1">
                {constituteCompleted && deployedPowersAddress ? (
                  <button 
                    className="w-full sm:w-fit h-12 px-6 bg-green-600 hover:bg-green-700 text-white font-medium rounded-md transition-colors duration-200 flex items-center justify-center"
                    onClick={handleSeeYourPowers}
                  > 
                    See Your New Powers
                  </button>
                ) : (
                  <button 
                    className={`w-full sm:w-fit h-12 px-6 font-medium rounded-md transition-colors duration-200 flex items-center justify-center ${
                      status === 'error'
                        ? 'bg-red-600 hover:bg-red-700 text-white border border-red-700'
                        : !ready || !authenticated || currentOrg.metadata.disabled || !areRequiredFieldsFilled()
                          ? 'bg-gray-300 text-gray-500 cursor-not-allowed' 
                          : 'bg-indigo-600 hover:bg-indigo-700 text-white'
                    }`}
                    onClick={() => {
                      if (ready && authenticated && !currentOrg.metadata.disabled && areRequiredFieldsFilled() && bytecodePowers) {
                        handleDeploySequence();
                      }
                    }}
                    disabled={!ready || !authenticated || currentOrg.metadata.disabled || !areRequiredFieldsFilled() || status === 'pending'}
                  > 
                    {status === 'error' ? (
                      'Error - Try Again'
                    ) : currentOrg.metadata.disabled ? (
                      'Coming soon!'
                    ) : status === 'pending' ? (
                      <div className="flex items-center gap-2">
                        <TwoSeventyRingWithBg className="w-5 h-5 animate-spin" color="text-slate-200" />
                        Deploying...
                      </div>
                    ) : (
                      `Deploy ${currentOrg.metadata.title}`
                    )}
                  </button>
                )}
              </div>

              {/* Chain and Connect buttons - positioned above deploy button on small screens, right on large screens */}
              <div className="flex items-center gap-4 h-12 w-full sm:w-fit order-1 sm:order-2">
                {/* Chain Selection Button */}
                <div className="relative h-full w-full sm:w-fit">
                  <Button
                    size={1}
                    role={2}
                    onClick={() => setIsChainMenuOpen(!isChainMenuOpen)}
                  >
                    <div className="flex items-center gap-2 text-slate-600 font-medium">
                      {selectedChain}
                      <ChevronUpIcon 
                        className={`w-4 h-4 transition-transform duration-200 ${
                          isChainMenuOpen ? 'rotate-180' : ''
                        }`}
                      />
                    </div>
                  </Button>

                  {/* Drop-up Menu */}
                  {isChainMenuOpen && (
                    <div className="absolute bottom-full left-0 mb-2 bg-white border border-gray-200 rounded-lg shadow-lg z-10">
                      {chains.map((chain) => (
                        <button
                          key={chain.id}
                          className={`w-full px-4 py-2 text-left hover:bg-gray-50 transition-colors ${
                            selectedChain === chain.name ? 'bg-blue-50 text-blue-600' : 'text-gray-700'
                          }`}
                          onClick={() => {
                            setSelectedChain(chain.name);
                            setIsChainMenuOpen(false);
                          }}
                        >
                          {chain.name}
                        </button>
                      ))}
                    </div>
                  )}
                </div>

                {/* Connect Button */}
                <div className="sm:w-fit h-full">
                  <ConnectButton />
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Deployment Status Display */}
        {(status === 'pending' || status === 'error' || status === 'success') && (
          <section className="w-full flex flex-col justify-start items-start bg-white border border-slate-200 rounded-md max-w-4xl shadow-sm p-6">
            <h4 className="text-lg font-semibold text-slate-800 mb-4">Deployment Status</h4>
            
            <div className="w-full space-y-3">
              {/* Step 1: Powers Contract */}
              <div className="flex items-center gap-3">
                {deployStatus.powersCreate === 'success' ? (
                  <div className="w-6 h-6 rounded-full bg-green-500 flex items-center justify-center flex-shrink-0">
                    <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                  </div>
                ) : deployStatus.powersCreate === 'pending' ? (
                  <div className="w-6 h-6 flex-shrink-0">
                    <TwoSeventyRingWithBg className="w-6 h-6" />
                  </div>
                ) : deployStatus.powersCreate === 'error' ? (
                  <div className="w-6 h-6 rounded-full bg-red-500 flex items-center justify-center flex-shrink-0">
                    <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </div>
                ) : (
                  <div className="w-6 h-6 rounded-full bg-slate-300 flex-shrink-0" />
                )}
                <span className={`text-sm ${deployStatus.powersCreate === 'success' ? 'text-green-600 font-medium' : deployStatus.powersCreate === 'error' ? 'text-red-600' : 'text-slate-600'}`}>
                  Deploy Powers Contract
                </span>
              </div>

              {/* Step 2: Dependencies - show all from the start */}
              {currentOrg.dependencies.map((dep, idx) => {
                const mockStatus = deployStatus.mocksDeploy.find(m => m.name === dep.name)?.status || 'idle';
                return (
                  <div key={idx} className="flex items-center gap-3">
                    {mockStatus === 'success' ? (
                      <div className="w-6 h-6 rounded-full bg-green-500 flex items-center justify-center flex-shrink-0">
                        <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                      </div>
                    ) : mockStatus === 'pending' ? (
                      <div className="w-6 h-6 flex-shrink-0">
                        <TwoSeventyRingWithBg className="w-6 h-6" />
                      </div>
                    ) : mockStatus === 'error' ? (
                      <div className="w-6 h-6 rounded-full bg-red-500 flex items-center justify-center flex-shrink-0">
                        <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </div>
                    ) : (
                      <div className="w-6 h-6 rounded-full bg-slate-300 flex-shrink-0" />
                    )}
                    <span className={`text-sm ${mockStatus === 'success' ? 'text-green-600 font-medium' : mockStatus === 'error' ? 'text-red-600' : 'text-slate-600'}`}>
                      Deploy {dep.name}
                    </span>
                  </div>
                );
              })}

              {/* Step 3: Final Transactions - show all from the start */}
              {deployStatus.finalTransactions.map((tx, idx) => (
                <div key={idx} className="flex items-center gap-3">
                  {tx.status === 'success' ? (
                    <div className="w-6 h-6 rounded-full bg-green-500 flex items-center justify-center flex-shrink-0">
                      <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                      </svg>
                    </div>
                  ) : tx.status === 'pending' ? (
                    <div className="w-6 h-6 flex-shrink-0">
                      <TwoSeventyRingWithBg className="w-6 h-6" />
                    </div>
                  ) : tx.status === 'error' ? (
                    <div className="w-6 h-6 rounded-full bg-red-500 flex items-center justify-center flex-shrink-0">
                      <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </div>
                  ) : (
                    <div className="w-6 h-6 rounded-full bg-slate-300 flex-shrink-0" />
                  )}
                  <span className={`text-sm ${tx.status === 'success' ? 'text-green-600 font-medium' : tx.status === 'error' ? 'text-red-600' : 'text-slate-600'}`}>
                    {tx.name}
                  </span>
                </div>
              ))}
            </div>

            {error && (
              <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-md max-h-64 h-full overflow-y-auto">
                <p className="text-sm text-red-600 break-words break-all whitespace-pre-wrap">
                  <strong>Error:</strong> {error.message}
                </p>
              </div>
            )}
          </section>
        )}

        <div className="text-center">
          <p className="text-sm text-slate-500 max-w-2xl">
            <strong>Important:</strong> These deployments are for testing purposes only. 
            The Powers protocol has not been audited and should not be used for production environments. 
            Many of the examples lack basic security mechanisms and are for demo purposes only.
          </p>
        </div>
      </div>
    </section>
  );
}
