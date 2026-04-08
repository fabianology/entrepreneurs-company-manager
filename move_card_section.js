const fs = require('fs');
const file = "components/FinancialList.tsx";
const content = fs.readFileSync(file, 'utf8');
const lines = content.split('\n');

// 0-indexed line numbers
// Info section is from line 927 -> 967 approx. Wait, let's locate it by string.
const startInfoCard = lines.findIndex(l => l.includes('<div className="grid grid-cols-1 md:grid-cols-2 gap-6">'));
const startAddCardBtn = lines.findIndex(l => l.includes('button onClick={() => handleAddInstAccount(\'Credit Card\')}'));

// End of cards list is the line before "LOAN CARDS inside bank modal"
const startLoans = lines.findIndex(l => l.includes('LOAN CARDS inside bank modal'));
// Looking backwards from startLoans for the closing div
let endCardsList = startLoans - 1;
while(endCardsList > 0 && lines[endCardsList].trim() === '') {
    endCardsList--;
}
// One more for the closing div
if (lines[endCardsList].trim() === '</div>') {
    // Keep it
}

console.log('Info card start:', startInfoCard + 1);
console.log('Add card btn start:', startAddCardBtn + 1);
console.log('Cards list end:', endCardsList + 1);

const cardSection = lines.slice(startAddCardBtn, endCardsList + 1);
const beforeInfo = lines.slice(0, startInfoCard);
const infoSection = lines.slice(startInfoCard, startAddCardBtn);
const afterCards = lines.slice(endCardsList + 1);

const newLines = [...beforeInfo, ...cardSection, ...infoSection, ...afterCards];

fs.writeFileSync(file, newLines.join('\n'));
console.log('File successfully updated.');

