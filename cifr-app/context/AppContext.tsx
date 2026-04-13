import React, { createContext, useContext, useState, useEffect, useMemo } from 'react';
import { db } from '../services/dbService';
import { AppState, Company, Account, Subscription, FinancialCard, Loan, Institution, CompanyDocument } from '../types';

interface AppContextType {
  state: AppState | null;
  activeView: 'dashboard' | 'company';
  setActiveView: (view: 'dashboard' | 'company') => void;
  selectedCompanyId: string | null;
  setSelectedCompanyId: (id: string | null) => void;
  searchQuery: string;
  setSearchQuery: (q: string) => void;
  
  // Company
  handleAddCompany: (newCompany: Omit<Company, 'id'>) => void;
  handleUpdateCompany: (id: string, updates: Partial<Company>) => void;
  handleDeleteCompany: (id?: string) => void;

  // Subscriptions
  handleAddSubscription: (sub: Partial<Subscription>) => void;
  handleUpdateSubscription: (id: string, updates: Partial<Subscription>) => void;
  handleDeleteSubscription: (id: string) => void;

  // Financial Cards
  handleAddFinancialCard: (card: Partial<FinancialCard>) => void;
  handleUpdateFinancialCard: (id: string, updates: Partial<FinancialCard>) => void;
  handleDeleteFinancialCard: (id: string) => void;

  // Institutions
  handleAddInstitution: (inst: Partial<Institution>) => void;
  handleUpdateInstitution: (id: string, updates: Partial<Institution>) => void;
  handleDeleteInstitution: (id: string) => void;

  // Loans
  handleAddLoan: (loan: Partial<Loan>) => void;
  handleUpdateLoan: (id: string, updates: Partial<Loan>) => void;
  handleDeleteLoan: (id: string) => void;

  // Documents
  handleAddCompanyDocument: (doc: Partial<CompanyDocument>) => void;
  handleUpdateCompanyDocument: (id: string, updates: Partial<CompanyDocument>) => void;
  handleDeleteCompanyDocument: (id: string) => void;

  // Computed
  totalMonthlyBurn: number;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [state, setState] = useState<AppState | null>(null);
  
  // In Expo, you usually use AsyncStorage, but for now we mimic the web's localStorage implementation
  const [activeView, setActiveView] = useState<'dashboard' | 'company'>('dashboard');
  const [selectedCompanyId, setSelectedCompanyId] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');

  // Initial Data Load
  useEffect(() => {
    const initData = async () => {
      const data = await db.load();
      setState(data);
    };
    initData();
  }, []);

  // Save changes to DB whenever state updates
  useEffect(() => {
    if (state) {
      db.save(state);
    }
  }, [state]);

  const totalMonthlyBurn = useMemo(() => {
    if (!state) return 0;
    return state.subscriptions.reduce((sum, sub) => {
      const subServiceCost = (sub.subServices || []).reduce((acc: number, s: any) => acc + s.cost, 0);
      const monthlyFactor = sub.billingCycle === 'Monthly' ? 1 : 1 / 12;
      return sum + (sub.cost + subServiceCost) * monthlyFactor;
    }, 0);
  }, [state]);

  const handleUpdateCompany = (id: string, updates: Partial<Company>) => {
    if (!state) return;
    setState(prev => prev ? ({
      ...prev,
      companies: prev.companies.map(c => c.id === id ? { ...c, ...updates, lastModified: updates.lastModified || Date.now() } : c)
    }) : null);
  };

  const handleDeleteCompany = (id?: string) => {
    const targetId = id || selectedCompanyId;
    if (!targetId || !state) return;
    setState(prev => prev ? ({
      companies: prev.companies.filter(c => c.id !== targetId),
      accounts: prev.accounts.filter(a => a.companyId !== targetId),
      subscriptions: prev.subscriptions.filter(s => s.companyId !== targetId),
      financialCards: prev.financialCards.filter(c => c.companyId !== targetId),
      loans: prev.loans.filter(l => l.companyId !== targetId),
      institutions: (prev.institutions || []).filter(i => i.companyId !== targetId),
      documents: (prev.documents || []).filter(d => d.companyId !== targetId)
    }) : null);
    if (targetId === selectedCompanyId) {
      setSelectedCompanyId(null);
      setActiveView('dashboard');
    }
  };

  const handleAddCompany = (newCompany: Omit<Company, 'id'>) => {
    const id = Math.random().toString(36).substr(2, 9);
    setState(prev => prev ? ({
      ...prev,
      companies: [...prev.companies, { ...newCompany, id, lastModified: Date.now(), lastViewed: Date.now() }]
    }) : null);
  };

  // --- Subscriptions ---
  const handleAddSubscription = (sub: Partial<Subscription>) => {
    const id = Math.random().toString(36).substr(2, 9);
    setState(prev => prev ? ({ ...prev, subscriptions: [...prev.subscriptions, { ...sub, id } as Subscription] }) : null);
  };
  const handleUpdateSubscription = (id: string, updates: Partial<Subscription>) => {
    setState(prev => prev ? ({ ...prev, subscriptions: prev.subscriptions.map(s => s.id === id ? { ...s, ...updates } : s) }) : null);
  };
  const handleDeleteSubscription = (id: string) => {
    setState(prev => prev ? ({ ...prev, subscriptions: prev.subscriptions.filter(s => s.id !== id) }) : null);
  };

  // --- Financial Cards ---
  const handleAddFinancialCard = (card: Partial<FinancialCard>) => {
    const id = Math.random().toString(36).substr(2, 9);
    setState(prev => prev ? ({ ...prev, financialCards: [...prev.financialCards, { ...card, id } as FinancialCard] }) : null);
  };
  const handleUpdateFinancialCard = (id: string, updates: Partial<FinancialCard>) => {
    setState(prev => prev ? ({ ...prev, financialCards: prev.financialCards.map(c => c.id === id ? { ...c, ...updates } : c) }) : null);
  };
  const handleDeleteFinancialCard = (id: string) => {
    setState(prev => prev ? ({ ...prev, financialCards: prev.financialCards.filter(c => c.id !== id) }) : null);
  };

  // --- Institutions ---
  const handleAddInstitution = (inst: Partial<Institution>) => {
    const id = Math.random().toString(36).substr(2, 9);
    setState(prev => prev ? ({ ...prev, institutions: [...(prev.institutions || []), { ...inst, id } as Institution] }) : null);
  };
  const handleUpdateInstitution = (id: string, updates: Partial<Institution>) => {
    setState(prev => prev ? ({ ...prev, institutions: (prev.institutions || []).map(i => i.id === id ? { ...i, ...updates } : i) }) : null);
  };
  const handleDeleteInstitution = (id: string) => {
    setState(prev => prev ? ({ ...prev, institutions: (prev.institutions || []).filter(i => i.id !== id) }) : null);
  };

  // --- Loans ---
  const handleAddLoan = (loan: Partial<Loan>) => {
    const id = Math.random().toString(36).substr(2, 9);
    setState(prev => prev ? ({ ...prev, loans: [...prev.loans, { ...loan, id } as Loan] }) : null);
  };
  const handleUpdateLoan = (id: string, updates: Partial<Loan>) => {
    setState(prev => prev ? ({ ...prev, loans: prev.loans.map(l => l.id === id ? { ...l, ...updates } : l) }) : null);
  };
  const handleDeleteLoan = (id: string) => {
    setState(prev => prev ? ({ ...prev, loans: prev.loans.filter(l => l.id !== id) }) : null);
  };

  // --- Documents ---
  const handleAddCompanyDocument = (doc: Partial<CompanyDocument>) => {
    const id = Math.random().toString(36).substr(2, 9);
    setState(prev => prev ? ({ ...prev, documents: [...(prev.documents || []), { ...doc, id } as CompanyDocument] }) : null);
  };
  const handleUpdateCompanyDocument = (id: string, updates: Partial<CompanyDocument>) => {
    setState(prev => prev ? ({ ...prev, documents: (prev.documents || []).map(d => d.id === id ? { ...d, ...updates } : d) }) : null);
  };
  const handleDeleteCompanyDocument = (id: string) => {
    setState(prev => prev ? ({ ...prev, documents: (prev.documents || []).filter(d => d.id !== id) }) : null);
  };

  const value = {
    state,
    activeView,
    setActiveView,
    selectedCompanyId,
    setSelectedCompanyId,
    searchQuery,
    setSearchQuery,
    handleAddCompany,
    handleUpdateCompany,
    handleDeleteCompany,
    handleAddSubscription,
    handleUpdateSubscription,
    handleDeleteSubscription,
    handleAddFinancialCard,
    handleUpdateFinancialCard,
    handleDeleteFinancialCard,
    handleAddInstitution,
    handleUpdateInstitution,
    handleDeleteInstitution,
    handleAddLoan,
    handleUpdateLoan,
    handleDeleteLoan,
    handleAddCompanyDocument,
    handleUpdateCompanyDocument,
    handleDeleteCompanyDocument,
    totalMonthlyBurn,
  };

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
};

export const useAppContext = () => {
  const context = useContext(AppContext);
  if (context === undefined) {
    throw new Error('useAppContext must be used within an AppProvider');
  }
  return context;
};
