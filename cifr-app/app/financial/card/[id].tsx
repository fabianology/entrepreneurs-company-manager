import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, ScrollView, Alert } from 'react-native';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useAppContext } from '../../../context/AppContext';
import { FinancialCard } from '../../../types';

export default function CardDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { state, handleUpdateFinancialCard, handleAddFinancialCard, handleDeleteFinancialCard, selectedCompanyId } = useAppContext();

  const isNew = id === 'new';
  const existingCard = state?.financialCards?.find(c => c.id === id);

  if (!isNew && !existingCard) {
    return (
      <View className="flex-1 bg-black items-center justify-center">
        <Text className="text-white">Card not found.</Text>
        <TouchableOpacity onPress={() => router.back()} className="mt-4 bg-white/10 p-3 rounded-xl">
          <Text className="text-white">Go Back</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const [editingCard, setEditingCard] = useState<Partial<FinancialCard>>(
    isNew 
      ? { 
          companyId: selectedCompanyId || '', 
          name: '', 
          institutionName: '',
          last4: '',
          expiry: '',
          network: 'Visa',
          type: 'Credit',
          status: 'Active',
          limit: 0,
          cardHolder: ''
        } 
      : { ...existingCard }
  );

  const handleSave = () => {
    if (!editingCard.name || editingCard.name.trim() === '') {
      Alert.alert('Missing Name', 'Please enter a nickname for this card.');
      return;
    }

    if (isNew) {
      handleAddFinancialCard(editingCard);
    } else {
      handleUpdateFinancialCard(id as string, editingCard);
    }
    router.back();
  };

  const requestDelete = () => {
    Alert.alert(
      "Delete Card",
      `Remove ${editingCard.name}?`,
      [
        { text: "Cancel", style: "cancel" },
        { 
          text: "Delete", 
          style: "destructive", 
          onPress: () => {
             handleDeleteFinancialCard(id as string);
             router.back();
          } 
        }
      ]
    );
  };

  const updateField = (key: keyof FinancialCard, value: any) => {
    setEditingCard(prev => ({ ...prev, [key]: value }));
  };

  const getCardColor = () => {
    const name = (editingCard.institutionName || '').toLowerCase();
    if (name.includes('chase') || name.includes('amex') || name.includes('citi')) return 'bg-blue-900 border-blue-500/30';
    if (name.includes('bofa') || name.includes('bank of america') || name.includes('wells')) return 'bg-red-900 border-red-500/30';
    if (name.includes('discover')) return 'bg-orange-800 border-orange-500/30';
    if (name.includes('td bank') || name.includes('fidelity')) return 'bg-emerald-900 border-emerald-500/30';
    if (editingCard.network === 'Amex') return 'bg-slate-700 border-slate-500/30';
    return 'bg-stone-900 border-white/10';
  };

  return (
    <View className="flex-1 bg-black">
       <Stack.Screen 
        options={{ 
          title: isNew ? 'New Card' : editingCard.name,
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
              <Text className="text-black font-black uppercase tracking-widest text-[11px]">Save Card</Text>
            </TouchableOpacity>
        </View>

        {/* Dynamic Card Hero */}
        <View className={`w-full h-[220px] rounded-[32px] p-6 mb-8 shadow-2xl border ${getCardColor()} justify-between`}>
             <View className="flex-row justify-between items-start opacity-90">
               <View className="flex-1 mr-4">
                  <TextInput 
                     value={editingCard.name}
                     onChangeText={(text) => updateField('name', text)}
                     placeholder="Card Nickname"
                     placeholderTextColor="rgba(255,255,255,0.4)"
                     className="text-white font-bold tracking-widest uppercase text-xs"
                  />
                  <TextInput 
                     value={editingCard.institutionName}
                     onChangeText={(text) => updateField('institutionName', text)}
                     placeholder="Bank Name"
                     placeholderTextColor="rgba(255,255,255,0.2)"
                     className="text-white/60 font-medium text-[10px] mt-1"
                  />
               </View>
               <TextInput 
                 value={editingCard.network}
                 onChangeText={(text) => updateField('network', text)}
                 placeholder="Visa"
                 placeholderTextColor="rgba(255,255,255,0.4)"
                 className="text-white font-black italic tracking-tighter text-sm text-right w-20"
               />
             </View>
             
             <View>
               <View className="flex-row items-center mb-4">
                 <Text className="text-white text-3xl font-mono tracking-[0.2em] opacity-90 mr-2">••••</Text>
                 <TextInput 
                    value={editingCard.last4}
                    onChangeText={(text) => updateField('last4', text)}
                    placeholder="1234"
                    maxLength={4}
                    keyboardType="numeric"
                    placeholderTextColor="rgba(255,255,255,0.4)"
                    className="text-white text-3xl font-mono tracking-[0.2em] opacity-90 w-24"
                 />
               </View>
               
               <View className="flex-row justify-between items-center opacity-70">
                 <TextInput 
                    value={editingCard.cardHolder}
                    onChangeText={(text) => updateField('cardHolder', text)}
                    placeholder="CARDHOLDER NAME"
                    placeholderTextColor="rgba(255,255,255,0.4)"
                    className="text-xs font-bold text-white uppercase tracking-widest flex-1 mr-4"
                 />
                 <TextInput 
                    value={editingCard.expiry}
                    onChangeText={(text) => updateField('expiry', text)}
                    placeholder="MM/YY"
                    maxLength={5}
                    placeholderTextColor="rgba(255,255,255,0.4)"
                    className="text-xs font-bold text-white uppercase tracking-widest w-16 text-right"
                 />
               </View>
             </View>
        </View>

        {/* Details Form */}
        <Text className="text-[11px] font-black uppercase tracking-widest text-white/40 mb-3 px-4">Card Logistics</Text>
        <View className="bg-[#1C1C1E] border border-white/5 rounded-[24px] p-6 mb-8 divide-y divide-white/5">
            
            <View className="pb-4 flex-row justify-between items-center bg-black/50 p-1 rounded-xl mb-4">
                <TouchableOpacity 
                  onPress={() => updateField('type', 'Credit')}
                  className={`flex-1 py-2 items-center rounded-lg ${editingCard.type === 'Credit' ? 'bg-white' : 'bg-transparent'}`}
                >
                  <Text className={`text-[10px] font-black uppercase tracking-widest ${editingCard.type === 'Credit' ? 'text-black' : 'text-white/40'}`}>Credit Card</Text>
                </TouchableOpacity>
                <TouchableOpacity 
                  onPress={() => updateField('type', 'Debit')}
                  className={`flex-1 py-2 items-center rounded-lg ${editingCard.type === 'Debit' ? 'bg-white' : 'bg-transparent'}`}
                >
                  <Text className={`text-[10px] font-black uppercase tracking-widest ${editingCard.type === 'Debit' ? 'text-black' : 'text-white/40'}`}>Debit</Text>
                </TouchableOpacity>
            </View>

            <View className="py-4">
              <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Limit / Available Balance</Text>
              <View className="flex-row items-center border-b border-white/10 pb-2">
                 <Text className="text-white/40 mr-2">$</Text>
                 <TextInput 
                    value={editingCard.limit?.toString() || ''}
                    onChangeText={(text) => updateField('limit', parseFloat(text) || 0)}
                    placeholder="0.00"
                    keyboardType="numeric"
                    placeholderTextColor="rgba(255,255,255,0.2)"
                    className="text-lg font-bold text-white flex-1"
                 />
              </View>
            </View>
            
        </View>

        {/* Delete */}
        {!isNew && (
          <TouchableOpacity onPress={requestDelete} className="p-4 rounded-3xl items-center border border-red-500/30 mb-20">
            <Text className="text-red-500 font-bold">Delete Card</Text>
          </TouchableOpacity>
        )}

      </ScrollView>
    </View>
  );
}
