import re

svg_path = "Assets.xcassets/miloom.console.symbolset/miloom.console.svg"
with open(svg_path, 'r') as f:
    content = f.read()

# Find the Regular-S group
# Since it's XML, we can just duplicate `<g id="Regular-S">...` up to the matching `</g>`
# A simpler regex approach: find the exact block for Regular-S
import xml.etree.ElementTree as ET

# Register namespaces to avoid ns0 prefixes
ET.register_namespace('', 'http://www.w3.org/2000/svg')
ET.register_namespace('i', 'http://ns.adobe.com/AdobeIllustrator/10.0/')

tree = ET.parse(svg_path)
root = tree.getroot()

# Find the group with id="Regular-S"
regular_s = None
for elem in root.iter():
    if elem.attrib.get('id') == 'Regular-S':
        regular_s = elem
        break

if regular_s is not None:
    import copy
    
    regular_m = copy.deepcopy(regular_s)
    regular_m.set('id', 'Regular-M')
    root.append(regular_m)
    
    regular_l = copy.deepcopy(regular_s)
    regular_l.set('id', 'Regular-L')
    root.append(regular_l)
    
    tree.write(svg_path, encoding='utf-8', xml_declaration=True)
    print("Successfully duplicated Regular-S to Regular-M and Regular-L.")
else:
    print("Could not find Regular-S.")
