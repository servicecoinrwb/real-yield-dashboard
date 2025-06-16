import React from 'react';
import { useAccount } from 'wagmi';

export default function InvestorPanel({ data }: any) {
  const { address } = useAccount();
  if (!address) return <div>Please connect your wallet</div>;

  return (
    <div className="p-4 border border-orange-500 rounded-xl">
      <h2 className="text-xl font-semibold mb-2 text-orange-300">Your Position</h2>
      <p>Shares: {Number(data?.share || 0)}</p>
      <p>Claimable Yield: ${Number(data?.claimable || 0) / 1e6}</p>
      <p>Claimed Yield: ${Number(data?.claimed || 0) / 1e6}</p>
      <p>Unlock Time: {new Date(Number(data?.unlockTime || 0) * 1000).toLocaleString()}</p>
      <div className="mt-4 space-x-2">
        <button onClick={data?.claim} className="bg-orange-500 px-4 py-2 rounded">Claim</button>
        <button onClick={data?.compound} className="bg-orange-700 px-4 py-2 rounded">Compound</button>
        <button onClick={data?.withdraw} className="bg-red-500 px-4 py-2 rounded">Withdraw</button>
      </div>
    </div>
  );
}
