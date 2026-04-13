import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, ScrollView, Alert } from 'react-native';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useAppContext } from '../../context/AppContext';

export default function CompanyDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { state, handleUpdateCompany, handleDeleteCompany, setSelectedCompanyId } = useAppContext();

  const company = state?.companies.find(c => c.id === id);

  const [isEditingName, setIsEditingName] = useState(false);
  const [internalName, setInternalName] = useState(company?.name || '');

  const [isEditingDesc, setIsEditingDesc] = useState(false);
  const [internalDesc, setInternalDesc] = useState(company?.description || '');

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

  const saveName = () => {
    setIsEditingName(false);
    if (internalName.trim()) {
      handleUpdateCompany(id as string, { name: internalName });
    } else {
      setInternalName(company.name); // Revert
    }
  };

  const saveDesc = () => {
    setIsEditingDesc(false);
    handleUpdateCompany(id as string, { description: internalDesc });
  };

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
    // Keep this company selected and navigate to the related tab
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
      
      <ScrollView className="flex-1 p-6">
        
        {/* Dismiss Button */}
        <TouchableOpacity onPress={() => router.back()} className="self-end bg-white/10 p-2 rounded-full mb-2">
          <Ionicons name="close" size={24} color="rgba(255,255,255,0.6)" />
        </TouchableOpacity>

        {/* Header Hero Section */}
        <View className="mb-8 items-center mt-4">
          <View 
            style={{ backgroundColor: company.color || '#3b82f6' }}
            className="w-24 h-24 rounded-3xl items-center justify-center shadow-lg mb-6"
          >
            <Text className="text-white font-black text-5xl">{company.name.charAt(0)}</Text>
          </View>
          
          {/* Editable Name */}
          <View className="flex-row items-center justify-center w-full">
            {isEditingName ? (
              <TextInput
                value={internalName}
                onChangeText={setInternalName}
                onBlur={saveName}
                autoFocus
                className="text-4xl font-black text-white bg-white/10 rounded-xl px-4 py-2 w-full text-center"
                returnKeyType="done"
                onSubmitEditing={saveName}
              />
            ) : (
              <TouchableOpacity onPress={() => setIsEditingName(true)} className="flex-row items-center border border-transparent hover:border-white/10 rounded-xl px-4 py-2">
                <Text className="text-4xl font-black text-white text-center">{company.name}</Text>
                <Ionicons name="pencil" size={16} color="rgba(255,255,255,0.3)" className="ml-2" />
              </TouchableOpacity>
            )}
          </View>
          <Text className="text-stone-400 font-bold uppercase tracking-widest mt-2">{company.structure}</Text>
        </View>

        {/* Description Section */}
        <View className="bg-white/5 border border-white/10 rounded-3xl p-6 mb-8">
          <View className="flex-row items-center justify-between mb-4">
            <Text className="text-white/40 font-bold uppercase tracking-widest">About</Text>
            {!isEditingDesc && (
              <TouchableOpacity onPress={() => setIsEditingDesc(true)}>
                <Ionicons name="pencil" size={18} color="rgba(255,255,255,0.4)" />
              </TouchableOpacity>
            )}
          </View>
          
          {isEditingDesc ? (
            <View>
              <TextInput
                value={internalDesc}
                onChangeText={setInternalDesc}
                multiline
                className="text-white text-lg bg-white/10 rounded-xl p-4 min-h-[100px]"
                autoFocus
              />
              <TouchableOpacity onPress={saveDesc} className="mt-4 bg-[#primary] self-end px-6 py-2 rounded-full border border-white/20">
                <Text className="text-white font-bold">Save</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <TouchableOpacity onPress={() => setIsEditingDesc(true)}>
              <Text className="text-white text-lg leading-relaxed">
                {company.description || "No description provided. Tap to edit."}
              </Text>
            </TouchableOpacity>
          )}
        </View>

        {/* Quick Jumps */}
        <Text className="text-white/40 font-bold uppercase tracking-widest mb-4 ml-2">App Navigators</Text>
        <View className="space-y-3 mb-10">
          
          <TouchableOpacity onPress={() => jumpToTab('subscriptions')} className="bg-white/5 border border-white/10 p-5 rounded-3xl flex-row items-center justify-between">
            <View className="flex-row items-center">
              <View className="bg-emerald-500/20 p-3 rounded-xl mr-4">
                 <Ionicons name="layers" size={24} color="#10b981" />
              </View>
              <Text className="text-white font-bold text-xl">Tech Stack</Text>
            </View>
            <Ionicons name="arrow-forward" size={24} color="rgba(255,255,255,0.2)" />
          </TouchableOpacity>

          <TouchableOpacity onPress={() => jumpToTab('financials')} className="bg-white/5 border border-white/10 p-5 rounded-3xl flex-row items-center justify-between">
            <View className="flex-row items-center">
              <View className="bg-blue-500/20 p-3 rounded-xl mr-4">
                 <Ionicons name="card" size={24} color="#3b82f6" />
              </View>
              <Text className="text-white font-bold text-xl">Financials</Text>
            </View>
            <Ionicons name="arrow-forward" size={24} color="rgba(255,255,255,0.2)" />
          </TouchableOpacity>

          <TouchableOpacity onPress={() => jumpToTab('documents')} className="bg-white/5 border border-white/10 p-5 rounded-3xl flex-row items-center justify-between">
            <View className="flex-row items-center">
              <View className="bg-pink-500/20 p-3 rounded-xl mr-4">
                 <Ionicons name="document-text" size={24} color="#ec4899" />
              </View>
              <Text className="text-white font-bold text-xl">Doc Vault</Text>
            </View>
            <Ionicons name="arrow-forward" size={24} color="rgba(255,255,255,0.2)" />
          </TouchableOpacity>
          
        </View>

        {/* Danger Zone */}
        <TouchableOpacity onPress={requestDelete} className="p-4 rounded-3xl items-center border border-red-500/30 mb-12">
          <Text className="text-red-500 font-bold">Delete {company.name}</Text>
        </TouchableOpacity>

      </ScrollView>
    </View>
  );
}
