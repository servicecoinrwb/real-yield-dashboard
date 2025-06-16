import React from 'react';
import { useAccount } from 'wagmi';

const DAO = '0xcfe077e6f7554B1724546E02624a0832D1f4557a';

export default function DaoToolsPanel({ data }: any) {
  const { address } = useAccount();
  const isDao = address?.toLowerCase() === DAO.toLowerCase();

  if (!isDao) return null;

  return (
    <div className="p-4 border border-yellow-600 rounded-xl">
      <h2 className="text-xl font-semibold mb-2 text-yellow-400">DAO Operator Tools</h2>
      <p>Kernel Balance: ${Number(data?.kernelBalance || 0) / 1e6}</p>
      <p>Fees in Vault: ${Number(data?.vaultBalance || 0) / 1e6}</p>
      <div className="mt-4 space-x-2">
        <button onClick={data?.sweepToTreasury} className="bg-yellow-500 px-4 py-2 rounded">Sweep Fees</button>
        <button onClick={data?.batchClaim} className="bg-green-500 px-4 py-2 rounded">Batch Claim</button>
        <button onClick={data?.batchWithdraw} className="bg-blue-500 px-4 py-2 rounded">Batch Withdraw</button>
      </div>
    </div>
  );
}
