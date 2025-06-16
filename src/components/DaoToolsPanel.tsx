import React from 'react';
import { useAccount } from 'wagmi';

// Hardcoded DAO owner wallet for admin access
const DAO = '0xcfe077e6f7554B1724546E02624a0832D1f4557a';

export default function DaoToolsPanel({ data }: any) {
  const { address } = useAccount();
  const isDao = address?.toLowerCase() === DAO.toLowerCase();

  if (!isDao) return null;

  return (
    <div className="p-4 border border-yellow-600 rounded-xl">
      <h2 className="text-xl font-semibold mb-2 text-yellow-400">DAO Operator Tools</h2>
      <p className="mb-1">Kernel Balance: ${Number(data?.kernelBalance || 0) / 1e6}</p>
      <p className="mb-3">Fees in Yield Vault: ${Number(data?.vaultBalance || 0) / 1e6}</p>

      <div className="flex flex-wrap gap-3">
        <button
          onClick={data?.sweepToTreasury}
          className="bg-yellow-500 hover:bg-yellow-600 text-black px-4 py-2 rounded-lg"
        >
          Sweep Fees
        </button>
        <button
          onClick={data?.batchClaim}
          className="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-lg"
        >
          Batch Claim Yield
        </button>
        <button
          onClick={data?.batchWithdraw}
          className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg"
        >
          Batch Withdraw
        </button>
      </div>
    </div>
  );
}
