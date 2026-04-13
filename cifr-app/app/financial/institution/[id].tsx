import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, ScrollView, Alert } from 'react-native';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useAppContext } from '../../../context/AppContext';
import { Institution, InstitutionAccount } from '../../../types';

export default function InstitutionDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { state, handleUpdateInstitution, handleAddInstitution, handleDeleteInstitution, selectedCompanyId } = useAppContext();

  const isNew = id === 'new';
  const existingInst = state?.institutions?.find(i => i.id === id);

  if (!isNew && !existingInst) {
    return (
      <View className="flex-1 bg-black items-center justify-center">
        <Text className="text-white">Institution not found.</Text>
        <TouchableOpacity onPress={() => router.back()} className="mt-4 bg-white/10 p-3 rounded-xl">
          <Text className="text-white">Go Back</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const [editingInst, setEditingInst] = useState<Partial<Institution>>(
    isNew 
      ? { 
          companyId: selectedCompanyId || '', 
          name: '', 
          loginUrl: '',
          email: '',
          username: '',
          password: '',
          accounts: []
        } 
      : { ...existingInst }
  );

  const [showPassword, setShowPassword] = useState(false);

  const handleSave = () => {
    if (!editingInst.name || editingInst.name.trim() === '') {
      Alert.alert('Missing Name', 'Please enter a name for the institution.');
      return;
    }

    if (isNew) {
      handleAddInstitution(editingInst);
    } else {
      handleUpdateInstitution(id as string, editingInst);
    }
    router.back();
  };

  const requestDelete = () => {
    Alert.alert(
      "Delete Institution",
      `Remove ${editingInst.name}? This will not automatically delete the synced Credit Cards connected to this account.`,
      [
        { text: "Cancel", style: "cancel" },
        { 
          text: "Delete", 
          style: "destructive", 
          onPress: () => {
             handleDeleteInstitution(id as string);
             router.back();
          } 
        }
      ]
    );
  };

  const updateInstField = (key: keyof Institution, value: any) => {
    setEditingInst(prev => ({ ...prev, [key]: value }));
  };

  const addEmptyAccount = () => {
    const newAcc: InstitutionAccount = {
      id: Math.random().toString(36).substr(2, 9),
      name: 'New Account',
      type: 'Checking',
      last4: '',
      balance: 0
    };
    updateInstField('accounts', [...(editingInst.accounts || []), newAcc]);
  };

  const removeAccount = (index: number) => {
    const updated = [...(editingInst.accounts || [])];
    updated.splice(index, 1);
    updateInstField('accounts', updated);
  };

  return (
    <View className="flex-1 bg-black">
       <Stack.Screen 
        options={{ 
          title: isNew ? 'New Institution' : editingInst.name,
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
              <Text className="text-black font-black uppercase tracking-widest text-[11px]">Save Bank</Text>
            </TouchableOpacity>
        </View>

        {/* Hero Form */}
        <View className="bg-[#1C1C1E] border border-white/5 rounded-[24px] p-6 mb-6">
            <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Institution Name</Text>
            <TextInput 
              value={editingInst.name}
              onChangeText={(text) => updateInstField('name', text)}
              placeholder="e.g. Chase Bank"
              placeholderTextColor="rgba(255,255,255,0.2)"
              className="text-3xl font-black text-white"
            />
        </View>

        {/* Credentials Form */}
        <Text className="text-[11px] font-black uppercase tracking-widest text-white/40 mb-3 px-4">Web Credentials</Text>
        <View className="bg-[#1C1C1E] border border-white/5 rounded-[24px] p-6 mb-6 divide-y divide-white/5">
            <View className="pb-4">
              <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Login URL</Text>
              <TextInput 
                 value={editingInst.loginUrl}
                 onChangeText={(text) => updateInstField('loginUrl', text)}
                 placeholder="chase.com"
                 placeholderTextColor="rgba(255,255,255,0.2)"
                 className="text-sm font-medium text-white px-4 py-3 bg-black/40 rounded-xl"
              />
            </View>
            <View className="py-4">
              <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Username / Login ID</Text>
              <TextInput 
                 value={editingInst.username}
                 onChangeText={(text) => updateInstField('username', text)}
                 placeholder="admin@startup.com"
                 placeholderTextColor="rgba(255,255,255,0.2)"
                 className="text-sm font-medium text-white px-4 py-3 bg-black/40 rounded-xl"
                 autoCapitalize="none"
              />
            </View>
            <View className="pt-4">
              <View className="flex-row items-center justify-between mb-2">
                <Text className="text-[10px] font-black uppercase tracking-widest text-white/40">Password</Text>
                <TouchableOpacity onPress={() => setShowPassword(!showPassword)}>
                  <Ionicons name={showPassword ? "eye-off" : "eye"} size={16} color="rgba(255,255,255,0.4)" />
                </TouchableOpacity>
              </View>
              <TextInput 
                 value={editingInst.password}
                 onChangeText={(text) => updateInstField('password', text)}
                 placeholder="••••••••"
                 secureTextEntry={!showPassword}
                 placeholderTextColor="rgba(255,255,255,0.2)"
                 className="text-sm font-medium text-white px-4 py-3 bg-black/40 rounded-xl"
              />
            </View>
        </View>

        {/* Bank Accounts Form */}
        <View className="flex-row justify-between items-center px-4 mb-3">
          <Text className="text-[11px] font-black uppercase tracking-widest text-white/40">Linked Accounts ({editingInst.accounts?.length || 0})</Text>
          <TouchableOpacity onPress={addEmptyAccount}>
             <Text className="text-[#EBC351] font-bold text-xs uppercase tracking-widest">+ Add</Text>
          </TouchableOpacity>
        </View>

        <View className="bg-[#1C1C1E] border border-white/5 rounded-[24px] mb-8 overflow-hidden divide-y divide-white/5">
           {!editingInst.accounts || editingInst.accounts.length === 0 ? (
             <View className="p-6 items-center">
               <Text className="text-white/20 text-xs text-center font-bold">No internal accounts tracked.</Text>
             </View>
           ) : (
             editingInst.accounts.map((acc, idx) => (
               <View key={acc.id || idx} className="p-5 flex-row items-center justify-between">
                 <View className="flex-1 mr-4">
                   <TextInput 
                      value={acc.name}
                      onChangeText={(text) => {
                         const updated = [...(editingInst.accounts || [])];
                         updated[idx].name = text;
                         updateInstField('accounts', updated);
                      }}
                      placeholder="Biz Checking"
                      placeholderTextColor="rgba(255,255,255,0.2)"
                      className="text-base font-bold text-white mb-2"
                   />
                   <View className="flex-row items-center space-x-4">
                       <View className="flex-row items-center">
                         <Text className="text-[10px] text-white/40 font-bold uppercase tracking-widest mr-2">Num:</Text>
                         <TextInput 
                            value={acc.last4}
                            onChangeText={(text) => {
                               const updated = [...(editingInst.accounts || [])];
                               updated[idx].last4 = text;
                               updateInstField('accounts', updated);
                            }}
                            placeholder="x1234"
                            placeholderTextColor="rgba(255,255,255,0.2)"
                            className="text-sm text-white font-bold border-b border-white/10 w-16"
                            maxLength={4}
                         />
                       </View>
                       <View className="flex-row items-center">
                         <Text className="text-[10px] text-white/40 font-bold uppercase tracking-widest mr-1">$</Text>
                         <TextInput 
                            value={acc.balance?.toString() || ''}
                            onChangeText={(text) => {
                               const updated = [...(editingInst.accounts || [])];
                               updated[idx].balance = parseFloat(text) || 0;
                               updateInstField('accounts', updated);
                            }}
                            keyboardType="numeric"
                            placeholder="0.00"
                            placeholderTextColor="rgba(255,255,255,0.2)"
                            className="text-sm text-white font-bold border-b border-white/10 w-24"
                         />
                       </View>
                   </View>
                 </View>
                 
                 <TouchableOpacity onPress={() => removeAccount(idx)}>
                   <Ionicons name="trash" size={20} color="rgba(239, 68, 68, 0.6)" />
                 </TouchableOpacity>
               </View>
             ))
           )}
        </View>

        {/* Delete */}
        {!isNew && (
          <TouchableOpacity onPress={requestDelete} className="p-4 rounded-3xl items-center border border-red-500/30 mb-20">
            <Text className="text-red-500 font-bold">Delete Institution</Text>
          </TouchableOpacity>
        )}

      </ScrollView>
    </View>
  );
}
