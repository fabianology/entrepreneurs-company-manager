
import React, { useState } from 'react';
import { CompanyDocument } from '../types';

interface DocumentListProps {
  documents: CompanyDocument[];
  onAddDocument: (doc: Partial<CompanyDocument>) => void;
  onUpdateDocument: (id: string, updates: Partial<CompanyDocument>) => void;
  onDeleteDocument: (id: string) => void;
}

const DocumentList: React.FC<DocumentListProps> = ({ 
  documents, 
  onAddDocument, 
  onUpdateDocument,
  onDeleteDocument 
}) => {
  const [editingDoc, setEditingDoc] = useState<Partial<CompanyDocument> | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [uploadMode, setUploadMode] = useState<'link' | 'file'>('link');

  const handleAddNew = () => {
    setShowDeleteConfirm(false);
    setUploadMode('link');
    setEditingDoc({
      name: '',
      type: 'Other',
      url: '',
      notes: '',
      uploadDate: new Date().toISOString().split('T')[0]
    });
  };

  const handleSaveModal = () => {
    if (editingDoc) {
      if (editingDoc.id) {
         onUpdateDocument(editingDoc.id, editingDoc);
      } else {
         onAddDocument(editingDoc);
      }
      setEditingDoc(null);
    }
  };

  const processFile = (file: File) => {
    if (file) {
        if (file.size > 2 * 1024 * 1024) { // 2MB Limit
             alert("File too large. Please use a file smaller than 2MB.");
             return;
        }
        const reader = new FileReader();
        reader.onloadend = () => {
          setEditingDoc(prev => prev ? ({ ...prev, url: reader.result as string, name: prev.name || file.name }) : null);
        };
        reader.readAsDataURL(file);
    }
  };

  const getTypeColor = (type: string) => {
    switch(type) {
        case 'Formation': return 'bg-purple-50 text-purple-700 border-purple-100';
        case 'Legal': return 'bg-blue-50 text-blue-700 border-blue-100';
        case 'Contract': return 'bg-amber-50 text-amber-700 border-amber-100';
        case 'Finance': return 'bg-emerald-50 text-emerald-700 border-emerald-100';
        default: return 'bg-slate-50 text-slate-700 border-slate-100';
    }
  };

  return (
    <div className="space-y-5 animate-fadeIn">
      {/* Action Bar - Minimalist Floating Style */}
      <div className="w-full h-10 flex items-center justify-start p-0 overflow-x-auto no-scrollbar flex-nowrap mb-2 pb-1">
        <button
          onClick={handleAddNew}
          className="h-full px-8 bg-[#1C1C1E] text-white rounded-full text-[13px] font-medium uppercase tracking-normal transition-all flex items-center space-x-2 active:scale-95 shrink-0 group"
        >
          <svg className="w-3.5 h-3.5 text-white/40 group-hover:text-[#EBC351] transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M12 4v16m8-8H4" /></svg>
          <span>Document</span>
        </button>
      </div>

      {/* Edit/Add Modal */}
      {editingDoc && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 pb-[160px] bg-black/60 backdrop-blur-md animate-fadeIn">
          <div className="bg-[#1C1C1E] rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden border border-white/10">
            <div className="px-6 py-4 border-b border-white/5 flex justify-between items-center bg-black/20">
              <h3 className="text-sm font-bold text-white uppercase tracking-widest">
                {editingDoc.id ? 'Edit Document' : 'Add Document'}
              </h3>
              <button onClick={() => setEditingDoc(null)} className="text-white/40 hover:text-white transition p-2 hover:bg-white/5 rounded-lg">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>

            <div className="p-6 space-y-5 overflow-y-auto max-h-[70vh]">
              <div className="space-y-1">
                <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Document Name</label>
                <input
                  className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                  placeholder="Operating Agreement"
                  value={editingDoc.name || ''}
                  onChange={e => setEditingDoc({ ...editingDoc, name: e.target.value })}
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Type</label>
                  <select
                    className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition appearance-none"
                    value={editingDoc.type || 'Other'}
                    onChange={e => setEditingDoc({ ...editingDoc, type: e.target.value as any })}
                  >
                    <option value="Formation" className="bg-[#1C1C1E]">Formation</option>
                    <option value="Legal" className="bg-[#1C1C1E]">Legal</option>
                    <option value="Contract" className="bg-[#1C1C1E]">Contract</option>
                    <option value="Finance" className="bg-[#1C1C1E]">Finance</option>
                    <option value="Other" className="bg-[#1C1C1E]">Other</option>
                  </select>
                </div>
                <div className="space-y-1">
                  <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Date</label>
                  <input
                    type="date"
                    className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition [color-scheme:dark]"
                    value={editingDoc.uploadDate || ''}
                    onChange={e => setEditingDoc({ ...editingDoc, uploadDate: e.target.value })}
                  />
                </div>
              </div>

              <div className="space-y-1">
                <div className="flex justify-between items-center mb-1">
                  <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">File / Link</label>
                  <div className="flex bg-black/40 p-1 rounded-lg border border-white/5 h-[30px] items-center">
                    <button
                      onClick={() => setUploadMode('link')}
                      className={`px-3 h-full rounded text-[10px] font-bold uppercase tracking-widest transition-all ${uploadMode === 'link' ? 'bg-[#EBC351] text-black shadow-sm' : 'text-white/40 hover:text-white'}`}
                    >
                      Link
                    </button>
                    <button
                      onClick={() => setUploadMode('file')}
                      className={`px-3 h-full rounded text-[10px] font-bold uppercase tracking-widest transition-all ${uploadMode === 'file' ? 'bg-[#EBC351] text-black shadow-sm' : 'text-white/40 hover:text-white'}`}
                    >
                      File
                    </button>
                  </div>
                </div>

                {uploadMode === 'link' ? (
                  <input
                    className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition"
                    placeholder="https://drive.google.com/..."
                    value={editingDoc.url || ''}
                    onChange={e => setEditingDoc({ ...editingDoc, url: e.target.value })}
                  />
                ) : (
                  <div className="border border-dashed border-white/10 rounded-lg p-5 text-center hover:bg-white/5 transition cursor-pointer relative bg-black/20">
                    <input
                      type="file"
                      className="absolute inset-0 opacity-0 cursor-pointer"
                      onChange={(e) => e.target.files && processFile(e.target.files[0])}
                    />
                    <div className="text-xs text-white/40 font-medium">
                      {editingDoc.url && editingDoc.url.startsWith('data:') ? (
                        <span className="text-[#EBC351] font-bold flex items-center justify-center gap-2">
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" /></svg>
                          File Attached
                        </span>
                      ) : 'Drop file here or click to browse (max 2MB)'}
                    </div>
                  </div>
                )}
              </div>

              <div className="space-y-1">
                <label className="text-[12px] font-bold uppercase tracking-widest text-white/40 ml-1">Notes</label>
                <textarea
                  className="w-full bg-black/20 border border-white/[0.03] rounded-lg px-3 py-2 text-[13px] font-medium text-white outline-none focus:border-[#EBC351]/50 transition resize-none custom-scrollbar"
                  placeholder="Details about this document..."
                  rows={3}
                  value={editingDoc.notes || ''}
                  onChange={e => setEditingDoc({ ...editingDoc, notes: e.target.value })}
                />
              </div>
            </div>

            <div className="px-6 py-3 border-t border-white/5 bg-black/20 flex items-center justify-between font-bold">
              <div>
                {editingDoc.id && (
                  showDeleteConfirm ? (
                    <div className="flex items-center bg-orange-500/10 rounded-lg p-1 border border-orange-500/30 gap-3">
                      <span className="text-[10px] font-bold text-orange-500 uppercase px-2">Confirm?</span>
                      <div className="flex gap-1">
                        <button onClick={() => { onDeleteDocument(editingDoc.id!); setEditingDoc(null); }} className="text-[10px] font-bold text-white hover:text-orange-500 px-4 py-2 bg-black/40 hover:bg-black/80 rounded transition-colors">YES</button>
                        <button onClick={() => setShowDeleteConfirm(false)} className="text-[10px] font-bold text-white/40 hover:text-white px-4 py-2 bg-black/40 hover:bg-black/80 rounded transition-colors">NO</button>
                      </div>
                    </div>
                  ) : (
                    <button onClick={() => setShowDeleteConfirm(true)} className="text-white/20 hover:text-orange-500 p-3 transition rounded-lg hover:bg-white/5 border border-transparent flex items-center justify-center">
                      <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                    </button>
                  )
                )}
              </div>
              <div className="flex space-x-4">
                <button onClick={() => setEditingDoc(null)} className="px-6 py-3 text-[11px] font-bold text-white/40 uppercase tracking-widest hover:text-white transition">Cancel</button>
                <button onClick={handleSaveModal} className="h-[36px] px-8 bg-orange-500 rounded-lg text-[11px] font-bold text-white uppercase tracking-widest shadow-lg shadow-orange-500/20 hover:scale-[1.02] active:scale-95 transition">Save</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Grid Layout */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {documents.map(doc => (
            <div key={doc.id} className="bg-white rounded-xl border border-slate-100 shadow-sm p-4 hover:shadow-md transition group relative">
                <div className="flex justify-between items-start mb-2">
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wide border ${getTypeColor(doc.type)}`}>
                        {doc.type}
                    </span>
                    <button 
                        onClick={() => setEditingDoc(doc)}
                        className="text-slate-300 hover:text-indigo-600 opacity-0 group-hover:opacity-100 transition-opacity"
                    >
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" /></svg>
                    </button>
                </div>
                
                <h4 className="font-bold text-slate-800 mb-1 truncate" title={doc.name}>{doc.name}</h4>
                <p className="text-xs text-slate-500 mb-4 line-clamp-2 min-h-[2.5em]">{doc.notes || 'No notes added.'}</p>
                
                <div className="flex justify-between items-center border-t border-slate-50 pt-3">
                    <span className="text-[10px] text-slate-400 font-medium">{doc.uploadDate}</span>
                    {doc.url ? (
                        <a 
                            href={doc.url} 
                            target="_blank" 
                            rel="noreferrer"
                            className="text-xs font-bold text-indigo-600 hover:text-indigo-800 flex items-center gap-1 bg-indigo-50 px-2 py-1 rounded hover:bg-indigo-100 transition-colors"
                            download={doc.url.startsWith('data:') ? doc.name : undefined}
                        >
                            {doc.url.startsWith('data:') ? 'Download' : 'Open Link'}
                            <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
                        </a>
                    ) : (
                        <span className="text-[10px] text-slate-300 italic">No file/link</span>
                    )}
                </div>
            </div>
        ))}
        {documents.length === 0 && (
          <div className="md:col-span-3">
            <button
              onClick={handleAddNew}
              className="w-full max-w-[400px] mx-auto h-[216px] rounded-[32px] border border-dashed border-slate-300 flex flex-col items-center justify-center bg-slate-50 hover:bg-slate-100 hover:border-indigo-400 transition-all duration-300 group shadow-sm mt-8"
            >
              <div className="w-16 h-16 bg-white rounded-full flex items-center justify-center mx-auto mb-4 group-hover:scale-110 transition-transform duration-300 shadow-sm border border-slate-100">
                <span className="text-2xl">📄</span>
              </div>
              <span className="text-[10px] font-black text-slate-400 group-hover:text-indigo-600 uppercase tracking-[0.2em] transition-colors">+ Add Your First Document</span>
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default DocumentList;
