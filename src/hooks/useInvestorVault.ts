import { useAccount } from 'wagmi';
import { useEffect, useState } from 'react';
import { readContract, writeContract } from '@wagmi/core';
import { INVESTOR_VAULT } from '../constants/contracts';
import InvestorVaultABI from '../constants/InvestorVaultABI.json';

export function useInvestorVault() {
  const { address } = useAccount();
  const [data, setData] = useState<any>({});

  async function fetch() {
    if (!address) return;

    try {
      const [share, claimable, claimed, unlockTime] = await readContract({
        address: INVESTOR_VAULT,
        abi: InvestorVaultABI,
        functionName: 'getInvestorInfo',
        args: [address],
      }) as any;

      setData({
        share,
        claimable,
        claimed,
        unlockTime,
        claim: async () =>
          await writeContract({
            address: INVESTOR_VAULT,
            abi: InvestorVaultABI,
            functionName: 'claimYield',
          }),
        compound: async () =>
          await writeContract({
            address: INVESTOR_VAULT,
            abi: InvestorVaultABI,
            functionName: 'compoundYield',
          }),
        withdraw: async () =>
          await writeContract({
            address: INVESTOR_VAULT,
            abi: InvestorVaultABI,
            functionName: 'withdraw',
            args: [share],
          }),
      });
    } catch (error) {
      console.error('InvestorVault fetch error:', error);
    }
  }

  useEffect(() => {
    fetch();
  }, [address]);

  return data;
}
