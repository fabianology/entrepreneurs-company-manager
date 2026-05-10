import re

with open("Zifr/Views/Subscriptions/SubscriptionListView.swift", "r") as f:
    content = f.read()

# Replace ScrollView + LazyVStack
content = re.sub(r'ScrollView \{\s*LazyVStack\(spacing: 0\) \{', r'MiloomListView {', content)

# Remove the action bar's horizontal padding
content = content.replace('.padding(.horizontal, 20)\n                .padding(.top, 15)\n                .padding(.bottom, 20)', '.padding(.top, 15)\n                .padding(.bottom, 8)')

# Remove padding from SubscriptionCardView call
content = content.replace('.padding(.horizontal, 20)\n                            .padding(.bottom, 16)', '')

# Remove trailing ScrollView modifiers
content = content.replace('            }\n            .padding(.bottom, 120)\n        }\n        .scrollIndicators(.hidden)', '            }\n')

with open("Zifr/Views/Subscriptions/SubscriptionListView.swift", "w") as f:
    f.write(content)
