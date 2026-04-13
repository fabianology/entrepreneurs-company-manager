import React, { useState, useEffect, useRef } from 'react';
import { View, Text, TextInput, TouchableOpacity, ScrollView, Alert, Image, Modal, TouchableWithoutFeedback } from 'react-native';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as DocumentPicker from 'expo-document-picker';
import { getFaviconUrl } from "../../services/logoService";
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

  const handleUploadMedia = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: 'image/*',
        copyToCacheDirectory: true,
      });
      if (!result.canceled && result.assets && result.assets.length > 0) {
        setFormState(prev => ({ ...prev, logoUrl: result.assets[0].uri }));
      }
    } catch (e) {
      console.log('Document picker error:', e);
    }
  };

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
      
      <ScrollView className="flex-1 p-6" contentContainerStyle={{ paddingBottom: 100 }}>
        
        {/* Dismiss Button */}
        <TouchableOpacity onPress={() => router.back()} className="self-end bg-white/10 p-2 rounded-full mb-2">
          <Ionicons name="close" size={24} color="rgba(255,255,255,0.6)" />
        </TouchableOpacity>

        {/* Profile Form */}
        <View className="mb-8 mt-2">
          
          {/* Logo & Name Row */}
          <View className="flex-row items-center gap-4 mb-5">
            {/* Left aligned logo */}
            <View 
              style={{ backgroundColor: (formState.logoUrl || getFaviconUrl(formState.website)) ? 'transparent' : (formState.color || '#3b82f6') }}
              className="w-16 h-16 rounded-2xl items-center justify-center shadow-lg overflow-hidden border border-white/10"
            >
              {(formState.logoUrl || getFaviconUrl(formState.website)) ? (
                <Image source={{ uri: formState.logoUrl || getFaviconUrl(formState.website)! }} style={{ width: '70%', height: '70%' }} resizeMode="contain" />
              ) : (
                <Text className="text-white font-black text-3xl">{formState.name?.charAt(0) || '?'}</Text>
              )}
            </View>

            {/* Entity Name Input */}
            <View className="flex-1">
              <Text className="text-[10px] font-black text-white/50 uppercase tracking-[0.2em] ml-1 mb-1">Entity Name</Text>
              <TextInput
                value={formState.name}
                onChangeText={v => setFormState({ ...formState, name: v })}
                className="w-full bg-[#111111] border border-white/10 rounded-2xl px-5 py-3.5 text-white font-bold"
                placeholderTextColor="rgba(255,255,255,0.2)"
                placeholder="Acme Holdings Inc."
              />
            </View>
          </View>

          {/* Structure */}
          <View className="mb-5">
            <Text className="text-[10px] font-black text-white/50 uppercase tracking-[0.2em] ml-1 mb-2">Entity Structure</Text>
            <TouchableOpacity 
              onPress={() => setShowStructureMenu(!showStructureMenu)}
              className={`w-full flex-row items-center justify-between bg-[#111111] border border-white/10 px-5 py-3.5 transition-all ${showStructureMenu ? 'rounded-t-2xl border-b-0' : 'rounded-2xl'}`}
            >
              <Text className="text-white font-bold">{formState.structure}</Text>
              <Ionicons name={showStructureMenu ? "chevron-up" : "chevron-down"} size={18} color="rgba(255,255,255,0.4)" />
            </TouchableOpacity>

            {showStructureMenu && (
              <View className="bg-[#111111] border border-white/10 border-t-0 rounded-b-2xl max-h-[220px]">
                <ScrollView nestedScrollEnabled className="w-full">
                  {COMPANY_STRUCTURES.map(type => (
                    <TouchableOpacity 
                      key={type} 
                      onPress={() => { setFormState({ ...formState, structure: type }); setShowStructureMenu(false); }}
                      className="flex-row items-center justify-between px-5 py-3.5 border-t border-white/5"
                    >
                      <Text className={`font-bold text-sm ${formState.structure === type ? 'text-[#1FE400]' : 'text-white/70'}`}>{type}</Text>
                      {formState.structure === type && <Ionicons name="checkmark" size={16} color="#1FE400" />}
                    </TouchableOpacity>
                  ))}
                </ScrollView>
              </View>
            )}
          </View>

          {/* Color */}
          <View className="mb-5">
            <Text className="text-[10px] font-black text-white/50 uppercase tracking-[0.2em] ml-1 mb-2">Identity Color</Text>
            <View className="flex-row flex-wrap gap-[6px]">
              {BRAND_COLORS.map(color => (
                <TouchableOpacity
                  key={color}
                  onPress={() => setFormState({ ...formState, color, logoUrl: '' })}
                  style={{ backgroundColor: color }}
                  className={`w-8 h-8 rounded-full border border-white/10 items-center justify-center`}
                >
                  {formState.color === color && !formState.logoUrl && (
                    <View className="w-3 h-3 rounded-full border-2 border-white" />
                  )}
                </TouchableOpacity>
              ))}
            </View>
          </View>

          {/* Website URL */}
          <View className="mb-5">
            <Text className="text-[10px] font-black text-white/50 uppercase tracking-[0.2em] ml-1 mb-2">Website URL</Text>
            <View className="flex-row items-center gap-2">
              <TextInput
                value={formState.website}
                onChangeText={v => setFormState({ ...formState, website: v })}
                className="flex-1 bg-[#111111] border border-white/10 rounded-2xl px-5 py-[12px] text-white font-bold"
                placeholderTextColor="rgba(255,255,255,0.2)"
                placeholder="service.com"
                autoCapitalize="none"
                keyboardType="url"
              />
              <TouchableOpacity 
                onPress={handleUploadMedia} 
                className="bg-[#111111] border border-white/10 rounded-2xl p-[11px] items-center justify-center flex-row gap-2"
              >
                <Ionicons name="cloud-upload" size={20} color="#fff" />
              </TouchableOpacity>
            </View>
          </View>
        </View>

        {/* Quick Jumps */}
        <Text className="text-[10px] font-black text-white/50 uppercase tracking-[0.2em] ml-1 mb-2">App Navigators</Text>
        <View className="flex-row gap-3 mb-10 w-full">
          
          <TouchableOpacity 
            onPress={() => jumpToTab('subscriptions')} 
            className="flex-1 bg-[#1C1C1E] border border-white/5 p-4 rounded-2xl items-center justify-center gap-2"
          >
            <Ionicons name="layers" size={24} color="#60A5FA" />
            <Text className="text-white/90 font-bold text-[11px]" numberOfLines={1}>Subscriptions</Text>
          </TouchableOpacity>

          <TouchableOpacity 
            onPress={() => jumpToTab('financials')} 
            className="flex-1 bg-[#1C1C1E] border border-white/5 p-4 rounded-2xl items-center justify-center gap-2"
          >
            <Ionicons name="card" size={24} color="#22c55e" />
            <Text className="text-white/90 font-bold text-[11px]" numberOfLines={1}>Financials</Text>
          </TouchableOpacity>

          <TouchableOpacity 
            onPress={() => jumpToTab('documents')} 
            className="flex-1 bg-[#1C1C1E] border border-white/5 p-4 rounded-2xl items-center justify-center gap-2"
          >
            <Ionicons name="document-text" size={24} color="#FBBF24" />
            <Text className="text-white/90 font-bold text-[11px]" numberOfLines={1}>Docs</Text>
          </TouchableOpacity>
          
        </View>


        {/* Danger Zone */}
        <TouchableOpacity onPress={requestDelete} className="p-4 rounded-3xl items-center border border-red-500/30 mb-8 bg-red-500/5">
          <Text className="text-red-500 font-bold tracking-widest uppercase text-xs">Delete {company.name}</Text>
        </TouchableOpacity>

      </ScrollView>
    </View>
  );
}
