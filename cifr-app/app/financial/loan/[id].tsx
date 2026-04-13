import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, ScrollView, Alert } from 'react-native';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useAppContext } from '../../../context/AppContext';
import { Loan } from '../../../types';

export default function LoanDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { state, handleUpdateLoan, handleAddLoan, handleDeleteLoan, selectedCompanyId } = useAppContext();

  const isNew = id === 'new';
  const existingLoan = state?.loans?.find(l => l.id === id);

  if (!isNew && !existingLoan) {
    return (
      <View className="flex-1 bg-black items-center justify-center">
        <Text className="text-white">Loan not found.</Text>
        <TouchableOpacity onPress={() => router.back()} className="mt-4 bg-white/10 p-3 rounded-xl">
          <Text className="text-white">Go Back</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const [editingLoan, setEditingLoan] = useState<Partial<Loan>>(
    isNew 
      ? { 
          companyId: selectedCompanyId || '', 
          name: '',
          lender: '',
          principalAmount: 0,
          remainingBalance: 0,
          interestRate: 0,
          termYears: 0,
          termMonths: 0,
          monthlyPayment: 0,
          status: 'Active'
        } 
      : { ...existingLoan }
  );

  const handleSave = () => {
    if (!editingLoan.name || editingLoan.name.trim() === '') {
      Alert.alert('Missing Name', 'Please enter a name for this debt/loan.');
      return;
    }

    if (isNew) {
      handleAddLoan(editingLoan);
    } else {
      handleUpdateLoan(id as string, editingLoan);
    }
    router.back();
  };

  const requestDelete = () => {
    Alert.alert(
      "Delete Loan",
      `Remove ${editingLoan.name}?`,
      [
        { text: "Cancel", style: "cancel" },
        { 
          text: "Delete", 
          style: "destructive", 
          onPress: () => {
             handleDeleteLoan(id as string);
             router.back();
          } 
        }
      ]
    );
  };

  const updateField = (key: keyof Loan, value: any) => {
    setEditingLoan(prev => ({ ...prev, [key]: value }));
  };

  // NATIVE AMORTIZATION CALCULATOR
  const calcAmortization = () => {
    const loan = editingLoan;
    const principal = loan.principalAmount || 0;
    const rate = loan.interestRate || 0;
    const totalMonths = (loan.termYears || 0) * 12 + (loan.termMonths || 0);

    if (principal <= 0 || totalMonths <= 0) return null;

    let payment = 0;
    let totalInterest = 0;

    const perPeriodRate = (rate / 100) / 12;
    if (perPeriodRate <= 0) {
      payment = principal / totalMonths;
    } else {
      payment = principal * (perPeriodRate * Math.pow(1 + perPeriodRate, totalMonths)) / (Math.pow(1 + perPeriodRate, totalMonths) - 1);
      let balance = principal;
      for (let i = 1; i <= totalMonths; i++) {
        const interest = balance * perPeriodRate;
        const principalPayment = payment - interest;
        balance -= principalPayment;
        totalInterest += interest;
      }
    }

    const totalCost = principal + totalInterest;

    return { 
      monthlyPayment: payment, 
      totalInterest, 
      totalCost 
    };
  };

  const amort = calcAmortization();

  return (
    <View className="flex-1 bg-black">
       <Stack.Screen 
        options={{ 
          title: isNew ? 'New Loan' : editingLoan.name,
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
              <Text className="text-black font-black uppercase tracking-widest text-[11px]">Save Loan</Text>
            </TouchableOpacity>
        </View>

        {/* Hero Form */}
        <View className="bg-[#1C1C1E] border border-white/5 rounded-[24px] p-6 mb-8 shadow-2xl">
            <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Loan Name</Text>
            <TextInput 
              value={editingLoan.name}
              onChangeText={(text) => updateField('name', text)}
              placeholder="e.g. Equipment Financing"
              placeholderTextColor="rgba(255,255,255,0.2)"
              className="text-3xl font-black text-white mb-2"
            />
            <TextInput 
              value={editingLoan.lender}
              onChangeText={(text) => updateField('lender', text)}
              placeholder="Bank of America"
              placeholderTextColor="rgba(255,255,255,0.2)"
              className="text-white/60 font-medium text-sm mb-6"
            />

            <View className="flex-row space-x-6">
               <View className="flex-1">
                 <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Principal</Text>
                 <View className="flex-row items-center border-b border-white/10 pb-2">
                    <Text className="text-white/40 text-lg mr-1">$</Text>
                    <TextInput 
                      value={editingLoan.principalAmount?.toString() || ''}
                      onChangeText={(text) => updateField('principalAmount', parseFloat(text) || 0)}
                      keyboardType="numeric"
                      placeholder="0.00"
                      placeholderTextColor="rgba(255,255,255,0.2)"
                      className="text-2xl font-black text-white flex-1"
                    />
                 </View>
               </View>

               <View className="flex-1">
                 <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Balance</Text>
                 <View className="flex-row items-center border-b border-white/10 pb-2">
                    <Text className="text-white/40 text-lg mr-1">$</Text>
                    <TextInput 
                      value={editingLoan.remainingBalance?.toString() || ''}
                      onChangeText={(text) => updateField('remainingBalance', parseFloat(text) || 0)}
                      keyboardType="numeric"
                      placeholder="0.00"
                      placeholderTextColor="rgba(255,255,255,0.2)"
                      className="text-2xl font-black text-red-500 flex-1"
                    />
                 </View>
               </View>
            </View>
        </View>

        {/* Amortization Form */}
        <Text className="text-[11px] font-black uppercase tracking-widest text-white/40 mb-3 px-4">Amortization Details</Text>
        <View className="bg-[#1C1C1E] border border-white/5 rounded-[24px] p-6 mb-8 divide-y divide-white/5">
            
            <View className="pb-4 flex-row items-center space-x-4">
               <View className="flex-1">
                 <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">APR %</Text>
                 <TextInput 
                    value={editingLoan.interestRate?.toString() || ''}
                    onChangeText={(text) => updateField('interestRate', parseFloat(text) || 0)}
                    placeholder="5.5"
                    keyboardType="numeric"
                    placeholderTextColor="rgba(255,255,255,0.2)"
                    className="text-lg font-bold text-white bg-black/40 px-4 py-2 rounded-xl"
                 />
               </View>

               <View className="flex-1">
                 <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Term (Yrs)</Text>
                 <TextInput 
                    value={editingLoan.termYears?.toString() || ''}
                    onChangeText={(text) => updateField('termYears', parseFloat(text) || 0)}
                    placeholder="3"
                    keyboardType="numeric"
                    placeholderTextColor="rgba(255,255,255,0.2)"
                    className="text-lg font-bold text-white bg-black/40 px-4 py-2 rounded-xl"
                 />
               </View>

               <View className="flex-1">
                 <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Term (Mo)</Text>
                 <TextInput 
                    value={editingLoan.termMonths?.toString() || ''}
                    onChangeText={(text) => updateField('termMonths', parseFloat(text) || 0)}
                    placeholder="0"
                    keyboardType="numeric"
                    placeholderTextColor="rgba(255,255,255,0.2)"
                    className="text-lg font-bold text-white bg-black/40 px-4 py-2 rounded-xl"
                 />
               </View>
            </View>

            {/* Calculations block */}
            <View className="pt-6 relative">
              <Ionicons name="calculator-outline" size={80} color="rgba(255,255,255,0.02)" style={{ position: 'absolute', right: 0, top: 10 }} />
              
              <Text className="text-white/30 text-[10px] uppercase font-bold tracking-widest mb-4">Calculated Burn</Text>
              
              <View className="flex-row justify-between mb-2">
                <Text className="text-white/70 font-medium">Monthly Note</Text>
                <Text className="text-white font-bold">${amort ? amort.monthlyPayment.toFixed(2) : '0.00'}</Text>
              </View>
              <View className="flex-row justify-between mb-4">
                <Text className="text-white/70 font-medium">Interest Over Life</Text>
                <Text className="text-red-400 font-bold">${amort ? amort.totalInterest.toFixed(2) : '0.00'}</Text>
              </View>
              
              <View className="h-[1px] bg-white/10 w-full mb-4" />
              
              <View className="flex-row justify-between">
                <Text className="text-white/40 text-xs font-bold uppercase tracking-widest">Total Cost</Text>
                <Text className="text-white font-black text-lg">${amort ? amort.totalCost.toFixed(2) : '0.00'}</Text>
              </View>
            </View>

        </View>

        {/* Delete */}
        {!isNew && (
          <TouchableOpacity onPress={requestDelete} className="p-4 rounded-3xl items-center border border-red-500/30 mb-20">
            <Text className="text-red-500 font-bold">Delete Loan</Text>
          </TouchableOpacity>
        )}

      </ScrollView>
    </View>
  );
}
