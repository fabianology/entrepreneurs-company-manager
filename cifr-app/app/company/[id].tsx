import React, { useState, useEffect, useRef } from 'react';
import { View, Text, TextInput, TouchableOpacity, ScrollView, Alert, Image, Modal, TouchableWithoutFeedback } from 'react-native';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useAppContext } from '../../context/AppContext';
import { Company } from '../../types';

const BRAND_COLORS = [
  '#4f46e5', '#10b981', '#f59e0b', '#ef4444', '#3b82f6',
  '#8b5cf6', '#ec4899', '#64748b', '#000000'
];

const COMPANY_STRUCTURES = [
  'LLC', 'S-Corp', 'C-Corp', 'Small Business', 'Sole Proprietorship',
  'Partnership', 'Holding Company', 'Non-Profit', 'Personal', 'Other'
];

export default function CompanyDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { state, handleUpdateCompany, handleDeleteCompany, setSelectedCompanyId } = useAppContext();

  const company = state?.companies.find(c => c.id === id);

  const [formState, setFormState] = useState<Partial<Company>>({
    name: company?.name || '',
    structure: company?.structure || 'LLC',
    color: company?.color || BRAND_COLORS[0],
    logoUrl: company?.logoUrl || '',
    website: company?.website || ''
  });

  const [showStructureMenu, setShowStructureMenu] = useState(false);

  if (!company) {
    return (
      <View className="flex-1 bg-black items-center justify-center">
        <Text className="text-white">Company not found.</Text>
        <TouchableOpacity onPress={() => router.back()} className="mt-4 bg-white/10 p-3 rounded-xl">
          <Text className="text-white">Go Back</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const formStateRef = useRef(formState);
  useEffect(() => {
    formStateRef.current = formState;
  }, [formState]);

  useEffect(() => {
    return () => {
      if (formStateRef.current.name && formStateRef.current.name.trim()) {
        handleUpdateCompany(id as string, formStateRef.current);
      }
    };
  }, []);

  const requestDelete = () => {
    Alert.alert(
      "Delete Company",
      `Are you sure you want to permanently delete ${company.name}? All attached financial and subscription records will be lost.`,
      [
        { text: "Cancel", style: "cancel" },
        { 
          text: "Delete", 
          style: "destructive", 
          onPress: () => {
            handleDeleteCompany(id as string);
            router.back();
          } 
        }
      ]
    );
  };

  const jumpToTab = (tabName: 'subscriptions' | 'financials' | 'documents') => {
    setSelectedCompanyId(id as string);
    router.navigate(`/(tabs)/${tabName}`);
  };

  return (
    <View className="flex-1 bg-black">
      <Stack.Screen 
        options={{ 
          title: company.name,
          headerStyle: { backgroundColor: '#000000' },
          headerTintColor: '#fff',
          headerBackTitleVisible: false
        }} 
      />
      
      <ScrollView className="flex-1 p-6" contentContainerStyle={{ paddingBottom: 40 }} keyboardShouldPersistTaps="handled">
        
        {/* Header Row: Logo, Name, Dismiss */}
        <View className="flex-row items-center justify-between mb-5 z-10">
          <View className="flex-row items-center flex-1 mr-4">
            <View 
              style={{ backgroundColor: formState.color || '#3b82f6' }}
              className="w-16 h-16 rounded-2xl items-center justify-center overflow-hidden border border-white/10 mr-4"
            >
              {formState.logoUrl ? (
                <Image source={{ uri: formState.logoUrl }} style={{ width: '100%', height: '100%' }} resizeMode="cover" />
              ) : (
                <Text className="text-white font-black text-3xl">{formState.name?.charAt(0) || '?'}</Text>
              )}
            </View>
            <View className="flex-1">
              <Text className="text-[10px] font-black text-white/50 uppercase tracking-[0.2em] ml-1 mb-1">Entity Name</Text>
              <TextInput
                value={formState.name}
                onChangeText={v => setFormState({ ...formState, name: v })}
                className="w-full bg-[#111111] border border-white/10 rounded-xl px-4 py-2.5 text-white font-bold text-sm"
                placeholderTextColor="rgba(255,255,255,0.2)"
                placeholder="Acme Holdings Inc."
              />
            </View>
          </View>
          <TouchableOpacity onPress={() => router.back()} className="bg-white/10 p-2 rounded-full self-start mt-1">
            <Ionicons name="close" size={20} color="rgba(255,255,255,0.6)" />
          </TouchableOpacity>
        </View>

        {/* Form Row 1: Structure & Color */}
        <View style={{ zIndex: 50 }} className="flex-row gap-4 mb-4">
          {/* Structure */}
          <View className="flex-1">
            <Text className="text-[10px] font-black text-white/50 uppercase tracking-[0.2em] ml-1 mb-1">Structure</Text>
            <View className="relative z-50">
              <TouchableOpacity 
                onPress={() => setShowStructureMenu(!showStructureMenu)}
                className={`w-full flex-row items-center justify-between bg-[#111111] border border-white/10 px-4 py-3 transition-all z-50 ${showStructureMenu ? 'rounded-t-xl border-b-0' : 'rounded-xl'}`}
              >
                <Text className="text-white font-bold text-xs" numberOfLines={1}>{formState.structure}</Text>
                <Ionicons name={showStructureMenu ? "chevron-up" : "chevron-down"} size={14} color="rgba(255,255,255,0.4)" />
              </TouchableOpacity>

              {showStructureMenu && (
                <View className="absolute top-full left-0 right-0 bg-[#111111] border border-white/10 border-t-0 rounded-b-xl max-h-[160px] z-50">
                  <ScrollView nestedScrollEnabled className="w-full">
                    {COMPANY_STRUCTURES.map(type => (
                      <TouchableOpacity 
                        key={type} 
                        onPress={() => { setFormState({ ...formState, structure: type }); setShowStructureMenu(false); }}
                        className="flex-row items-center justify-between px-4 py-2.5 border-t border-white/5"
                      >
                        <Text className={`font-bold text-[11px] ${formState.structure === type ? 'text-[#1FE400]' : 'text-white/70'}`}>{type}</Text>
                        {formState.structure === type && <Ionicons name="checkmark" size={14} color="#1FE400" />}
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                </View>
              )}
            </View>
          </View>

          {/* Color */}
          <View className="flex-1">
            <Text className="text-[10px] font-black text-white/50 uppercase tracking-[0.2em] ml-1 mb-1">Identity Hue</Text>
            <View className="flex-row flex-wrap gap-1.5 mt-1">
              {BRAND_COLORS.slice(0, 8).map(color => (
                <TouchableOpacity
                  key={color}
                  onPress={() => setFormState({ ...formState, color, logoUrl: '' })}
                  style={{ backgroundColor: color }}
                  className={`w-6 h-6 rounded-full border border-white/10 items-center justify-center`}
                >
                  {formState.color === color && !formState.logoUrl && (
                    <View className="w-2 h-2 rounded-full border-2 border-white" />
                  )}
                </TouchableOpacity>
              ))}
            </View>
          </View>
        </View>

        {/* Form Row 2: Website & Logo */}
        <View className="flex-row gap-4 mb-6 z-10">
          <View className="flex-1">
            <Text className="text-[10px] font-black text-white/50 uppercase tracking-[0.2em] ml-1 mb-1">Website</Text>
            <TextInput
              value={formState.website}
              onChangeText={v => setFormState({ ...formState, website: v })}
              onBlur={() => {
                if (formState.website && !formState.logoUrl) {
                  const domain = formState.website.replace(/^(?:https?:\/\/)?(?:www\.)?/i, '').split('/')[0];
                  if (domain) setFormState(prev => ({ ...prev, logoUrl: `https://logo.clearbit.com/${domain}` }));
                }
              }}
              className="w-full bg-[#111111] border border-white/10 rounded-xl px-4 py-2.5 text-white font-bold text-xs"
              placeholderTextColor="rgba(255,255,255,0.2)"
              placeholder="service.com"
              autoCapitalize="none"
              keyboardType="url"
            />
          </View>
          <View className="flex-1">
            <Text className="text-[10px] font-black text-white/50 uppercase tracking-[0.2em] ml-1 mb-1">Logo URL</Text>
            <TextInput
              value={formState.logoUrl}
              onChangeText={v => setFormState({ ...formState, logoUrl: v })}
              className="w-full bg-[#111111] border border-white/10 rounded-xl px-4 py-2.5 text-white font-bold text-xs"
              placeholderTextColor="rgba(255,255,255,0.2)"
              placeholder="url.png"
              autoCapitalize="none"
              keyboardType="url"
            />
          </View>
        </View>

        {/* Quick Jumps */}
        <View className="z-10 mb-6">
          <Text className="text-[10px] font-black text-white/50 uppercase tracking-[0.2em] ml-1 mb-2">App Navigators</Text>
          <View className="flex-col gap-[5px]">
            <TouchableOpacity onPress={() => jumpToTab('subscriptions')} style={{ height: 40 }} className="bg-[#1C1C1E] border border-white/5 px-4 rounded-xl flex-row items-center justify-between">
              <View className="flex-row items-center gap-2.5">
                 <Ionicons name="layers" size={16} color="#60A5FA" />
                 <Text className="text-white/90 font-bold text-[12px]">Tech Stack</Text>
              </View>
              <Ionicons name="chevron-forward" size={14} color="rgba(255,255,255,0.2)" />
            </TouchableOpacity>

            <TouchableOpacity onPress={() => jumpToTab('financials')} style={{ height: 40 }} className="bg-[#1C1C1E] border border-white/5 px-4 rounded-xl flex-row items-center justify-between">
              <View className="flex-row items-center gap-2.5">
                 <Ionicons name="card" size={16} color="#22c55e" />
                 <Text className="text-white/90 font-bold text-[12px]">Financials</Text>
              </View>
              <Ionicons name="chevron-forward" size={14} color="rgba(255,255,255,0.2)" />
            </TouchableOpacity>

            <TouchableOpacity onPress={() => jumpToTab('documents')} style={{ height: 40 }} className="bg-[#1C1C1E] border border-white/5 px-4 rounded-xl flex-row items-center justify-between">
              <View className="flex-row items-center gap-2.5">
                 <Ionicons name="document-text" size={16} color="#FBBF24" />
                 <Text className="text-white/90 font-bold text-[12px]">Doc Vault</Text>
              </View>
              <Ionicons name="chevron-forward" size={14} color="rgba(255,255,255,0.2)" />
            </TouchableOpacity>
          </View>
        </View>

        {/* Danger Zone */}
        <TouchableOpacity onPress={requestDelete} className="p-3 rounded-2xl items-center border border-red-500/30 bg-red-500/5 z-10">
          <Text className="text-red-500 font-bold tracking-widest uppercase text-[10px]">Delete {company.name}</Text>
        </TouchableOpacity>

      </ScrollView>
    </View>
  );
}
