
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
    <div className="space-y-6 animate-fadeIn">
      <div className="flex justify-between items-center px-1">
        <h3 className="text-lg font-bold text-slate-800">Company Documents</h3>
        <button 
          onClick={handleAddNew}
          className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-indigo-700 transition shadow-sm active:scale-95"
        >
          + Add Document
        </button>
      </div>

      {/* Edit/Add Modal */}
      {editingDoc && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fadeIn overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg text-slate-900 my-auto">
            <div className="p-6 border-b border-slate-100 flex justify-between items-center">
              <h3 className="text-xl font-bold text-slate-900">
                {editingDoc.id ? 'Edit Document' : 'Add Document'}
              </h3>
              <button onClick={() => setEditingDoc(null)} className="text-slate-400 hover:text-slate-600">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            
            <div className="p-6 space-y-4">
               <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Document Name</label>
                  <input 
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    placeholder="e.g. Operating Agreement"
                    value={editingDoc.name || ''}
                    onChange={e => setEditingDoc({...editingDoc, name: e.target.value})}
                  />
               </div>
               
               <div className="grid grid-cols-2 gap-4">
                 <div>
                    <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Type</label>
                    <select
                      className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                      value={editingDoc.type || 'Other'}
                      onChange={e => setEditingDoc({...editingDoc, type: e.target.value as any})}
                    >
                      <option value="Formation">Formation</option>
                      <option value="Legal">Legal</option>
                      <option value="Contract">Contract</option>
                      <option value="Finance">Finance</option>
                      <option value="Other">Other</option>
                    </select>
                 </div>
                 <div>
                    <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Date</label>
                    <input 
                       type="date"
                       className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                       value={editingDoc.uploadDate || ''}
                       onChange={e => setEditingDoc({...editingDoc, uploadDate: e.target.value})}
                    />
                 </div>
               </div>

               <div>
                   <div className="flex justify-between items-center mb-1">
                      <label className="block text-xs font-bold text-slate-500 uppercase">File / Link</label>
                      <div className="flex bg-slate-100 rounded p-0.5">
                         <button 
                            onClick={() => setUploadMode('link')}
                            className={`px-2 py-0.5 text-[10px] font-bold rounded ${uploadMode === 'link' ? 'bg-white shadow-sm text-indigo-600' : 'text-slate-500'}`}
                         >
                            Link
                         </button>
                         <button 
                            onClick={() => setUploadMode('file')}
                            className={`px-2 py-0.5 text-[10px] font-bold rounded ${uploadMode === 'file' ? 'bg-white shadow-sm text-indigo-600' : 'text-slate-500'}`}
                         >
                            Upload
                         </button>
                      </div>
                   </div>
                   
                   {uploadMode === 'link' ? (
                      <input 
                        className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                        placeholder="https://drive.google.com/..."
                        value={editingDoc.url || ''}
                        onChange={e => setEditingDoc({...editingDoc, url: e.target.value})}
                      />
                   ) : (
                      <div className="border-2 border-dashed border-slate-200 rounded-lg p-4 text-center hover:bg-slate-50 transition cursor-pointer relative">
                         <input 
                            type="file" 
                            className="absolute inset-0 opacity-0 cursor-pointer"
                            onChange={(e) => e.target.files && processFile(e.target.files[0])}
                         />
                         <div className="text-sm text-slate-500">
                            {editingDoc.url && editingDoc.url.startsWith('data:') ? (
                                <span className="text-emerald-600 font-bold flex items-center justify-center gap-1">
                                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" /></svg>
                                    File Attached
                                </span>
                            ) : 'Click to select file (max 2MB)'}
                         </div>
                      </div>
                   )}
               </div>

               <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1">Notes</label>
                  <textarea 
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-black bg-white"
                    placeholder="Details about this document..."
                    rows={3}
                    value={editingDoc.notes || ''}
                    onChange={e => setEditingDoc({...editingDoc, notes: e.target.value})}
                  />
               </div>
            </div>

            <div className="p-6 border-t border-slate-100 bg-slate-50 rounded-b-2xl flex justify-between items-center">
              <div>
                  {editingDoc.id && (
                     showDeleteConfirm ? (
                        <div className="flex items-center space-x-2">
                           <button 
                              onClick={() => { onDeleteDocument(editingDoc.id!); setEditingDoc(null); }}
                              className="bg-rose-600 text-white px-3 py-1.5 rounded text-xs font-bold"
                           >
                              Confirm
                           </button>
                           <button 
                              onClick={() => setShowDeleteConfirm(false)}
                              className="text-slate-500 text-xs font-bold underline"
                           >
                              Cancel
                           </button>
                        </div>
                     ) : (
                        <button 
                           onClick={() => setShowDeleteConfirm(true)}
                           className="text-rose-500 text-sm font-bold hover:text-rose-700"
                        >
                           Delete
                        </button>
                     )
                  )}
               </div>
               <div className="flex space-x-3">
                  <button 
                     onClick={() => setEditingDoc(null)}
                     className="px-4 py-2 text-slate-600 font-bold hover:text-slate-800"
                  >
                     Cancel
                  </button>
                  <button 
                     onClick={handleSaveModal}
                     className="px-6 py-2 bg-indigo-600 text-white rounded-lg font-bold shadow-sm hover:bg-indigo-700 transition"
                  >
                     Save
                  </button>
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
             <div className="col-span-1 md:col-span-3 py-12 text-center border-2 border-dashed border-slate-100 rounded-xl">
                <div className="w-12 h-12 bg-slate-50 rounded-full flex items-center justify-center mx-auto mb-3">
                   <svg className="w-6 h-6 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
                </div>
                <p className="text-slate-400 font-medium text-sm">No documents found.</p>
             </div>
        )}
      </div>
    </div>
  );
};

export default DocumentList;
