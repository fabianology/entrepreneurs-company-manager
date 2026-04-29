import xml.etree.ElementTree as ET
import copy

svg_path = "Assets.xcassets/miloom.console.symbolset/miloom.console.svg"
ET.register_namespace('', 'http://www.w3.org/2000/svg')
ET.register_namespace('i', 'http://ns.adobe.com/AdobeIllustrator/10.0/')

tree = ET.parse(svg_path)
root = tree.getroot()

def duplicate_line(base_id, suffix_s, suffix_m, suffix_l):
    line_s = None
    for elem in root.iter():
        if elem.attrib.get('id') == f'{base_id}-{suffix_s}':
            line_s = elem
            break
    if line_s is not None:
        line_m = copy.deepcopy(line_s)
        line_m.set('id', f'{base_id}-{suffix_m}')
        root.append(line_m)
        line_l = copy.deepcopy(line_s)
        line_l.set('id', f'{base_id}-{suffix_l}')
        root.append(line_l)

duplicate_line('right-margin', 'Regular-S', 'Regular-M', 'Regular-L')
duplicate_line('left-margin', 'Regular-S', 'Regular-M', 'Regular-L')

tree.write(svg_path, encoding='utf-8', xml_declaration=True)
