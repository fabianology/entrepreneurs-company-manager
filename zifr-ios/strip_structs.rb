def strip_struct(filename, struct_name)
  content = File.read(filename)
  pattern = /struct\s+#{struct_name}\s*:\s*View\s*\{/
  match = pattern.match(content)
  return unless match

  start_idx = match.begin(0)
  open_braces = 0
  end_idx = start_idx
  
  i = match.end(0) - 1
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

  preceding_text = content[0...start_idx]
  mark_pattern = /\/\/ MARK: -[^\n]*\n\z/
  mark_match = preceding_text.match(mark_pattern)
  actual_start = mark_match ? mark_match.begin(0) : start_idx

  # Remove the matched text
  content.slice!(actual_start..end_idx)
  File.write(filename, content)
  puts "Stripped #{struct_name}"
end

file = "Zifr/Views/Financial/FinancialView.swift"
structs_to_strip = [
  "EditInstitutionSheet",
  "InstitutionAccountsSection",
  "InstitutionCardsSection",
  "InstitutionLoansSection",
  "InstitutionAccountHUD",
  "LoanPaymentHUD",
  "EditCardSheet",
  "EditLoanSheet"
]

structs_to_strip.each do |struct|
  strip_struct(file, struct)
end
