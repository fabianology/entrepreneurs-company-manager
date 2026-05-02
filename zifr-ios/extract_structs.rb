def extract_struct(filename, struct_name)
  content = File.read(filename)
  # Find the struct declaration
  pattern = /struct\s+#{struct_name}\s*:\s*View\s*\{/
  match = pattern.match(content)
  return nil unless match

  start_idx = match.begin(0)
  open_braces = 0
  end_idx = start_idx
  
  # Scan forward to find the matching closing brace
  i = match.end(0) - 1 # Position of the opening '{'
  in_string = false
  string_char = nil

  while i < content.length
    char = content[i]
    
    if in_string
      if char == string_char && content[i-1] != "\\"
        in_string = false
      end
    else
      if char == '"' || char == "'"
        in_string = true
        string_char = char
      elsif char == "{"
        open_braces += 1
      elsif char == "}"
        open_braces -= 1
        if open_braces == 0
          end_idx = i
          break
        end
      end
    end
    i += 1
  end

  # We also want to capture the // MARK: comment right before it, if any
  preceding_text = content[0...start_idx]
  mark_pattern = /\/\/ MARK: -[^\n]*\n\z/
  mark_match = preceding_text.match(mark_pattern)
  actual_start = mark_match ? mark_match.begin(0) : start_idx

  struct_code = content[actual_start..end_idx]
  return struct_code, actual_start, end_idx
end

file = "Zifr/Views/Financial/FinancialView.swift"
structs_to_extract = [
  "EditInstitutionSheet",
  "InstitutionAccountsSection",
  "InstitutionCardsSection",
  "InstitutionLoansSection",
  "InstitutionAccountHUD",
  "LoanPaymentHUD",
  "EditCardSheet",
  "EditLoanSheet"
]

structs_to_extract.each do |struct|
  code, start_idx, end_idx = extract_struct(file, struct)
  if code
    imports = "import SwiftUI\nimport SwiftData\n\n"
    File.write("Zifr/Views/Financial/#{struct}.swift", imports + code + "\n")
    puts "Extracted #{struct}."
  else
    puts "Failed to extract #{struct}."
  end
end
