import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, ScrollView, Alert } from 'react-native';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useAppContext } from '../../context/AppContext';
import { CompanyDocument } from '../../types';

export default function DocumentDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { state, handleUpdateCompanyDocument, handleAddCompanyDocument, handleDeleteCompanyDocument, selectedCompanyId } = useAppContext();

  const isNew = id === 'new';
  const existingDoc = state?.companyDocuments?.find(d => d.id === id);

  if (!isNew && !existingDoc) {
    return (
      <View className="flex-1 bg-black items-center justify-center">
        <Text className="text-white">Document not found.</Text>
        <TouchableOpacity onPress={() => router.back()} className="mt-4 bg-white/10 p-3 rounded-xl">
          <Text className="text-white">Go Back</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const [editingDoc, setEditingDoc] = useState<Partial<CompanyDocument>>(
    isNew 
      ? { 
          companyId: selectedCompanyId || '', 
          name: '',
          type: 'Other',
          url: '',
          notes: '',
          uploadDate: new Date().toISOString().split('T')[0]
        } 
      : { ...existingDoc }
  );

  const handleSave = () => {
    if (!editingDoc.name || editingDoc.name.trim() === '') {
      Alert.alert('Missing Name', 'Please enter a name for this document.');
      return;
    }

    if (isNew) {
      handleAddCompanyDocument(editingDoc);
    } else {
      handleUpdateCompanyDocument(id as string, editingDoc);
    }
    router.back();
  };

  const requestDelete = () => {
    Alert.alert(
      "Delete Document",
      `Remove ${editingDoc.name}?`,
      [
        { text: "Cancel", style: "cancel" },
        { 
          text: "Delete", 
          style: "destructive", 
          onPress: () => {
             handleDeleteCompanyDocument(id as string);
             router.back();
          } 
        }
      ]
    );
  };

  const updateField = (key: keyof CompanyDocument, value: any) => {
    setEditingDoc(prev => ({ ...prev, [key]: value }));
  };

  return (
    <View className="flex-1 bg-black">
       <Stack.Screen 
        options={{ 
          title: isNew ? 'New Document' : editingDoc.name,
          headerStyle: { backgroundColor: '#000000' },
          headerTintColor: '#fff',
          headerBackTitleVisible: false
        }} 
      />

      <ScrollView className="flex-1 px-4 py-6">
        
        {/* Top Actions */}
        <View className="flex-row justify-between items-center mb-6 px-2">
            <TouchableOpacity onPress={() => router.back()} className="bg-white/10 p-2 rounded-full">
              <Ionicons name="close" size={24} color="rgba(255,255,255,0.6)" />
            </TouchableOpacity>
            
            <TouchableOpacity onPress={handleSave} className="bg-white px-6 py-2 rounded-full">
              <Text className="text-black font-black uppercase tracking-widest text-[11px]">Save Document</Text>
            </TouchableOpacity>
        </View>

        {/* Hero Form */}
        <View className="bg-[#1C1C1E] border border-white/5 rounded-[24px] p-6 mb-6">
            <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Document Name</Text>
            <TextInput 
              value={editingDoc.name}
              onChangeText={(text) => updateField('name', text)}
              placeholder="e.g. Q3 Profit and Loss"
              placeholderTextColor="rgba(255,255,255,0.2)"
              className="text-3xl font-black text-white mb-6"
            />

            <View className="flex-row space-x-4">
               <View className="flex-1">
                 <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Type</Text>
                 <View className="bg-black/50 rounded-xl overflow-hidden">
                   <ScrollView horizontal showsHorizontalScrollIndicator={false} className="py-2 px-2">
                     {['Formation', 'Legal', 'Contract', 'Finance', 'Other'].map(type => (
                       <TouchableOpacity 
                          key={type}
                          onPress={() => updateField('type', type)}
                          className={`px-4 py-2 rounded-lg mr-2 ${editingDoc.type === type ? 'bg-[#EBC351]' : 'bg-white/5'}`}
                       >
                         <Text className={`text-[10px] font-black uppercase tracking-widest ${editingDoc.type === type ? 'text-black' : 'text-white/40'}`}>
                            {type}
                         </Text>
                       </TouchableOpacity>
                     ))}
                   </ScrollView>
                 </View>
               </View>
            </View>
        </View>

        {/* Data Tracking Form */}
        <Text className="text-[11px] font-black uppercase tracking-widest text-white/40 mb-3 px-4">Metadata & Links</Text>
        <View className="bg-[#1C1C1E] border border-white/5 rounded-[24px] p-6 mb-8 divide-y divide-white/5">
            
            <View className="pb-4">
              <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Linked URL / Location</Text>
              <TextInput 
                 value={editingDoc.url}
                 onChangeText={(text) => updateField('url', text)}
                 placeholder="https://drive.google.com/..."
                 placeholderTextColor="rgba(255,255,255,0.2)"
                 className="text-sm font-medium text-[#EBC351] px-4 py-3 bg-black/40 rounded-xl"
              />
            </View>

            <View className="py-4">
              <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Date (YYYY-MM-DD)</Text>
              <TextInput 
                 value={editingDoc.uploadDate}
                 onChangeText={(text) => updateField('uploadDate', text)}
                 placeholder="2026-04-13"
                 placeholderTextColor="rgba(255,255,255,0.2)"
                 className="text-sm font-medium text-white px-4 py-3 bg-black/40 rounded-xl"
              />
            </View>

            <View className="py-4">
              <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Notes</Text>
              <TextInput 
                 value={editingDoc.notes}
                 onChangeText={(text) => updateField('notes', text)}
                 placeholder="Add context to this document..."
                 placeholderTextColor="rgba(255,255,255,0.2)"
                 className="text-sm font-medium text-white px-4 py-3 bg-black/40 rounded-xl min-h-[100px]"
                 multiline
                 textAlignVertical="top"
              />
            </View>

        </View>

        {/* Delete */}
        {!isNew && (
          <TouchableOpacity onPress={requestDelete} className="p-4 rounded-3xl items-center border border-red-500/30 mb-20">
            <Text className="text-red-500 font-bold">Delete Document</Text>
          </TouchableOpacity>
        )}

      </ScrollView>
    </View>
  );
}
