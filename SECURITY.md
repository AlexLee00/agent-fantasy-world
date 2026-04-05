# Security Policy

## Supported Versions

| Version | Supported |
|---------|-------------------|
| 0.x.x | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously at Agent Fantasy World. If you discover a security vulnerability,
please report it responsibly.

### How to Report

1. **DO NOT** open a public GitHub issue for security vulnerabilities
2. Email **security@afw-project.io** with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)
3. You will receive an acknowledgment within **48 hours**
4. We will work with you to understand and address the issue

### Smart Contract Vulnerabilities

For smart contract vulnerabilities, please include:
- The affected contract(s)
- The function(s) involved
- Proof of concept (if possible)
- Estimated severity (Critical / High / Medium / Low)

### Bug Bounty

We plan to launch a formal bug bounty program before mainnet.
In the meantime, significant vulnerability reports will be rewarded with $AFW tokens.

| Severity | Reward |
|----------|--------|
| Critical | 50,000 $AFW |
| High | 20,000 $AFW |
| Medium | 5,000 $AFW |
| Low | 1,000 $AFW |

### Disclosure Policy

- We follow responsible disclosure practices
- We will coordinate with reporters on disclosure timeline
- Public disclosure after fix is deployed and verified
- Credit will be given to reporters (unless anonymity is requested)

## Security Best Practices for Contributors

- Never commit secrets, private keys, or API keys
- Use `.env` files for local configuration (included in `.gitignore`)
- Follow the principle of least privilege in smart contract access control
- All smart contract changes require security review
