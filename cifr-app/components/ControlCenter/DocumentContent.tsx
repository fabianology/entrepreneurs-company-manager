import React from 'react';
import { View, Text, TouchableOpacity, Linking, Alert } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAppContext } from '../../context/AppContext';
import { CompanyDocument } from '../../types';

interface DocumentContentProps {
  onAddDocument: () => void;
}

const getTypeStyle = (type: string) => {
  switch(type) {
    case 'Formation': return { bg: 'rgba(168,85,247,0.2)', text: '#c084fc', border: 'rgba(168,85,247,0.3)' };
    case 'Legal': return { bg: 'rgba(59,130,246,0.2)', text: '#60a5fa', border: 'rgba(59,130,246,0.3)' };
    case 'Contract': return { bg: 'rgba(245,158,11,0.2)', text: '#fbbf24', border: 'rgba(245,158,11,0.3)' };
    case 'Finance': return { bg: 'rgba(16,185,129,0.2)', text: '#34d399', border: 'rgba(16,185,129,0.3)' };
    default: return { bg: 'rgba(255,255,255,0.1)', text: 'rgba(255,255,255,0.7)', border: 'rgba(255,255,255,0.2)' };
  }
};

export default function DocumentContent({ onAddDocument }: DocumentContentProps) {
  const router = useRouter();
  const { state, selectedCompanyId } = useAppContext();

  const documents = (state?.documents || []).filter(d => d.companyId === selectedCompanyId);

  if (documents.length === 0) {
    return (
      <TouchableOpacity 
        onPress={onAddDocument}
        style={{
          borderWidth: 1,
          borderColor: 'rgba(255,255,255,0.1)',
          borderStyle: 'dashed',
          borderRadius: 24,
          padding: 32,
          alignItems: 'center',
          justifyContent: 'center',
          marginHorizontal: 16,
          marginTop: 16
        }}
      >
        <Ionicons name="document-text-outline" size={48} color="rgba(255,255,255,0.2)" />
        <Text style={{ color: 'rgba(255,255,255,0.4)', marginTop: 12, fontSize: 16, fontWeight: '500' }}>
          The Vault is Empty
        </Text>
        <Text style={{ color: 'rgba(255,255,255,0.3)', marginTop: 4, fontSize: 14 }}>
          Tap to add your first document
        </Text>
      </TouchableOpacity>
    );
  }

  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', paddingHorizontal: 16, marginTop: 16 }}>
      {documents.map((doc: CompanyDocument) => {
        const typeStyle = getTypeStyle(doc.type);
        const uploadDate = doc.uploadDate ? new Date(doc.uploadDate).toLocaleDateString() : 'Unknown Date';

        return (
          <TouchableOpacity 
            key={doc.id}
            onPress={() => router.push(`/document/${doc.id}`)}
            style={{
              width: '48%',
              backgroundColor: '#1C1C1E',
              borderWidth: 1,
              borderColor: 'rgba(255,255,255,0.05)',
              borderRadius: 24,
              padding: 16,
              marginBottom: 16
            }}
          >
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
              <View style={{
                backgroundColor: typeStyle.bg,
                paddingHorizontal: 8,
                paddingVertical: 4,
                borderRadius: 8,
                borderWidth: 1,
                borderColor: typeStyle.border
              }}>
                <Text style={{ color: typeStyle.text, fontSize: 10, fontWeight: '600' }}>
                  {doc.type}
                </Text>
              </View>
              {doc.url && (
                <TouchableOpacity onPress={() => Linking.openURL(doc.url!).catch(() => Alert.alert('Error', 'Could not open URL'))}>
                  <Ionicons name="link" size={16} color="rgba(255,255,255,0.5)" />
                </TouchableOpacity>
              )}
            </View>

            <Text style={{ color: '#fff', fontSize: 13, fontWeight: '600', marginBottom: 4 }} numberOfLines={2}>
              {doc.name}
            </Text>

            {doc.notes ? (
              <Text style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12, marginBottom: 12 }} numberOfLines={3}>
                {doc.notes}
              </Text>
            ) : null}

            <View style={{ marginTop: 'auto', flexDirection: 'row', alignItems: 'center', paddingTop: 8, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.05)' }}>
              <Ionicons name="calendar-outline" size={12} color="rgba(255,255,255,0.3)" style={{ marginRight: 4 }} />
              <Text style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10 }}>
                {uploadDate}
              </Text>
            </View>
          </TouchableOpacity>
        );
      })}
    </View>
  );
}
