# 🎓 On-Chain Academic Transcript System

A decentralized academic credential system built on Stacks blockchain where students own their academic transcripts as NFTs, ensuring permanent, verifiable, and transferable educational records.

## 🌟 Features

- 📜 **NFT-based Transcripts**: Academic credentials stored as unique NFTs
- 🏛️ **Institution Verification**: Only verified institutions can issue transcripts  
- 🔒 **Student Ownership**: Students have full control over their academic records
- 📊 **Detailed Records**: Complete course history with grades and credits
- ✅ **Verification System**: Easy verification of transcript authenticity
- 🔄 **Transferable**: Students can transfer transcripts between wallets

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd On-Chain-Academic-Transcript-System
clarinet check
```

## 📋 Usage

### For Contract Owner

**Add Verified Institution:**
```clarity
(contract-call? .On-Chain-Academic-Transcript-System add-verified-institution 'SP1EXAMPLE...)
```

### For Institutions

**Issue Academic Transcript:**
```clarity
(contract-call? .On-Chain-Academic-Transcript-System issue-transcript
  'SP1STUDENT...  ;; student address
  "Bachelor"      ;; degree type
  "Computer Science" ;; major
  u2024          ;; graduation date
  u350           ;; GPA (out of 400)
  u120           ;; total credits
  (list 
    {course-code: "CS101", course-name: "Intro to Programming", credits: u3, grade: "A", semester: "Fall2023"}
    {course-code: "MATH201", course-name: "Calculus II", credits: u4, grade: "B+", semester: "Spring2024"}
  )
)
```

### For Students

**View Your Transcripts:**
```clarity
(contract-call? .On-Chain-Academic-Transcript-System get-student-transcripts tx-sender)
```

**Transfer Transcript:**
```clarity
(contract-call? .On-Chain-Academic-Transcript-System transfer-transcript u1 'SP1NEWOWNER...)
```

**Get GPA Summary:**
```clarity
(contract-call? .On-Chain-Academic-Transcript-System get-student-gpa-summary tx-sender)
```

### For Employers/Verifiers

**Verify Transcript:**
```clarity
(contract-call? .On-Chain-Academic-Transcript-System verify-transcript u1)
```

**Get Transcript Details:**
```clarity
(contract-call? .On-Chain-Academic-Transcript-System get-transcript-data u1)
```

**Get Course Records:**
```clarity
(contract-call? .On-Chain-Academic-Transcript-System get-course-records u1)
```

## 🏗️ Contract Structure

### Data Storage
- **NFTs**: Each transcript is a unique NFT owned by the student
- **Transcript Data**: Degree info, GPA, credits, graduation date
- **Course Records**: Detailed course history with grades
- **Institution Registry**: Verified institutions that can issue transcripts

### Key Functions
- `issue-transcript`: Create new academic transcript NFT
- `transfer-transcript`: Transfer ownership between wallets  
- `verify-transcript`: Validate transcript authenticity
- `add-verified-institution`: Register authorized institutions

## 🔐 Security Features

- ✅ Only verified institutions can issue transcripts
- ✅ Students maintain full ownership of their credentials
- ✅ Immutable records prevent tampering
- ✅ Public verification without exposing private data

## 📊 Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Transcript not found |
| u102 | Already exists |
| u103 | Invalid grade |
| u104 | Not owner |
| u105 | Institution not verified |

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🎯 Future Enhancements

- 🌐 Multi-institution degree programs
- 📱 Mobile wallet integration  
- 🔍 Advanced search and filtering
- 📈 Analytics dashboard for institutions
- 🌍 International credential recognition
```

**Git Commit Message:**
```
Add complete on-chain academic transcript system with NFT-based credentials
```

**GitHub Pull Request Title:**
```
🎓 Implement On-Chain Academic Transcript System with NFT Credentials
```

**GitHub Pull Request Description:**
```
## Summary
Added a complete decentralized academic transcript system where students own their educational credentials as NFTs on the Stacks blockchain.

## What's Added
- ✅ NFT-based academic transcript system
- ✅ Institution verification and authorization
- ✅ Complete transcript data storage (GPA, courses, credits)
- ✅ Student ownership and transfer capabilities  
- ✅ Public verification system for employers
- ✅ Comprehensive course record tracking

## Key Features
- Students maintain full control over their academic records
- Only verified institutions can issue transcripts
- Immutable and tamper-proof credential storage
- Easy verification for employers and third parties
- Transferable between wallet addresses

## Files Changed
- `contracts/On-Chain-Academic-Transcript-System.clar` - Main smart contract
- `README.md` - Complete documentation and usage guide

Ready for testing and deployment on Stacks testnet.
