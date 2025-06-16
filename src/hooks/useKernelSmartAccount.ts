import { useEffect, useState } from 'react';
import { readContract, writeContract } from '@wagmi/core';
import { KERNEL_ACCOUNT } from '../constants/contracts';
import KernelABI from '../constants/KernelABI.json';

export function useKernelSmartAccount() {
  const [data, setData] = useState<any>({});

  async function fetch() {
    const kernelBalance = await readContract({
      address: KERNEL_ACCOUNT,
      abi: KernelABI,
      functionName: 'getKernelBalance'
    });
    setData({
      kernelBalance,
      batchClaim: () => writeContract({ address: KERNEL_ACCOUNT, abi: KernelABI, functionName: 'batchClaimYield', args: [[]] }),
      batchWithdraw: () => writeContract({ address: KERNEL_ACCOUNT, abi: KernelABI, functionName: 'batchWithdraw', args: [[]] })
    });
  }

  useEffect(() => { fetch(); }, []);

  return data;
}
