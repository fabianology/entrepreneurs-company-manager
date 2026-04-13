import React from 'react';
import { View, Text, ScrollView, TouchableOpacity, Linking, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAppContext } from '../../context/AppContext';
import { CompanyDocument } from '../../types';

export default function DocumentsScreen() {
  const router = useRouter();
  const { state, selectedCompanyId } = useAppContext();

  if (!state) return null;

  const documents = selectedCompanyId 
    ? (state.documents || []).filter(d => d.companyId === selectedCompanyId)
    : (state.documents || []);

  const getTypeStyle = (type: string) => {
    switch(type) {
        case 'Formation': return 'bg-purple-500/20 text-purple-400 border-purple-500/30';
        case 'Legal': return 'bg-blue-500/20 text-blue-400 border-blue-500/30';
        case 'Contract': return 'bg-amber-500/20 text-amber-400 border-amber-500/30';
        case 'Finance': return 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30';
        default: return 'bg-white/10 text-white/70 border-white/20';
    }
  };

  const openLink = async (url?: string) => {
    if (!url) return;
    if (url.startsWith('data:')) {
      Alert.alert('Unsupported', 'Base64 file previews are unsupported in this native phase. Please migrate to deep links.');
      return;
    }
    const supported = await Linking.canOpenURL(url);
    if (supported) {
      await Linking.openURL(url);
    } else {
      Alert.alert('Error', 'Unable to open this URL.');
    }
  };

  return (
    <SafeAreaView className="flex-1 bg-black">
      <ScrollView className="flex-1 px-4">
        
        {/* Header */}
        <View className="mb-6 mt-4">
          <Text className="text-sm font-bold text-white/40 uppercase tracking-widest pl-2 mb-1">
            {selectedCompanyId ? 'Company Documents' : 'All Documents'}
          </Text>
          <Text className="text-4xl font-black text-white px-2">Doc Vault</Text>
        </View>

        {/* List */}
        <View className="mb-24 flex-row flex-wrap justify-between">
          {documents.length === 0 ? (
            <View className="w-full border border-dashed border-white/20 p-10 rounded-[32px] items-center justify-center bg-[#1C1C1E]/50 mt-4">
              <View className="bg-white/5 p-4 rounded-full mb-4 cursor-pointer">
                <Ionicons name="document-text-outline" size={32} color="rgba(255,255,255,0.4)" />
              </View>
              <Text className="text-white/40 font-bold uppercase tracking-widest text-xs">The Vault is Empty</Text>
            </View>
          ) : (
            documents.map((doc) => {
              const styleStr = getTypeStyle(doc.type);
              const [bgStyle, textStyle, borderStyle] = styleStr.split(' ');
              
              return (
                <TouchableOpacity 
                   key={doc.id}
                   onPress={() => router.push(`/document/${doc.id}`)}
                   className="w-[48%] bg-[#1C1C1E] border border-white/5 rounded-[24px] p-4 mb-4 shadow-2xl justify-between"
                >
                  <View>
                     <View className="flex-row justify-between items-start mb-3">
                       <View className={`px-2 py-1 rounded border ${bgStyle} ${borderStyle}`}>
                          <Text className={`text-[9px] font-black uppercase tracking-widest ${textStyle}`}>
                            {doc.type}
                          </Text>
                       </View>
                       {doc.url && (
                         <TouchableOpacity onPress={(e) => { e.stopPropagation(); openLink(doc.url); }}>
                           <Ionicons name="link" size={18} color="rgba(255,255,255,0.6)" />
                         </TouchableOpacity>
                       )}
                     </View>
                     <Text className="text-white font-bold text-sm mb-2 leading-tight" numberOfLines={2}>
                       {doc.name}
                     </Text>
                     <Text className="text-white/40 text-xs leading-snug mb-4" numberOfLines={3}>
                       {doc.notes || 'No description provided.'}
                     </Text>
                  </View>
                  <View className="pt-3 border-t border-white/5">
                     <Text className="text-white/30 text-[10px] font-bold tracking-widest uppercase">{doc.uploadDate}</Text>
                  </View>
                </TouchableOpacity>
              )
            })
          )}
        </View>

      </ScrollView>

      {/* Floating Action Button */}
      {selectedCompanyId && (
        <TouchableOpacity 
          onPress={() => router.push('/document/new')}
          className="absolute bottom-6 right-6 w-16 h-16 bg-[#EBC351] rounded-full items-center justify-center shadow-[0_0_20px_rgba(235,195,81,0.4)] z-50"
        >
          <Ionicons name="add" size={32} color="#000" />
        </TouchableOpacity>
      )}
    </SafeAreaView>
  );
}
