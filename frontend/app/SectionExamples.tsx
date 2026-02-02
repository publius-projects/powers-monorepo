"use client";

import { ChevronDownIcon, ChevronLeftIcon, ChevronRightIcon } from "@heroicons/react/24/outline";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { DeployedExamples } from "@/organisations/DeployedExamples";
import Image from "next/image";

export function SectionExamples() {
  const router = useRouter();
  const [currentExampleIndex, setCurrentExampleIndex] = useState(0);

  // Get all organizations that have example deployments  
  const exampleOrganizations = DeployedExamples;

  // If no examples, don't render the section
  if (exampleOrganizations.length === 0) {
    return null;
  }

  const currentExample = exampleOrganizations[currentExampleIndex];
  const isComingSoon = currentExample.address === '0x0000000000000000000000000000000000000000';

  const handleViewExample = () => {
    if (currentExample.address && !isComingSoon) {
      router.push(`/protocol/${currentExample.chainId}/${currentExample.address}`);
    }
  };

  const nextExample = () => {
    setCurrentExampleIndex((prev) => (prev + 1) % exampleOrganizations.length);
  };

  const prevExample = () => {
    setCurrentExampleIndex((prev) => (prev - 1 + exampleOrganizations.length) % exampleOrganizations.length);
  };

  return (
    <section id="examples" className="min-h-screen flex flex-col justify-start items-center px-4 snap-start snap-always bg-gradient-to-b from-blue-300 to-slate-100 sm:pt-16 pt-4">
      <div className="w-full flex flex-col gap-4 justify-between items-center min-h-[calc(100vh-4rem)]">
        <div className="w-full h-full flex flex-col justify-start items-center">
          {/* Title and subtitle */}
          <section className="flex flex-col justify-start items-center">
            <div className="w-full flex flex-row justify-center items-center md:text-4xl text-2xl text-slate-600 text-center max-w-4xl text-pretty font-bold px-4">
              Examples
            </div>
            <div className="w-full flex flex-row justify-center items-center md:text-2xl text-xl text-slate-600 max-w-3xl text-center text-pretty py-2 px-4 pb-12">
              Explore live implementations of the Powers protocol
            </div>
          </section>


          {/* Example Display */}
          <section className="w-full sm:max-h-[80vh] flex flex-col justify-start items-center bg-white border border-slate-200 rounded-md overflow-hidden max-w-4xl shadow-sm">
            {/* Carousel Header */}
            <div className="w-full flex flex-row justify-between items-center py-4 px-6 border-b border-slate-200 flex-shrink-0">
              <button
                onClick={prevExample}
                className="p-2 rounded-md hover:bg-slate-100 transition-colors"
                disabled={exampleOrganizations.length <= 1}
              >
                <ChevronLeftIcon className="w-6 h-6 text-slate-600" />
              </button>
              
              <div className="flex flex-col items-center">
                <h3 className="text-xl font-semibold text-slate-800 text-center">{currentExample.title}</h3>
                <div className="flex gap-1 mt-2">
                  {exampleOrganizations.map((_, index) => (
                    <div
                      key={index}
                      className={`w-2 h-2 rounded-full ${
                        index === currentExampleIndex ? 'bg-slate-600' : 'bg-slate-300'
                      }`}
                    />
                  ))}
                </div>
              </div>

              <button
                onClick={nextExample}
                className="p-2 rounded-md hover:bg-slate-100 transition-colors"
                disabled={exampleOrganizations.length <= 1}
              >
                <ChevronRightIcon className="w-6 h-6 text-slate-600" />
              </button>
            </div>

            {/* Content */}
            <div className="w-full py-6 px-6 flex flex-col overflow-y-auto flex-1">
              {/* Image Display */}
              {currentExample.banner && (
                <div className="mb-4 flex justify-center">
                  <div className="relative w-full h-48 sm:h-64">
                    <Image
                      src={currentExample.banner} 
                      alt={`${currentExample.title} example`}
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
                  {currentExample.description}
                </p>
              </div>

              {/* View Example Button */}
              <div className="w-full grow mt-4 flex justify-center items-center">
                <button
                  className={`w-full sm:min-w-[400px] sm:w-auto h-12 px-12 font-medium rounded-md transition-colors duration-200 flex items-center justify-center ${
                    isComingSoon
                      ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                      : 'bg-indigo-600 hover:bg-indigo-700 text-white'
                  }`}
                  onClick={handleViewExample}
                  disabled={isComingSoon}
                >
                  {isComingSoon ? 'Coming Soon' : 'View Example'}
                </button>
              </div>
            </div>
          </section>
        </div>

        {/* Arrow down */}
        <div className="flex flex-col align-center justify-center pb-8">
          <ChevronDownIcon className="w-16 h-16 text-slate-400" />
        </div>
      </div>
    </section>
  );
}
