
import React, { useState } from 'react';
import { AppState, Company } from '../types';

interface DashboardProps {
  state: AppState;
  onSelectCompany: (id: string) => void;
  onAddCompany: (company: Omit<Company, 'id'>) => void;
  onUpdateCompany: (id: string, updates: Partial<Company>) => void;
}

const BRAND_COLORS = [
  '#4f46e5', // Indigo
  '#10b981', // Emerald
  '#f59e0b', // Amber
  '#ef4444', // Red
  '#3b82f6', // Blue
  '#8b5cf6', // Violet
  '#ec4899', // Pink
  '#64748b', // Slate
  '#000000', // Black
];

const COMPANY_STRUCTURES = [
  'LLC',
  'S-Corp',
  'C-Corp',
  'Small Business',
  'Sole Proprietorship',
  'Partnership',
  'Holding Company',
  'Non-Profit',
  'Personal',
  'Other'
];

const getTimeAgo = (timestamp?: number) => {
  if (!timestamp) return 'Never';
  const now = Date.now();
  const diffInMs = now - timestamp;
  const diffInDays = Math.floor(diffInMs / (1000 * 60 * 60 * 24));

  if (diffInDays === 0) {
    const diffInHours = Math.floor(diffInMs / (1000 * 60 * 60));
    if (diffInHours === 0) return 'Just now';
    return `${diffInHours}h ago`;
  }
  return `${diffInDays}d ago`;
};

const Dashboard: React.FC<DashboardProps> = ({ state, onSelectCompany, onAddCompany, onUpdateCompany }) => {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingCompany, setEditingCompany] = useState<Partial<Company> | null>(null);
  const [isDragging, setIsDragging] = useState(false);

  const initialCompanyState: Partial<Company> = {
    name: '',
    structure: 'LLC',
    description: '',
    color: BRAND_COLORS[0],
    logoUrl: ''
  };

  const [formState, setFormState] = useState<Partial<Company>>(initialCompanyState);

  const openAddModal = () => {
    setEditingCompany(null);
    setFormState(initialCompanyState);
    setIsModalOpen(true);
  };

  const openEditModal = (e: React.MouseEvent, company: Company) => {
    e.stopPropagation();
    setEditingCompany(company);
    setFormState({ ...company });
    setIsModalOpen(true);
  };

  const processFile = (file: File) => {
    if (file && file.type.startsWith('image/')) {
      if (file.size > 1024 * 1024) { // 1MB Limit
        alert("Image too large. Please use a logo smaller than 1MB to ensure data saves correctly.");
        return;
      }
      const reader = new FileReader();
      reader.onloadend = () => {
        setFormState(prev => ({ ...prev, logoUrl: reader.result as string }));
      };
      reader.readAsDataURL(file);
    }
  };

  const handleLogoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) processFile(file);
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files?.[0];
    if (file) processFile(file);
  };

  const handleSaveCompany = () => {
    if (formState.name) {
      if (editingCompany && editingCompany.id) {
        onUpdateCompany(editingCompany.id, formState);
      } else {
        onAddCompany({
          name: formState.name,
          structure: formState.structure || 'LLC',
          description: formState.description || '',
          color: formState.color || BRAND_COLORS[0],
          logoUrl: formState.logoUrl
        });
      }
      setIsModalOpen(false);
    }
  };

  return (
    <div className="space-y-8 animate-fadeIn bg-black min-h-screen">
      {/* Add/Edit Company Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-fadeIn overflow-y-auto">
          <div className="bg-[#1C1C1E] rounded-3xl shadow-2xl w-full max-w-lg text-white border border-white/10 overflow-hidden my-auto">
            <div className="p-8 border-b border-white/5 flex justify-between items-center">
              <h3 className="text-xl font-black text-white uppercase tracking-widest">{editingCompany ? 'Edit Entity Profile' : 'Register New Entity'}</h3>
              <button onClick={() => setIsModalOpen(false)} className="text-white/20 hover:text-white transition-colors">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            <div className="p-8 space-y-6 overflow-y-auto max-h-[70vh]">
              <div className="space-y-2">
                <label className="text-[10px] font-black text-white/20 uppercase tracking-[0.2em] ml-1">Entity Name</label>
                <input
                  autoFocus
                  className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#1FE400]/50 transition font-bold"
                  placeholder="e.g. Acme Holdings Inc."
                  value={formState.name}
                  onChange={(e) => setFormState({ ...formState, name: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-white/20 uppercase tracking-[0.2em] ml-1">Entity Structure</label>
                <select
                  className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#1FE400]/50 transition font-bold"
                  value={formState.structure}
                  onChange={(e) => setFormState({ ...formState, structure: e.target.value })}
                >
                  {COMPANY_STRUCTURES.map(type => (
                    <option key={type} value={type} className="bg-[#1C1C1E]">{type}</option>
                  ))}
                </select>
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black text-white/20 uppercase tracking-[0.2em] ml-1">Purpose / Vision</label>
                <textarea
                  className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-white outline-none focus:border-[#1FE400]/50 transition font-bold"
                  placeholder="A brief mission statement..."
                  rows={3}
                  value={formState.description}
                  onChange={(e) => setFormState({ ...formState, description: e.target.value })}
                />
              </div>
              <div className="space-y-4">
                <label className="text-[10px] font-black text-white/20 uppercase tracking-[0.2em] ml-1">Identity Color</label>
                <div className="flex flex-wrap gap-2 mb-4">
                  {BRAND_COLORS.map(color => (
                    <button
                      key={color}
                      type="button"
                      onClick={() => setFormState({ ...formState, color, logoUrl: '' })}
                      className={`w-8 h-8 rounded-full border border-white/10 transition-transform hover:scale-110 ${formState.color === color && !formState.logoUrl ? 'ring-2 ring-white/50 ring-offset-2 ring-offset-[#1C1C1E]' : ''}`}
                      style={{ backgroundColor: color }}
                    />
                  ))}
                </div>

                <label className="text-[10px] font-black text-white/20 uppercase tracking-[0.2em] ml-1 block pt-2">Corporate Identity (Logo)</label>
                <div
                  className={`flex items-center space-x-4 p-5 rounded-2xl border-2 transition-all duration-200 ${isDragging
                    ? 'bg-[#1FE400]/5 border-[#1FE400]/40 border-dashed scale-[1.02]'
                    : 'bg-white/5 border-white/10'
                    }`}
                  onDragOver={handleDragOver}
                  onDragLeave={handleDragLeave}
                  onDrop={handleDrop}
                >
                  <div className="relative w-16 h-16 flex-shrink-0">
                    <div
                      className="w-full h-full rounded-2xl flex items-center justify-center overflow-hidden border border-white/10 bg-black shadow-2xl transition-transform group-hover:scale-105"
                    >
                      {formState.logoUrl ? (
                        <img src={formState.logoUrl} alt="Logo Preview" className="w-full h-full object-cover" />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center transition-colors" style={{ backgroundColor: formState.color || '#333' }}>
                          <span className="text-white font-black text-2xl">{formState.name?.charAt(0) || '?'}</span>
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex-1">
                    <label className="cursor-pointer flex flex-col items-start group">
                      <span className={`text-[10px] font-bold ${isDragging ? 'text-[#1FE400]' : 'text-white/40'} uppercase mb-1 tracking-tight`}>
                        {isDragging ? 'Release to upload' : 'Drag & drop logo'}
                      </span>
                      <span className="inline-flex items-center px-4 py-2 bg-white/5 border border-white/10 rounded-xl font-black text-[10px] text-white/70 uppercase tracking-widest group-hover:bg-[#1FE400] group-hover:text-black transition-all shadow-sm">
                        <svg className="w-3.5 h-3.5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" /></svg>
                        Browse Media
                      </span>
                      <input
                        type="file"
                        className="hidden"
                        accept="image/*"
                        onChange={handleLogoUpload}
                      />
                    </label>
                  </div>

                  {formState.logoUrl && (
                    <button
                      onClick={() => setFormState({ ...formState, logoUrl: '' })}
                      className="text-white/20 hover:text-rose-500 p-2 hover:bg-rose-500/10 rounded-full transition-colors"
                      title="Clear Identity"
                    >
                      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                    </button>
                  )}
                </div>
              </div>
            </div>
            <div className="p-8 border-t border-white/5 bg-black/20 flex justify-end items-center space-x-6">
              <button
                onClick={() => setIsModalOpen(false)}
                className="text-xs font-black text-white/40 uppercase tracking-widest hover:text-white transition-colors"
              >
                Discard
              </button>
              <button
                onClick={handleSaveCompany}
                disabled={!formState.name}
                className="px-8 py-4 bg-white text-black rounded-2xl font-black text-xs uppercase tracking-[0.2em] shadow-2xl hover:bg-[#1FE400] transition-all active:scale-95 disabled:opacity-20 disabled:cursor-not-allowed"
              >
                {editingCompany ? 'Commit Changes' : 'Launch Entity'}
              </button>
            </div>
          </div>
        </div>
      )}

      <section className="space-y-6 pt-2">
        <div className="flex justify-between items-end">
          <h3 className="text-2xl font-black text-white tracking-tight uppercase">Venture Portfolio</h3>
          <p className="text-[10px] font-black text-white/40 uppercase tracking-[0.2em]">{state.companies.length} Active Entities</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {state.companies.map((company) => {
            const companyAccounts = state.accounts.filter(a => a.companyId === company.id);
            const companySubs = state.subscriptions.filter(s => s.companyId === company.id);
            const companyCards = state.financialCards.filter(c => c.companyId === company.id);
            const companyLoans = state.loans.filter(l => l.companyId === company.id);
            const companyBanks = state.institutions.filter(i => i.companyId === company.id);
            const companyDocs = state.documents.filter(d => d.companyId === company.id);

            const financialCount = companyCards.length + companyLoans.length + (companyBanks.length * 2); // Weight banks slightly higher

            return (
              <div
                key={company.id}
                onClick={() => onSelectCompany(company.id)}
                className="group relative bg-[#1C1C1E] rounded-[2rem] shadow-2xl border border-white/5 hover:border-[#1FE400]/30 transition-all duration-300 flex flex-col justify-between overflow-hidden cursor-pointer"
              >
                <div className="p-6">
                  <div className="flex items-center justify-between mb-6">
                    <div className="flex items-center space-x-4 min-w-0">
                      <div
                        className="w-14 h-14 rounded-2xl flex items-center justify-center text-white font-black flex-shrink-0 overflow-hidden bg-cover bg-center shadow-inner border border-white/5 transition-transform group-hover:scale-105 cursor-pointer"
                        onClick={(e) => { e.stopPropagation(); openEditModal(e, company); }}
                        style={{
                          backgroundColor: company.logoUrl ? 'white' : company.color,
                          backgroundImage: company.logoUrl ? `url(${company.logoUrl})` : 'none'
                        }}
                      >
                        {!company.logoUrl && <span className="text-2xl">{company.name.charAt(0)}</span>}
                      </div>
                      <div className="min-w-0">
                        <h4 className="text-xl font-black text-white group-hover:text-[#1FE400] transition-colors tracking-tight leading-tight truncate">{company.name}</h4>
                        <p className="text-[10px] font-black text-white/40 uppercase tracking-widest">{company.structure}</p>
                      </div>
                    </div>

                    <div
                      className="p-2 text-white/20 hover:text-[#1FE400] hover:bg-white/5 rounded-xl transition-all duration-200 flex-shrink-0 cursor-pointer"
                      onClick={(e) => { e.stopPropagation(); openEditModal(e, company); }}
                      title="Edit Entity Profile"
                    >
                      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                    </div>
                  </div>

                  <div className="flex flex-col space-y-1 mb-8">
                    <div className="flex items-center text-[10px] font-black tracking-tight text-white/30 uppercase">
                      <svg className="w-3 h-3 mr-1.5 opacity-40" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" /></svg>
                      Last Modified: <span className="text-white/70 ml-1.5 font-bold">{getTimeAgo(company.lastModified)}</span>
                    </div>
                    <div className="flex items-center text-[10px] font-black tracking-tight text-white/30 uppercase">
                      <svg className="w-3 h-3 mr-1.5 opacity-40" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268-2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                      Last Viewed: <span className="text-white/70 ml-1.5 font-bold">{getTimeAgo(company.lastViewed)}</span>
                    </div>
                  </div>
                </div>

                <div
                  className="grid grid-cols-4 gap-2 p-6 pt-6 border-t border-white/5 bg-black/20 hover:bg-[#1FE400]/5 transition-colors group/stats"
                >
                  <div className="flex flex-col min-w-0">
                    <p className="text-[9px] font-black text-white/30 uppercase tracking-widest mb-1 truncate group-hover/stats:text-white/50 transition-colors">Logins</p>
                    <div className="flex items-baseline space-x-1">
                      <p className="text-lg font-black text-white">{companyAccounts.length}</p>
                    </div>
                  </div>
                  <div className="flex flex-col border-l border-white/5 pl-2 min-w-0">
                    <p className="text-[9px] font-black text-white/30 uppercase tracking-widest mb-1 truncate group-hover/stats:text-[#1FE400]/50 transition-colors">Services</p>
                    <div className="flex items-baseline space-x-1">
                      <p className="text-lg font-black text-[#1FE400]">{companySubs.length}</p>
                    </div>
                  </div>
                  <div className="flex flex-col border-l border-white/5 pl-2 min-w-0">
                    <p className="text-[9px] font-black text-white/30 uppercase tracking-widest mb-1 truncate group-hover/stats:text-[#EBC351]/50 transition-colors">Finance</p>
                    <div className="flex items-baseline space-x-1">
                      <p className="text-lg font-black text-[#EBC351]">{financialCount}</p>
                    </div>
                  </div>
                  <div className="flex flex-col border-l border-white/5 pl-2 min-w-0">
                    <p className="text-[9px] font-black text-white/30 uppercase tracking-widest mb-1 truncate group-hover/stats:text-[#0091FF]/50 transition-colors">Docs</p>
                    <div className="flex items-baseline space-x-1">
                      <p className="text-lg font-black text-[#0091FF]">{companyDocs.length}</p>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}

          <button
            onClick={openAddModal}
            className="bg-white/5 border-2 border-dashed border-white/10 rounded-[2rem] flex flex-col items-center justify-center p-8 text-white/20 hover:border-[#1FE400]/50 hover:text-[#1FE400] hover:bg-white/5 transition-all duration-300 group min-h-[240px]"
          >
            <div className="w-14 h-14 rounded-2xl bg-[#1C1C1E] shadow-2xl flex items-center justify-center mb-4 group-hover:scale-110 group-hover:bg-[#1FE400] group-hover:text-black transition-all duration-300">
              <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M12 4v16m8-8H4" /></svg>
            </div>
            <span className="font-black text-sm uppercase tracking-widest">Incorporate Entity</span>
          </button>
        </div>
      </section>
    </div>
  );
};

export default Dashboard;
