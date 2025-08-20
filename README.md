# SkillForge 🔨⚡

*A decentralized platform for skill verification, peer learning, and trustless freelance collaboration*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Stacks](https://img.shields.io/badge/Built%20on-Stacks-purple)](https://stacks.co)
[![Clarity](https://img.shields.io/badge/Smart%20Contracts-Clarity-blue)](https://clarity-lang.org)

## 🌟 Overview

SkillForge revolutionizes how professionals prove their skills, learn from peers, and collaborate on projects. Instead of relying on centralized platforms that take large fees, SkillForge uses blockchain technology to create verifiable skill credentials, enable peer-to-peer learning, and facilitate trustless project collaborations with built-in escrow and reputation systems.

### Key Benefits

- **🔐 Trustless Verification**: Blockchain-based skill credentials that can't be faked
- **💰 Lower Fees**: Decentralized architecture eliminates middleman fees
- **🤝 Peer Learning**: Community-driven skill development and mentorship
- **⚖️ Fair Disputes**: Decentralized arbitration by qualified peers
- **🏆 Reputation System**: Build lasting professional reputation on-chain
- **🔒 Privacy First**: Selective disclosure of skills and achievements

## 🏗️ Architecture

SkillForge is built on the Stacks blockchain using Clarity smart contracts, providing Bitcoin-level security with smart contract functionality.

### Core Components

\`\`\`
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Frontend DApp  │    │   IPFS Storage  │    │  Stacks Network │
│                 │    │                 │    │                 │
│ • React/Next.js │◄──►│ • Portfolios    │◄──►│ • Smart         │
│ • Web3 Auth     │    │ • Evidence      │    │   Contracts     │
│ • Stacks.js     │    │ • Metadata      │    │ • STX/BTC       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
\`\`\`

## 📋 Smart Contract Features

### 1. Skill Verification Contract
- **Skill NFT Minting**: Create unique NFTs representing verified skills (e.g., "React Developer Level 3")
- **Peer Validation System**: Allow other verified users to stake tokens to validate someone's skill demonstration
- **Skill Challenges**: Create and manage coding challenges, design tasks, or other skill-based tests
- **Evidence Storage**: Store IPFS hashes of portfolios, code repositories, and project demonstrations
- **Skill Decay Mechanism**: Implement time-based skill relevance (skills need periodic re-validation)

### 2. Reputation & Trust Contract
- **Reputation Scoring**: Calculate and store reputation scores based on completed projects and peer reviews
- **Trust Network**: Build web-of-trust relationships between users
- **Slashing Mechanism**: Penalize users who provide false validations or fail to deliver on commitments
- **Reputation Staking**: Allow users to stake their reputation on others' skills or project outcomes

### 3. Project Escrow Contract
- **Multi-milestone Escrow**: Lock funds for projects with multiple deliverable milestones
- **Dispute Resolution**: Implement a decentralized arbitration system using randomly selected qualified peers
- **Automatic Releases**: Release payments automatically when milestones are approved by clients
- **Emergency Withdrawal**: Allow fund recovery in case of abandoned projects (with time locks)

### 4. Learning Pool Contract
- **Study Group Formation**: Create and manage peer learning groups with shared goals
- **Knowledge Bounties**: Post bounties for creating educational content or solving learning challenges
- **Mentorship Matching**: Pair experienced users with learners based on skills and availability
- **Learning Progress Tracking**: Record and verify completion of learning milestones

### 5. Governance & DAO Contract
- **Platform Governance**: Vote on platform parameters, fee structures, and new features
- **Skill Category Management**: Community-driven addition and modification of skill categories
- **Dispute Resolution Rules**: Govern the arbitration process and penalty structures
- **Treasury Management**: Manage platform fees and community rewards distribution

### 6. Token Economics Contract
- **SKILL Token**: Native utility token for staking, governance, and platform fees
- **Staking Rewards**: Distribute rewards to users who stake on skill validations
- **Fee Distribution**: Share platform revenue with active community members
- **Liquidity Mining**: Reward early adopters and active participants

### 7. Identity & Privacy Contract
- **Decentralized Identity**: Link wallet addresses to professional identities while maintaining privacy
- **Selective Disclosure**: Allow users to prove specific skills without revealing full portfolio
- **Anonymous Skill Challenges**: Enable skill testing without revealing identity until after completion
- **Professional Verification**: Optional integration with traditional credential systems

### 8. Marketplace Contract
- **Project Posting**: Create and manage freelance project listings with detailed requirements
- **Skill-based Matching**: Automatically match projects with qualified freelancers
- **Bid Management**: Handle competitive bidding with skill-weighted proposals
- **Success Fee Distribution**: Distribute platform fees based on project completion success

## 🚀 Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v18 or higher)
- [Clarinet](https://github.com/hirosystems/clarinet) for smart contract development
- [Stacks Wallet](https://wallet.hiro.so/) for testing
- [Git](https://git-scm.com/)

### Installation

1. **Clone the repository**
   \`\`\`bash
   git clone https://github.com/your-org/skillforge.git
   cd skillforge
   \`\`\`

2. **Install dependencies**
   \`\`\`bash
   npm install
   \`\`\`

3. **Set up Clarinet**
   \`\`\`bash
   clarinet new skillforge-contracts
   cd skillforge-contracts
   \`\`\`

4. **Deploy contracts locally**
   \`\`\`bash
   clarinet console
   \`\`\`

5. **Start the frontend**
   \`\`\`bash
   cd ../frontend
   npm run dev
   \`\`\`

### Environment Variables

Create a `.env.local` file in the frontend directory:

\`\`\`env
NEXT_PUBLIC_STACKS_NETWORK=testnet
NEXT_PUBLIC_CONTRACT_ADDRESS=your-contract-address
NEXT_PUBLIC_IPFS_GATEWAY=https://ipfs.io/ipfs/
PINATA_API_KEY=your-pinata-key
PINATA_SECRET_KEY=your-pinata-secret
\`\`\`

## 💻 Usage Examples

### Minting a Skill NFT

\`\`\`javascript
import { StacksTestnet } from '@stacks/network';
import { makeContractCall } from '@stacks/transactions';

const mintSkill = async (skillName, level, evidenceHash) => {
  const txOptions = {
    contractAddress: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7',
    contractName: 'skill-verification',
    functionName: 'mint-skill',
    functionArgs: [
      stringAsciiCV(skillName),
      uintCV(level),
      stringAsciiCV(evidenceHash)
    ],
    network: new StacksTestnet(),
    anchorMode: AnchorMode.Any,
  };
  
  return await makeContractCall(txOptions);
};
\`\`\`

### Validating a Skill

\`\`\`javascript
const validateSkill = async (skillId, stakeAmount) => {
  const txOptions = {
    contractAddress: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7',
    contractName: 'skill-verification',
    functionName: 'validate-skill',
    functionArgs: [
      uintCV(skillId),
      uintCV(stakeAmount)
    ],
    network: new StacksTestnet(),
    anchorMode: AnchorMode.Any,
  };
  
  return await makeContractCall(txOptions);
};
\`\`\`

## 🧪 Testing

### Smart Contract Tests

\`\`\`bash
cd contracts
clarinet test
\`\`\`

### Frontend Tests

\`\`\`bash
cd frontend
npm test
\`\`\`

### Integration Tests

\`\`\`bash
npm run test:integration
\`\`\`

## 📊 Token Economics

### SKILL Token Distribution

- **Community Rewards**: 40%
- **Development Team**: 20%
- **Early Adopters**: 15%
- **Ecosystem Fund**: 15%
- **Advisors**: 5%
- **Marketing**: 5%

### Staking Mechanics

- **Skill Validation**: Stake SKILL tokens to validate others' skills
- **Reputation Boost**: Higher stakes increase validation weight
- **Slashing Risk**: False validations result in stake loss
- **Rewards**: Successful validators earn SKILL tokens

## 🛣️ Roadmap

### Phase 1: Foundation (Q1 2024)
- [ ] Core smart contracts deployment
- [ ] Basic skill verification system
- [ ] Simple web interface
- [ ] IPFS integration

### Phase 2: Community (Q2 2024)
- [ ] Peer validation system
- [ ] Reputation mechanics
- [ ] Learning pools
- [ ] Mobile app beta

### Phase 3: Marketplace (Q3 2024)
- [ ] Project escrow system
- [ ] Freelance marketplace
- [ ] Dispute resolution
- [ ] Advanced matching algorithms

### Phase 4: Governance (Q4 2024)
- [ ] DAO implementation
- [ ] Community governance
- [ ] Token economics optimization
- [ ] Cross-chain integration

## 🤝 Contributing

We welcome contributions from the community! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting pull requests.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Follow [Clarity best practices](https://book.clarity-lang.org/)
- Use TypeScript for frontend development
- Write comprehensive tests
- Document all public functions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with ❤️ by the SkillForge community**
