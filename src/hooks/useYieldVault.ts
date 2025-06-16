import { useEffect, useState } from 'react';
import { readContract, writeContract } from '@wagmi/core';
import { YIELD_VAULT } from '../constants/contracts';
import YieldVaultABI from '../constants/YieldVaultABI.json';

export function useYieldVault() {
  const [data, setData] = useState<any>({});

  async function fetch() {
    try {
      const [vaultBalance, totalShares, totalYield] = await Promise.all([
        readContract({
          address: YIELD_VAULT,
          abi: YieldVaultABI,
          functionName: 'getVaultBalance',
        }),
        readContract({
          address: YIELD_VAULT,
          abi: YieldVaultABI,
          functionName: 'getTotalFeesAccumulatedInVault',
        }),
        readContract({
          address: YIELD_VAULT,
          abi: YieldVaultABI,
          functionName: 'totalFeesAccumulatedInVault',
        }),
      ]);

      setData({
        totalUSDC: vaultBalance,
        totalShares,
        totalYield,
        vaultBalance,
        sweepToTreasury: async () =>
          await writeContract({
            address: YIELD_VAULT,
            abi: YieldVaultABI,
            functionName: 'sweepToTreasury',
            args: [vaultBalance],
          }),
      });
