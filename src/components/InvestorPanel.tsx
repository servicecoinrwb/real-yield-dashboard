import React from 'react';
import { useAccount } from 'wagmi';

export default function InvestorPanel({ data }: any) {
  const { address } = useAccount();

  if (!address) {
    return (
      <div className="p-4 border border-gray-700 rounded-xl">
        <h2 className="text-xl font-semibold text-gray-300 mb-2">Your Position</h2>
        <p>Please connect your wallet to view your position.</p>
      </div>
    );
  }

  return (
    <div className="p-4 border border-orange-500 rounded-xl">
      <h2 className="text-xl font-semibold mb-3 text-orange-300">Your Position</h2>
      <p>Shares: {Number(data?.share || 0)}</p>
      <p>Claimable Yield: ${Number(data?.claimable || 0) / 1e6}</p>
      <p>Claimed Yield: ${Number(data?.claimed || 0) / 1e6}</p>
      <p>
        Unlock Time:{' '}
        {data?.unlockTime
          ? new Date(Number(data.unlockTime) * 1000).toLocaleString()
          : 'N/A'}
      </p>

      <div className="mt-4 flex flex-wrap gap-3">
        <button
          onClick={data?.claim}
          className="bg-orange-500 hover:bg-orange-600 px-4 py-2 rounded text-white"
        >
          Claim
        </button>
        <button
          onClick={data?.compound}
          className="bg-orange-700 hover:bg-orange-800 px-4 py-2 rounded text-white"
        >
          Compound
        </button>
        <button
          onClick={data?.withdraw}
          className="bg-red-500 hover:bg-red-600 px-4 py-2 rounded text-white"
        >
          Withdraw
        </button>
      </div>
    </div>
  );
}
