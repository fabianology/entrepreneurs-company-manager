import sys

def replace_in_file(filepath, old, new):
    with open(filepath, "r") as f:
        content = f.read()
    content = content.replace(old, new)
    with open(filepath, "w") as f:
        f.write(content)

replace_in_file("Zifr/Views/Company/EntityHomeView.swift", 
                'glanceBox(title: "NEXT DUE", value: sub.nextRenewal ?? "—")', 
                'glanceBox(title: "NEXT DUE", value: sub.nextRenewal?.withOrdinal ?? "—")')

replace_in_file("Zifr/Views/Subscriptions/SubscriptionReceiptView.swift", 
                'Text(sub.nextRenewal ?? "—")', 
                'Text(sub.nextRenewal?.withOrdinal ?? "—")')

replace_in_file("Zifr/Views/Subscriptions/SubscriptionListView.swift", 
                'Text(sub.nextRenewal ?? "—")', 
                'Text(sub.nextRenewal?.withOrdinal ?? "—")')

