import React from 'react';
import { Company } from '../types';

interface SidebarProps {
  companies: Company[];
  activeView: string;
  setActiveView: (view: 'dashboard' | 'company') => void;
  selectedCompanyId: string | null;
  setSelectedCompanyId: (id: string | null) => void;
  isOpen: boolean;
  onClose: () => void;
  totalMonthlyBurn: number;
}

const Sidebar: React.FC<SidebarProps> = ({ 
  companies, 
  activeView, 
  setActiveView, 
  selectedCompanyId, 
  setSelectedCompanyId,
  isOpen,
  onClose,
  totalMonthlyBurn
}) => {
  return (
    <>
      {/* Mobile Backdrop */}
      {isOpen && (
        <div 
          className="fixed inset-0 bg-black/50 z-30 md:hidden backdrop-blur-sm transition-opacity"
          onClick={onClose}
        />
      )}

      {/* Sidebar */}
      <aside 
        className={`
          fixed left-0 top-0 bottom-0 h-full w-64 bg-stone-900 text-white z-40
          transform transition-transform duration-300 ease-in-out flex flex-col
          ${isOpen ? 'translate-x-0' : '-translate-x-full'} 
          md:translate-x-0
        `}
      >
        <div className="p-6 border-b border-stone-800 flex justify-between items-center">
          <div>
            <h1 className="text-xl font-bold tracking-tight text-white">CiFr</h1>
            <p className="text-xs text-stone-400 mt-1 uppercase tracking-widest font-semibold">Workspace Manager</p>
          </div>
          {/* Mobile Close Button */}
          <button onClick={onClose} className="md:hidden text-stone-400 hover:text-white">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
          </button>
        </div>
        
        <nav className="flex-1 p-4 space-y-1 overflow-y-auto">
          <button 
            onClick={() => { setActiveView('dashboard'); setSelectedCompanyId(null); onClose(); }}
            className={`w-full text-left px-4 py-3 rounded-lg transition-colors flex items-center space-x-3 ${activeView === 'dashboard' ? 'bg-stone-800 text-white' : 'text-stone-400 hover:bg-stone-800 hover:text-white'}`}
          >
            <svg className="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" /></svg>
            <span className="font-medium">Dashboard</span>
          </button>

          <div className="pt-6 pb-2 px-4 text-xs font-semibold text-stone-500 uppercase tracking-widest">
            Your Companies
          </div>
          
          {companies.map(company => (
            <button 
              key={company.id}
              onClick={() => { setActiveView('company'); setSelectedCompanyId(company.id); onClose(); }}
              className={`w-full text-left px-4 py-3 rounded-lg transition-colors flex items-center space-x-3 ${selectedCompanyId === company.id ? 'bg-rose-600 text-white' : 'text-stone-400 hover:bg-stone-800 hover:text-white'}`}
            >
              {company.logoUrl ? (
                 <img src={company.logoUrl} alt={company.name} className="w-5 h-5 rounded-full object-cover bg-white flex-shrink-0" />
              ) : (
                 <div className="w-2 h-2 rounded-full flex-shrink-0" style={{ backgroundColor: company.color }}></div>
              )}
              <span className="truncate font-medium">{company.name}</span>
            </button>
          ))}
        </nav>
        
        <div className="p-4 border-t border-stone-800 mt-auto">
          <div className="bg-stone-800/50 p-3 rounded-lg border border-stone-700/50">
            <p className="text-[10px] text-stone-400 font-bold uppercase tracking-tight">Total Mo. Burn</p>
            <p className="text-xl font-black text-white">${totalMonthlyBurn.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}<span className="text-[10px] font-normal text-stone-500 ml-1">/mo</span></p>
          </div>
        </div>
      </aside>
    </>
  );
};

export default Sidebar;