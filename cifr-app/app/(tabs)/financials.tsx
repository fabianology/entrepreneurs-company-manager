import React, { useState } from 'react';
import { View, Text, ScrollView, TouchableOpacity, ActionSheetIOS } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAppContext } from '../../context/AppContext';
import { FinancialCard } from '../../types';

export default function FinancialsScreen() {
  const router = useRouter();
  const { state, selectedCompanyId } = useAppContext();

  if (!state) return null;

  const financialCards = selectedCompanyId 
    ? state.financialCards.filter(c => c.companyId === selectedCompanyId)
    : state.financialCards;

  const institutions = selectedCompanyId
    ? (state.institutions || []).filter(i => i.companyId === selectedCompanyId)
    : (state.institutions || []);

  const loans = selectedCompanyId
    ? (state.loans || []).filter(l => l.companyId === selectedCompanyId)
    : (state.loans || []);

  const getCardColor = (card: FinancialCard) => {
    const name = (card.institutionName || '').toLowerCase();
    if (name.includes('chase') || name.includes('amex') || name.includes('citi')) return 'bg-blue-900';
    if (name.includes('bofa') || name.includes('bank of america') || name.includes('wells')) return 'bg-red-900';
    if (name.includes('discover')) return 'bg-orange-800';
    if (name.includes('td bank') || name.includes('fidelity')) return 'bg-emerald-900';
    if (card.network === 'Amex') return 'bg-slate-700';
    return 'bg-stone-900'; // Default dark
  };

  const handleAddPress = () => {
    ActionSheetIOS.showActionSheetWithOptions(
      {
        options: ['Cancel', 'Add Bank Account', 'Add Credit Card', 'Add Loan'],
        cancelButtonIndex: 0,
      },
      (buttonIndex) => {
        if (buttonIndex === 1) router.push('/financial/institution/new');
        else if (buttonIndex === 2) router.push('/financial/card/new');
        else if (buttonIndex === 3) router.push('/financial/loan/new');
      }
    );
  };

  return (
    <SafeAreaView className="flex-1 bg-black">
      <ScrollView className="flex-1">
        
        {/* Header */}
        <View className="mb-6 mt-4 px-4">
          <Text className="text-sm font-bold text-white/40 uppercase tracking-widest pl-2 mb-1">
            {selectedCompanyId ? 'Company Financials' : 'All Financials'}
          </Text>
          <Text className="text-4xl font-black text-white px-2">Wallets</Text>
        </View>

        {/* --- CARDS SECTION (Horizontal) --- */}
        <View className="mb-8">
          <Text className="text-white/40 font-bold uppercase tracking-widest px-6 mb-4 text-xs">Credit & Debit</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} className="px-4 overflow-visible">
             {financialCards.length === 0 ? (
                <TouchableOpacity onPress={() => router.push('/financial/card/new')} className="ml-2 w-[280px] h-[170px] border border-dashed border-white/20 rounded-[24px] items-center justify-center bg-[#1C1C1E]/50">
                  <Ionicons name="card-outline" size={32} color="rgba(255,255,255,0.4)" />
                  <Text className="text-white/40 font-bold mt-2 text-xs uppercase tracking-widest">+ Add Card</Text>
                </TouchableOpacity>
             ) : (
               financialCards.map((card) => (
                 <TouchableOpacity 
                   key={card.id} 
                   onPress={() => router.push(`/financial/card/${card.id}`)}
                   className={`w-[280px] h-[170px] rounded-[24px] p-5 mr-4 shadow-xl border border-white/10 ${getCardColor(card)} justify-between`}
                 >
                   <View className="flex-row justify-between items-start opacity-90">
                     <Text className="text-white font-bold tracking-widest uppercase text-[10px] w-2/3 truncate" numberOfLines={1}>{card.name}</Text>
                     <Text className="text-white font-black italic tracking-tighter text-xs">{card.network}</Text>
                   </View>
                   <View>
                     <Text className="text-white text-2xl font-mono tracking-[0.2em] opacity-90 mb-2">
                       •••• {card.last4 || '0000'}
                     </Text>
                     <View className="flex-row justify-between items-center opacity-70">
                       <Text className="text-[10px] font-bold text-white uppercase tracking-widest w-2/3 truncate" numberOfLines={1}>{card.cardHolder}</Text>
                       <Text className="text-[10px] font-bold text-white uppercase tracking-widest">{card.expiry}</Text>
                     </View>
                   </View>
                 </TouchableOpacity>
               ))
             )}
             {/* Spacer to allow scrolling past the last card nicely */}
             <View className="w-4" />
          </ScrollView>
        </View>

        {/* --- INSTITUTIONS SECTION --- */}
        <View className="mb-8 px-4">
          <Text className="text-white/40 font-bold uppercase tracking-widest px-2 mb-4 text-xs">Linked Banks</Text>
          <View className="bg-[#1C1C1E] rounded-[24px] border border-white/5 divide-y divide-white/5">
            {institutions.length === 0 ? (
              <View className="p-8 items-center justify-center">
                <Text className="text-white/20 font-bold text-xs uppercase tracking-widest">No banks linked</Text>
              </View>
            ) : (
              institutions.map((inst) => (
                <TouchableOpacity 
                  key={inst.id} 
                  onPress={() => router.push(`/financial/institution/${inst.id}`)}
                  className="p-5 flex-row items-center justify-between"
                >
                  <View className="flex-row items-center">
                    <View className="bg-white/10 p-3 rounded-2xl mr-4">
                      <Ionicons name="business" size={24} color="#f59e0b" />
                    </View>
                    <View>
                      <Text className="text-white font-bold text-lg">{inst.name}</Text>
                      <Text className="text-white/40 text-[10px] uppercase font-bold tracking-widest mt-0.5">
                        {inst.accounts.length} linked accounts
                      </Text>
                    </View>
                  </View>
                  <Ionicons name="chevron-forward" size={20} color="rgba(255,255,255,0.2)" />
                </TouchableOpacity>
              ))
            )}
          </View>
        </View>

        {/* --- LOANS SECTION --- */}
        <View className="mb-24 px-4">
          <Text className="text-white/40 font-bold uppercase tracking-widest px-2 mb-4 text-xs">Active Loans</Text>
          <View className="bg-[#1C1C1E] rounded-[24px] border border-white/5 divide-y divide-white/5">
            {loans.length === 0 ? (
              <View className="p-8 items-center justify-center">
                <Text className="text-white/20 font-bold text-xs uppercase tracking-widest">No active loans</Text>
              </View>
            ) : (
              loans.map((loan) => (
                <TouchableOpacity 
                  key={loan.id} 
                  onPress={() => router.push(`/financial/loan/${loan.id}`)}
                  className="p-5 flex-row items-center justify-between"
                >
                  <View className="flex-row items-center">
                    <View className="bg-red-500/20 p-3 rounded-2xl mr-4">
                      <Ionicons name="document-text" size={24} color="#ef4444" />
                    </View>
                    <View>
                      <Text className="text-white font-bold text-lg">{loan.name}</Text>
                      <Text className="text-white/40 text-[10px] uppercase font-bold tracking-widest mt-0.5">
                        {loan.lender} • {loan.interestRate}% APR
                      </Text>
                    </View>
                  </View>
                  <View className="items-end">
                    <Text className="text-white font-black text-lg">${loan.remainingBalance.toLocaleString()}</Text>
                    <Text className="text-red-500 text-[9px] uppercase font-bold tracking-widest">Balance</Text>
                  </View>
                </TouchableOpacity>
              ))
            )}
          </View>
        </View>

      </ScrollView>

      {/* Floating Action Button */}
      {selectedCompanyId && (
        <TouchableOpacity 
          onPress={handleAddPress}
          className="absolute bottom-6 right-6 w-16 h-16 bg-[#EBC351] rounded-full items-center justify-center shadow-[0_0_20px_rgba(235,195,81,0.4)] z-50"
        >
          <Ionicons name="add" size={32} color="#000" />
        </TouchableOpacity>
      )}
    </SafeAreaView>
  );
}
