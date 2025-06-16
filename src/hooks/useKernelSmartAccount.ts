import { useEffect, useState } from 'react';
import { readContract, writeContract } from '@wagmi/core';
import { KERNEL_ACCOUNT } from '../constants/contracts';
import KernelABI from '../constants/KernelABI.json';

export function useKernelSmartAccount() {
  const [data, setData] = useState<any>({});

  async function fetch() {
    try {
      const kernelBalance = await readContract({
        address: KERNEL_ACCOUNT,
        abi: KernelABI,
        functionName: 'getKernelBalance',
      });

      setData({
        kernelBalance,
        batchClaim: async () =>
          await writeContract({
            address: KERNEL_ACCOUNT,
            abi: KernelABI,
            functionName: 'batchClaimYield',
            args: [[]], // Replace with actual array of investor addresses if needed
          }),
        batchWithdraw: async () =>
          await writeContract({
            address: KERNEL_ACCOUNT,
            abi: KernelABI,
            functionName: 'batchWithdraw',
            args: [[]], // Replace with actual array of investor addresses if needed
          }),
      });
    } catch (error) {
      console.error('KernelSmartAccount fetch error:', error);
    }
  }

  useEffect(() => {
    fetch();
  }, []);

  return data;
}
