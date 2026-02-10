
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
    <div className="space-y-8 animate-fadeIn">
      {/* Add/Edit Company Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fadeIn overflow-y-auto">
            <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg text-slate-900 overflow-hidden my-auto">
                <div className="p-6 border-b border-slate-100 flex justify-between items-center bg-white">
                    <h3 className="text-xl font-bold text-slate-900">{editingCompany ? 'Edit Entity Profile' : 'Register New Entity'}</h3>
                    <button onClick={() => setIsModalOpen(false)} className="text-slate-400 hover:text-slate-600 transition-colors">
                        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
                    </button>
                </div>
                <div className="p-6 space-y-4 overflow-y-auto max-h-[70vh]">
                    <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1 tracking-wider">Entity Name</label>
                        <input 
                            autoFocus
                            className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white transition-shadow"
                            placeholder="e.g. Acme Holdings Inc."
                            value={formState.name}
                            onChange={(e) => setFormState({ ...formState, name: e.target.value })}
                        />
                    </div>
                    <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1 tracking-wider">Entity Structure</label>
                        <select
                            className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white transition-shadow"
                            value={formState.structure}
                            onChange={(e) => setFormState({ ...formState, structure: e.target.value })}
                        >
                            {COMPANY_STRUCTURES.map(type => (
                                <option key={type} value={type}>{type}</option>
                            ))}
                        </select>
                    </div>
                    <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-1 tracking-wider">Purpose / Vision</label>
                        <textarea 
                            className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white transition-shadow"
                            placeholder="A brief mission statement..."
                            rows={3}
                            value={formState.description}
                            onChange={(e) => setFormState({ ...formState, description: e.target.value })}
                        />
                    </div>
                    <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase mb-2 tracking-wider">Identity Color</label>
                        <div className="flex flex-wrap gap-2 mb-4">
                            {BRAND_COLORS.map(color => (
                                <button
                                    key={color}
                                    type="button"
                                    onClick={() => setFormState({ ...formState, color, logoUrl: '' })}
                                    className={`w-8 h-8 rounded-full border border-white transition-transform hover:scale-110 ${formState.color === color && !formState.logoUrl ? 'ring-2 ring-offset-2 ring-indigo-600' : ''}`}
                                    style={{ backgroundColor: color }}
                                />
                            ))}
                        </div>

                        <label className="block text-xs font-bold text-slate-500 uppercase mb-2 tracking-wider">Corporate Identity (Logo)</label>
                        <div 
                            className={`flex items-center space-x-3 p-4 rounded-xl border-2 transition-all duration-200 ${
                                isDragging 
                                    ? 'bg-indigo-50 border-indigo-400 border-dashed scale-[1.02]' 
                                    : 'bg-slate-50 border-slate-100'
                            }`}
                            onDragOver={handleDragOver}
                            onDragLeave={handleDragLeave}
                            onDrop={handleDrop}
                        >
                             <div className="relative w-14 h-14 flex-shrink-0">
                                 <div 
                                    className="w-full h-full rounded-xl flex items-center justify-center overflow-hidden border border-slate-200 bg-white shadow-sm transition-transform group-hover:scale-105"
                                 >
                                    {formState.logoUrl ? (
                                        <img src={formState.logoUrl} alt="Logo Preview" className="w-full h-full object-cover" />
                                    ) : (
                                        <div className="w-full h-full flex items-center justify-center transition-colors" style={{ backgroundColor: formState.color || '#cbd5e1' }}>
                                            <span className="text-white font-black text-xl">{formState.name?.charAt(0) || '?'}</span>
                                        </div>
                                    )}
                                 </div>
                             </div>
                             
                             <div className="flex-1">
                                <label className="cursor-pointer flex flex-col items-start group">
                                    <span className={`text-[10px] font-bold ${isDragging ? 'text-indigo-600' : 'text-slate-400'} uppercase mb-1 tracking-tight`}>
                                        {isDragging ? 'Release to upload' : 'Drag & drop logo'}
                                    </span>
                                    <span className="inline-flex items-center px-4 py-2 bg-white border border-slate-300 rounded-lg font-bold text-xs text-slate-700 group-hover:bg-indigo-50 group-hover:text-indigo-600 transition-all shadow-sm">
                                        <svg className="w-3.5 h-3.5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" /></svg>
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
                                    onClick={() => setFormState({...formState, logoUrl: ''})}
                                    className="text-slate-400 hover:text-rose-500 p-2 hover:bg-rose-50 rounded-full transition-colors"
                                    title="Clear Identity"
                                 >
                                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                                 </button>
                             )}
                        </div>
                    </div>
                </div>
                <div className="p-6 border-t border-slate-100 bg-slate-50 flex justify-end space-x-3">
                    <button 
                        onClick={() => setIsModalOpen(false)}
                        className="px-4 py-2 text-slate-600 font-bold hover:text-slate-800 transition-colors"
                    >
                        Discard
                    </button>
                    <button 
                        onClick={handleSaveCompany}
                        disabled={!formState.name}
                        className="px-8 py-2 bg-indigo-600 text-white rounded-xl font-bold shadow-lg shadow-indigo-200 hover:bg-indigo-700 hover:shadow-indigo-300 transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        {editingCompany ? 'Commit Changes' : 'Launch Entity'}
                    </button>
                </div>
            </div>
        </div>
      )}

      <section className="space-y-6 pt-2">
        <div className="flex justify-between items-end">
          <h3 className="text-2xl font-black text-slate-900 tracking-tight">Venture Portfolio</h3>
          <p className="text-xs font-bold text-slate-400 uppercase tracking-widest">{state.companies.length} Active Entities</p>
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
                className="group relative bg-white p-6 rounded-[2rem] shadow-sm border border-slate-100 hover:shadow-2xl hover:border-indigo-100 transition-all duration-300 cursor-pointer flex flex-col justify-between"
              >
                <div>
                    <div className="flex items-center justify-between mb-6">
                       <div className="flex items-center space-x-4 min-w-0">
                          <div 
                            className="w-14 h-14 rounded-2xl flex items-center justify-center text-white font-black flex-shrink-0 overflow-hidden bg-cover bg-center shadow-inner border border-slate-50 transition-transform group-hover:scale-105"
                            style={{ 
                                backgroundColor: company.logoUrl ? 'white' : company.color,
                                backgroundImage: company.logoUrl ? `url(${company.logoUrl})` : 'none'
                            }}
                          >
                            {!company.logoUrl && <span className="text-2xl">{company.name.charAt(0)}</span>}
                          </div>
                          <div className="min-w-0">
                            <h4 className="text-xl font-black text-slate-900 group-hover:text-indigo-600 transition-colors tracking-tight leading-tight truncate">{company.name}</h4>
                            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{company.structure}</p>
                          </div>
                       </div>
                       
                       <button
                         onClick={(e) => openEditModal(e, company)}
                         className="p-2 text-slate-200 hover:text-indigo-600 hover:bg-indigo-50 rounded-xl transition-all duration-200 flex-shrink-0"
                         title="Edit Entity Profile"
                       >
                         <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                       </button>
                    </div>
                    
                    <div className="flex flex-col space-y-1 mb-8">
                       <div className="flex items-center text-[10px] font-bold tracking-tight text-slate-400 uppercase">
                          <svg className="w-3 h-3 mr-1.5 opacity-60" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" /></svg>
                          Last Modified: <span className="text-slate-600 ml-1.5 font-black">{getTimeAgo(company.lastModified)}</span>
                       </div>
                       <div className="flex items-center text-[10px] font-bold tracking-tight text-slate-400 uppercase">
                          <svg className="w-3 h-3 mr-1.5 opacity-60" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268-2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                          Last Viewed: <span className="text-slate-600 ml-1.5 font-black">{getTimeAgo(company.lastViewed)}</span>
                       </div>
                    </div>
                </div>
                
                <div className="grid grid-cols-4 gap-2 pt-6 border-t border-slate-50/80">
                    <div className="flex flex-col min-w-0">
                      <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest mb-1 truncate">Logins</p>
                      <div className="flex items-baseline space-x-1">
                        <p className="text-lg font-black text-slate-800">{companyAccounts.length}</p>
                      </div>
                    </div>
                    <div className="flex flex-col border-l border-slate-50 pl-2 min-w-0">
                      <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest mb-1 truncate">Services</p>
                      <div className="flex items-baseline space-x-1">
                        <p className="text-lg font-black text-indigo-600">{companySubs.length}</p>
                      </div>
                    </div>
                    <div className="flex flex-col border-l border-slate-50 pl-2 min-w-0">
                      <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest mb-1 truncate">Finance</p>
                      <div className="flex items-baseline space-x-1">
                        <p className="text-lg font-black text-emerald-600">{financialCount}</p>
                      </div>
                    </div>
                    <div className="flex flex-col border-l border-slate-50 pl-2 min-w-0">
                      <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest mb-1 truncate">Docs</p>
                      <div className="flex items-baseline space-x-1">
                        <p className="text-lg font-black text-amber-500">{companyDocs.length}</p>
                      </div>
                    </div>
                </div>
              </div>
            );
          })}

          <button 
            onClick={openAddModal}
            className="bg-slate-50 border-2 border-dashed border-slate-200 rounded-[2rem] flex flex-col items-center justify-center p-8 text-slate-400 hover:border-indigo-400 hover:text-indigo-600 hover:bg-white transition-all duration-300 group min-h-[240px]"
          >
            <div className="w-14 h-14 rounded-2xl bg-white shadow-sm flex items-center justify-center mb-4 group-hover:scale-110 group-hover:bg-indigo-600 group-hover:text-white transition-all duration-300">
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
