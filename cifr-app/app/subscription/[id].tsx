import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, ScrollView, Alert, Switch } from 'react-native';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useAppContext } from '../../context/AppContext';
import { Subscription, SubService } from '../../types';

export default function SubscriptionDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { state, handleUpdateSubscription, handleAddSubscription, handleDeleteSubscription, selectedCompanyId } = useAppContext();

  const isNew = id === 'new';
  const existingSub = state?.subscriptions.find(s => s.id === id);

  // If we are looking for an existing sub but it's not found
  if (!isNew && !existingSub) {
    return (
      <View className="flex-1 bg-black items-center justify-center">
        <Text className="text-white">Service not found.</Text>
        <TouchableOpacity onPress={() => router.back()} className="mt-4 bg-white/10 p-3 rounded-xl">
          <Text className="text-white">Go Back</Text>
        </TouchableOpacity>
      </View>
    );
  }

  // Local state for editing
  const [editingSub, setEditingSub] = useState<Partial<Subscription>>(
    isNew 
      ? { 
          companyId: selectedCompanyId || '', 
          name: '', 
          cost: 0, 
          pricingModel: 'paid', 
          billingCycle: 'Monthly', 
          renew: 'Auto', 
          status: 'Active',
          subServices: [],
          linkedEmails: []
        } 
      : { ...existingSub }
  );

  const [showPassword, setShowPassword] = useState(false);

  const handleSave = () => {
    if (!editingSub.name || editingSub.name.trim() === '') {
      Alert.alert('Missing Name', 'Please enter a name for the service.');
      return;
    }

    if (isNew) {
      handleAddSubscription(editingSub);
    } else {
      handleUpdateSubscription(id as string, editingSub);
    }
    router.back();
  };

  const requestDelete = () => {
    Alert.alert(
      "Delete Service",
      `Remove ${editingSub.name}?`,
      [
        { text: "Cancel", style: "cancel" },
        { 
          text: "Delete", 
          style: "destructive", 
          onPress: () => {
             handleDeleteSubscription(id as string);
             router.back();
          } 
        }
      ]
    );
  };

  const updateSubField = (key: keyof Subscription, value: any) => {
    setEditingSub(prev => ({ ...prev, [key]: value }));
  };

  const addEmptySubService = () => {
    const newService: SubService = {
      id: Math.random().toString(36).substr(2, 9),
      name: 'New Feature',
      cost: 0,
      billingCycle: 'Monthly',
      purpose: '',
      status: 'Active'
    };
    updateSubField('subServices', [...(editingSub.subServices || []), newService]);
  };

  return (
    <View className="flex-1 bg-black">
       <Stack.Screen 
        options={{ 
          title: isNew ? 'New Service' : editingSub.name,
          headerStyle: { backgroundColor: '#000000' },
          headerTintColor: '#fff',
          headerBackTitleVisible: false
        }} 
      />

      <ScrollView className="flex-1 px-4 py-6">
        
        {/* Top Dismiss Button */}
        <View className="flex-row justify-between items-center mb-6 px-2">
            <TouchableOpacity onPress={() => router.back()} className="bg-white/10 p-2 rounded-full">
              <Ionicons name="close" size={24} color="rgba(255,255,255,0.6)" />
            </TouchableOpacity>
            
            <TouchableOpacity onPress={handleSave} className="bg-white px-6 py-2 rounded-full">
              <Text className="text-black font-black uppercase tracking-widest text-[11px]">Save Service</Text>
            </TouchableOpacity>
        </View>

        {/* Hero Form */}
        <View className="bg-[#1C1C1E] border border-white/5 rounded-[24px] p-6 mb-6">
            <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Service Name</Text>
            <TextInput 
              value={editingSub.name}
              onChangeText={(text) => updateSubField('name', text)}
              placeholder="e.g. GitHub Enterprise"
              placeholderTextColor="rgba(255,255,255,0.2)"
              className="text-3xl font-black text-white mb-6"
            />

            <View className="flex-row space-x-4 mb-6">
               <View className="flex-1">
                 <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Cost</Text>
                 <View className="flex-row items-center border-b border-white/10 pb-2">
                    <Text className="text-white/40 text-lg mr-1">$</Text>
                    <TextInput 
                      value={editingSub.cost?.toString() || ''}
                      onChangeText={(text) => updateSubField('cost', parseFloat(text) || 0)}
                      keyboardType="numeric"
                      placeholder="0.00"
                      placeholderTextColor="rgba(255,255,255,0.2)"
                      className="text-2xl font-black text-white flex-1"
                    />
                 </View>
               </View>

               <View className="flex-1">
                 <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Cycle</Text>
                 <View className="flex-row bg-black/50 rounded-xl p-1 pb-1">
                    <TouchableOpacity 
                      onPress={() => updateSubField('billingCycle', 'Monthly')}
                      className={`flex-1 py-2 items-center rounded-lg ${editingSub.billingCycle === 'Monthly' ? 'bg-[#EBC351]' : 'bg-transparent'}`}
                    >
                      <Text className={`text-[10px] font-black uppercase tracking-widest ${editingSub.billingCycle === 'Monthly' ? 'text-black' : 'text-white/40'}`}>mo</Text>
                    </TouchableOpacity>
                    <TouchableOpacity 
                      onPress={() => updateSubField('billingCycle', 'Yearly')}
                      className={`flex-1 py-2 items-center rounded-lg ${editingSub.billingCycle === 'Yearly' ? 'bg-[#EBC351]' : 'bg-transparent'}`}
                    >
                      <Text className={`text-[10px] font-black uppercase tracking-widest ${editingSub.billingCycle === 'Yearly' ? 'text-black' : 'text-white/40'}`}>yr</Text>
                    </TouchableOpacity>
                 </View>
               </View>
            </View>

            <View className="flex-row items-center justify-between">
              <Text className="text-[12px] font-bold uppercase tracking-widest text-white/60">Auto Renew</Text>
              <Switch 
                value={editingSub.renew === 'Auto'} 
                onValueChange={(val) => updateSubField('renew', val ? 'Auto' : 'Manual')}
                trackColor={{ false: "#3f3f46", true: "#1FE400" }}
              />
            </View>
        </View>

        {/* Credentials Form */}
        <Text className="text-[11px] font-black uppercase tracking-widest text-white/40 mb-3 px-4">Credentials & Logistics</Text>
        <View className="bg-[#1C1C1E] border border-white/5 rounded-[24px] p-6 mb-6 divide-y divide-white/5">
            
            <View className="pb-4">
              <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Login URL</Text>
              <TextInput 
                 value={editingSub.website}
                 onChangeText={(text) => updateSubField('website', text)}
                 placeholder="app.example.com"
                 placeholderTextColor="rgba(255,255,255,0.2)"
                 className="text-sm font-medium text-white px-4 py-3 bg-black/40 rounded-xl"
              />
            </View>
            
            <View className="py-4">
              <Text className="text-[10px] font-black uppercase tracking-widest text-white/40 mb-2">Login ID / Email</Text>
              <TextInput 
                 value={editingSub.loginId}
                 onChangeText={(text) => updateSubField('loginId', text)}
                 placeholder="admin@startup.com"
                 placeholderTextColor="rgba(255,255,255,0.2)"
                 className="text-sm font-medium text-white px-4 py-3 bg-black/40 rounded-xl"
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
                 value={editingSub.password}
                 onChangeText={(text) => updateSubField('password', text)}
                 placeholder="••••••••"
                 secureTextEntry={!showPassword}
                 placeholderTextColor="rgba(255,255,255,0.2)"
                 className="text-sm font-medium text-white px-4 py-3 bg-black/40 rounded-xl"
              />
            </View>

        </View>

        {/* Sub-Services Form */}
        <View className="flex-row justify-between items-center px-4 mb-3">
          <Text className="text-[11px] font-black uppercase tracking-widest text-white/40">Sub Services ({editingSub.subServices?.length || 0})</Text>
          <TouchableOpacity onPress={addEmptySubService}>
             <Text className="text-[#EBC351] font-bold text-xs uppercase tracking-widest">+ Add</Text>
          </TouchableOpacity>
        </View>

        <View className="bg-[#1C1C1E] border border-white/5 rounded-[24px] mb-8 overflow-hidden divide-y divide-white/5">
           {!editingSub.subServices || editingSub.subServices.length === 0 ? (
             <View className="p-6 items-center">
               <Text className="text-white/20 text-xs text-center font-bold">No internal services tracked. (e.g. extra seats, modules)</Text>
             </View>
           ) : (
             editingSub.subServices.map((subService, idx) => (
               <View key={subService.id || idx} className="p-5 flex-row items-center justify-between">
                 <View className="flex-1 mr-4">
                   <TextInput 
                      value={subService.name}
                      onChangeText={(text) => {
                         const updated = [...(editingSub.subServices || [])];
                         updated[idx].name = text;
                         updateSubField('subServices', updated);
                      }}
                      placeholder="Service Name"
                      placeholderTextColor="rgba(255,255,255,0.2)"
                      className="text-base font-bold text-white mb-2"
                   />
                   <View className="flex-row items-center">
                     <Text className="text-[10px] text-white/40 font-bold uppercase tracking-widest mr-2">Cost:</Text>
                     <TextInput 
                        value={subService.cost.toString()}
                        onChangeText={(text) => {
                           const updated = [...(editingSub.subServices || [])];
                           updated[idx].cost = parseFloat(text) || 0;
                           updateSubField('subServices', updated);
                        }}
                        keyboardType="numeric"
                        className="text-sm text-[#1FE400] font-bold border-b border-white/10"
                     />
                   </View>
                 </View>
                 
                 <TouchableOpacity onPress={() => {
                     const updated = [...(editingSub.subServices || [])];
                     updated.splice(idx, 1);
                     updateSubField('subServices', updated);
                 }}>
                   <Ionicons name="trash" size={20} color="rgba(239, 68, 68, 0.6)" />
                 </TouchableOpacity>
               </View>
             ))
           )}
        </View>

        {/* Delete */}
        {!isNew && (
          <TouchableOpacity onPress={requestDelete} className="p-4 rounded-3xl items-center border border-red-500/30 mb-20">
            <Text className="text-red-500 font-bold">Delete Service Completely</Text>
          </TouchableOpacity>
        )}

      </ScrollView>
    </View>
  );
}
