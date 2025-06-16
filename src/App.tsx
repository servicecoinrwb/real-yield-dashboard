import { useEffect, useState } from 'react';
import { createWeb3Modal, defaultWagmiConfig } from '@web3modal/wagmi/react';
import { WagmiConfig } from 'wagmi';
import { arbitrum } from 'wagmi/chains';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

import VaultOverview from './components/VaultOverview';
import InvestorPanel from './components/InvestorPanel';
import DaoToolsPanel from './components/DaoToolsPanel';

import { useInvestorVault } from './hooks/useInvestorVault';
import { useKernelSmartAccount } from './hooks/useKernelSmartAccount';
import { useYieldVault } from './hooks/useYieldVault';

const projectId = 'SERVICE_COIN_REAL_YIELD';

const metadata = {
  name: 'Service Coin DAO',
  description: 'Real Yield Dashboard',
  url: 'https://www.servicerevenue.net',
  icons: ['https://www.servicerevenue.net/icon.png'],
};

const chains = [arbitrum];
const wagmiConfig = defaultWagmiConfig({ chains, projectId, metadata });
createWeb3Modal({ wagmiConfig, projectId, chains });

const queryClient = new QueryClient();

export default function App() {
  const investorData = useInvestorVault();
  const kernelData = useKernelSmartAccount();
  const vaultData = useYieldVault();

  return (
    <WagmiConfig config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <div className="min-h-screen bg-black text-white p-4 space-y-6 max-w-3xl mx-auto">
          <h1 className="text-3xl font-bold text-orange-400 text-center">
            Service Coin: Real Yield Dashboard
          </h1>
          <VaultOverview data={vaultData} />
          <InvestorPanel data={investorData} />
          <DaoToolsPanel data={kernelData} />
        </div>
      </QueryClientProvider>
    </WagmiConfig>
  );
}
