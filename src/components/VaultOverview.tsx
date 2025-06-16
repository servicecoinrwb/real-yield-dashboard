import React from 'react';

export default function VaultOverview({ data }: any) {
  return (
    <div className="p-4 border border-orange-500 rounded-xl">
      <h2 className="text-xl font-semibold mb-2 text-orange-300">Vault Overview</h2>
      <p>Total Deposits: ${Number(data?.totalUSDC || 0) / 1e6}</p>
      <p>Total Yield Distributed: ${Number(data?.totalYield || 0) / 1e6}</p>
      <p>Total Shares Minted: {Number(data?.totalShares || 0)}</p>
    </div>
  );
}
