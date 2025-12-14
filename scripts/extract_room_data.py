#!/usr/bin/env python3
"""
Extract rich data from room specification markdown files and update rooms_data.json
"""
import json
import re
from pathlib import Path

def parse_room_spec(md_path: Path) -> dict:
    """Parse a room specification markdown file and extract structured data."""
    content = md_path.read_text()
    data = {}
    
    # Extract room number from filename (room_031_the_laboratory.md -> 031)
    match = re.search(r'room_(\d+)_', md_path.name)
    if match:
        data['number'] = match.group(1)
    
    # Helper to extract section content
    def extract_section(pattern: str):
        match = re.search(pattern, content, re.IGNORECASE | re.DOTALL)
        if match:
            return match.group(1).strip()
        return None
    
    # Extract archetype (e.g., "The Filter", "The Reactor")
    archetype_match = re.search(r'\*\*Archetype:\*\*\s*(.+)', content)
    if archetype_match:
        data['archetype'] = archetype_match.group(1).strip()
    
    # Extract physics description
    physics_section = extract_section(r'## 2\. The Physics.*?\n\n(.+?)(?=\n##|\n\*\*Equation|\Z)')
    if physics_section:
        data['physics_description'] = physics_section.replace('\n', ' ').strip()
    
    # Extract equation
    equation_match = re.search(r'\*\*Equation:\*\*\s*`?(.+?)`?\n', content)
    if equation_match:
        data['equation'] = equation_match.group(1).strip()
    
    # Extract input logic
    input_match = re.search(r'\*\*Input Logic:\*\*\s*(.+)', content)
    if input_match:
        data['input_logic'] = input_match.group(1).strip()
    
    # Extract output logic
    output_match = re.search(r'\*\*Output Logic:\*\*\s*(.+)', content)
    if output_match:
        data['output_logic'] = output_match.group(1).strip()
    
    # Extract evocative quote
    quote_match = re.search(r'## 3\. The Evocative Why.*?\n\n>\s*"(.+?)"', content, re.DOTALL)
    if quote_match:
        data['evocative_quote'] = quote_match.group(1).strip().replace('\n', ' ')
    
    # Extract evocative description (paragraph after quote)
    evocative_desc = re.search(r'## 3\. The Evocative Why.*?>\s*".+?"\n\n(.+?)(?=\n##)', content, re.DOTALL)
    if evocative_desc:
        data['evocative_description'] = evocative_desc.group(1).strip().replace('\n', ' ')
    
    # Extract constraints
    constraints_section = re.search(r'## 4\. The Architecture.*?\n\n(.+?)(?=\n##)', content, re.DOTALL)
    if constraints_section:
        constraints = []
        for match in re.finditer(r'-\s*\*\*(.+?)\*\*[:\s]*(.+)', constraints_section.group(1)):
            constraints.append({
                'name': match.group(1).strip(),
                'description': match.group(2).strip()
            })
        if constraints:
            data['constraints'] = constraints
    
    # Extract altar items
    altar_section = re.search(r'## 5\. The Altar.*?\n\n(.+?)(?=\n##)', content, re.DOTALL)
    if altar_section:
        altar = []
        for match in re.finditer(r'-\s*\*\*(.+?)\*\*[:\s]*(.+)', altar_section.group(1)):
            altar.append({
                'name': match.group(1).strip(),
                'description': match.group(2).strip()
            })
        if altar:
            data['altar'] = altar
    
    # Extract liturgy
    liturgy_section = re.search(r'## 6\. The Liturgy.*?\n\n(.+?)(?=\n##)', content, re.DOTALL)
    if liturgy_section:
        liturgy = {}
        entry_match = re.search(r'\*\*Entry:\*\*\s*(.+)', liturgy_section.group(1))
        if entry_match:
            liturgy['entry'] = entry_match.group(1).strip()
        
        exit_match = re.search(r'\*\*Exit:\*\*\s*(.+)', liturgy_section.group(1))
        if exit_match:
            liturgy['exit'] = exit_match.group(1).strip()
        
        # Extract steps
        for i, match in enumerate(re.finditer(r'\*\*Step\s*\d*[:\s]*\*\*\s*(.+)', liturgy_section.group(1)), 1):
            liturgy[f'step_{i}'] = match.group(1).strip()
        
        if liturgy:
            data['liturgy'] = liturgy
    
    # Extract trap
    trap_section = re.search(r'## 7\. The Trap.*?\n\n(.+?)(?=\n##|\Z)', content, re.DOTALL)
    if trap_section:
        trap = {}
        leak_match = re.search(r'\*\*The Leak:\*\*\s*(.+)', trap_section.group(1))
        if leak_match:
            trap['leak'] = leak_match.group(1).strip()
        
        result_match = re.search(r'\*\*The Result:\*\*\s*(.+)', trap_section.group(1))
        if result_match:
            trap['result'] = result_match.group(1).strip()
        
        if trap:
            data['trap'] = trap
    
    return data


def update_rooms_data(rooms_data_path: Path, specs_dir: Path):
    """Update rooms_data.json with data from markdown specifications."""
    # Load existing data
    with open(rooms_data_path) as f:
        wings = json.load(f)
    
    # Parse all spec files
    spec_data = {}
    for spec_file in specs_dir.glob('room_*.md'):
        parsed = parse_room_spec(spec_file)
        if 'number' in parsed:
            spec_data[parsed['number']] = parsed
    
    # Update rooms in wings
    updated_count = 0
    for wing in wings:
        for room in wing['rooms']:
            number = room['number']
            if number in spec_data:
                spec = spec_data[number]
                # Add new fields (don't overwrite existing basic fields)
                for key in ['archetype', 'physics_description', 'equation', 'input_logic', 
                           'output_logic', 'evocative_quote', 'evocative_description',
                           'constraints', 'altar', 'liturgy', 'trap']:
                    if key in spec:
                        room[key] = spec[key]
                updated_count += 1
    
    # Save updated data
    with open(rooms_data_path, 'w') as f:
        json.dump(wings, f, indent=4)
    
    print(f"Updated {updated_count} rooms with rich data from specifications")


if __name__ == '__main__':
    base = Path('/Users/hariprasanna/Workspace/castle')
    rooms_data = base / 'castle/Resources/rooms_data.json'
    specs = base / 'rooms/specifications'
    
    update_rooms_data(rooms_data, specs)
